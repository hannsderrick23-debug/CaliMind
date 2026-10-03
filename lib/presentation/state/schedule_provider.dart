import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:calimind/core/utils/date_time_utils.dart';
import 'package:calimind/data/repositories/schedule_repository_impl.dart';
import 'package:calimind/domain/models/schedule_slot.dart';
import 'package:calimind/domain/models/task.dart';
import 'package:calimind/domain/use_cases/generate_schedule_use_case.dart';

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
  final GenerateScheduleUseCase _scheduler = GenerateScheduleUseCase();

  ScheduleNotifier(this._repo)
      : super(ScheduleState(
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
          errorMessage: 'Could not load calendar schedule: $error',
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
        errorMessage: 'Could not load schedule for $date: $error',
      );
    }
  }

  Future<ScheduleResult> generateSchedule(List<Task> tasks) async {
    state = state.copyWith(isGenerating: true, clearError: true);
    final dateStr = DateTimeUtils.toIsoDate(state.activeDate);
    final dateOnlyTasks = tasks.where((task) {
      final deadline = task.deadline?.toLocal();
      return deadline == null ||
          DateTimeUtils.toIsoDate(deadline) == dateStr ||
          DateTimeUtils.toIsoDate(deadline).compareTo(dateStr) < 0;
    }).toList();
    final result = _scheduler.execute(dateOnlyTasks, dateStr);
    try {
      await _repo.saveSchedule(result.slots, dateStr);
      state = state.copyWith(
        slots: result.slots,
        unscheduled: result.unscheduled,
        isGenerating: false,
        isLoaded: true,
      );
    } catch (error) {
      state = state.copyWith(
        isGenerating: false,
        errorMessage: 'Could not save schedule for $dateStr: $error',
      );
      rethrow;
    }
    await loadScheduleForMonth(state.activeDate);
    return result;
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

final scheduleProvider = StateNotifierProvider<ScheduleNotifier, ScheduleState>((ref) {
  final repo = ref.watch(scheduleRepositoryProvider);
  return ScheduleNotifier(repo);
});
