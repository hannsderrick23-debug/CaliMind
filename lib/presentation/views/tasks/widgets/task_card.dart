import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:share_plus/share_plus.dart';
import 'package:calimind/core/constants/app_colors.dart';
import 'package:calimind/core/constants/app_typography.dart';
import 'package:calimind/core/utils/app_feedback.dart';
import 'package:calimind/core/utils/haptic_feedback_utils.dart';
import 'package:calimind/domain/models/task.dart';
import 'package:calimind/presentation/state/task_provider.dart';

class TaskCard extends ConsumerWidget {
  final Task task;
  final VoidCallback? onEdit;

  const TaskCard({super.key, required this.task, this.onEdit});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = task.category.color;

    return Dismissible(
      key: ValueKey(task.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) async {
        await HapticFeedbackUtils.heavyImpact();
        final deleted =
            await ref.read(taskProvider.notifier).deleteTask(task.id);
        if (context.mounted) {
          if (deleted) {
            AppFeedback.success(
              ScaffoldMessenger.of(context),
              'Task deleted.',
            );
          } else {
            AppFeedback.error(
              ScaffoldMessenger.of(context),
              'Could not delete this task. Please try again.',
            );
          }
        }
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        decoration: BoxDecoration(
          color: CaliMindColors.destructive.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(LucideIcons.trash2,
            color: CaliMindColors.destructive, size: 22),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: CaliMindColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: CaliMindColors.cardBorder),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: () async {
                      await HapticFeedbackUtils.mediumImpact();
                      final notifier = ref.read(taskProvider.notifier);
                      final changed = await notifier.toggleCompletion(
                        task.id,
                        !task.completed,
                      );
                      if (context.mounted) {
                        if (changed) {
                          AppFeedback.success(
                            ScaffoldMessenger.of(context),
                            task.completed
                                ? 'Task moved back to Active.'
                                : 'Task marked complete.',
                          );
                        } else {
                          AppFeedback.error(
                            ScaffoldMessenger.of(context),
                            _taskUpdateError(notifier),
                          );
                        }
                      }
                    },
                    child: AnimatedContainer(
                      duration: 200.ms,
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: task.completed ? color : Colors.transparent,
                        border: Border.all(
                          color: task.completed
                              ? color
                              : CaliMindColors.mutedForeground,
                          width: 1.8,
                        ),
                      ),
                      child: task.completed
                          ? const Icon(
                              LucideIcons.check,
                              color: Colors.white,
                              size: 15,
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: InkWell(
                      onTap: onEdit,
                      child: Text(
                        task.title,
                        style: CaliMindTypography.bodyMedium.copyWith(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          decoration: task.completed
                              ? TextDecoration.lineThrough
                              : null,
                          color: task.completed
                              ? CaliMindColors.mutedForeground
                              : CaliMindColors.foreground,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _PriorityBadge(priority: task.priority),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _CategoryBadge(category: task.category),
                  _TaskMeta(
                    icon: LucideIcons.clock,
                    value: _formatDuration(task.duration),
                  ),
                  if (task.specificTime != null)
                    _TaskMeta(
                      icon: LucideIcons.alarmClock,
                      value: task.specificTime!,
                    ),
                ],
              ),
              if (task.deadline != null || task.reminderAt != null) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  runSpacing: 5,
                  children: [
                    if (task.deadline != null)
                      _TaskDateLabel(
                        icon: LucideIcons.calendarClock,
                        value:
                            'Due ${DateFormat('MMM d, h:mm a').format(task.deadline!.toLocal())}',
                      ),
                    if (task.reminderAt != null)
                      _TaskDateLabel(
                        icon: LucideIcons.bell,
                        value:
                            'Reminder ${DateFormat('MMM d, h:mm a').format(task.reminderAt!.toLocal())}',
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _actionButton(
                      label: task.completed ? 'Reopen' : 'Complete',
                      icon: task.completed
                          ? LucideIcons.rotateCcw
                          : LucideIcons.circleCheck,
                      color: CaliMindColors.success,
                      onPressed: () async {
                        final notifier = ref.read(taskProvider.notifier);
                        final changed = await notifier.toggleCompletion(
                          task.id,
                          !task.completed,
                        );
                        if (!context.mounted) return;
                        if (changed) {
                          AppFeedback.success(
                            ScaffoldMessenger.of(context),
                            task.completed
                                ? 'Task moved back to Active.'
                                : 'Task marked complete.',
                          );
                        } else {
                          AppFeedback.error(
                            ScaffoldMessenger.of(context),
                            _taskUpdateError(notifier),
                          );
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: _actionButton(
                      label: 'Edit',
                      icon: LucideIcons.pencil,
                      color: CaliMindColors.primary,
                      onPressed: onEdit,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: _actionButton(
                      label: 'Delete',
                      icon: LucideIcons.trash2,
                      color: CaliMindColors.destructive,
                      onPressed: () => _confirmDelete(context, ref),
                    ),
                  ),
                ],
              ),
              if (task.category == TaskCategory.classRep) ...[
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () => _shareAnnouncement(context),
                    icon: const Icon(LucideIcons.share2, size: 15),
                    label: const Text('Share'),
                    style: TextButton.styleFrom(
                      foregroundColor: CaliMindColors.mutedForeground,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    ).animate().fadeIn(duration: 350.ms).slideX(begin: 0.05);
  }

  Widget _actionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback? onPressed,
  }) =>
      TextButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 15),
        label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        style: TextButton.styleFrom(
          foregroundColor: color,
          minimumSize: const Size(0, 42),
          padding: const EdgeInsets.symmetric(horizontal: 4),
          textStyle: CaliMindTypography.bodySmall.copyWith(
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(11),
            side: BorderSide(color: color.withValues(alpha: 0.22)),
          ),
          backgroundColor: color.withValues(alpha: 0.06),
        ),
      );

  String _formatDuration(int minutes) {
    if (minutes < 60) return '${minutes}m';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return m == 0 ? '${h}h' : '${h}h ${m}m';
  }

  String _taskUpdateError(TaskNotifier notifier) {
    final error = notifier.lastOperationError;
    return error == null || error.isEmpty
        ? 'Could not update this task. Please try again.'
        : 'Could not update task: $error';
  }

  Future<void> _shareAnnouncement(BuildContext context) async {
    final text =
        '📢 [Class Rep Announcement]\n\n${task.title}\n${task.description ?? ''}\n\nShared via CaliMind';
    await Share.share(text, subject: task.title);
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete task?'),
        content: Text('“${task.title}” will be removed from your task list.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      final deleted = await ref.read(taskProvider.notifier).deleteTask(task.id);
      if (context.mounted) {
        if (deleted) {
          AppFeedback.success(
            ScaffoldMessenger.of(context),
            'Task deleted.',
          );
        } else {
          AppFeedback.error(
            ScaffoldMessenger.of(context),
            'Could not delete this task. Please try again.',
          );
        }
      }
    }
  }
}

class _TaskMeta extends StatelessWidget {
  final IconData icon;
  final String value;

  const _TaskMeta({required this.icon, required this.value});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: CaliMindColors.mutedForeground),
          const SizedBox(width: 4),
          Text(
            value,
            style: CaliMindTypography.bodySmall.copyWith(
              color: CaliMindColors.foreground,
              fontSize: 11,
            ),
          ),
        ],
      );
}

class _PriorityBadge extends StatelessWidget {
  final int priority;
  const _PriorityBadge({required this.priority});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (priority) {
      1 => ('P1 · High', CaliMindColors.destructive),
      2 => ('P2 · Medium', CaliMindColors.warning),
      _ => ('P3 · Low', CaliMindColors.mutedForeground),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: CaliMindTypography.bodySmall.copyWith(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _TaskDateLabel extends StatelessWidget {
  final IconData icon;
  final String value;

  const _TaskDateLabel({required this.icon, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11, color: CaliMindColors.mutedForeground),
        const SizedBox(width: 4),
        Text(value, style: CaliMindTypography.bodySmall.copyWith(fontSize: 10)),
      ],
    );
  }
}

class _CategoryBadge extends StatelessWidget {
  final TaskCategory category;
  const _CategoryBadge({required this.category});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(category.icon, size: 11, color: category.color),
        const SizedBox(width: 4),
        Text(
          category.label,
          style: CaliMindTypography.bodySmall.copyWith(
            fontSize: 10,
            color: category.color,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
