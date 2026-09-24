import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/utils/date_time_utils.dart';
import '../../data/repositories/schedule_repository_impl.dart';
import '../../domain/models/schedule_slot.dart';
import '../../domain/models/task.dart';
import '../../domain/use_cases/generate_schedule_use_case.dart';
import 'task_provider.dart';

class ScheduleState {
  final List<ScheduleSlot> slots;
  final List<UnscheduledTask> unscheduled;
  final DateTime activeDate;
  final bool isGenerating;
  final bool isLoaded;
  final String? errorMessage;

  const ScheduleState({
    this.slots = const [],
    this.unscheduled = const [],
    required this.activeDate,
    this.isGenerating = false,
    this.isLoaded = false,
    this.errorMessage,
  });

  ScheduleState copyWith({
    List<ScheduleSlot>? slots,
    List<UnscheduledTask>? unscheduled,
    DateTime? activeDate,
    bool? isGenerating,
    bool? isLoaded,
    String? errorMessage,
    bool clearError = false,
  }) =>
      ScheduleState(
        slots: slots ?? this.slots,
        unscheduled: unscheduled ?? this.unscheduled,
        activeDate: activeDate ?? this.activeDate,
        isGenerating: isGenerating ?? this.isGenerating,
        isLoaded: isLoaded ?? this.isLoaded,
        errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      );
}

class ScheduleNotifier extends StateNotifier<ScheduleState> {
  final ScheduleRepositoryImpl _repo;
  final Ref _ref;
  final GenerateScheduleUseCase _scheduler = GenerateScheduleUseCase();

  ScheduleNotifier(this._repo, this._ref)
      : super(ScheduleState(activeDate: DateTime.now())) {
    loadScheduleForDate(DateTimeUtils.toIsoDate(DateTime.now()));
  }

  Future<void> loadScheduleForDate(String date) async {
    state = state.copyWith(isGenerating: true, clearError: true);
    try {
      final slots = await _repo.getSlotsForDate(date);
      state = state.copyWith(
        slots: slots,
        isGenerating: false,
        isLoaded: true,
      );
    } catch (e) {
      state = state.copyWith(
        isGenerating: false,
        errorMessage: 'Failed to load schedule.',
      );
    }
  }

  Future<ScheduleResult> generateSchedule(List<Task> tasks) async {
    state = state.copyWith(isGenerating: true, clearError: true);
    final dateStr = DateTimeUtils.toIsoDate(state.activeDate);
    final result = _scheduler.execute(tasks, dateStr);

    try {
      await _repo.saveSchedule(result.slots, dateStr);
    } catch (_) {}

    state = state.copyWith(
      slots: result.slots,
      unscheduled: result.unscheduled,
      isGenerating: false,
      isLoaded: true,
    );
    return result;
  }

  Future<void> clearSchedule() async {
    final dateStr = DateTimeUtils.toIsoDate(state.activeDate);
    try {
      await _repo.clearScheduleForDate(dateStr);
    } catch (_) {}
    state = state.copyWith(slots: [], unscheduled: []);
  }

  void changeDate(DateTime date) {
    state = state.copyWith(
      activeDate: date,
      slots: [],
      unscheduled: [],
      isLoaded: false,
    );
    loadScheduleForDate(DateTimeUtils.toIsoDate(date));
  }
}

final scheduleRepositoryProvider = Provider<ScheduleRepositoryImpl>(
  (ref) => ScheduleRepositoryImpl(),
);

final scheduleProvider = StateNotifierProvider<ScheduleNotifier, ScheduleState>((ref) {
  final repo = ref.watch(scheduleRepositoryProvider);
  return ScheduleNotifier(repo, ref);
});
