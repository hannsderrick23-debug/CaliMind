import 'dart:async';
import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';

class InboxNotification {
  const InboxNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.event,
    required this.receivedAt,
    required this.isRead,
    this.taskId,
    this.scheduleDate,
  });

  final String id;
  final String title;
  final String body;
  final String event;
  final DateTime receivedAt;
  final bool isRead;
  final String? taskId;
  final String? scheduleDate;

  InboxNotification copyWith({bool? isRead}) => InboxNotification(
    id: id,
    title: title,
    body: body,
    event: event,
    receivedAt: receivedAt,
    isRead: isRead ?? this.isRead,
    taskId: taskId,
    scheduleDate: scheduleDate,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'body': body,
    'event': event,
    'received_at': receivedAt.toIso8601String(),
    'is_read': isRead,
    'task_id': taskId,
    'schedule_date': scheduleDate,
  };

  factory InboxNotification.fromJson(Object? value) {
    if (value is! Map) throw const FormatException('Invalid notification.');
    final json = Map<String, dynamic>.from(value);
    final id = json['id'];
    final title = json['title'];
    final body = json['body'];
    final event = json['event'];
    final receivedAt = DateTime.tryParse(json['received_at'] as String? ?? '');
    if (id is! String ||
        title is! String ||
        body is! String ||
        event is! String ||
        receivedAt == null) {
      throw const FormatException('Invalid notification.');
    }
    return InboxNotification(
      id: id,
      title: title,
      body: body,
      event: event,
      receivedAt: receivedAt.toLocal(),
      isRead: json['is_read'] == true,
      taskId: json['task_id'] as String?,
      scheduleDate: json['schedule_date'] as String?,
    );
  }
}

class NotificationInboxService {
  NotificationInboxService._();

  static final instance = NotificationInboxService._();
  static const _keyPrefix = 'calimind_notification_inbox_v1_';
  static const _maxEntries = 50;

  final StreamController<String> _changes =
      StreamController<String>.broadcast();

  Stream<String> get changes => _changes.stream;

  Future<List<InboxNotification>> getForUser(String userId) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.reload();
    final encoded = preferences.getString('$_keyPrefix$userId');
    if (encoded == null) return const [];

    try {
      final decoded = jsonDecode(encoded);
      if (decoded is! List) return const [];
      final notifications = <InboxNotification>[];
      for (final value in decoded) {
        try {
          notifications.add(InboxNotification.fromJson(value));
        } on FormatException {
          continue;
        } on TypeError {
          continue;
        }
      }
      notifications.sort((a, b) => b.receivedAt.compareTo(a.receivedAt));
      return notifications;
    } on FormatException {
      return const [];
    }
  }

  Future<void> recordPush(RemoteMessage message) async {
    final userId = message.data['recipient_user_id'];
    final title = message.notification?.title ?? message.data['title'];
    final body = message.notification?.body ?? message.data['body'];
    if (userId is! String ||
        userId.isEmpty ||
        title is! String ||
        title.trim().isEmpty ||
        body is! String ||
        body.trim().isEmpty) {
      return;
    }

    final receivedAt = (message.sentTime ?? DateTime.now()).toLocal();
    final notification = InboxNotification(
      id: message.messageId ?? '${receivedAt.microsecondsSinceEpoch}',
      title: title.trim(),
      body: body.trim(),
      event: message.data['event'] as String? ?? 'push',
      receivedAt: receivedAt,
      isRead: false,
      taskId: message.data['task_id'] as String?,
      scheduleDate: message.data['schedule_date'] as String?,
    );
    final current = await getForUser(userId);
    if (current.any((item) => item.id == notification.id)) return;
    await _write(userId, [notification, ...current].take(_maxEntries).toList());
  }

  Future<void> markAllRead(String userId) async {
    final current = await getForUser(userId);
    if (!current.any((item) => !item.isRead)) return;
    await _write(
      userId,
      current.map((item) => item.copyWith(isRead: true)).toList(),
    );
  }

  Future<void> markRead(String userId, String notificationId) async {
    final current = await getForUser(userId);
    final index = current.indexWhere((item) => item.id == notificationId);
    if (index < 0 || current[index].isRead) return;
    final updated = [...current];
    updated[index] = updated[index].copyWith(isRead: true);
    await _write(userId, updated);
  }

  Future<void> clear(String userId) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove('$_keyPrefix$userId');
    _changes.add(userId);
  }

  Future<void> _write(
    String userId,
    List<InboxNotification> notifications,
  ) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      '$_keyPrefix$userId',
      jsonEncode(notifications.map((item) => item.toJson()).toList()),
    );
    _changes.add(userId);
  }
}
