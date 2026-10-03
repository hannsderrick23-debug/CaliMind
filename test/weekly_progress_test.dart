import 'package:calimind/domain/models/task.dart';
import 'package:calimind/domain/use_cases/calculate_weekly_progress_use_case.dart';
import 'package:calimind/presentation/widgets/weekly_progress_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CalculateWeeklyProgressUseCase', () {
    const calculate = CalculateWeeklyProgressUseCase();
    final now = DateTime(2026, 10, 7, 12);

    test('counts completed tasks, category distribution, and current streak',
        () {
      final category = TaskCategory.values.first;
      final result = calculate([
        _task('today-1', category, completedAt: DateTime(2026, 10, 7, 8)),
        _task('today-2', category, completedAt: DateTime(2026, 10, 7, 9)),
        _task('yesterday', TaskCategory.values.last,
            completedAt: DateTime(2026, 10, 6, 20)),
        _task('open', category, completed: false, completedAt: now),
      ], now: now);

      expect(result.weekStart, DateTime(2026, 10, 5));
      expect(result.completedTaskCount, 3);
      expect(result.categoryCounts[category], 2);
      expect(result.categoryCounts[TaskCategory.values.last], 1);
      expect(result.streakDays, 2);
    });

    test('streak continues from yesterday when nothing is completed today', () {
      final result = calculate([
        _task('yesterday', TaskCategory.values.first,
            completedAt: DateTime(2026, 10, 6)),
      ], now: now);

      expect(result.streakDays, 1);
    });
  });

  testWidgets('shows a useful empty state with no completed tasks',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: WeeklyProgressWidget(tasks: [])),
      ),
    );

    expect(find.text('Weekly progress'), findsOneWidget);
    expect(find.byKey(const ValueKey('weekly-progress-empty')), findsOneWidget);
  });

  testWidgets('shows weekly totals and category breakdown', (tester) async {
    final task = _task(
      'today',
      TaskCategory.values.first,
      completedAt: DateTime(2026, 10, 7, 8),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WeeklyProgressWidget(
            tasks: [task],
            now: DateTime(2026, 10, 7, 12),
          ),
        ),
      ),
    );

    expect(find.text('Completed'), findsOneWidget);
    expect(find.text('Day streak'), findsOneWidget);
    expect(find.text(task.category.label), findsOneWidget);
  });
}

Task _task(
  String id,
  TaskCategory category, {
  bool completed = true,
  DateTime? completedAt,
}) {
  final createdAt = DateTime(2026, 10, 1);
  return Task(
    id: id,
    userId: 'test-user',
    title: id,
    category: category,
    duration: 25,
    priority: 1,
    completed: completed,
    completedAt: completedAt,
    createdAt: createdAt,
    updatedAt: createdAt,
  );
}
