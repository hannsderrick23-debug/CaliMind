import 'dart:io';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:calimind/domain/models/calendar_busy_interval.dart';

enum DeviceCalendarAccessStatus {
  disabled,
  notRequested,
  granted,
  denied,
  restricted,
  unsupported,
  error,
}

class DeviceCalendarBusyResult {
  final DeviceCalendarAccessStatus status;
  final List<CalendarBusyInterval> intervals;

  DeviceCalendarBusyResult({
    required this.status,
    List<CalendarBusyInterval> intervals = const [],
  }) : intervals = List.unmodifiable(intervals);
}

class DeviceCalendarService {
  static const _enabledPreferenceKey = 'device_calendar_busy_times_enabled';
  static const _readOnlyCalendarChannel =
      MethodChannel('com.calimind/device_calendar_read_only');

  static bool get supportsReadOnlyCalendarAccess => Platform.isAndroid;

  DeviceCalendarService();

  Future<bool> isEnabled() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getBool(_enabledPreferenceKey) ?? false;
  }

  Future<DeviceCalendarAccessStatus> enableAfterUserAction() async {
    if (!Platform.isAndroid) return DeviceCalendarAccessStatus.unsupported;
    try {
      final response = await _readOnlyCalendarChannel
          .invokeMapMethod<String, dynamic>('requestReadPermission');
      final status = _statusFromPlatform(response?['status'] as String?);
      if (status != DeviceCalendarAccessStatus.granted) {
        await _setEnabled(false);
        return status;
      }
      await _setEnabled(true);
      return status;
    } on PlatformException catch (error) {
      await _setEnabled(false);
      return _statusFromMessage('${error.code} ${error.message}');
    } on Exception {
      await _setEnabled(false);
      return DeviceCalendarAccessStatus.error;
    }
  }

  Future<void> disable() async {
    await _setEnabled(false);
  }

  Future<void> _setEnabled(bool enabled) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_enabledPreferenceKey, enabled);
  }

  Future<DeviceCalendarBusyResult> getBusyIntervalsForDay(
    DateTime selectedDay,
  ) async {
    if (!Platform.isAndroid) {
      return DeviceCalendarBusyResult(
        status: DeviceCalendarAccessStatus.unsupported,
      );
    }
    if (!await isEnabled()) {
      return DeviceCalendarBusyResult(
        status: DeviceCalendarAccessStatus.disabled,
      );
    }

    final rangeStart =
        DateTime(selectedDay.year, selectedDay.month, selectedDay.day);
    final rangeEnd =
        DateTime(selectedDay.year, selectedDay.month, selectedDay.day + 1);

    try {
      final permissionResponse = await _readOnlyCalendarChannel
          .invokeMapMethod<String, dynamic>('permissionStatus');
      final permissionStatus =
          _statusFromPlatform(permissionResponse?['status'] as String?);
      if (permissionStatus != DeviceCalendarAccessStatus.granted) {
        await _setEnabled(false);
        return DeviceCalendarBusyResult(status: permissionStatus);
      }

      final response = await _readOnlyCalendarChannel
          .invokeMapMethod<String, dynamic>('getBusyIntervals', {
        'startMillis': rangeStart.millisecondsSinceEpoch,
        'endMillis': rangeEnd.millisecondsSinceEpoch,
      });
      final status = _statusFromPlatform(response?['status'] as String?);
      if (status != DeviceCalendarAccessStatus.granted) {
        return DeviceCalendarBusyResult(status: status);
      }
      final intervals = (response?['intervals'] as List<dynamic>? ?? [])
          .whereType<Map<dynamic, dynamic>>()
          .map((interval) => CalendarBusyInterval.fromEventTimes(
                start: DateTime.fromMillisecondsSinceEpoch(
                  (interval['startMillis'] as num).toInt(),
                ),
                end: DateTime.fromMillisecondsSinceEpoch(
                  (interval['endMillis'] as num).toInt(),
                ),
                rangeStart: rangeStart,
                rangeEnd: rangeEnd,
              ))
          .whereType<CalendarBusyInterval>()
          .toList(growable: false);
      return DeviceCalendarBusyResult(
        status: status,
        intervals: intervals,
      );
    } on PlatformException catch (error) {
      await _setEnabled(false);
      return DeviceCalendarBusyResult(
        status: _statusFromMessage('${error.code} ${error.message}'),
      );
    } on Exception {
      await _setEnabled(false);
      return DeviceCalendarBusyResult(
        status: DeviceCalendarAccessStatus.error,
      );
    }
  }

  DeviceCalendarAccessStatus _statusFromPlatform(String? status) {
    switch (status) {
      case 'granted':
        return DeviceCalendarAccessStatus.granted;
      case 'notRequested':
        return DeviceCalendarAccessStatus.notRequested;
      case 'denied':
        return DeviceCalendarAccessStatus.denied;
      case 'restricted':
        return DeviceCalendarAccessStatus.restricted;
      case 'unsupported':
        return DeviceCalendarAccessStatus.unsupported;
      default:
        return DeviceCalendarAccessStatus.error;
    }
  }

  DeviceCalendarAccessStatus _statusFromMessage(String message) {
    final normalized = message.toLowerCase();
    if (normalized.contains('restrict') ||
        normalized.contains('parental') ||
        normalized.contains('screen time')) {
      return DeviceCalendarAccessStatus.restricted;
    }
    if (normalized.contains('denied') ||
        normalized.contains('not authorized') ||
        normalized.contains('permission')) {
      return DeviceCalendarAccessStatus.denied;
    }
    if (Platform.isAndroid || Platform.isIOS) {
      return DeviceCalendarAccessStatus.error;
    }
    return DeviceCalendarAccessStatus.restricted;
  }
}
