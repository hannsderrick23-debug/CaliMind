import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:calimind/core/services/notification_inbox_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  test('stores each push once under its recipient account', () async {
    final service = NotificationInboxService.instance;
    const message = RemoteMessage(
      messageId: 'push-1',
      notification: RemoteNotification(
        title: 'Task reminder',
        body: 'Review calculus notes',
      ),
      data: {
        'recipient_user_id': 'account-a',
        'event': 'task_reminder',
        'task_id': 'task-1',
      },
    );

    await service.recordPush(message);
    await service.recordPush(message);

    final accountA = await service.getForUser('account-a');
    expect(accountA, hasLength(1));
    expect(accountA.single.title, 'Task reminder');
    expect(accountA.single.taskId, 'task-1');
    expect(await service.getForUser('account-b'), isEmpty);
  });

  test(
    'marks notifications read and clears only that account history',
    () async {
      final service = NotificationInboxService.instance;
      const message = RemoteMessage(
        messageId: 'push-2',
        notification: RemoteNotification(
          title: 'Schedule ready',
          body: 'Today',
        ),
        data: {'recipient_user_id': 'account-a', 'event': 'schedule_generated'},
      );
      await service.recordPush(message);
      await service.markRead('account-a', 'push-2');

      expect((await service.getForUser('account-a')).single.isRead, isTrue);

      await service.clear('account-a');
      expect(await service.getForUser('account-a'), isEmpty);
    },
  );
}
