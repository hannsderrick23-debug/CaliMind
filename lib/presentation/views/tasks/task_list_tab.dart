import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:calimind/core/constants/app_colors.dart';
import 'package:calimind/core/constants/app_typography.dart';
import 'package:calimind/domain/models/task.dart';
import 'package:calimind/presentation/state/role_focus_provider.dart';
import 'package:calimind/presentation/state/schedule_provider.dart';
import 'package:calimind/presentation/state/task_provider.dart';
import 'package:calimind/presentation/widgets/weekly_progress_widget.dart';
import 'package:calimind/presentation/widgets/aventor_eye_feed.dart';
import 'task_input_sheet.dart';
import 'widgets/task_card.dart';

class TaskListTab extends ConsumerWidget {
  const TaskListTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(taskProvider);
    final focus = ref.watch(roleFocusProvider);
    final schedule = ref.watch(scheduleProvider);

    return tasksAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: CaliMindColors.primary),
      ),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Could not load tasks: ${taskOperationErrorMessage(e)}',
            textAlign: TextAlign.center,
            style: CaliMindTypography.bodyMedium,
          ),
        ),
      ),
      data: (allTasks) {
        final filtered = focus == null
            ? allTasks
            : allTasks.where((t) => t.category == focus).toList();

        final active = filtered.where((t) => !t.completed).toList();
        final done = filtered.where((t) => t.completed).toList();

        if (filtered.isEmpty) {
          return _buildEmptyState(context, focus);
        }

        return RefreshIndicator(
          color: CaliMindColors.primary,
          backgroundColor: CaliMindColors.card,
          onRefresh: () => ref.read(taskProvider.notifier).loadTasks(),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
            children: [
              AventorEyeFeed(
                tasks: allTasks,
                slots: schedule.slots,
                date: schedule.activeDate,
              ),
              const SizedBox(height: 12),
              WeeklyProgressWidget(tasks: allTasks),
              const SizedBox(height: 16),
              if (active.isNotEmpty) ...[
                _SectionHeader(
                  label: 'Active',
                  count: active.length,
                  color: CaliMindColors.primary,
                ),
                const SizedBox(height: 8),
                ...active.map(
                  (t) => TaskCard(
                    task: t,
                    onOpen: () => context.push('/tasks/${t.id}', extra: t),
                    onEdit: () => showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => TaskInputSheet(taskToEdit: t),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
              if (done.isNotEmpty) ...[
                _SectionHeader(
                  label: 'Completed',
                  count: done.length,
                  color: CaliMindColors.success,
                ),
                const SizedBox(height: 8),
                ...done.map(
                  (t) => TaskCard(
                    task: t,
                    onOpen: () => context.push('/tasks/${t.id}', extra: t),
                    onEdit: () => showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => TaskInputSheet(taskToEdit: t),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context, TaskCategory? focus) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: CaliMindColors.card,
              shape: BoxShape.circle,
              border: Border.all(color: CaliMindColors.cardBorder),
            ),
            child: Icon(
              focus?.icon ?? LucideIcons.listTodo,
              color: focus?.color ?? CaliMindColors.mutedForeground,
              size: 26,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            focus == null ? 'No tasks yet' : 'No ${focus.label} tasks',
            style: CaliMindTypography.h3,
          ),
          const SizedBox(height: 8),
          Text(
            'Use the + button to add a task, or tap the mic to add one by voice.',
            style: CaliMindTypography.label,
            textAlign: TextAlign.center,
          ),
        ],
      ).animate().fadeIn(duration: 500.ms).scale(begin: const Offset(0.9, 0.9)),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _SectionHeader({
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: CaliMindTypography.label.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '$count',
            style: CaliMindTypography.bodySmall.copyWith(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}
