import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:calimind/core/services/notification_inbox_service.dart';

final notificationInboxServiceProvider = Provider<NotificationInboxService>(
  (ref) => NotificationInboxService.instance,
);

final notificationInboxChangesProvider = StreamProvider.autoDispose<String>(
  (ref) => ref.watch(notificationInboxServiceProvider).changes,
);

final notificationInboxProvider = FutureProvider.autoDispose
    .family<List<InboxNotification>, String>((ref, userId) {
      return ref.watch(notificationInboxServiceProvider).getForUser(userId);
    });
