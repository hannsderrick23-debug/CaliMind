import 'package:intl/intl.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../domain/models/task.dart';
import '../../domain/use_cases/calculate_weekly_progress_use_case.dart';

/// Displays a read-only summary calculated from already-loaded task data.
class WeeklyProgressWidget extends StatelessWidget {
  const WeeklyProgressWidget({
    required this.tasks,
    this.now,
    super.key,
  });

  final List<Task> tasks;
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final referenceTime = (now ?? DateTime.now()).toLocal();
    final today = DateTime(
      referenceTime.year,
      referenceTime.month,
      referenceTime.day,
    );
    final days = List.generate(
      7,
      (index) => today.subtract(Duration(days: 6 - index)),
    );
    final dailyCounts = _completionCountsByDay(tasks, days);
    final progress = const CalculateWeeklyProgressUseCase()(tasks, now: today);
    final categories = progress.categoryCounts.entries.toList()
      ..sort((a, b) => a.key.label.compareTo(b.key.label));
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Weekly progress',
                style: Theme.of(context).textTheme.titleLarge),
            if (progress.isEmpty) ...[
              const SizedBox(height: 8),
              const Text(
                'No completed tasks yet. Complete a task to start your progress.',
                key: ValueKey('weekly-progress-empty'),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _ProgressMetric(
                    label: 'Completed',
                    value: '${progress.completedTaskCount}',
                  ),
                ),
                Expanded(
                  child: _ProgressMetric(
                    label: 'Day streak',
                    value: '${progress.streakDays}',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _WeeklyCompletionChart(days: days, counts: dailyCounts),
            if (categories.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text('By category',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              for (final entry in categories)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(child: Text(entry.key.label)),
                      Text('${entry.value}'),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  List<int> _completionCountsByDay(List<Task> tasks, List<DateTime> days) {
    final counts = List<int>.filled(days.length, 0);
    if (days.isEmpty) return counts;

    final firstDay = days.first;
    final lastDay = days.last;
    final rangeStart = DateTime(firstDay.year, firstDay.month, firstDay.day);
    final rangeEnd = DateTime(lastDay.year, lastDay.month, lastDay.day + 1);
    for (final task in tasks) {
      if (!task.completed || task.completedAt == null) continue;
      final completedAt = task.completedAt!.toLocal();
      final completedDay =
          DateTime(completedAt.year, completedAt.month, completedAt.day);
      if (completedDay.isBefore(rangeStart) || !completedDay.isBefore(rangeEnd)) {
        continue;
      }
      final index = DateTime.utc(
        completedDay.year,
        completedDay.month,
        completedDay.day,
      ).difference(DateTime.utc(rangeStart.year, rangeStart.month, rangeStart.day)).inDays;
      counts[index]++;
    }
    return counts;
  }
}

class _WeeklyCompletionChart extends StatelessWidget {
  const _WeeklyCompletionChart({
    required this.days,
    required this.counts,
  });

  final List<DateTime> days;
  final List<int> counts;

  @override
  Widget build(BuildContext context) {
    final maximum = counts.fold<int>(
      0,
      (largest, count) => count > largest ? count : largest,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Completed by day · last 7 days',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 96,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var index = 0; index < days.length; index++)
                Expanded(
                  child: Semantics(
                    label:
                        '${DateFormat('EEEE, MMM d').format(days[index])}: ${counts[index]} completed ${counts[index] == 1 ? 'task' : 'tasks'}',
                    child: ExcludeSemantics(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              '${counts[index]}',
                              key: ValueKey(
                                'weekly-completion-count-${DateFormat('yyyy-MM-dd').format(days[index])}',
                              ),
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                            const SizedBox(height: 4),
                            Container(
                              height: counts[index] == 0
                                  ? 3
                                  : 12 + counts[index] / (maximum == 0 ? 1 : maximum) * 36,
                              decoration: BoxDecoration(
                                color: CaliMindColors.primary.withValues(
                                  alpha: counts[index] == 0 ? 0.12 : 0.78,
                                ),
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              DateFormat('E').format(days[index]),
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProgressMetric extends StatelessWidget {
  const _ProgressMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: Theme.of(context).textTheme.headlineMedium),
          Text(label),
        ],
      );
}
