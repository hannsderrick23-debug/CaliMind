import 'package:flutter_test/flutter_test.dart';
import 'package:calimind/domain/models/calendar_busy_interval.dart';
import 'package:calimind/domain/models/schedule_slot.dart';
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
  bool completed = false,
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
      completed: completed,
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
        _mockTask(
            id: '1',
            title: 'Task A',
            category: TaskCategory.personal,
            duration: 30),
        _mockTask(
            id: '2',
            title: 'Task B',
            category: TaskCategory.study,
            duration: 45),
        _mockTask(
            id: '3',
            title: 'Task C',
            category: TaskCategory.classRep,
            duration: 60),
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

    test('calendar busy intervals are blocked with rest buffers', () {
      final task = _mockTask(
        id: '1',
        title: 'Prepare notes',
        category: TaskCategory.personal,
        duration: 60,
      );

      final result = scheduler.execute(
        [task],
        testDate,
        busyIntervals: [
          CalendarBusyInterval(
            start: DateTime(2026, 9, 24, 9),
            end: DateTime(2026, 9, 24, 10),
          ),
        ],
      );

      expect(result.slots, hasLength(1));
      expect(result.slots.single.startTime, '10:15');
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
              reason:
                  'Study slot "${slot.taskTitle}" duration ${slot.duration} exceeds 120m cap');
        }
      }
    });

    test('Exact Time Priority: fixed tasks placed before floating tasks', () {
      final tasks = [
        _mockTask(
            id: '1',
            title: 'Float',
            category: TaskCategory.personal,
            duration: 30,
            priority: 1),
        _mockTask(
            id: '2',
            title: 'Fixed',
            category: TaskCategory.classRep,
            duration: 30,
            specificTime: '10:00'),
      ];

      final result = scheduler.execute(tasks, testDate);
      final fixedSlot = result.slots.firstWhere((s) => s.taskTitle == 'Fixed');
      expect(fixedSlot.startTime, equals('10:00'));
    });

    test('Diagnostic Integrity: passed deadline tasks have explanatory reason',
        () {
      final target = DateTime.parse('${testDate}T12:00:00Z');
      final pastDeadline = target.subtract(const Duration(days: 1));
      final tasks = [
        _mockTask(
            id: '1',
            title: 'Overdue Task',
            category: TaskCategory.personal,
            duration: 30,
            deadline: pastDeadline),
      ];

      final result = scheduler.execute(tasks, testDate);
      expect(result.unscheduled, isNotEmpty);
      expect(result.unscheduled.first.reason, contains('deadline'));
    });

    test('UTC deadlines are evaluated using the selected local calendar date',
        () {
      final deadline = DateTime.utc(2026, 9, 24, 12, 30);
      final localDeadline = deadline.toLocal();
      final targetDate = [
        localDeadline.year.toString().padLeft(4, '0'),
        localDeadline.month.toString().padLeft(2, '0'),
        localDeadline.day.toString().padLeft(2, '0'),
      ].join('-');

      final result = scheduler.execute(
        [
          _mockTask(
            id: 'local-deadline',
            title: 'Task due today locally',
            category: TaskCategory.personal,
            duration: 30,
            deadline: deadline,
          ),
        ],
        targetDate,
      );

      expect(
        result.unscheduled.where((task) => task.reason.contains('passed')),
        isEmpty,
      );
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

    test('target time prevents floating tasks from being placed in the past',
        () {
      final result = scheduler.execute(
        [
          _mockTask(
            id: 'remaining',
            title: 'Remaining task',
            category: TaskCategory.personal,
            duration: 30,
          ),
        ],
        testDate,
        targetTime: DateTime(2026, 9, 24, 10, 15, 1),
      );

      expect(result.slots.single.startTime, '10:16');
    });

    test('past exact-time tasks are reported as unscheduled', () {
      final result = scheduler.execute(
        [
          _mockTask(
            id: 'past-fixed',
            title: 'Past fixed task',
            category: TaskCategory.personal,
            duration: 30,
            specificTime: '10:00',
          ),
        ],
        testDate,
        targetTime: DateTime(2026, 9, 24, 10, 15),
      );

      expect(result.slots, isEmpty);
      expect(result.unscheduled.single.reason, contains('already passed'));
    });

    test(
        'preserved exact-time slots remain fixed while incomplete tasks replan',
        () {
      final fixed = _mockTask(
        id: 'fixed',
        title: 'Fixed task',
        category: TaskCategory.personal,
        duration: 30,
        specificTime: '15:30',
      );
      final floating = _mockTask(
        id: 'floating',
        title: 'Floating task',
        category: TaskCategory.personal,
        duration: 30,
      );
      final result = scheduler.execute(
        [fixed, floating],
        testDate,
        targetTime: DateTime(2026, 9, 24, 11),
        preservedSlots: const [
          ScheduleSlot(
            taskId: 'fixed',
            taskTitle: 'Fixed task',
            category: TaskCategory.personal,
            startTime: '15:30',
            endTime: '16:00',
            duration: 30,
          ),
        ],
      );

      expect(
          result.slots.firstWhere((slot) => slot.taskId == 'fixed').startTime,
          '15:30');
      expect(
          result.slots
              .firstWhere((slot) => slot.taskId == 'floating')
              .startTime,
          '11:00');
    });

    test('Day boundary: tasks outside 08:00-22:00 exact times are unscheduled',
        () {
      final tasks = [
        _mockTask(
            id: '1',
            title: 'Midnight Task',
            category: TaskCategory.personal,
            duration: 30,
            specificTime: '02:00'),
      ];

      final result = scheduler.execute(tasks, testDate);
      expect(result.unscheduled, isNotEmpty);
      expect(result.unscheduled.first.reason,
          contains('outside your planning hours'));
    });

    test('Priority P1 tasks are scheduled before P3 tasks', () {
      final tasks = [
        _mockTask(
            id: '1',
            title: 'Low Priority',
            category: TaskCategory.personal,
            duration: 30,
            priority: 3),
        _mockTask(
            id: '2',
            title: 'High Priority',
            category: TaskCategory.personal,
            duration: 30,
            priority: 1),
      ];

      final result = scheduler.execute(tasks, testDate);
      expect(result.slots.length, equals(2));
      expect(result.slots.first.taskTitle, equals('High Priority'));
    });

    test('Study session of 180m chunks into 2 slots (120m + 60m)', () {
      final tasks = [
        _mockTask(
            id: '1',
            title: 'Big Study',
            category: TaskCategory.study,
            duration: 180,
            priority: 1),
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
      final cmd =
          parser.parse('Remind me to submit class rep report for 20 minutes');
      expect(cmd, isA<AddTaskCommand>());
      final add = cmd as AddTaskCommand;
      expect(add.task.category, equals(TaskCategory.classRep));
      expect(add.task.duration, equals(20));
      expect(add.task.priority, equals(2)); // default
    });

    test('Parses "I need to prepare club budget for 2 hours priority 1"', () {
      final cmd =
          parser.parse('I need to prepare club budget for 2 hours priority 1');
      expect(cmd, isA<AddTaskCommand>());
      final add = cmd as AddTaskCommand;
      expect(add.task.category, equals(TaskCategory.clubPresident));
      expect(add.task.duration, equals(120));
      expect(add.task.priority, equals(1));
    });

    test('Parses "Create buy groceries" as an errand', () {
      final cmd = parser.parse('Create buy groceries');
      expect(cmd, isA<AddTaskCommand>());
      final add = cmd as AddTaskCommand;
      expect(add.task.title, equals('Buy groceries'));
      expect(add.task.category, equals(TaskCategory.errands));
      expect(add.task.duration, equals(30)); // default
    });

    test('Parses exact spoken time and urgent priority', () {
      final cmd = parser.parse('Add workout at 7:15 pm urgent');
      expect(cmd, isA<AddTaskCommand>());
      final add = cmd as AddTaskCommand;
      expect(add.task.category, TaskCategory.health);
      expect(add.task.specificTime, '19:15');
      expect(add.task.priority, 1);
    });

    test('Infers work, family, finance, and social categories', () {
      expect(
        (parser.parse('Add prepare client report') as AddTaskCommand)
            .task
            .category,
        TaskCategory.work,
      );
      expect(
        (parser.parse('Add call my sister') as AddTaskCommand).task.category,
        TaskCategory.family,
      );
      expect(
        (parser.parse('Add pay electricity bill') as AddTaskCommand)
            .task
            .category,
        TaskCategory.finance,
      );
      expect(
        (parser.parse('Add dinner with friends') as AddTaskCommand)
            .task
            .category,
        TaskCategory.social,
      );
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

    test('Does not interpret a voice acknowledgment as a task', () {
      expect(parser.parse('Thank you'), isA<UnknownCommand>());
    });

    test('Parses an ordinary statement of intention without a command prefix',
        () {
      final cmd = parser.parse('I have to email my lecturer tomorrow');
      expect(cmd, isA<AddTaskCommand>());
      final add = cmd as AddTaskCommand;
      expect(add.task.title, 'Email my lecturer tomorrow');
      expect(add.task.category, TaskCategory.classRep);
    });

    test('Parses a casual reminder request', () {
      final cmd = parser.parse('Don’t let me forget to call Mum');
      expect(cmd, isA<AddTaskCommand>());
      final add = cmd as AddTaskCommand;
      expect(add.task.title, 'Call Mum');
      expect(add.task.category, TaskCategory.family);
    });

    test('Parses a conversational study intention', () {
      final cmd = parser.parse('I should revise calculus tonight');
      expect(cmd, isA<AddTaskCommand>());
      final add = cmd as AddTaskCommand;
      expect(add.task.title, 'Revise calculus tonight');
      expect(add.task.category, TaskCategory.study);
    });

    test('Parses a direct natural-language task without a command phrase', () {
      final cmd = parser.parse('Email my lecturer tomorrow');
      expect(cmd, isA<AddTaskCommand>());
      final add = cmd as AddTaskCommand;
      expect(add.task.title, 'Email my lecturer tomorrow');
      expect(add.task.category, TaskCategory.classRep);
    });

    test('Parses an ordinary spoken task request with an exact time', () {
      final cmd = parser.parse('Schedule a call with the class rep at 3:30 pm');
      expect(cmd, isA<AddTaskCommand>());
      final add = cmd as AddTaskCommand;
      expect(add.task.title, 'Call with the class rep');
      expect(add.task.category, TaskCategory.classRep);
      expect(add.task.specificTime, '15:30');
    });

    test('Parses natural spoken command with "please" and minutes alias', () {
      final cmd =
          parser.parse('Please add study calculus for 45 mins priority high');
      expect(cmd, isA<AddTaskCommand>());
      final add = cmd as AddTaskCommand;
      expect(add.task.title, equals('Calculus'));
      expect(add.task.category, equals(TaskCategory.study));
      expect(add.task.duration, equals(45));
      expect(add.task.priority, equals(1));
    });

    test('Parses natural spoken command with "can you create"', () {
      final cmd =
          parser.parse('Can you create a class rep report for 20 minutes');
      expect(cmd, isA<AddTaskCommand>());
      final add = cmd as AddTaskCommand;
      expect(add.task.category, equals(TaskCategory.classRep));
      expect(add.task.duration, equals(20));
      expect(add.task.priority, equals(2));
    });

    test('Parses word-based duration and low priority', () {
      final cmd =
          parser.parse('I need to study math for one hour priority low');
      expect(cmd, isA<AddTaskCommand>());
      final add = cmd as AddTaskCommand;
      expect(add.task.category, equals(TaskCategory.study));
      expect(add.task.duration, equals(60));
      expect(add.task.priority, equals(3));
    });

    test('Parses plan request with extra words', () {
      final cmd = parser.parse('Please plan my day now');
      expect(cmd, isA<GenerateScheduleCommand>());
    });

    test('Rejects malformed add command without a task title', () {
      final cmd = parser.parse('Add');
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
