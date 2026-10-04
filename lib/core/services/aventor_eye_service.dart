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

class AventorEyeService {
  AventorEyeService._();

  static final instance = AventorEyeService._();
  static const _enabledKey = 'aventor_eye_enabled';
  static const _cachePrefix = 'aventor_eye_cache_';
  static final ValueNotifier<bool?> enabled = ValueNotifier<bool?>(null);

  Future<bool> isEnabled() async {
    final current = enabled.value;
    if (current != null) return current;
    final preferences = await SharedPreferences.getInstance();
    final saved = preferences.getBool(_enabledKey) ?? false;
    enabled.value = saved;
    return saved;
  }

  Future<void> setEnabled(bool value) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_enabledKey, value);
    enabled.value = value;
    if (!value) {
      for (final key in preferences.getKeys()) {
        if (key.startsWith(_cachePrefix)) {
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

  Future<List<AventorEyeInsight>> getInsights({
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

    final localNow = (now ?? DateTime.now()).toLocal();
    final localDate = DateTime(date.year, date.month, date.day);
    final snapshot = _snapshot(
      tasks: tasks,
      slots: slots,
      date: localDate,
      now: localNow,
      busyIntervals: busyIntervals,
    );
    final cacheKey = '$_cachePrefix${_dateKey(localDate)}_'
        '${_fingerprint(jsonEncode(snapshot))}';
    final preferences = await SharedPreferences.getInstance();
    if (!forceRefresh) {
      final cached = preferences.getString(cacheKey);
      if (cached != null) return _decodeCards(cached);
    }

    final response = await Supabase.instance.client.functions.invoke(
      'aventor-eye',
      body: snapshot,
    );
    final data = response.data;
    if (data is! Map || data['cards'] is! List) {
      throw const FormatException('Aventor Eye returned an invalid response.');
    }
    final cards = _decodeCards(jsonEncode(data['cards']));
    final dayPrefix = '$_cachePrefix${_dateKey(localDate)}_';
    for (final key in preferences.getKeys()) {
      if (key.startsWith(dayPrefix) && key != cacheKey) {
        await preferences.remove(key);
      }
    }
    await preferences.setString(
      cacheKey,
      jsonEncode(cards.map((card) => card.toJson()).toList()),
    );
    return cards;
  }

  List<AventorEyeInsight> _decodeCards(String encoded) {
    final decoded = jsonDecode(encoded);
    if (decoded is! List || decoded.length > 3) {
      throw const FormatException('Aventor Eye returned invalid insight cards.');
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
    final relevantTasks = tasks.where((task) {
      if (task.completed) return false;
      final deadline = task.deadline?.toLocal();
      return deadline == null || _dateKey(deadline).compareTo(dateKey) <= 0;
    }).toList()
      ..sort((a, b) {
        final byPriority = a.priority.compareTo(b.priority);
        if (byPriority != 0) return byPriority;
        return (a.deadline?.toIso8601String() ?? '')
            .compareTo(b.deadline?.toIso8601String() ?? '');
      });

    return {
      'local_date': dateKey,
      'local_time':
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
      'tasks': relevantTasks.take(40).map((task) {
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
      }).toList(growable: false),
      'schedule': slots.take(40).map((slot) {
        final title = slot.taskTitle.trim();
        return {
          'title': title.substring(0, title.length.clamp(0, 120)),
          'category': slot.category.label,
          'start_time': slot.startTime,
          'end_time': slot.endTime,
        };
      }).toList(growable: false),
      'busy_intervals': busyIntervals.map((interval) {
        String time(DateTime value) =>
            '${value.hour.toString().padLeft(2, '0')}:'
            '${value.minute.toString().padLeft(2, '0')}';
        return {
          'start_time': time(interval.start.toLocal()),
          'end_time': time(interval.end.toLocal()),
        };
      }).toList(growable: false),
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
