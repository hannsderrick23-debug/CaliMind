import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum FocusSessionPhase { idle, focusing, paused, onBreak, completed }

@immutable
class FocusSessionSnapshot {
  const FocusSessionSnapshot({
    required this.phase,
    required this.focusElapsed,
    required this.breakElapsed,
    required this.breaksEnabled,
    this.taskId,
    this.taskTitle,
    this.focusTarget,
    this.breakTarget,
    this.startedAt,
  });

  final FocusSessionPhase phase;
  final Duration focusElapsed;
  final Duration breakElapsed;
  final bool breaksEnabled;
  final String? taskId;
  final String? taskTitle;
  final Duration? focusTarget;
  final Duration? breakTarget;
  final DateTime? startedAt;

  bool get isActive =>
      phase == FocusSessionPhase.focusing ||
      phase == FocusSessionPhase.paused ||
      phase == FocusSessionPhase.onBreak;

  static const idle = FocusSessionSnapshot(
    phase: FocusSessionPhase.idle,
    focusElapsed: Duration.zero,
    breakElapsed: Duration.zero,
    breaksEnabled: false,
  );
}

abstract interface class FocusSessionStorage {
  Future<String?> read();
  Future<void> write(String value);
  Future<void> clear();
}

class SharedPreferencesFocusSessionStorage implements FocusSessionStorage {
  SharedPreferencesFocusSessionStorage({this.key = 'focus_session_v1'});

  final String key;

  @override
  Future<String?> read() async =>
      (await SharedPreferences.getInstance()).getString(key);

  @override
  Future<void> write(String value) async {
    await (await SharedPreferences.getInstance()).setString(key, value);
  }

  @override
  Future<void> clear() async {
    await (await SharedPreferences.getInstance()).remove(key);
  }
}

/// Tracks a focus timer independently from task completion.
///
/// Running intervals are persisted as timestamps, so [restore] includes time
/// spent while the app was closed. Pauses and breaks are persisted separately.
class FocusSessionController extends ChangeNotifier {
  FocusSessionController({
    required FocusSessionStorage storage,
    DateTime Function()? clock,
    Duration tickInterval = const Duration(seconds: 1),
  })  : _storage = storage,
        _clock = clock ?? DateTime.now,
        _tickInterval = tickInterval;

  final FocusSessionStorage _storage;
  final DateTime Function() _clock;
  final Duration _tickInterval;

  FocusSessionPhase _phase = FocusSessionPhase.idle;
  String? _taskId;
  String? _taskTitle;
  Duration? _focusTarget;
  Duration? _breakTarget;
  DateTime? _startedAt;
  DateTime? _phaseStartedAt;
  Duration _focusElapsed = Duration.zero;
  Duration _breakElapsed = Duration.zero;
  bool _breaksEnabled = false;
  bool _pausedDuringBreak = false;
  Timer? _ticker;
  bool _disposed = false;
  FocusSessionSnapshot _snapshot = FocusSessionSnapshot.idle;

  FocusSessionSnapshot get snapshot {
    _updateSnapshot();
    return _snapshot;
  }

  Future<void> restore() async {
    final encoded = await _storage.read();
    if (encoded == null) return;

    try {
      final data = jsonDecode(encoded) as Map<String, dynamic>;
      _phase = FocusSessionPhase.values.byName(data['phase'] as String);
      _taskId = data['taskId'] as String?;
      _taskTitle = data['taskTitle'] as String?;
      _focusTarget = _durationFromMillis(data['focusTargetMs']);
      _breakTarget = _durationFromMillis(data['breakTargetMs']);
      _startedAt = _dateFromString(data['startedAt']);
      _phaseStartedAt = _dateFromString(data['phaseStartedAt']);
      _focusElapsed = Duration(
        milliseconds: data['focusElapsedMs'] as int? ?? 0,
      );
      _breakElapsed = Duration(
        milliseconds: data['breakElapsedMs'] as int? ?? 0,
      );
      _breaksEnabled = data['breaksEnabled'] as bool? ?? false;
      _pausedDuringBreak = data['pausedDuringBreak'] as bool? ?? false;
      _updateSnapshot();
      _syncTicker();
      notifyListeners();
    } on Object {
      await _storage.clear();
      await reset();
    }
  }

  Future<void> start({
    String? taskId,
    String? taskTitle,
    Duration? focusTarget,
    bool breaksEnabled = false,
    Duration? breakTarget,
  }) async {
    _phase = FocusSessionPhase.focusing;
    _taskId = taskId;
    _taskTitle = taskTitle;
    _focusTarget = focusTarget;
    _breakTarget = breaksEnabled ? breakTarget : null;
    _startedAt = _clock();
    _phaseStartedAt = _startedAt;
    _focusElapsed = Duration.zero;
    _breakElapsed = Duration.zero;
    _breaksEnabled = breaksEnabled;
    _pausedDuringBreak = false;
    await _commit();
  }

  Future<void> pause() async {
    if (_phase != FocusSessionPhase.focusing &&
        _phase != FocusSessionPhase.onBreak) {
      return;
    }
    _captureRunningInterval();
    _pausedDuringBreak = _phase == FocusSessionPhase.onBreak;
    _phase = FocusSessionPhase.paused;
    _phaseStartedAt = null;
    await _commit();
  }

  Future<void> resume() async {
    if (_phase != FocusSessionPhase.paused) return;
    _phase = _pausedDuringBreak
        ? FocusSessionPhase.onBreak
        : FocusSessionPhase.focusing;
    _pausedDuringBreak = false;
    _phaseStartedAt = _clock();
    await _commit();
  }

  Future<void> startBreak() async {
    if (!_breaksEnabled) {
      throw StateError('Breaks are not enabled for this focus session.');
    }
    if (_phase != FocusSessionPhase.focusing) return;
    _captureRunningInterval();
    _phase = FocusSessionPhase.onBreak;
    _phaseStartedAt = _clock();
    await _commit();
  }

  Future<void> endBreak() async {
    if (_phase != FocusSessionPhase.onBreak) return;
    _captureRunningInterval();
    _phase = FocusSessionPhase.focusing;
    _phaseStartedAt = _clock();
    await _commit();
  }

  Future<void> finish() async {
    if (!_snapshot.isActive) return;
    if (_phase == FocusSessionPhase.focusing ||
        _phase == FocusSessionPhase.onBreak) {
      _captureRunningInterval();
    }
    _phase = FocusSessionPhase.completed;
    _phaseStartedAt = null;
    await _commit();
  }

  Future<void> reset() async {
    _ticker?.cancel();
    _ticker = null;
    _phase = FocusSessionPhase.idle;
    _taskId = null;
    _taskTitle = null;
    _focusTarget = null;
    _breakTarget = null;
    _startedAt = null;
    _phaseStartedAt = null;
    _focusElapsed = Duration.zero;
    _breakElapsed = Duration.zero;
    _breaksEnabled = false;
    _pausedDuringBreak = false;
    _updateSnapshot();
    await _storage.clear();
    if (!_disposed) notifyListeners();
  }

  void _captureRunningInterval() {
    final phaseStartedAt = _phaseStartedAt;
    if (phaseStartedAt == null) return;
    final interval = _clock().difference(phaseStartedAt);
    if (_phase == FocusSessionPhase.focusing) {
      _focusElapsed += interval;
    } else if (_phase == FocusSessionPhase.onBreak) {
      _breakElapsed += interval;
    }
  }

  Duration _currentFocusElapsed() {
    if (_phase != FocusSessionPhase.focusing || _phaseStartedAt == null) {
      return _focusElapsed;
    }
    return _focusElapsed + _clock().difference(_phaseStartedAt!);
  }

  Duration _currentBreakElapsed() {
    if (_phase != FocusSessionPhase.onBreak || _phaseStartedAt == null) {
      return _breakElapsed;
    }
    return _breakElapsed + _clock().difference(_phaseStartedAt!);
  }

  Future<void> _commit() async {
    _updateSnapshot();
    _syncTicker();
    await _storage.write(_encode());
    if (!_disposed) notifyListeners();
  }

  void _updateSnapshot() {
    _snapshot = FocusSessionSnapshot(
      phase: _phase,
      focusElapsed: _currentFocusElapsed(),
      breakElapsed: _currentBreakElapsed(),
      breaksEnabled: _breaksEnabled,
      taskId: _taskId,
      taskTitle: _taskTitle,
      focusTarget: _focusTarget,
      breakTarget: _breakTarget,
      startedAt: _startedAt,
    );
  }

  String _encode() => jsonEncode({
        'phase': _phase.name,
        'taskId': _taskId,
        'taskTitle': _taskTitle,
        'focusTargetMs': _focusTarget?.inMilliseconds,
        'breakTargetMs': _breakTarget?.inMilliseconds,
        'startedAt': _startedAt?.toUtc().toIso8601String(),
        'phaseStartedAt': _phaseStartedAt?.toUtc().toIso8601String(),
        'focusElapsedMs': _focusElapsed.inMilliseconds,
        'breakElapsedMs': _breakElapsed.inMilliseconds,
        'breaksEnabled': _breaksEnabled,
        'pausedDuringBreak': _pausedDuringBreak,
      });

  void _syncTicker() {
    final running = _phase == FocusSessionPhase.focusing ||
        _phase == FocusSessionPhase.onBreak;
    if (running && _ticker == null) {
      _ticker = Timer.periodic(_tickInterval, (_) {
        _updateSnapshot();
        if (!_disposed) notifyListeners();
      });
    } else if (!running) {
      _ticker?.cancel();
      _ticker = null;
    }
  }

  static DateTime? _dateFromString(Object? value) =>
      value is String ? DateTime.tryParse(value) : null;

  static Duration? _durationFromMillis(Object? value) =>
      value is int ? Duration(milliseconds: value) : null;

  @override
  void dispose() {
    _disposed = true;
    _ticker?.cancel();
    super.dispose();
  }
}
