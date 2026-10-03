import 'package:flutter_test/flutter_test.dart';
import 'package:calimind/data/datasources/schedule_remote_datasource.dart';
import 'package:calimind/data/repositories/schedule_repository_impl.dart';
import 'package:calimind/domain/models/schedule_slot.dart';
import 'package:calimind/domain/models/task.dart';
import 'package:calimind/presentation/state/schedule_provider.dart';

class _FakeScheduleDatasource implements ScheduleRemoteDatasource {
  final Map<String, List<ScheduleSlot>> byDate = {};
  Object? saveError;

  @override
  Future<List<ScheduleSlot>> fetchSlotsForDate(String date) async =>
      byDate[date] ?? const [];

  @override
  Future<List<ScheduleSlot>> fetchSlotsBetween(
    String startDate,
    String endDate,
  ) async =>
      byDate.entries
          .where((entry) =>
              entry.key.compareTo(startDate) >= 0 &&
              entry.key.compareTo(endDate) <= 0)
          .expand((entry) => entry.value)
          .toList();

  @override
  Future<void> saveSchedule(List<ScheduleSlot> slots, String date) async {
    if (saveError case final error?) throw error;
    byDate[date] = slots
        .map(
          (slot) => ScheduleSlot(
            taskId: slot.taskId,
            taskTitle: slot.taskTitle,
            category: slot.category,
            startTime: slot.startTime,
            endTime: slot.endTime,
            duration: slot.duration,
            scheduleDate: date,
          ),
        )
        .toList();
  }

  @override
  Future<void> clearScheduleForDate(String date) async {
    byDate.remove(date);
  }
}

Task _task({
  required String id,
  required String title,
  required String specificTime,
  DateTime? deadline,
}) =>
    Task(
      id: id,
      userId: 'user-1',
      title: title,
      category: TaskCategory.study,
      duration: 45,
      specificTime: specificTime,
      deadline: deadline,
      priority: 1,
      completed: false,
      createdAt: DateTime(2026, 10, 3),
      updatedAt: DateTime(2026, 10, 3),
    );

void main() {
  test(
      'task date-times are serialized as UTC instants without shifting local time',
      () {
    final localDeadline = DateTime(2026, 10, 4, 16, 15);
    const task = NewTask(
      title: 'Study chemistry',
      category: TaskCategory.study,
      duration: 45,
      priority: 1,
    );
    final serialized = task
        .copyWith(deadline: localDeadline)
        .toInsertJson('user-1')['deadline'] as String;

    expect(serialized, localDeadline.toUtc().toIso8601String());
    expect(DateTime.parse(serialized).toLocal(), localDeadline);
  });

  test('selected date loads its persisted schedule slots', () async {
    final datasource = _FakeScheduleDatasource()
      ..byDate['2026-10-04'] = const [
        ScheduleSlot(
          taskId: 'task-1',
          taskTitle: 'Study chemistry',
          category: TaskCategory.study,
          startTime: '15:30',
          endTime: '16:15',
          duration: 45,
          scheduleDate: '2026-10-04',
        ),
      ];
    final notifier = ScheduleNotifier(
      ScheduleRepositoryImpl(datasource: datasource),
    );
    addTearDown(notifier.dispose);

    notifier.changeDate(DateTime(2026, 10, 4));
    await Future<void>.delayed(Duration.zero);

    expect(notifier.state.slots, hasLength(1));
    expect(notifier.state.slots.single.scheduleDate, '2026-10-04');
    expect(notifier.state.slots.single.startTime, '15:30');
  });

  test('generated schedules preserve exact times and persist by date',
      () async {
    final datasource = _FakeScheduleDatasource();
    final notifier = ScheduleNotifier(
      ScheduleRepositoryImpl(datasource: datasource),
    );
    addTearDown(notifier.dispose);
    notifier.changeDate(DateTime(2026, 10, 4));
    await Future<void>.delayed(Duration.zero);

    final result = await notifier.generateSchedule([
      _task(
        id: 'task-1',
        title: 'Study chemistry',
        specificTime: '15:30',
      ),
    ]);

    expect(result.slots.single.startTime, '15:30');
    expect(datasource.byDate['2026-10-04']?.single.startTime, '15:30');
  });

  test('schedule persistence failures are surfaced rather than hidden',
      () async {
    final datasource = _FakeScheduleDatasource()
      ..saveError = StateError('schedule_blocks permission denied');
    final notifier = ScheduleNotifier(
      ScheduleRepositoryImpl(datasource: datasource),
    );
    addTearDown(notifier.dispose);
    notifier.changeDate(DateTime(2026, 10, 4));
    await Future<void>.delayed(Duration.zero);

    await expectLater(
      notifier.generateSchedule([
        _task(
          id: 'task-1',
          title: 'Study chemistry',
          specificTime: '15:30',
        ),
      ]),
      throwsStateError,
    );
    expect(notifier.state.isGenerating, isFalse);
    expect(notifier.state.errorMessage, contains('permission denied'));
  });
}
