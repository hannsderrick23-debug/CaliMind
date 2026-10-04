import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:calimind/core/services/task_reminder_service.dart';

class PushDeliveryResult {
  final bool delivered;
  final String message;

  const PushDeliveryResult({required this.delivered, required this.message});
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
  String? _firebaseUnavailableReason;

  bool get isFirebaseAvailable => _firebaseAvailable;

  String get firebaseUnavailableMessage =>
      'Local reminders are available, but cloud push could not initialize'
      '${_firebaseUnavailableReason == null ? '' : ' ($_firebaseUnavailableReason)'}. '
      'Add the Android Firebase client configuration at '
      'android/app/google-services.json, then rebuild.';

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    try {
      await Firebase.initializeApp();
      _firebaseAvailable = true;
      _messageSubscription = FirebaseMessaging.onMessage.listen(
        _showForegroundMessage,
      );
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
      _authSubscription = Supabase.instance.client.auth.onAuthStateChange
          .listen((event) {
            if (event.session != null) {
              _deviceRegistration = _registerCurrentDevice();
            }
          });
      if (Supabase.instance.client.auth.currentUser != null) {
        _deviceRegistration = _registerCurrentDevice();
      }
    } on FirebaseException catch (error) {
      _firebaseUnavailableReason = error.code;
      debugPrint(
        'Firebase push is unavailable (${error.code}). Push function calls are skipped; local reminders remain available. Check android/app/google-services.json and the Firebase Android app configuration.',
      );
    } catch (error) {
      _firebaseUnavailableReason = error.runtimeType.toString();
      debugPrint(
        'Firebase push initialization failed ($error). Push function calls are skipped; local reminders remain available. Check android/app/google-services.json and the Firebase Android app configuration.',
      );
    }
  }

  Future<bool> unregisterCurrentDevice() async {
    if (!_firebaseAvailable) return true;
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) return true;
      await Supabase.instance.client.functions.invoke(
        'push-notifications',
        body: {'action': 'unregister', 'token': token},
      );
      return true;
    } catch (error) {
      debugPrint(
        'Could not unregister this device for push notifications: $error',
      );
      return false;
    }
  }

  Future<String?> configureNotifications(bool enabled) async {
    if (enabled && !await _localNotifications.requestPermission()) {
      return 'Allow notifications in device settings to turn reminders on.';
    }
    await _localNotifications.setNotificationsEnabled(enabled);
    if (enabled) {
      if (!_firebaseAvailable) return firebaseUnavailableMessage;
      _deviceRegistration = _registerCurrentDevice();
      await _deviceRegistration;
    } else {
      if (!await unregisterCurrentDevice()) {
        return 'Local reminders are off, but cloud notifications could not be disconnected. Try again while online.';
      }
    }
    return null;
  }

  Future<PushDeliveryResult> notifyScheduleGenerated({
    required String scheduleDate,
    required int scheduledTaskCount,
  }) async {
    if (!await _localNotifications.areNotificationsEnabled()) {
      return const PushDeliveryResult(
        delivered: false,
        message: 'Notifications are turned off in Settings.',
      );
    }
    try {
      await _deviceRegistration;
      debugPrint(
        'Calling push-notifications Edge Function for schedule_generated.',
      );
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
            ? _firebaseAvailable
                  ? 'No registered devices can receive push notifications.'
                  : 'The Edge Function received the request, but this device is not registered for push. $firebaseUnavailableMessage'
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
      if (!await _localNotifications.areNotificationsEnabled()) {
        debugPrint(
          'Push registration skipped: notifications are disabled in CaliMind settings.',
        );
        return;
      }
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        debugPrint(
          'Push registration deferred: no authenticated Supabase user is available yet.',
        );
        return;
      }
      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        debugPrint('Push notifications are disabled by the device owner.');
        return;
      }
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) {
        debugPrint(
          'Push registration failed: Firebase returned no device token.',
        );
        return;
      }
      await _registerToken(token);
    } catch (error) {
      debugPrint(
        'Could not register this device for push notifications: $error',
      );
    }
  }

  Future<void> _registerToken(String token) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      debugPrint(
        'Push registration skipped: there is no authenticated Supabase user.',
      );
      return;
    }
    try {
      debugPrint(
        'Calling push-notifications Edge Function to register this device.',
      );
      await Supabase.instance.client.functions.invoke(
        'push-notifications',
        body: {'action': 'register', 'token': token},
      );
      debugPrint('push-notifications device registration request completed.');
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
