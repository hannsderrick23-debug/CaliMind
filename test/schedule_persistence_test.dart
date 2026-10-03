import 'package:flutter_test/flutter_test.dart';
import 'package:calimind/core/utils/date_time_utils.dart';
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
  required String? specificTime,
  DateTime? deadline,
  bool completed = false,
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
      completed: completed,
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

  test('preview does not persist until reviewed schedule is explicitly saved',
      () async {
    final datasource = _FakeScheduleDatasource()
      ..byDate['2026-10-04'] = const [
        ScheduleSlot(
          taskId: 'existing-plan',
          taskTitle: 'Existing plan',
          category: TaskCategory.personal,
          startTime: '09:00',
          endTime: '09:30',
          duration: 30,
          scheduleDate: '2026-10-04',
        ),
      ];
    final notifier = ScheduleNotifier(
      ScheduleRepositoryImpl(datasource: datasource),
    );
    addTearDown(notifier.dispose);
    notifier.changeDate(DateTime(2026, 10, 4));
    await Future<void>.delayed(Duration.zero);

    final draft = notifier.previewSchedule([
      _task(
        id: 'task-1',
        title: 'Study chemistry',
        specificTime: '15:30',
      ),
    ]);

    expect(
      datasource.byDate['2026-10-04']?.single.taskId,
      'existing-plan',
    );
    await notifier.saveReviewedSchedule(
      draft,
      slots: draft.result.slots,
      unscheduled: draft.result.unscheduled,
    );
    expect(datasource.byDate['2026-10-04']?.single.startTime, '15:30');
  });

  test(
      'replanning excludes completed tasks, preserves exact times, and starts'
      ' remaining work no earlier than now', () async {
    final datasource = _FakeScheduleDatasource()
      ..byDate['2026-10-04'] = const [
        ScheduleSlot(
          taskId: 'fixed',
          taskTitle: 'Fixed task',
          category: TaskCategory.study,
          startTime: '15:30',
          endTime: '16:15',
          duration: 45,
          scheduleDate: '2026-10-04',
        ),
        ScheduleSlot(
          taskId: 'complete',
          taskTitle: 'Already complete',
          category: TaskCategory.study,
          startTime: '09:00',
          endTime: '09:45',
          duration: 45,
          scheduleDate: '2026-10-04',
        ),
      ];
    final notifier = ScheduleNotifier(
      ScheduleRepositoryImpl(datasource: datasource),
      clock: () => DateTime(2026, 10, 4, 11),
    );
    addTearDown(notifier.dispose);
    notifier.changeDate(DateTime(2026, 10, 4));
    await Future<void>.delayed(Duration.zero);

    final draft = notifier.previewRemainingSchedule([
      _task(
        id: 'fixed',
        title: 'Fixed task',
        specificTime: '15:30',
      ),
      _task(
        id: 'complete',
        title: 'Already complete',
        specificTime: '09:00',
        completed: true,
      ),
      _task(
        id: 'floating',
        title: 'Remaining task',
        specificTime: null,
      ),
    ]);

    expect(draft.result.slots.map((slot) => slot.taskId),
        containsAll(['fixed', 'floating']));
    expect(draft.result.slots.map((slot) => slot.taskId),
        isNot(contains('complete')));
    expect(
      draft.result.slots.firstWhere((slot) => slot.taskId == 'fixed').startTime,
      '15:30',
    );
    expect(
      DateTimeUtils.toMinutes(
        draft.result.slots
            .firstWhere((slot) => slot.taskId == 'floating')
            .startTime,
      ),
      greaterThanOrEqualTo(11 * 60),
    );
    expect(datasource.byDate['2026-10-04']?.map((slot) => slot.taskId),
        contains('complete'));
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
