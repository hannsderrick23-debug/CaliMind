import 'dart:io';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PhoneClockAlarmService {
  static const _enabledPreferenceKey = 'phone_clock_alarm_integration_enabled';
  static const _channel = MethodChannel('com.calimind/phone_clock_alarm');

  static bool get isSupported => Platform.isAndroid;

  Future<bool> isEnabled() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getBool(_enabledPreferenceKey) ?? false;
  }

  Future<void> setEnabled(bool enabled) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_enabledPreferenceKey, enabled);
  }

  Future<bool> openAlarm({
    required int hour,
    required int minute,
    required String label,
  }) async {
    if (!isSupported) return false;
    if (!await isEnabled()) {
      throw PlatformException(
        code: 'integration_disabled',
        message: 'Enable phone Clock alarms in Settings first.',
      );
    }
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) {
      throw ArgumentError('A valid alarm time is required.');
    }
    return await _channel.invokeMethod<bool>('openAlarm', {
          'hour': hour,
          'minute': minute,
          'label': label,
        }) ??
        false;
  }
}
