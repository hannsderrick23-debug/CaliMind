import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:calimind/core/services/task_reminder_service.dart';

class PushDeliveryResult {
  final bool delivered;
  final String message;

  const PushDeliveryResult({
    required this.delivered,
    required this.message,
  });
}

class PushNotificationService {
  PushNotificationService._();

  static final PushNotificationService instance = PushNotificationService._();

  final TaskReminderService _localNotifications = TaskReminderService();
  StreamSubscription<AuthState>? _authSubscription;
  StreamSubscription<String>? _tokenSubscription;
  StreamSubscription<RemoteMessage>? _messageSubscription;
  StreamSubscription<RemoteMessage>? _openedSubscription;
  Future<void> _deviceRegistration = Future<void>.value();
  bool _initialized = false;
  bool _firebaseAvailable = false;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    try {
      await Firebase.initializeApp();
      _firebaseAvailable = true;
      _messageSubscription =
          FirebaseMessaging.onMessage.listen(_showForegroundMessage);
      _openedSubscription = FirebaseMessaging.onMessageOpenedApp.listen(
        (message) => debugPrint(
          'Push notification opened: ${message.messageId ?? 'unknown message'}',
        ),
      );
      _tokenSubscription = FirebaseMessaging.instance.onTokenRefresh.listen(
        _registerToken,
        onError: (Object error) =>
            debugPrint('Could not refresh the Firebase push token: $error'),
      );
      _authSubscription =
          Supabase.instance.client.auth.onAuthStateChange.listen((event) {
        if (event.session != null) {
          _deviceRegistration = _registerCurrentDevice();
        }
      });
      if (Supabase.instance.client.auth.currentUser != null) {
        _deviceRegistration = _registerCurrentDevice();
      }
    } on FirebaseException catch (error) {
      debugPrint(
        'Firebase push is not configured (${error.code}); local reminders remain available.',
      );
    } catch (error) {
      debugPrint(
        'Firebase push initialization failed: $error. Local reminders remain available.',
      );
    }
  }

  Future<void> unregisterCurrentDevice() async {
    if (!_firebaseAvailable) return;
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) return;
      await Supabase.instance.client.functions.invoke(
        'push-notifications',
        body: {'action': 'unregister', 'token': token},
      );
    } catch (error) {
      debugPrint('Could not unregister this device for push notifications: $error');
    }
  }

  Future<PushDeliveryResult> notifyScheduleGenerated({
    required String scheduleDate,
    required int scheduledTaskCount,
  }) async {
    if (!_firebaseAvailable) {
      return const PushDeliveryResult(
        delivered: false,
        message: 'Push notifications are not configured on this device.',
      );
    }

    try {
      await _deviceRegistration;
      final response = await Supabase.instance.client.functions.invoke(
        'push-notifications',
        body: {
          'action': 'schedule_generated',
          'schedule_date': scheduleDate,
          'task_count': scheduledTaskCount,
        },
      );
      final data = response.data;
      if (data is Map && data['delivered'] == true) {
        return const PushDeliveryResult(
          delivered: true,
          message: 'Schedule notification sent.',
        );
      }
      final reason = data is Map ? data['reason'] : null;
      return PushDeliveryResult(
        delivered: false,
        message: reason == 'no_registered_devices'
            ? 'No registered devices can receive push notifications.'
            : 'The schedule was created, but its push notification was not delivered.',
      );
    } catch (error) {
      debugPrint('Could not send schedule push notification: $error');
      return const PushDeliveryResult(
        delivered: false,
        message:
            'The schedule was created, but its push notification could not be sent.',
      );
    }
  }

  Future<void> _registerCurrentDevice() async {
    if (!_firebaseAvailable) return;
    try {
      final settings =
          await FirebaseMessaging.instance.requestPermission(alert: true, badge: true, sound: true);
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        debugPrint('Push notifications are disabled by the device owner.');
        return;
      }
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) await _registerToken(token);
    } catch (error) {
      debugPrint('Could not register this device for push notifications: $error');
    }
  }

  Future<void> _registerToken(String token) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    try {
      await Supabase.instance.client.functions.invoke(
        'push-notifications',
        body: {'action': 'register', 'token': token},
      );
    } catch (error) {
      debugPrint('Could not save the Firebase push token: $error');
    }
  }

  Future<void> _showForegroundMessage(RemoteMessage message) async {
    final notification = message.notification;
    final title = notification?.title ?? message.data['title'] as String?;
    final body = notification?.body ?? message.data['body'] as String?;
    if (title == null || body == null) return;

    await _localNotifications.showNotification(
      id: message.messageId?.hashCode ?? DateTime.now().millisecondsSinceEpoch,
      title: title,
      body: body,
    );
  }

  Future<void> dispose() async {
    await _authSubscription?.cancel();
    await _tokenSubscription?.cancel();
    await _messageSubscription?.cancel();
    await _openedSubscription?.cancel();
  }
}
