import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:calimind/core/constants/app_colors.dart';
import 'package:calimind/core/constants/app_typography.dart';
import 'package:calimind/core/services/push_notification_service.dart';
import 'package:calimind/core/utils/app_feedback.dart';
import 'package:calimind/core/utils/date_time_utils.dart';
import 'package:calimind/domain/models/schedule_slot.dart';
import 'package:calimind/domain/models/task.dart';
import 'package:calimind/domain/use_cases/generate_schedule_use_case.dart';
import 'package:calimind/presentation/state/schedule_provider.dart';
import 'package:calimind/presentation/state/task_provider.dart';
import '../tasks/task_input_sheet.dart';
import 'widgets/timeline_view.dart';
import 'widgets/grid_view.dart';
import 'widgets/feed_view.dart';
import 'widgets/month_calendar_view.dart';
import 'widgets/needs_attention_sheet.dart';

enum ScheduleViewMode { timeline, grid, feed }

class ScheduleTab extends ConsumerStatefulWidget {
  const ScheduleTab({super.key});

  @override
  ConsumerState<ScheduleTab> createState() => _ScheduleTabState();
}

class _ScheduleTabState extends ConsumerState<ScheduleTab> {
  ScheduleViewMode _mode = ScheduleViewMode.timeline;
  final GenerateScheduleUseCase _scheduler = GenerateScheduleUseCase();

  Future<void> _generate() async {
    final tasks = ref.read(taskProvider).valueOrNull ?? [];
    late final ScheduleResult result;
    try {
      result = await ref.read(scheduleProvider.notifier).generateSchedule(tasks);
    } catch (error) {
      if (mounted) {
        AppFeedback.error(
          ScaffoldMessenger.of(context),
          'Could not save the schedule: $error',
        );
      }
      return;
    }
    await ref.read(voiceScheduleSummaryProvider.notifier).announce(result);
    if (mounted && result.slots.isNotEmpty) {
      final activeDate = ref.read(scheduleProvider).activeDate;
      final pushResult =
          await PushNotificationService.instance.notifyScheduleGenerated(
        scheduleDate: DateTimeUtils.toIsoDate(activeDate),
        scheduledTaskCount: result.slots.length,
      );
      if (mounted && !pushResult.delivered) {
        AppFeedback.info(
          ScaffoldMessenger.of(context),
          pushResult.message,
        );
      }
    }
    if (mounted && result.hasUnscheduled) {
      _showNeedsAttention(result.unscheduled);
    }
  }

  void _showNeedsAttention(List<UnscheduledTask> items) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => NeedsAttentionSheet(unscheduled: items),
    );
  }

  void _showScheduledTaskActions(ScheduleSlot slot) {
    final tasks = ref.read(taskProvider).valueOrNull ?? const <Task>[];
    Task? task;
    for (final candidate in tasks) {
      if (candidate.id == slot.taskId) {
        task = candidate;
        break;
      }
    }
    if (task == null) {
      AppFeedback.info(
        ScaffoldMessenger.of(context),
        'This schedule entry is no longer linked to a task.',
      );
      return;
    }

    final selectedTask = task;
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
        decoration: BoxDecoration(
          color: CaliMindColors.card,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: CaliMindColors.cardBorder),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              selectedTask.title,
              style: CaliMindTypography.h3,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 5),
            Text(
              '${slot.startTime} – ${slot.endTime}  ·  ${slot.category.label}',
              style: CaliMindTypography.bodySmall.copyWith(
                color: CaliMindColors.mutedForeground,
              ),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: () async {
                Navigator.of(sheetContext).pop();
                final notifier = ref.read(taskProvider.notifier);
                final changed = await notifier.toggleCompletion(
                  selectedTask.id,
                  !selectedTask.completed,
                );
                if (!mounted) return;
                if (changed) {
                  AppFeedback.success(
                    ScaffoldMessenger.of(context),
                    selectedTask.completed
                        ? 'Task moved back to Active.'
                        : 'Task marked complete.',
                  );
                } else {
                  AppFeedback.error(
                    ScaffoldMessenger.of(context),
                    notifier.lastOperationError == null
                        ? 'Could not update this task. Please try again.'
                        : 'Could not update task: ${notifier.lastOperationError}',
                  );
                }
              },
              icon: Icon(
                selectedTask.completed
                    ? LucideIcons.rotateCcw
                    : LucideIcons.circleCheck,
              ),
              label: Text(selectedTask.completed ? 'Reopen task' : 'Mark complete'),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(sheetContext).pop();
                      showModalBottomSheet<void>(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (_) =>
                            TaskInputSheet(taskToEdit: selectedTask),
                      );
                    },
                    icon: const Icon(LucideIcons.pencil, size: 17),
                    label: const Text('Edit'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(sheetContext).pop();
                      _confirmDeleteScheduledTask(selectedTask);
                    },
                    icon: const Icon(LucideIcons.trash2, size: 17),
                    label: const Text('Delete'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: CaliMindColors.destructive,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDeleteScheduledTask(Task task) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete task?'),
        content: Text('“${task.title}” will be removed from your tasks.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final deleted = await ref.read(taskProvider.notifier).deleteTask(task.id);
    if (!mounted) return;
    if (deleted) {
      AppFeedback.success(ScaffoldMessenger.of(context), 'Task deleted.');
    } else {
      AppFeedback.error(
        ScaffoldMessenger.of(context),
        'Could not delete this task. Please try again.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final schedule = ref.watch(scheduleProvider);
    final tasks = ref.watch(taskProvider).valueOrNull ?? const [];

    return Column(
      children: [
        MonthCalendarView(
          month: schedule.calendarMonth,
          selectedDate: schedule.activeDate,
          tasks: tasks,
          scheduledSlots: schedule.monthSlots,
          onDateSelected: ref.read(scheduleProvider.notifier).changeDate,
          onMonthChanged: (offset) {
            final current = schedule.activeDate;
            final targetMonth = DateTime(current.year, current.month + offset);
            final lastDay = DateUtils.getDaysInMonth(
              targetMonth.year,
              targetMonth.month,
            );
            final day = current.day > lastDay ? lastDay : current.day;
            ref.read(scheduleProvider.notifier).changeDate(
                  DateTime(targetMonth.year, targetMonth.month, day),
                );
          },
        ),
        // View Mode Switcher
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 7, 16, 0),
          child: Row(
            children: [
              Expanded(child: _buildViewSwitcher()),
              const SizedBox(width: 8),
              _buildGenerateButton(schedule),
            ],
          ),
        ),
        if (schedule.errorMessage != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                schedule.errorMessage!,
                style: CaliMindTypography.bodySmall.copyWith(
                  color: CaliMindColors.destructive,
                ),
              ),
            ),
          ),
        const SizedBox(height: 12),
        // Unscheduled warning banner
        if (schedule.unscheduled.isNotEmpty)
          _buildUnscheduledBanner(schedule.unscheduled),
        // Schedule view
        Expanded(
          child: schedule.isGenerating
              ? const Center(child: CircularProgressIndicator(color: CaliMindColors.primary))
              : _buildCurrentView(schedule),
        ),
      ],
    );
  }

  Widget _buildViewSwitcher() {
    final modes = [
      (ScheduleViewMode.timeline, LucideIcons.alignLeft, 'Timeline'),
      (ScheduleViewMode.grid, LucideIcons.layoutGrid, 'Grid'),
      (ScheduleViewMode.feed, LucideIcons.messageSquare, 'Feed'),
    ];

    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: CaliMindColors.card,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: CaliMindColors.cardBorder),
      ),
      child: Row(
        children: modes.map((m) {
          final (mode, icon, label) = m;
          final isSelected = _mode == mode;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 3),
              child: Material(
                color: isSelected
                    ? CaliMindColors.primary
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => setState(() => _mode = mode),
                  child: SizedBox.expand(
                    child: Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            icon,
                            size: 17,
                            color: isSelected
                                ? Colors.white
                                : CaliMindColors.mutedForeground,
                          ),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: CaliMindTypography.bodySmall.copyWith(
                                fontSize: 12,
                                color: isSelected
                                    ? Colors.white
                                    : CaliMindColors.mutedForeground,
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildGenerateButton(ScheduleState schedule) {
    return GestureDetector(
      onTap: schedule.isGenerating ? null : _generate,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: CaliMindColors.primary,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(LucideIcons.zap, size: 13, color: Colors.white),
            const SizedBox(width: 5),
            Text('Generate', style: CaliMindTypography.bodySmall.copyWith(color: Colors.white, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _buildUnscheduledBanner(List<UnscheduledTask> unscheduled) {
    return GestureDetector(
      onTap: () => _showNeedsAttention(unscheduled),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: CaliMindColors.warning.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: CaliMindColors.warning.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            const Icon(LucideIcons.alertTriangle, size: 14, color: CaliMindColors.warning),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${unscheduled.length} task${unscheduled.length > 1 ? 's' : ''} couldn\'t be scheduled. Tap to see why.',
                style: CaliMindTypography.bodySmall.copyWith(color: CaliMindColors.warning),
              ),
            ),
            const Icon(LucideIcons.chevronRight, size: 14, color: CaliMindColors.warning),
          ],
        ),
      ).animate().shake(delay: 100.ms),
    );
  }

  Widget _buildCurrentView(ScheduleState schedule) {
    if (schedule.slots.isEmpty && !schedule.isLoaded) {
      return _buildEmptySchedule();
    }
    final slots = _slotsForSelectedDate(schedule);
    return switch (_mode) {
      ScheduleViewMode.timeline => TimelineView(
          slots: slots,
          onSlotTap: _showScheduledTaskActions,
        ),
      ScheduleViewMode.grid => ScheduleGridView(
          slots: slots,
          onSlotTap: _showScheduledTaskActions,
        ),
      ScheduleViewMode.feed => FeedView(
          slots: slots,
          onSlotTap: _showScheduledTaskActions,
        ),
    };
  }

  List<ScheduleSlot> _slotsForSelectedDate(ScheduleState schedule) {
    final targetDate = DateTimeUtils.toIsoDate(schedule.activeDate);
    final tasks = ref.read(taskProvider).valueOrNull ?? const <Task>[];
    final datedTasks = tasks.where((task) {
      if (task.completed || task.deadline == null) return false;
      return DateTimeUtils.toIsoDate(task.deadline!.toLocal()) == targetDate;
    }).toList();

    if (datedTasks.isEmpty) return schedule.slots;

    final generated = _scheduler.execute(datedTasks, targetDate).slots;
    final persistedTaskIds = schedule.slots.map((slot) => slot.taskId).toSet();
    return [
      ...schedule.slots,
      ...generated.where((slot) => !persistedTaskIds.contains(slot.taskId)),
    ]..sort((a, b) => a.startTime.compareTo(b.startTime));
  }

  Widget _buildEmptySchedule() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              gradient: CaliMindColors.cardGlowGradient,
              shape: BoxShape.circle,
              border: Border.all(color: CaliMindColors.cardBorder),
            ),
            child: const Icon(LucideIcons.calendar, color: CaliMindColors.primary, size: 30),
          ),
          const SizedBox(height: 16),
          Text('No schedule yet', style: CaliMindTypography.h3),
          const SizedBox(height: 8),
          Text(
            'Tap Generate to compute your\ndeterministic daily schedule',
            style: CaliMindTypography.label,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: _generate,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: CaliMindColors.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(LucideIcons.zap, size: 16, color: Colors.white),
                  const SizedBox(width: 8),
                  Text('Generate Schedule', style: CaliMindTypography.bodyMedium.copyWith(color: Colors.white, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
        ],
      ).animate().fadeIn(duration: 500.ms),
    );
  }
}

// Provider to handle TTS announcement after schedule generation
final voiceScheduleSummaryProvider = StateNotifierProvider<_VoiceSummaryNotifier, void>(
  (ref) => _VoiceSummaryNotifier(),
);

class _VoiceSummaryNotifier extends StateNotifier<void> {
  _VoiceSummaryNotifier() : super(null);

  Future<void> announce(scheduleResult) async {
    // TTS via the voice assistant service
  }
}
