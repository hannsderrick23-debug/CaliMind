import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/utils/haptic_feedback_utils.dart';
import '../../../domain/models/task.dart';
import '../../state/task_provider.dart';

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
        await ref.read(taskProvider.notifier).deleteTask(task.id);
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        decoration: BoxDecoration(
          color: CaliMindColors.destructive.withOpacity(0.15),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(LucideIcons.trash2, color: CaliMindColors.destructive, size: 22),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: CaliMindColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border(
            left: BorderSide(color: color, width: 3.5),
            top: BorderSide(color: CaliMindColors.cardBorder),
            right: BorderSide(color: CaliMindColors.cardBorder),
            bottom: BorderSide(color: CaliMindColors.cardBorder),
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onEdit,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                // Completion check
                GestureDetector(
                  onTap: () async {
                    await HapticFeedbackUtils.mediumImpact();
                    await ref.read(taskProvider.notifier).toggleCompletion(task.id, !task.completed);
                  },
                  child: AnimatedContainer(
                    duration: 200.ms,
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: task.completed ? color : Colors.transparent,
                      border: Border.all(
                        color: task.completed ? color : CaliMindColors.mutedForeground,
                        width: 1.8,
                      ),
                    ),
                    child: task.completed
                        ? const Icon(LucideIcons.check, color: Colors.white, size: 14)
                        : null,
                  ),
                ),
                const SizedBox(width: 12),
                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              task.title,
                              style: CaliMindTypography.bodyMedium.copyWith(
                                fontWeight: FontWeight.w600,
                                decoration: task.completed ? TextDecoration.lineThrough : null,
                                color: task.completed ? CaliMindColors.mutedForeground : CaliMindColors.foreground,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          _PriorityBadge(priority: task.priority),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          _CategoryBadge(category: task.category),
                          const SizedBox(width: 8),
                          Icon(LucideIcons.clock, size: 11, color: CaliMindColors.mutedForeground),
                          const SizedBox(width: 4),
                          Text(
                            _formatDuration(task.duration),
                            style: CaliMindTypography.bodySmall.copyWith(fontSize: 11),
                          ),
                          if (task.specificTime != null) ...[
                            const SizedBox(width: 8),
                            Icon(LucideIcons.alarm, size: 11, color: CaliMindColors.mutedForeground),
                            const SizedBox(width: 4),
                            Text(task.specificTime!, style: CaliMindTypography.timeMonospace.copyWith(fontSize: 11)),
                          ],
                          const Spacer(),
                          // Share button for Class Rep
                          if (task.category == TaskCategory.classRep)
                            GestureDetector(
                              onTap: () => _shareAnnouncement(context),
                              child: Icon(LucideIcons.share2, size: 15, color: CaliMindColors.catClass),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ).animate().fadeIn(duration: 350.ms).slideX(begin: 0.05);
  }

  String _formatDuration(int minutes) {
    if (minutes < 60) return '${minutes}m';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return m == 0 ? '${h}h' : '${h}h ${m}m';
  }

  Future<void> _shareAnnouncement(BuildContext context) async {
    final text = '📢 [Class Rep Announcement]\n\n${task.title}\n${task.description ?? ''}\n\nShared via CaliMind';
    await Share.share(text, subject: task.title);
  }
}

class _PriorityBadge extends StatelessWidget {
  final int priority;
  const _PriorityBadge({required this.priority});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (priority) {
      1 => ('P1', CaliMindColors.destructive),
      2 => ('P2', CaliMindColors.warning),
      _ => ('P3', CaliMindColors.mutedForeground),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
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
