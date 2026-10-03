import '../models/task.dart';

class WeeklyProgress {
  const WeeklyProgress({
    required this.weekStart,
    required this.completedTaskCount,
    required this.streakDays,
    required this.categoryCounts,
  });

  final DateTime weekStart;
  final int completedTaskCount;
  final int streakDays;
  final Map<TaskCategory, int> categoryCounts;

  bool get isEmpty => completedTaskCount == 0 && streakDays == 0;
}

/// Computes local-calendar weekly progress from task data without side effects.
class CalculateWeeklyProgressUseCase {
  const CalculateWeeklyProgressUseCase();

  WeeklyProgress call(Iterable<Task> tasks, {DateTime? now}) {
    final currentDay = _dateOnly(now ?? DateTime.now());
    final weekStart = currentDay.subtract(
      Duration(days: currentDay.weekday - DateTime.monday),
    );
    final nextWeekStart = weekStart.add(const Duration(days: 7));
    final completed = tasks.where((task) => task.completed && task.completedAt != null);

    final thisWeek = completed.where((task) {
      final completedAt = _dateOnly(task.completedAt!);
      return !completedAt.isBefore(weekStart) &&
          completedAt.isBefore(nextWeekStart);
    }).toList(growable: false);

    final categoryCounts = <TaskCategory, int>{};
    for (final task in thisWeek) {
      categoryCounts.update(
        task.category,
        (count) => count + 1,
        ifAbsent: () => 1,
      );
    }

    final completionDays = completed
        .map((task) => _dateOnly(task.completedAt!))
        .toSet();
    var streakCursor = currentDay;
    if (!completionDays.contains(streakCursor)) {
      streakCursor = currentDay.subtract(const Duration(days: 1));
    }
    var streakDays = 0;
    while (completionDays.contains(streakCursor)) {
      streakDays++;
      streakCursor = streakCursor.subtract(const Duration(days: 1));
    }

    return WeeklyProgress(
      weekStart: weekStart,
      completedTaskCount: thisWeek.length,
      streakDays: streakDays,
      categoryCounts: Map.unmodifiable(categoryCounts),
    );
  }

  static DateTime _dateOnly(DateTime value) {
    final local = value.toLocal();
    return DateTime(local.year, local.month, local.day);
  }
}
