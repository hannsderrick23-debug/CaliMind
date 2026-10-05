import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/models/schedule_slot.dart';
import '../../domain/models/calendar_busy_interval.dart';
import '../../domain/models/task.dart';

enum AventorEyeInsightKind { focus, balance, celebrate, reset }

class AventorEyeInsight {
  const AventorEyeInsight({
    required this.kind,
    required this.title,
    required this.message,
  });

  final AventorEyeInsightKind kind;
  final String title;
  final String message;

  factory AventorEyeInsight.fromJson(Map<String, dynamic> json) {
    final kind = AventorEyeInsightKind.values.firstWhere(
      (value) => value.name == json['kind'],
      orElse: () => throw const FormatException(
        'Aventor Eye returned an invalid insight kind.',
      ),
    );
    final title = json['title'];
    final message = json['message'];
    if (title is! String ||
        title.trim().isEmpty ||
        title.length > 45 ||
        message is! String ||
        message.trim().isEmpty ||
        message.length > 120) {
      throw const FormatException('Aventor Eye returned an invalid insight.');
    }
    return AventorEyeInsight(
      kind: kind,
      title: title.trim(),
      message: message.trim(),
    );
  }

  Map<String, String> toJson() => {
    'kind': kind.name,
    'title': title,
    'message': message,
  };
}

class AventorEyeResult {
  const AventorEyeResult({
    required this.cards,
    required this.isStale,
    this.refreshFailed = false,
  });

  final List<AventorEyeInsight> cards;
  final bool isStale;
  final bool refreshFailed;
}

class _CachedAventorEyeResult {
  const _CachedAventorEyeResult({
    required this.snapshotFingerprint,
    required this.fetchedAt,
    required this.cards,
  });

  final String snapshotFingerprint;
  final DateTime fetchedAt;
  final List<AventorEyeInsight> cards;
}

class AventorEyeService {
  AventorEyeService._();

  static final instance = AventorEyeService._();
  static const _enabledKeyPrefix = 'aventor_eye_enabled_';
  static const _cachePrefix = 'aventor_eye_cache_';
  static const _latestCachePrefix = 'aventor_eye_latest_';
  static const _lastRefreshKeyPrefix = 'aventor_eye_last_refresh_at_';
  static const refreshInterval = Duration(minutes: 10);
  static final ValueNotifier<bool?> enabled = ValueNotifier<bool?>(null);
  static String? _enabledUserId;

  Future<bool> isEnabled() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      _enabledUserId = null;
      enabled.value = false;
      return false;
    }
    final current = enabled.value;
    if (current != null && _enabledUserId == userId) return current;
    final preferences = await SharedPreferences.getInstance();
    final saved = preferences.getBool('$_enabledKeyPrefix$userId') ?? false;
    if (Supabase.instance.client.auth.currentUser?.id != userId) return false;
    _enabledUserId = userId;
    enabled.value = saved;
    return saved;
  }

  Future<void> setEnabled(bool value) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('Sign in to update Aventor Eye settings.');
    }
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool('$_enabledKeyPrefix$userId', value);
    if (Supabase.instance.client.auth.currentUser?.id == userId) {
      _enabledUserId = userId;
      enabled.value = value;
    }
    if (!value) {
      for (final key in preferences.getKeys()) {
        if (key.startsWith('$_cachePrefix${userId}_') ||
            key.startsWith('$_latestCachePrefix${userId}_') ||
            key == '$_lastRefreshKeyPrefix$userId') {
          await preferences.remove(key);
        }
      }
    }
  }

  String snapshotKey({
    required List<Task> tasks,
    required List<ScheduleSlot> slots,
    required DateTime date,
    required DateTime now,
    List<CalendarBusyInterval> busyIntervals = const [],
  }) {
    final snapshot = _snapshot(
      tasks: tasks,
      slots: slots,
      date: date,
      now: now,
      busyIntervals: busyIntervals,
    );
    return '${_dateKey(date)}_${_fingerprint(jsonEncode(snapshot))}';
  }

  Future<AventorEyeResult> getInsights({
    required List<Task> tasks,
    required List<ScheduleSlot> slots,
    required DateTime date,
    DateTime? now,
    List<CalendarBusyInterval> busyIntervals = const [],
    bool forceRefresh = false,
  }) async {
    if (!await isEnabled()) {
      throw StateError('Enable Aventor Eye in Settings to request insights.');
    }
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('Sign in to refresh Aventor Eye insights.');
    }

    final localNow = (now ?? DateTime.now()).toLocal();
    final localDate = DateTime(date.year, date.month, date.day);
    final snapshot = _snapshot(
      tasks: tasks,
      slots: slots,
      date: localDate,
      now: localNow,
      busyIntervals: busyIntervals,
    );
    final requestContext = {
      'local_date': snapshot['local_date'],
      'local_time': snapshot['local_time'],
      'busy_intervals': snapshot['busy_intervals'],
    };
    final scopedDatePrefix = '$_cachePrefix${userId}_${_dateKey(localDate)}_';
    final fingerprint = _fingerprint(jsonEncode(snapshot));
    final cacheKey = '$scopedDatePrefix$fingerprint';
    final latestKey = '$_latestCachePrefix${userId}_${_dateKey(localDate)}';
    final preferences = await SharedPreferences.getInstance();
    await _removeUnscopedLegacyCache(preferences);
    if (!forceRefresh) {
      final cached = preferences.getString(cacheKey);
      if (cached != null) {
        return AventorEyeResult(cards: _decodeCards(cached), isStale: false);
      }
    }

    final latest = _readLatest(preferences.getString(latestKey));
    final lastRefresh = DateTime.tryParse(
      preferences.getString('$_lastRefreshKeyPrefix$userId') ?? '',
    )?.toLocal();
    final latestRefresh = latest?.fetchedAt;
    final mostRecentRefresh =
        lastRefresh == null ||
            (latestRefresh != null && latestRefresh.isAfter(lastRefresh))
        ? latestRefresh
        : lastRefresh;
    if (mostRecentRefresh != null) {
      final sinceRefresh = localNow.difference(mostRecentRefresh);
      if (sinceRefresh >= Duration.zero && sinceRefresh < refreshInterval) {
        if (latest != null) {
          return AventorEyeResult(
            cards: latest.cards,
            isStale: latest.snapshotFingerprint != fingerprint,
          );
        }
        throw StateError(
          'Aventor Eye will refresh automatically when its short cooldown ends.',
        );
      }
    }

    await preferences.setString(
      '$_lastRefreshKeyPrefix$userId',
      localNow.toIso8601String(),
    );
    if (Supabase.instance.client.auth.currentUser?.id != userId) {
      throw StateError('The signed-in account changed before Aventor Eye ran.');
    }
    late final List<AventorEyeInsight> cards;
    try {
      final response = await Supabase.instance.client.functions.invoke(
        'aventor-eye',
        body: requestContext,
      );
      final data = response.data;
      if (data is! Map || data['cards'] is! List) {
        throw const FormatException(
          'Aventor Eye returned an invalid response.',
        );
      }
      cards = _decodeCards(jsonEncode(data['cards']));
    } catch (error) {
      if (latest == null) rethrow;
      debugPrint('Aventor Eye refresh failed; showing cached insights: $error');
      return AventorEyeResult(
        cards: latest.cards,
        isStale: true,
        refreshFailed: true,
      );
    }
    if (Supabase.instance.client.auth.currentUser?.id != userId) {
      throw StateError(
        'The signed-in account changed while Aventor Eye was refreshing.',
      );
    }

    final dayPrefix = scopedDatePrefix;
    for (final key in preferences.getKeys()) {
      if (key.startsWith(dayPrefix) && key != cacheKey) {
        await preferences.remove(key);
      }
    }
    await preferences.setString(
      cacheKey,
      jsonEncode(cards.map((card) => card.toJson()).toList()),
    );
    await preferences.setString(
      latestKey,
      jsonEncode({
        'snapshot_fingerprint': fingerprint,
        'fetched_at': localNow.toIso8601String(),
        'cards': cards.map((card) => card.toJson()).toList(),
      }),
    );
    return AventorEyeResult(cards: cards, isStale: false);
  }

  Future<void> _removeUnscopedLegacyCache(SharedPreferences preferences) async {
    for (final key in preferences.getKeys()) {
      final isLegacyCache =
          key.startsWith(_cachePrefix) &&
          RegExp(
            r'^\d{4}-\d{2}-\d{2}_',
          ).hasMatch(key.substring(_cachePrefix.length));
      final isLegacyLatest =
          key.startsWith(_latestCachePrefix) &&
          RegExp(
            r'^\d{4}-\d{2}-\d{2}$',
          ).hasMatch(key.substring(_latestCachePrefix.length));
      if (isLegacyCache ||
          isLegacyLatest ||
          key == 'aventor_eye_last_refresh_at') {
        await preferences.remove(key);
      }
    }
  }

  _CachedAventorEyeResult? _readLatest(String? encoded) {
    if (encoded == null) return null;
    final decoded = jsonDecode(encoded);
    if (decoded is! Map<String, dynamic> ||
        decoded['snapshot_fingerprint'] is! String ||
        decoded['fetched_at'] is! String ||
        decoded['cards'] is! List) {
      throw const FormatException('Aventor Eye cache is invalid.');
    }
    return _CachedAventorEyeResult(
      snapshotFingerprint: decoded['snapshot_fingerprint'] as String,
      fetchedAt: DateTime.parse(decoded['fetched_at'] as String).toLocal(),
      cards: _decodeCards(jsonEncode(decoded['cards'])),
    );
  }

  List<AventorEyeInsight> _decodeCards(String encoded) {
    final decoded = jsonDecode(encoded);
    if (decoded is! List || decoded.length > 3) {
      throw const FormatException(
        'Aventor Eye returned invalid insight cards.',
      );
    }
    return decoded
        .map((item) {
          if (item is! Map<String, dynamic>) {
            throw const FormatException(
              'Aventor Eye returned an invalid insight.',
            );
          }
          return AventorEyeInsight.fromJson(item);
        })
        .toList(growable: false);
  }

  Map<String, Object?> _snapshot({
    required List<Task> tasks,
    required List<ScheduleSlot> slots,
    required DateTime date,
    required DateTime now,
    required List<CalendarBusyInterval> busyIntervals,
  }) {
    final dateKey = _dateKey(date);
    final userId = Supabase.instance.client.auth.currentUser?.id;
    final ownedTasks = tasks.where((task) => task.userId == userId).toList();
    final taskIds = ownedTasks.map((task) => task.id).toSet();
    final relevantTasks =
        ownedTasks.where((task) {
          if (task.completed) return false;
          final deadline = task.deadline?.toLocal();
          return deadline == null || _dateKey(deadline).compareTo(dateKey) <= 0;
        }).toList()..sort((a, b) {
          final byPriority = a.priority.compareTo(b.priority);
          if (byPriority != 0) return byPriority;
          return (a.deadline?.toIso8601String() ?? '').compareTo(
            b.deadline?.toIso8601String() ?? '',
          );
        });

    return {
      'local_date': dateKey,
      'local_time':
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
      'tasks': relevantTasks
          .take(40)
          .map((task) {
            final deadline = task.deadline?.toLocal();
            final reminder = task.reminderAt?.toLocal();
            return {
              'title': task.title.trim().substring(
                0,
                task.title.trim().length.clamp(0, 120),
              ),
              'category': task.category.label,
              'duration_minutes': task.duration.clamp(1, 1440),
              'priority': task.priority.clamp(1, 3),
              'deadline': deadline?.toIso8601String(),
              'reminder_at': reminder?.toIso8601String(),
              'specific_time': _validTime(task.specificTime)
                  ? task.specificTime
                  : null,
            };
          })
          .toList(growable: false),
      'schedule': slots
          .where((slot) => taskIds.contains(slot.taskId))
          .take(40)
          .map((slot) {
            final title = slot.taskTitle.trim();
            return {
              'title': title.substring(0, title.length.clamp(0, 120)),
              'category': slot.category.label,
              'start_time': slot.startTime,
              'end_time': slot.endTime,
            };
          })
          .toList(growable: false),
      'busy_intervals': busyIntervals
          .map((interval) {
            String time(DateTime value) =>
                '${value.hour.toString().padLeft(2, '0')}:'
                '${value.minute.toString().padLeft(2, '0')}';
            return {
              'start_time': time(interval.start.toLocal()),
              'end_time': time(interval.end.toLocal()),
            };
          })
          .toList(growable: false),
    };
  }

  bool _validTime(String? time) =>
      time != null && RegExp(r'^([01]\d|2[0-3]):[0-5]\d$').hasMatch(time);

  String _dateKey(DateTime date) {
    final local = date.toLocal();
    return '${local.year.toString().padLeft(4, '0')}-'
        '${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')}';
  }

  String _fingerprint(String value) {
    var hash = BigInt.parse('14695981039346656037');
    const prime = 1099511628211;
    final mask = (BigInt.one << 64) - BigInt.one;
    for (final byte in utf8.encode(value)) {
      hash = ((hash ^ BigInt.from(byte)) * BigInt.from(prime)) & mask;
    }
    return hash.toRadixString(16).padLeft(16, '0');
  }
}
