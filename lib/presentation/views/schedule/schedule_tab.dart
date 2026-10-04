import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:calimind/core/constants/app_colors.dart';
import 'package:calimind/core/constants/app_typography.dart';
import 'package:calimind/core/services/device_calendar_service.dart';
import 'package:calimind/core/services/push_notification_service.dart';
import 'package:calimind/core/services/task_reminder_service.dart';
import 'package:calimind/core/services/widget_service.dart';
import 'package:calimind/core/utils/app_feedback.dart';
import 'package:calimind/core/utils/date_time_utils.dart';
import 'package:calimind/domain/models/schedule_slot.dart';
import 'package:calimind/domain/models/calendar_busy_interval.dart';
import 'package:calimind/domain/models/task.dart';
import 'package:calimind/domain/use_cases/generate_schedule_use_case.dart';
import 'package:calimind/presentation/state/device_calendar_provider.dart';
import 'package:calimind/presentation/state/schedule_provider.dart';
import 'package:calimind/presentation/state/task_provider.dart';
import 'package:calimind/presentation/views/tasks/task_deletion_action.dart';
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
  ScheduleTabState createState() => ScheduleTabState();
}

class ScheduleTabState extends ConsumerState<ScheduleTab> {
  ScheduleViewMode _mode = ScheduleViewMode.timeline;
  final GenerateScheduleUseCase _scheduler = GenerateScheduleUseCase();
  bool _reviewInProgress = false;

  Future<void> generateFromVoice() => _generate();

  Future<void> _generate({bool replanRemaining = false}) async {
    if (_reviewInProgress) return;
    if (replanRemaining && !await _confirmReplan()) return;
    if (!mounted) return;
    setState(() => _reviewInProgress = true);
    final tasks = ref.read(taskProvider).valueOrNull ?? [];
    try {
      var busyIntervals = <CalendarBusyInterval>[];
      final calendarState = ref.read(deviceCalendarProvider);
      if (calendarState.enabled) {
        final busyResult = await ref
            .read(deviceCalendarProvider.notifier)
            .getBusyIntervalsForDay(ref.read(scheduleProvider).activeDate);
        if (busyResult.status != DeviceCalendarAccessStatus.granted) {
          if (mounted) {
            final message = switch (busyResult.status) {
              DeviceCalendarAccessStatus.denied =>
                'Calendar access was denied. Enable it in Settings or turn off calendar-aware planning.',
              DeviceCalendarAccessStatus.restricted =>
                'Calendar access is restricted on this device.',
              DeviceCalendarAccessStatus.unsupported =>
                'Read-only calendar access is unavailable on this platform.',
              DeviceCalendarAccessStatus.disabled =>
                'Calendar-aware planning is disabled. Try again.',
              DeviceCalendarAccessStatus.notRequested =>
                'Calendar permission has not been granted yet. Enable it in Settings.',
              DeviceCalendarAccessStatus.error =>
                'Could not read calendar busy times. Your existing plan was not changed.',
              DeviceCalendarAccessStatus.granted => '',
            };
            AppFeedback.error(ScaffoldMessenger.of(context), message);
          }
          return;
        }
        busyIntervals = busyResult.intervals;
      }
      if (!mounted) return;
      final notifier = ref.read(scheduleProvider.notifier);
      final draft = replanRemaining
          ? notifier.previewRemainingSchedule(
              tasks,
              busyIntervals: busyIntervals,
            )
          : notifier.previewSchedule(
              tasks,
              busyIntervals: busyIntervals,
            );
      final reviewed = await showDialog<ScheduleResult>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _ScheduleReviewDialog(
          result: draft.result,
          isReplan: replanRemaining,
        ),
      );
      if (reviewed == null || !mounted) return;
      await notifier.saveReviewedSchedule(
        draft,
        slots: reviewed.slots,
        unscheduled: reviewed.unscheduled,
        tasks: tasks,
      );
      if (!mounted) return;
      AppFeedback.success(
        ScaffoldMessenger.of(context),
        replanRemaining ? 'Remaining tasks rescheduled.' : 'Schedule saved.',
      );
      await ref.read(voiceScheduleSummaryProvider.notifier).announce(reviewed);
      var notificationsEnabled = false;
      try {
        notificationsEnabled =
            await TaskReminderService().areNotificationsEnabled();
      } catch (error) {
        debugPrint('Could not read notification preference: $error');
      }
      if (mounted && reviewed.slots.isNotEmpty && notificationsEnabled) {
        final pushResult =
            await PushNotificationService.instance.notifyScheduleGenerated(
          scheduleDate: draft.date,
          scheduledTaskCount: reviewed.slots.length,
        );
        if (mounted && !pushResult.delivered) {
          AppFeedback.info(
            ScaffoldMessenger.of(context),
            pushResult.message,
          );
        }
      }
      if (mounted && reviewed.hasUnscheduled) {
        _showNeedsAttention(reviewed.unscheduled);
      }
    } catch (error) {
      if (mounted) {
        AppFeedback.error(
          ScaffoldMessenger.of(context),
          'Could not save the schedule: $error',
        );
      }
    } finally {
      if (mounted) setState(() => _reviewInProgress = false);
    }
  }

  Future<bool> _confirmReplan() async =>
      await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Replan remaining tasks?'),
          content: const Text(
            'Completed tasks will be excluded and exact-time tasks will stay '
            'fixed. The saved plan will only be replaced after you review and '
            'confirm the new schedule.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Keep current plan'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Continue'),
            ),
          ],
        ),
      ) ??
      false;

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
            OutlinedButton.icon(
              onPressed: () {
                Navigator.of(sheetContext).pop();
                context.push(
                  '/tasks/${selectedTask.id}',
                  extra: selectedTask,
                );
              },
              icon: const Icon(LucideIcons.fileText),
              label: const Text('View task details'),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: () async {
                Navigator.of(sheetContext).pop();
                final notifier = ref.read(taskProvider.notifier);
                final changed = await notifier.toggleCompletion(
                  selectedTask.id,
                  !selectedTask.completed,
                );
                if (changed) await _refreshWidget();
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
              label: Text(
                  selectedTask.completed ? 'Reopen task' : 'Mark complete'),
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
    await deleteTaskWithUndo(context, ref, task, confirm: true);
  }

  Future<void> _refreshWidget() => WidgetService.refresh(
        ref.read(taskProvider).valueOrNull ?? const <Task>[],
        scheduledTaskIds:
            ref.read(scheduleProvider).slots.map((slot) => slot.taskId),
      );

  @override
  Widget build(BuildContext context) {
    final schedule = ref.watch(scheduleProvider);
    final tasks = ref.watch(taskProvider).valueOrNull ?? const [];

    return SingleChildScrollView(
      primary: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
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
              _buildScheduleActions(schedule),
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
        if (schedule.isGenerating)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 48),
            child: CircularProgressIndicator(color: CaliMindColors.primary),
          )
        else
          _buildCurrentView(schedule),
        const SizedBox(height: 24),
        ],
      ),
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
                color: isSelected ? CaliMindColors.primary : Colors.transparent,
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

  Widget _buildScheduleActions(ScheduleState schedule) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _scheduleActionButton(
          icon: LucideIcons.zap,
          label: 'Generate',
          onTap: schedule.isGenerating || _reviewInProgress
              ? null
              : () => _generate(),
        ),
        const SizedBox(width: 6),
        _scheduleActionButton(
          icon: LucideIcons.refreshCw,
          label: 'Replan',
          onTap: schedule.isGenerating || _reviewInProgress
              ? null
              : () => _generate(replanRemaining: true),
        ),
      ],
    );
  }

  Widget _scheduleActionButton({
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
  }) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
          decoration: BoxDecoration(
            color: onTap == null
                ? CaliMindColors.primary.withValues(alpha: 0.5)
                : CaliMindColors.primary,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 13, color: Colors.white),
              const SizedBox(width: 4),
              Text(
                label,
                style: CaliMindTypography.bodySmall.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );

  Widget _buildUnscheduledBanner(List<UnscheduledTask> unscheduled) {
    return GestureDetector(
      onTap: () => _showNeedsAttention(unscheduled),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: CaliMindColors.warning.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border:
              Border.all(color: CaliMindColors.warning.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            const Icon(LucideIcons.alertTriangle,
                size: 14, color: CaliMindColors.warning),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${unscheduled.length} task${unscheduled.length > 1 ? 's' : ''} couldn\'t be scheduled. Tap to see why.',
                style: CaliMindTypography.bodySmall
                    .copyWith(color: CaliMindColors.warning),
              ),
            ),
            const Icon(LucideIcons.chevronRight,
                size: 14, color: CaliMindColors.warning),
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
            child: const Icon(LucideIcons.calendar,
                color: CaliMindColors.primary, size: 30),
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
            onTap: () => _generate(),
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
                  Text('Generate Schedule',
                      style: CaliMindTypography.bodyMedium.copyWith(
                          color: Colors.white, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
        ],
      ).animate().fadeIn(duration: 500.ms),
    );
  }
}

class _ScheduleReviewDialog extends StatefulWidget {
  final ScheduleResult result;
  final bool isReplan;

  const _ScheduleReviewDialog({
    required this.result,
    required this.isReplan,
  });

  @override
  State<_ScheduleReviewDialog> createState() => _ScheduleReviewDialogState();
}

class _ScheduleReviewDialogState extends State<_ScheduleReviewDialog> {
  late final List<ScheduleSlot> _slots = [...widget.result.slots];
  late final List<UnscheduledTask> _unscheduled = [
    ...widget.result.unscheduled,
  ];

  String? get _validationMessage {
    final sorted = [..._slots]
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
    for (var i = 0; i < sorted.length; i++) {
      final slot = sorted[i];
      final start = DateTimeUtils.toMinutes(slot.startTime);
      final end = DateTimeUtils.toMinutes(slot.endTime);
      if (start < GenerateScheduleUseCase.dayStart ||
          end > GenerateScheduleUseCase.dayEnd ||
          end <= start) {
        return 'Scheduled times must fit between 08:00 and 22:00.';
      }
      if (i > 0 &&
          start - DateTimeUtils.toMinutes(sorted[i - 1].endTime) <
              GenerateScheduleUseCase.bufferMinutes) {
        return 'Leave at least 15 minutes between scheduled items.';
      }
    }
    return null;
  }

  void _replaceSlot(int index, ScheduleSlot slot) {
    setState(() => _slots[index] = slot);
  }

  Future<void> _editStartTime(int index) async {
    final slot = _slots[index];
    final minute = DateTimeUtils.toMinutes(slot.startTime);
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: minute ~/ 60, minute: minute % 60),
    );
    if (picked == null || !mounted) return;
    final startMinute = picked.hour * 60 + picked.minute;
    final startTime = DateTimeUtils.formatMinutes(startMinute);
    final endTime = DateTimeUtils.formatMinutes(startMinute + slot.duration);
    _replaceSlot(
      index,
      ScheduleSlot(
        taskId: slot.taskId,
        taskTitle: slot.taskTitle,
        category: slot.category,
        startTime: startTime,
        endTime: endTime,
        duration: slot.duration,
        scheduleDate: slot.scheduleDate,
      ),
    );
  }

  void _removeSlot(int index) {
    final removed = _slots.removeAt(index);
    setState(() {
      _unscheduled.add(
        UnscheduledTask(
          taskId: removed.taskId,
          title: removed.taskTitle,
          reason: 'Removed during schedule review.',
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final validationMessage = _validationMessage;
    return AlertDialog(
      title:
          Text(widget.isReplan ? 'Review remaining plan' : 'Review day plan'),
      content: SizedBox(
        width: 540,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.62,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Edit or remove scheduled items before saving. Your current '
                  'schedule stays unchanged if you cancel.',
                  style: CaliMindTypography.bodySmall.copyWith(
                    color: CaliMindColors.mutedForeground,
                  ),
                ),
                const SizedBox(height: 12),
                if (_slots.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Text('No tasks could be scheduled for this date.'),
                  ),
                ..._slots.asMap().entries.map((entry) {
                  final index = entry.key;
                  final slot = entry.value;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 5, 4, 8),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 14),
                                  child: Text(
                                    slot.taskTitle,
                                    style: CaliMindTypography.bodyMedium,
                                  ),
                                ),
                              ),
                              IconButton(
                                tooltip: 'Remove from plan',
                                onPressed: () => _removeSlot(index),
                                icon: const Icon(
                                  LucideIcons.trash2,
                                  color: CaliMindColors.destructive,
                                  size: 18,
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              TextButton.icon(
                                onPressed: () => _editStartTime(index),
                                icon: const Icon(LucideIcons.clock, size: 16),
                                label: Text(
                                  '${slot.startTime} – ${slot.endTime}',
                                ),
                              ),
                              const Spacer(),
                              Text(
                                DateTimeUtils.formatDuration(slot.duration),
                                style: CaliMindTypography.bodySmall.copyWith(
                                  color: CaliMindColors.mutedForeground,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }),
                if (_unscheduled.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text('Could not schedule', style: CaliMindTypography.h3),
                  const SizedBox(height: 4),
                  ..._unscheduled.map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            LucideIcons.alertTriangle,
                            size: 16,
                            color: CaliMindColors.warning,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${item.title}: ${item.reason}',
                              style: CaliMindTypography.bodySmall,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                if (validationMessage != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    validationMessage,
                    style: CaliMindTypography.bodySmall.copyWith(
                      color: CaliMindColors.destructive,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: validationMessage == null
              ? () {
                  final sorted = [..._slots]
                    ..sort((a, b) => a.startTime.compareTo(b.startTime));
                  Navigator.pop(
                    context,
                    ScheduleResult(
                      slots: sorted,
                      unscheduled: [..._unscheduled],
                    ),
                  );
                }
              : null,
          child: Text(widget.isReplan ? 'Replace saved plan' : 'Save plan'),
        ),
      ],
    );
  }
}

// Provider to handle TTS announcement after schedule generation
final voiceScheduleSummaryProvider =
    StateNotifierProvider<_VoiceSummaryNotifier, void>(
  (ref) => _VoiceSummaryNotifier(),
);

class _VoiceSummaryNotifier extends StateNotifier<void> {
  _VoiceSummaryNotifier() : super(null);

  Future<void> announce(scheduleResult) async {
    // TTS via the voice assistant service
  }
}
