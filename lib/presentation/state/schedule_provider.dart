import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:calimind/core/utils/date_time_utils.dart';
import 'package:calimind/core/utils/network_error_utils.dart';
import 'package:calimind/core/services/widget_service.dart';
import 'package:calimind/data/repositories/schedule_repository_impl.dart';
import 'package:calimind/domain/models/schedule_slot.dart';
import 'package:calimind/domain/models/calendar_busy_interval.dart';
import 'package:calimind/domain/models/task.dart';
import 'package:calimind/domain/use_cases/generate_schedule_use_case.dart';
import 'package:calimind/presentation/state/auth_provider.dart';

class ScheduleDraft {
  final String date;
  final ScheduleResult result;
  final bool isReplan;

  const ScheduleDraft({
    required this.date,
    required this.result,
    this.isReplan = false,
  });
}

class ScheduleState {
  final List<ScheduleSlot> slots;
  final List<ScheduleSlot> monthSlots;
  final List<UnscheduledTask> unscheduled;
  final DateTime activeDate;
  final DateTime calendarMonth;
  final bool isGenerating;
  final bool isLoaded;
  final String? errorMessage;

  const ScheduleState({
    this.slots = const [],
    this.monthSlots = const [],
    this.unscheduled = const [],
    required this.activeDate,
    required this.calendarMonth,
    this.isGenerating = false,
    this.isLoaded = false,
    this.errorMessage,
  });

  ScheduleState copyWith({
    List<ScheduleSlot>? slots,
    List<ScheduleSlot>? monthSlots,
    List<UnscheduledTask>? unscheduled,
    DateTime? activeDate,
    DateTime? calendarMonth,
    bool? isGenerating,
    bool? isLoaded,
    String? errorMessage,
    bool clearError = false,
  }) =>
      ScheduleState(
    slots: slots ?? this.slots,
    monthSlots: monthSlots ?? this.monthSlots,
    unscheduled: unscheduled ?? this.unscheduled,
    activeDate: activeDate ?? this.activeDate,
    calendarMonth: calendarMonth ?? this.calendarMonth,
    isGenerating: isGenerating ?? this.isGenerating,
    isLoaded: isLoaded ?? this.isLoaded,
    errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
  );
}

class ScheduleNotifier extends StateNotifier<ScheduleState> {
  final ScheduleRepositoryImpl _repo;
  final GenerateScheduleUseCase _scheduler;
  final DateTime Function() _clock;

  ScheduleNotifier(
    this._repo, {
    GenerateScheduleUseCase? scheduler,
    DateTime Function()? clock,
  }) : _scheduler = scheduler ?? GenerateScheduleUseCase(),
       _clock = clock ?? DateTime.now,
       super(ScheduleState(
           activeDate: DateTime.now(),
           calendarMonth: DateTime(DateTime.now().year, DateTime.now().month),
       )) {
    loadScheduleForDate(DateTimeUtils.toIsoDate(DateTime.now()));
    loadScheduleForMonth(DateTime.now());
  }

  Future<void> loadScheduleForMonth(DateTime month) async {
    final normalizedMonth = DateTime(month.year, month.month);
    state = state.copyWith(
      calendarMonth: normalizedMonth,
      monthSlots: [],
      clearError: true,
    );
    final startDate = DateTimeUtils.toIsoDate(normalizedMonth);
    final endDate = DateTimeUtils.toIsoDate(
      DateTime(month.year, month.month + 1).subtract(const Duration(days: 1)),
    );
    try {
      final slots = await _repo.getSlotsBetween(startDate, endDate);
      if (state.calendarMonth.year != normalizedMonth.year ||
          state.calendarMonth.month != normalizedMonth.month) {
        return;
      }
      state = state.copyWith(
        monthSlots: slots,
      );
    } catch (error) {
      if (state.calendarMonth.year == normalizedMonth.year &&
          state.calendarMonth.month == normalizedMonth.month) {
        state = state.copyWith(
          errorMessage:
              networkErrorMessage(error) ??
              'Could not load calendar schedule: $error',
        );
      }
    }
  }

  Future<void> loadScheduleForDate(String date) async {
    state = state.copyWith(isGenerating: true, clearError: true);
    try {
      final slots = await _repo.getSlotsForDate(date);
      if (DateTimeUtils.toIsoDate(state.activeDate) != date) return;
      state = state.copyWith(
        slots: slots,
        isGenerating: false,
        isLoaded: true,
      );
    } catch (error) {
      if (DateTimeUtils.toIsoDate(state.activeDate) != date) return;
      state = state.copyWith(
        isGenerating: false,
        isLoaded: true,
        errorMessage:
            networkErrorMessage(error) ??
            'Could not load schedule for $date: $error',
      );
    }
  }

  Future<ScheduleResult> generateSchedule(List<Task> tasks) async {
    final dateStr = DateTimeUtils.toIsoDate(state.activeDate);
    final result = _buildSchedule(tasks, dateStr);
    await _saveSchedule(result, dateStr, tasks);
    return result;
  }

  /// Builds a candidate without writing it or changing the currently loaded plan.
  ScheduleDraft previewSchedule(
    List<Task> tasks, {
    List<CalendarBusyInterval> busyIntervals = const [],
  }) {
    final date = DateTimeUtils.toIsoDate(state.activeDate);
    return ScheduleDraft(
      date: date,
      result: _buildSchedule(
        tasks,
        date,
        busyIntervals: busyIntervals,
      ),
    );
  }

  /// Rebuilds today's remaining work while preserving future exact-time slots.
  ScheduleDraft previewRemainingSchedule(
    List<Task> tasks, {
    List<CalendarBusyInterval> busyIntervals = const [],
  }) {
    final date = DateTimeUtils.toIsoDate(state.activeDate);
    final incompleteTasks =
        _tasksForDate(tasks, date).where((task) => !task.completed).toList();
    final targetTime = _clock();
    final now = targetTime.toLocal();
    final targetMinute = DateTimeUtils.toIsoDate(now) == date
        ? now.hour * 60 +
              now.minute +
              (now.second > 0 || now.millisecond > 0 || now.microsecond > 0
                  ? 1
                  : 0)
        : 0;
    final taskIds = incompleteTasks.map((task) => task.id).toSet();
    final preservedSlots = state.slots.where((slot) {
      if (!taskIds.contains(slot.taskId)) return false;
      final task = incompleteTasks.firstWhere((task) => task.id == slot.taskId);
      if (task.specificTime == null) return false;
      final start = DateTimeUtils.toMinutes(slot.startTime);
      return DateTimeUtils.toIsoDate(now) != date || start >= targetMinute;
    }).toList();
    final result = _scheduler.execute(
      incompleteTasks,
      date,
      targetTime: targetTime,
      preservedSlots: preservedSlots,
      busyIntervals: busyIntervals,
    );
    return ScheduleDraft(date: date, result: result, isReplan: true);
  }

  /// Persists a draft only when the caller explicitly confirms its review.
  Future<void> saveReviewedSchedule(
    ScheduleDraft draft, {
    required List<ScheduleSlot> slots,
    required List<UnscheduledTask> unscheduled,
    List<Task> tasks = const [],
  }) =>
      _saveSchedule(
    ScheduleResult(slots: slots, unscheduled: unscheduled),
    draft.date,
    tasks,
  );

  List<Task> _tasksForDate(List<Task> tasks, String date) =>
      tasks.where((task) {
        final deadline = task.deadline?.toLocal();
        return deadline == null ||
            DateTimeUtils.toIsoDate(deadline) == date ||
            DateTimeUtils.toIsoDate(deadline).compareTo(date) < 0;
      }).toList();

  ScheduleResult _buildSchedule(
    List<Task> tasks,
    String date, {
    List<CalendarBusyInterval> busyIntervals = const [],
  }) {
    final dateOnlyTasks = _tasksForDate(tasks, date);
    return _scheduler.execute(
      dateOnlyTasks,
      date,
      busyIntervals: busyIntervals,
    );
  }

  Future<void> _saveSchedule(
    ScheduleResult result,
    String dateStr,
    List<Task> tasks,
  ) async {
    state = state.copyWith(isGenerating: true, clearError: true);
    try {
      await _repo.saveSchedule(result.slots, dateStr);
      if (DateTimeUtils.toIsoDate(state.activeDate) == dateStr) {
        state = state.copyWith(
          slots: result.slots,
          unscheduled: result.unscheduled,
          isGenerating: false,
          isLoaded: true,
        );
      } else {
        state = state.copyWith(isGenerating: false);
      }
    } catch (error) {
      state = state.copyWith(
        isGenerating: false,
        errorMessage: 'Could not save schedule for $dateStr: $error',
      );
      rethrow;
    }
    final savedDate = DateTime.parse(dateStr);
    if (state.calendarMonth.year == savedDate.year &&
        state.calendarMonth.month == savedDate.month) {
      await loadScheduleForMonth(savedDate);
    }
    await WidgetService.refresh(
      tasks,
      scheduledTaskIds: result.slots.map((slot) => slot.taskId),
    );
  }

  Future<void> clearSchedule() async {
    final dateStr = DateTimeUtils.toIsoDate(state.activeDate);
    try {
      await _repo.clearScheduleForDate(dateStr);
    } catch (error) {
      state = state.copyWith(
        errorMessage: 'Could not clear schedule for $dateStr: $error',
      );
      rethrow;
    }
    state = state.copyWith(slots: [], unscheduled: []);
    await loadScheduleForMonth(state.activeDate);
  }

  void changeDate(DateTime date) {
    final normalized = DateTime(date.year, date.month, date.day);
    state = state.copyWith(
      activeDate: normalized,
      slots: [],
      unscheduled: [],
      isLoaded: false,
    );
    loadScheduleForDate(DateTimeUtils.toIsoDate(normalized));
    if (state.calendarMonth.year != normalized.year ||
        state.calendarMonth.month != normalized.month) {
      loadScheduleForMonth(normalized);
    }
  }
}

final scheduleRepositoryProvider = Provider<ScheduleRepositoryImpl>(
  (ref) => ScheduleRepositoryImpl(),
);

final scheduleProvider = StateNotifierProvider<ScheduleNotifier, ScheduleState>(
  (ref) {
    ref.watch(authProvider.select((auth) => auth.user?.id));
    final repo = ref.watch(scheduleRepositoryProvider);
    return ScheduleNotifier(repo);
  },
);
