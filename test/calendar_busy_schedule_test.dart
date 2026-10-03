import 'package:calimind/domain/models/calendar_busy_interval.dart';
import 'package:calimind/domain/models/task.dart';
import 'package:calimind/domain/use_cases/generate_schedule_use_case.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final generator = GenerateScheduleUseCase();
  final task = Task(
    id: 'focus',
    userId: 'user',
    title: 'Study',
    category: TaskCategory.study,
    duration: 60,
    priority: 1,
    completed: false,
    createdAt: DateTime(2026, 10, 1),
    updatedAt: DateTime(2026, 10, 1),
  );

  test('optional busy intervals preserve the existing default behavior', () {
    final result = generator.execute([task], '2026-10-05');

    expect(result.slots, hasLength(1));
    expect(result.slots.single.startTime, '08:00');
  });

  test('busy interval and rest buffer are avoided for floating tasks', () {
    final result = generator.execute(
      [task],
      '2026-10-05',
      busyIntervals: [
        CalendarBusyInterval(
          start: DateTime(2026, 10, 5, 8),
          end: DateTime(2026, 10, 5, 10),
        ),
      ],
    );

    expect(result.slots, hasLength(1));
    expect(result.slots.single.startTime, '10:15');
    expect(result.slots.single.endTime, '11:15');
  });

  test('busy overlap prevents an exact-time task from being scheduled', () {
    final exactTask = Task(
      id: task.id,
      userId: task.userId,
      title: task.title,
      category: task.category,
      duration: task.duration,
      specificTime: '09:00',
      priority: task.priority,
      completed: task.completed,
      createdAt: task.createdAt,
      updatedAt: task.updatedAt,
    );

    final result = generator.execute(
      [exactTask],
      '2026-10-05',
      busyIntervals: [
        CalendarBusyInterval(
          start: DateTime(2026, 10, 5, 9),
          end: DateTime(2026, 10, 5, 10),
        ),
      ],
    );

    expect(result.slots, isEmpty);
    expect(result.unscheduled, hasLength(1));
  });
}
