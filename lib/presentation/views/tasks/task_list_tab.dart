import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/utils/haptic_feedback_utils.dart';
import '../../../domain/models/task.dart';
import '../../state/role_focus_provider.dart';
import '../../state/task_provider.dart';
import 'task_input_sheet.dart';
import 'widgets/task_card.dart';

class TaskListTab extends ConsumerWidget {
  const TaskListTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(taskProvider);
    final focus = ref.watch(roleFocusProvider);

    return tasksAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: CaliMindColors.primary),
      ),
      error: (e, _) => Center(
        child: Text('Error loading tasks', style: CaliMindTypography.bodyMedium),
      ),
      data: (allTasks) {
        final filtered = focus == null
            ? allTasks
            : allTasks.where((t) => t.category == focus).toList();

        final active = filtered.where((t) => !t.completed).toList();
        final done = filtered.where((t) => t.completed).toList();

        if (filtered.isEmpty) {
          return _buildEmptyState(focus);
        }

        return RefreshIndicator(
          color: CaliMindColors.primary,
          backgroundColor: CaliMindColors.card,
          onRefresh: () => ref.read(taskProvider.notifier).loadTasks(),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
            children: [
              if (active.isNotEmpty) ...[
                _SectionHeader(
                  label: 'Active',
                  count: active.length,
                  color: CaliMindColors.primary,
                ),
                const SizedBox(height: 8),
                ...active.map((t) => TaskCard(
                      task: t,
                      onEdit: () => showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (_) => TaskInputSheet(taskToEdit: t),
                      ),
                    )),
                const SizedBox(height: 20),
              ],
              if (done.isNotEmpty) ...[
                _SectionHeader(
                  label: 'Completed',
                  count: done.length,
                  color: CaliMindColors.success,
                ),
                const SizedBox(height: 8),
                ...done.map((t) => TaskCard(task: t)),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(TaskCategory? focus) {
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
            'Tap the mic button to add tasks by voice',
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

  const _SectionHeader({required this.label, required this.count, required this.color});

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
        Text(label, style: CaliMindTypography.label.copyWith(color: color, fontWeight: FontWeight.w700)),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text('$count', style: CaliMindTypography.bodySmall.copyWith(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: color,
          )),
        ),
      ],
    );
  }
}
