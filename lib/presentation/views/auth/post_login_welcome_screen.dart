import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:calimind/core/constants/app_colors.dart';
import 'package:calimind/core/constants/app_typography.dart';
import 'package:calimind/domain/models/task.dart';
import 'package:calimind/domain/use_cases/calculate_weekly_progress_use_case.dart';
import 'package:calimind/presentation/state/auth_provider.dart';
import 'package:calimind/presentation/state/task_provider.dart';
import 'package:calimind/presentation/widgets/star_loading_indicator.dart';
import 'package:calimind/presentation/widgets/auth_backdrop.dart';
import 'package:calimind/presentation/widgets/calimind_mark.dart';

class PostLoginWelcomeScreen extends ConsumerWidget {
  const PostLoginWelcomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final metadataName = user?.userMetadata?['full_name'] as String? ??
        user?.userMetadata?['name'] as String?;
    final trimmedName = metadataName?.trim() ?? '';
    final firstName =
        trimmedName.isEmpty ? null : trimmedName.split(RegExp(r'\s+')).first;
    final now = DateTime.now();
    final greeting = switch (now.hour) {
      < 12 => 'Good morning',
      < 17 => 'Good afternoon',
      _ => 'Good evening',
    };
    final tasksAsync = ref.watch(taskProvider);

    return AuthBackdrop(
      backgroundAsset: 'assets/branding/register_photo.jpg',
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Center(child: CaliMindMark(size: 64)),
                const SizedBox(height: 20),
                Text(
                  firstName == null ? '$greeting.' : '$greeting, $firstName.',
                  textAlign: TextAlign.center,
                  style: CaliMindTypography.h1.copyWith(
                    color: Colors.white,
                    fontSize: 30,
                    shadows: const [
                      Shadow(color: Color(0xCC101639), blurRadius: 10),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  DateFormat('EEEE, MMMM d').format(now),
                  textAlign: TextAlign.center,
                  style: CaliMindTypography.bodyMedium.copyWith(
                    color: Colors.white.withValues(alpha: 0.86),
                    shadows: const [
                      Shadow(color: Color(0xCC101639), blurRadius: 8),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                tasksAsync.when(
                  loading: () => const _WelcomeCard(
                    child: Center(
                      child: SizedBox(
                        height: 24,
                        width: 24,
                        child: const StarLoadingIndicator(size: 24),
                      ),
                    ),
                  ),
                  error: (error, _) => _WelcomeCard(
                    child: Row(
                      children: [
                        const Icon(
                          LucideIcons.cloudOff,
                          color: CaliMindColors.mutedForeground,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Your planner is ready. Open it to check your tasks.',
                            style: CaliMindTypography.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
                  data: (tasks) => _TodayOverview(tasks: tasks, now: now),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  height: 54,
                  child: ElevatedButton.icon(
                    onPressed: () => context.go('/dashboard'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: CaliMindColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: const Icon(
                      LucideIcons.arrowRight,
                      color: Colors.white,
                      size: 18,
                    ),
                    label: const Text(
                      'Open my planner',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () => context.go('/dashboard?tab=schedule'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                    foregroundColor: Colors.white,
                    side: BorderSide(
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: const Icon(LucideIcons.calendarDays, size: 18),
                  label: const Text('View my schedule'),
                ),
                const SizedBox(height: 16),
                Text(
                  'A small next step is enough. Your plans stay yours.',
                  textAlign: TextAlign.center,
                  style: CaliMindTypography.bodySmall.copyWith(
                    color: Colors.white.withValues(alpha: 0.88),
                    shadows: const [
                      Shadow(color: Color(0xCC101639), blurRadius: 8),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TodayOverview extends StatelessWidget {
  const _TodayOverview({required this.tasks, required this.now});

  final List<Task> tasks;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final todayStart = DateTime(now.year, now.month, now.day);
    final tomorrowStart = todayStart.add(const Duration(days: 1));
    final active = tasks.where((task) => !task.completed).toList();
    final dueToday = active
        .where(
          (task) =>
              task.deadline != null &&
              !task.deadline!.isBefore(todayStart) &&
              task.deadline!.isBefore(tomorrowStart),
        )
        .length;
    final progress = const CalculateWeeklyProgressUseCase()(tasks, now: now);
    final nextTask = _suggestedTask(active, todayStart);

    return _WelcomeCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                LucideIcons.sun,
                color: CaliMindColors.primary,
                size: 19,
              ),
              const SizedBox(width: 8),
              Text('A gentle check-in', style: CaliMindTypography.h3),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _WelcomeMetric(
                  value: '$dueToday',
                  label: 'Due today',
                ),
              ),
              Expanded(
                child: _WelcomeMetric(
                  value: '${active.length}',
                  label: 'Active tasks',
                ),
              ),
              Expanded(
                child: _WelcomeMetric(
                  value: '${progress.completedTaskCount}',
                  label: 'Done this week',
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            _nextStep(active, dueToday, nextTask, todayStart),
            style: CaliMindTypography.bodySmall.copyWith(height: 1.45),
          ),
          if (nextTask != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: CaliMindColors.surfaceOverlay,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const Icon(
                    LucideIcons.sparkles,
                    color: CaliMindColors.primary,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'One small next step',
                          style: CaliMindTypography.bodySmall.copyWith(
                            color: CaliMindColors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          nextTask.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: CaliMindTypography.bodyMedium.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'View suggested task',
                    onPressed: () => context.push(
                      '/tasks/${nextTask.id}',
                      extra: nextTask,
                    ),
                    icon: const Icon(
                      LucideIcons.arrowRight,
                      color: CaliMindColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Task? _suggestedTask(List<Task> active, DateTime todayStart) {
    if (active.isEmpty) return null;
    final tasks = [...active];
    tasks.sort((a, b) {
      final aDeadline = a.deadline;
      final bDeadline = b.deadline;
      final aDay = aDeadline == null
          ? null
          : DateTime(
              aDeadline.toLocal().year,
              aDeadline.toLocal().month,
              aDeadline.toLocal().day,
            );
      final bDay = bDeadline == null
          ? null
          : DateTime(
              bDeadline.toLocal().year,
              bDeadline.toLocal().month,
              bDeadline.toLocal().day,
            );
      final aGroup = aDay == null
          ? 1
          : aDay.isBefore(todayStart)
              ? 2
              : 0;
      final bGroup = bDay == null
          ? 1
          : bDay.isBefore(todayStart)
              ? 2
              : 0;
      final byRelevance = aGroup.compareTo(bGroup);
      if (byRelevance != 0) return byRelevance;

      if (aDeadline != null || bDeadline != null) {
        if (aDeadline == null) return 1;
        if (bDeadline == null) return -1;
        if (aGroup == 0) {
          final byDeadline = aDeadline.compareTo(bDeadline);
          if (byDeadline != 0) return byDeadline;
        }
      }
      final byPriority = a.priority.compareTo(b.priority);
      if (byPriority != 0) return byPriority;
      final byCreated = a.createdAt.compareTo(b.createdAt);
      if (byCreated != 0) return byCreated;
      return a.id.compareTo(b.id);
    });
    return tasks.first;
  }

  String _nextStep(
    List<Task> active,
    int dueToday,
    Task? nextTask,
    DateTime todayStart,
  ) {
    if (active.isEmpty) {
      return 'Your list is clear. Add a task whenever something comes to mind.';
    }
    if (dueToday > 0) {
      return '$dueToday ${dueToday == 1 ? 'task is' : 'tasks are'} due today. Pick the one that matters most to you.';
    }
    if (nextTask != null && nextTask.deadline != null) {
      final today = DateTime(todayStart.year, todayStart.month, todayStart.day);
      final deadlineDate = nextTask.deadline!.toLocal();
      final deadlineDay =
          DateTime(deadlineDate.year, deadlineDate.month, deadlineDate.day);
      final isPastDue = deadlineDay.isBefore(today);
      return isPastDue
          ? 'This task is still on your list. You can work on it, reschedule it, or leave it for later.'
          : 'Your next task by due date is ${nextTask.title}. You can adjust the plan at any time.';
    }
    return 'Choose one task to focus on. There’s no need to do everything at once.';
  }
}

class _WelcomeCard extends StatelessWidget {
  const _WelcomeCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: CaliMindColors.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: CaliMindColors.cardBorder),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF101639).withValues(alpha: 0.16),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: child,
      );
}

class _WelcomeMetric extends StatelessWidget {
  const _WelcomeMetric({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: CaliMindTypography.h2.copyWith(
              color: CaliMindColors.primary,
              fontSize: 24,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: CaliMindTypography.bodySmall.copyWith(fontSize: 11),
          ),
        ],
      );
}
