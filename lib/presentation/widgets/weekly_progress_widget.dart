import 'package:flutter/material.dart';

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
    final progress = const CalculateWeeklyProgressUseCase()(tasks, now: now);
    if (progress.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Weekly progress'),
              SizedBox(height: 8),
              Text(
                'No completed tasks yet. Complete a task to start your progress.',
                key: ValueKey('weekly-progress-empty'),
              ),
            ],
          ),
        ),
      );
    }

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
