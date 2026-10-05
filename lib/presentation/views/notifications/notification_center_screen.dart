import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:calimind/core/constants/app_colors.dart';
import 'package:calimind/core/constants/app_typography.dart';
import 'package:calimind/core/services/notification_inbox_service.dart';
import 'package:calimind/domain/models/task.dart';
import 'package:calimind/presentation/state/auth_provider.dart';
import 'package:calimind/presentation/state/notification_inbox_provider.dart';
import 'package:calimind/presentation/state/task_provider.dart';
import 'package:calimind/presentation/widgets/star_loading_indicator.dart';

class NotificationCenterScreen extends ConsumerWidget {
  const NotificationCenterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = ref.watch(authProvider.select((state) => state.user?.id));
    if (userId == null) {
      return const Scaffold(body: Center(child: StarLoadingIndicator()));
    }

    ref.listen(notificationInboxChangesProvider, (previous, next) {
      if (next.valueOrNull == userId) {
        ref.invalidate(notificationInboxProvider(userId));
      }
    });

    final inbox = ref.watch(notificationInboxProvider(userId));
    final tasks = ref.watch(taskProvider).valueOrNull ?? const <Task>[];
    final now = DateTime.now();
    final upcoming =
        tasks
            .where(
              (task) =>
                  !task.completed &&
                  task.reminderAt != null &&
                  task.reminderAt!.isAfter(now),
            )
            .toList()
          ..sort((a, b) => a.reminderAt!.compareTo(b.reminderAt!));

    final notifications = inbox.valueOrNull ?? const <InboxNotification>[];
    final hasUnread = notifications.any((item) => !item.isRead);

    return Scaffold(
      appBar: AppBar(
        title: Text('Notifications', style: CaliMindTypography.h2),
        actions: [
          if (hasUnread)
            IconButton(
              tooltip: 'Mark all as read',
              onPressed: () => _markAllRead(ref, userId),
              icon: const Icon(LucideIcons.checkCheck),
            ),
          if (notifications.isNotEmpty)
            IconButton(
              tooltip: 'Clear notification history',
              onPressed: () => _clearHistory(context, ref, userId),
              icon: const Icon(LucideIcons.trash2),
            ),
        ],
      ),
      body: inbox.when(
        loading: () => const Center(child: StarLoadingIndicator(size: 28)),
        error: (error, _) => Center(
          child: Text(
            'Could not load notifications. Pull to refresh and try again.',
            style: CaliMindTypography.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ),
        data: (items) => RefreshIndicator(
          color: CaliMindColors.primary,
          onRefresh: () async {
            await ref.refresh(notificationInboxProvider(userId).future);
            await ref.read(taskProvider.notifier).loadTasks();
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              if (upcoming.isNotEmpty) ...[
                _SectionTitle(
                  title: 'Upcoming reminders',
                  count: upcoming.length,
                ),
                const SizedBox(height: 10),
                for (final task in upcoming.take(12))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _NotificationTile(
                      icon: LucideIcons.bellRing,
                      title: task.title,
                      body: DateFormat(
                        'EEE, MMM d · h:mm a',
                      ).format(task.reminderAt!.toLocal()),
                      onTap: () =>
                          context.push('/tasks/${task.id}', extra: task),
                    ),
                  ),
                const SizedBox(height: 20),
              ],
              if (items.isNotEmpty) ...[
                _SectionTitle(
                  title: 'Recent notifications',
                  count: items.length,
                ),
                const SizedBox(height: 10),
                for (final item in items)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _NotificationTile(
                      icon: _iconForEvent(item.event),
                      title: item.title,
                      body: item.body,
                      timestamp: DateFormat(
                        'EEE, MMM d · h:mm a',
                      ).format(item.receivedAt.toLocal()),
                      unread: !item.isRead,
                      onTap: () =>
                          _openNotification(context, ref, userId, item, tasks),
                    ),
                  ),
              ] else if (upcoming.isEmpty)
                const _EmptyNotifications(),
            ],
          ),
        ),
      ),
    );
  }

  IconData _iconForEvent(String event) => switch (event) {
    'task_reminder' => LucideIcons.bellRing,
    'schedule_generated' => LucideIcons.calendarCheck,
    _ => LucideIcons.bell,
  };

  Future<void> _markAllRead(WidgetRef ref, String userId) async {
    await ref.read(notificationInboxServiceProvider).markAllRead(userId);
    ref.invalidate(notificationInboxProvider(userId));
  }

  Future<void> _clearHistory(
    BuildContext context,
    WidgetRef ref,
    String userId,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Clear notification history?'),
        content: const Text(
          'This removes recent notifications from this device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(notificationInboxServiceProvider).clear(userId);
    ref.invalidate(notificationInboxProvider(userId));
  }

  Future<void> _openNotification(
    BuildContext context,
    WidgetRef ref,
    String userId,
    InboxNotification item,
    List<Task> tasks,
  ) async {
    await ref.read(notificationInboxServiceProvider).markRead(userId, item.id);
    ref.invalidate(notificationInboxProvider(userId));
    if (item.event == 'schedule_generated') {
      context.go('/dashboard?tab=schedule');
      return;
    }
    final taskId = item.taskId;
    if (taskId == null) return;
    for (final task in tasks) {
      if (task.id == taskId) {
        context.push('/tasks/$taskId', extra: task);
        return;
      }
    }
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.count});

  final String title;
  final int count;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(child: Text(title, style: CaliMindTypography.h3)),
      Text('$count', style: CaliMindTypography.label),
    ],
  );
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.icon,
    required this.title,
    required this.body,
    this.timestamp,
    this.unread = false,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String body;
  final String? timestamp;
  final bool unread;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: CaliMindColors.card,
    borderRadius: BorderRadius.circular(8),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: CaliMindColors.cardBorder),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: CaliMindColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 18, color: CaliMindColors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: CaliMindTypography.bodyMedium.copyWith(
                      fontWeight: unread ? FontWeight.w700 : FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    body,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: CaliMindTypography.bodySmall.copyWith(
                      color: CaliMindColors.mutedForeground,
                    ),
                  ),
                  if (timestamp != null) ...[
                    const SizedBox(height: 5),
                    Text(
                      timestamp!,
                      style: CaliMindTypography.label.copyWith(
                        color: CaliMindColors.mutedForeground,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (unread) ...[
              const SizedBox(width: 10),
              const Icon(
                LucideIcons.dot,
                size: 20,
                color: CaliMindColors.primary,
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

class _EmptyNotifications extends StatelessWidget {
  const _EmptyNotifications();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 70, horizontal: 24),
    child: Column(
      children: [
        const Icon(
          LucideIcons.bell,
          size: 34,
          color: CaliMindColors.mutedForeground,
        ),
        const SizedBox(height: 14),
        Text('You’re all caught up.', style: CaliMindTypography.h3),
        const SizedBox(height: 5),
        Text(
          'New reminders and schedule updates will appear here.',
          textAlign: TextAlign.center,
          style: CaliMindTypography.bodySmall.copyWith(
            color: CaliMindColors.mutedForeground,
          ),
        ),
      ],
    ),
  );
}
