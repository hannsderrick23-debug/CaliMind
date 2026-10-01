import 'package:flutter_test/flutter_test.dart';
import 'package:calimind/domain/models/task.dart';
import 'package:calimind/domain/use_cases/generate_schedule_use_case.dart';
import 'package:calimind/domain/use_cases/parse_voice_command_use_case.dart';
import 'package:calimind/domain/models/parsed_command.dart';

Task _mockTask({
  required String id,
  required String title,
  required TaskCategory category,
  required int duration,
  int priority = 2,
  String? specificTime,
  PreferredTime? preferredTime,
  DateTime? deadline,
}) =>
    Task(
      id: id,
      userId: 'test-user',
      title: title,
      category: category,
      duration: duration,
      priority: priority,
      specificTime: specificTime,
      preferredTime: preferredTime,
      deadline: deadline,
      completed: false,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

void main() {
  group('GenerateScheduleUseCase', () {
    late GenerateScheduleUseCase scheduler;
    const testDate = '2026-09-24';

    setUp(() => scheduler = GenerateScheduleUseCase());

    test('Buffer Invariant: consecutive slots have >=15m gap', () {
      final tasks = [
        _mockTask(id: '1', title: 'Task A', category: TaskCategory.personal, duration: 30),
        _mockTask(id: '2', title: 'Task B', category: TaskCategory.study, duration: 45),
        _mockTask(id: '3', title: 'Task C', category: TaskCategory.classRep, duration: 60),
      ];

      final result = scheduler.execute(tasks, testDate);
      expect(result.slots.length, greaterThan(1));

      for (var i = 0; i < result.slots.length - 1; i++) {
        final endMin = _toMin(result.slots[i].endTime);
        final nextStart = _toMin(result.slots[i + 1].startTime);
        expect(nextStart - endMin, greaterThanOrEqualTo(15),
            reason: 'Buffer violation between slot $i and ${i + 1}: '
                '${result.slots[i].taskTitle} ends ${result.slots[i].endTime}, '
                '${result.slots[i + 1].taskTitle} starts ${result.slots[i + 1].startTime}');
      }
    });

    test('Study Cap Invariant: no study slot exceeds 120 minutes', () {
      final tasks = [
        _mockTask(
          id: '1',
          title: 'Long Study',
          category: TaskCategory.study,
          duration: 180, // triggers chunking
          priority: 1,
        ),
      ];

      final result = scheduler.execute(tasks, testDate);
      for (final slot in result.slots) {
        if (slot.category == TaskCategory.study) {
          expect(slot.duration, lessThanOrEqualTo(120),
              reason: 'Study slot "${slot.taskTitle}" duration ${slot.duration} exceeds 120m cap');
        }
      }
    });

    test('Exact Time Priority: fixed tasks placed before floating tasks', () {
      final tasks = [
        _mockTask(id: '1', title: 'Float', category: TaskCategory.personal, duration: 30, priority: 1),
        _mockTask(id: '2', title: 'Fixed', category: TaskCategory.classRep, duration: 30, specificTime: '10:00'),
      ];

      final result = scheduler.execute(tasks, testDate);
      final fixedSlot = result.slots.firstWhere((s) => s.taskTitle == 'Fixed');
      expect(fixedSlot.startTime, equals('10:00'));
    });

    test('Diagnostic Integrity: passed deadline tasks have explanatory reason', () {
      final target = DateTime.parse('${testDate}T12:00:00Z');
      final pastDeadline = target.subtract(const Duration(days: 1));
      final tasks = [
        _mockTask(id: '1', title: 'Overdue Task', category: TaskCategory.personal, duration: 30, deadline: pastDeadline),
      ];

      final result = scheduler.execute(tasks, testDate);
      expect(result.unscheduled, isNotEmpty);
      expect(result.unscheduled.first.reason, contains('deadline'));
    });

    test('Completed tasks are excluded from scheduling', () {
      final tasks = [
        Task(
          id: '1',
          userId: 'test',
          title: 'Done Task',
          category: TaskCategory.personal,
          duration: 30,
          priority: 2,
          completed: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];

      final result = scheduler.execute(tasks, testDate);
      expect(result.slots, isEmpty);
    });

    test('Day boundary: tasks outside 08:00-22:00 exact times are unscheduled', () {
      final tasks = [
        _mockTask(id: '1', title: 'Midnight Task', category: TaskCategory.personal, duration: 30, specificTime: '02:00'),
      ];

      final result = scheduler.execute(tasks, testDate);
      expect(result.unscheduled, isNotEmpty);
      expect(result.unscheduled.first.reason, contains('outside your planning hours'));
    });

    test('Priority P1 tasks are scheduled before P3 tasks', () {
      final tasks = [
        _mockTask(id: '1', title: 'Low Priority', category: TaskCategory.personal, duration: 30, priority: 3),
        _mockTask(id: '2', title: 'High Priority', category: TaskCategory.personal, duration: 30, priority: 1),
      ];

      final result = scheduler.execute(tasks, testDate);
      expect(result.slots.length, equals(2));
      expect(result.slots.first.taskTitle, equals('High Priority'));
    });

    test('Study session of 180m chunks into 2 slots (120m + 60m)', () {
      final tasks = [
        _mockTask(id: '1', title: 'Big Study', category: TaskCategory.study, duration: 180, priority: 1),
      ];

      final result = scheduler.execute(tasks, testDate);
      final studySlots = result.slots.where((s) => s.taskId == '1').toList();
      expect(studySlots.length, equals(2));
      expect(studySlots[0].duration, equals(120));
      expect(studySlots[1].duration, equals(60));
    });
  });

  group('VoiceParserUseCase', () {
    late VoiceParserUseCase parser;

    setUp(() => parser = VoiceParserUseCase());

    test('Parses "Add study calculus for 45 minutes priority 1"', () {
      final cmd = parser.parse('Add study calculus for 45 minutes priority 1');
      expect(cmd, isA<AddTaskCommand>());
      final add = cmd as AddTaskCommand;
      expect(add.task.title, equals('Calculus'));
      expect(add.task.category, equals(TaskCategory.study));
      expect(add.task.duration, equals(45));
      expect(add.task.priority, equals(1));
    });

    test('Parses "Remind me to submit class rep report for 20 minutes"', () {
      final cmd = parser.parse('Remind me to submit class rep report for 20 minutes');
      expect(cmd, isA<AddTaskCommand>());
      final add = cmd as AddTaskCommand;
      expect(add.task.category, equals(TaskCategory.classRep));
      expect(add.task.duration, equals(20));
      expect(add.task.priority, equals(2)); // default
    });

    test('Parses "I need to prepare club budget for 2 hours priority 1"', () {
      final cmd = parser.parse('I need to prepare club budget for 2 hours priority 1');
      expect(cmd, isA<AddTaskCommand>());
      final add = cmd as AddTaskCommand;
      expect(add.task.category, equals(TaskCategory.clubPresident));
      expect(add.task.duration, equals(120));
      expect(add.task.priority, equals(1));
    });

    test('Parses "Create buy groceries" as personal task', () {
      final cmd = parser.parse('Create buy groceries');
      expect(cmd, isA<AddTaskCommand>());
      final add = cmd as AddTaskCommand;
      expect(add.task.title, equals('Buy groceries'));
      expect(add.task.category, equals(TaskCategory.personal));
      expect(add.task.duration, equals(30)); // default
    });

    test('Parses "Plan my day" as GenerateScheduleCommand', () {
      final cmd = parser.parse('Plan my day');
      expect(cmd, isA<GenerateScheduleCommand>());
    });

    test('Parses "Generate my schedule" as GenerateScheduleCommand', () {
      final cmd = parser.parse('Generate my schedule');
      expect(cmd, isA<GenerateScheduleCommand>());
    });

    test('Returns UnknownCommand for gibberish', () {
      final cmd = parser.parse('xkcd bleep bloop');
      expect(cmd, isA<UnknownCommand>());
    });

    test('Title capitalisation is applied', () {
      final cmd = parser.parse('Add finish the report');
      expect(cmd, isA<AddTaskCommand>());
      final add = cmd as AddTaskCommand;
      expect(add.task.title[0], equals(add.task.title[0].toUpperCase()));
    });
  });
}

int _toMin(String hhMm) {
  final parts = hhMm.split(':').map(int.parse).toList();
  return parts[0] * 60 + parts[1];
}
