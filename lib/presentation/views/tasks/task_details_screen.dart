import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:calimind/core/constants/app_colors.dart';
import 'package:calimind/core/constants/app_typography.dart';
import 'package:calimind/core/services/device_calendar_service.dart';
import 'package:calimind/core/services/widget_service.dart';
import 'package:calimind/core/utils/app_feedback.dart';
import 'package:calimind/domain/models/task.dart';
import 'package:calimind/presentation/state/schedule_provider.dart';
import 'package:calimind/presentation/state/task_provider.dart';
import 'package:calimind/presentation/views/tasks/task_input_sheet.dart';

class TaskDetailsScreen extends ConsumerWidget {
  const TaskDetailsScreen({required this.task, super.key});

  final Task task;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(taskProvider).valueOrNull?.where(
          (candidate) => candidate.id == task.id,
        );
    final currentTask = current == null || current.isEmpty ? task : current.first;

    return Scaffold(
      backgroundColor: CaliMindColors.background,
      appBar: AppBar(
        title: const Text('Task details'),
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () => context.pop(),
          icon: const Icon(LucideIcons.arrowLeft),
        ),
        actions: [
          IconButton(
            tooltip: 'Edit task',
            onPressed: () => _edit(context, currentTask),
            icon: const Icon(LucideIcons.pencil),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: CaliMindColors.card,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: CaliMindColors.cardBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(currentTask.category.icon,
                          color: currentTask.category.color),
                      const SizedBox(width: 10),
                      Text(currentTask.category.label,
                          style: CaliMindTypography.label.copyWith(
                            color: currentTask.category.color,
                            fontWeight: FontWeight.w700,
                          )),
                      const Spacer(),
                      Icon(
                        currentTask.completed
                            ? LucideIcons.circleCheck
                            : LucideIcons.circleDashed,
                        size: 18,
                        color: currentTask.completed
                            ? CaliMindColors.success
                            : CaliMindColors.mutedForeground,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        currentTask.completed ? 'Completed' : 'Active',
                        style: CaliMindTypography.bodySmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Text(currentTask.title, style: CaliMindTypography.h2),
                  const SizedBox(height: 20),
                  _DetailRow(
                    icon: LucideIcons.clock,
                    label: 'Duration',
                    value: _duration(currentTask.duration),
                  ),
                  _DetailRow(
                    icon: LucideIcons.flag,
                    label: 'Priority',
                    value: switch (currentTask.priority) {
                      1 => 'High',
                      2 => 'Medium',
                      _ => 'Low',
                    },
                  ),
                  if (currentTask.specificTime != null)
                    _DetailRow(
                      icon: LucideIcons.alarmClock,
                      label: 'Start time',
                      value: currentTask.specificTime!,
                    ),
                  if (currentTask.preferredTime != null)
                    _DetailRow(
                      icon: LucideIcons.sun,
                      label: 'Preferred time',
                      value: currentTask.preferredTime!.label,
                    ),
                  if (currentTask.deadline != null)
                    _DetailRow(
                      icon: LucideIcons.calendarClock,
                      label: 'Due',
                      value: DateFormat('EEE, MMM d, h:mm a')
                          .format(currentTask.deadline!.toLocal()),
                    ),
                  if (currentTask.reminderAt != null)
                    _DetailRow(
                      icon: LucideIcons.bell,
                      label: 'Reminder',
                      value: DateFormat('EEE, MMM d, h:mm a')
                          .format(currentTask.reminderAt!.toLocal()),
                    ),
                  if (currentTask.recurrence != null)
                    _DetailRow(
                      icon: LucideIcons.repeat,
                      label: 'Repeats',
                      value: currentTask.recurrence!.label,
                    ),
                  if (currentTask.description?.trim().isNotEmpty == true) ...[
                    const SizedBox(height: 18),
                    Text('Notes',
                        style: CaliMindTypography.label.copyWith(
                          color: CaliMindColors.mutedForeground,
                          fontWeight: FontWeight.w700,
                        )),
                    const SizedBox(height: 8),
                    Text(
                      currentTask.description!,
                      style: CaliMindTypography.bodyMedium,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: currentTask.completed
                  ? null
                  : () => _markComplete(context, ref, currentTask),
              icon: const Icon(LucideIcons.circleCheck),
              label: const Text('Mark complete'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: DeviceCalendarService.supportsEventCreation
                  ? () => _addToCalendar(context, currentTask)
                  : null,
              icon: const Icon(LucideIcons.calendarPlus),
              label: const Text('Add to phone calendar'),
            ),
            if (!DeviceCalendarService.supportsEventCreation)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Adding events to the phone calendar is currently available on Android.',
                  textAlign: TextAlign.center,
                  style: CaliMindTypography.bodySmall.copyWith(
                    color: CaliMindColors.mutedForeground,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _edit(BuildContext context, Task task) => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => TaskInputSheet(taskToEdit: task),
      );

  Future<void> _addToCalendar(BuildContext context, Task task) async {
    final now = DateTime.now();
    final suggestedDate = task.deadline != null &&
            task.deadline!.isAfter(DateTime(now.year, now.month, now.day))
        ? task.deadline!
        : now;
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime(
        suggestedDate.year,
        suggestedDate.month,
        suggestedDate.day,
      ),
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (date == null || !context.mounted) return;

    final suggestedTime = task.specificTime?.split(':');
    final time = await showTimePicker(
      context: context,
      initialTime: suggestedTime == null
          ? const TimeOfDay(hour: 9, minute: 0)
          : TimeOfDay(
              hour: int.parse(suggestedTime[0]),
              minute: int.parse(suggestedTime[1]),
            ),
    );
    if (time == null || !context.mounted) return;

    final start =     DateTime(date.year, date.month, date.day, time.hour, time.minute);
    if (!start.isAfter(DateTime.now())) {
      AppFeedback.error(
    ScaffoldMessenger.of(context),
    'Choose a future time for this calendar event.',
      );
      return;
    }
    try {
      final opened = await DeviceCalendarService().openEventEditor(
        title: task.title,
        description: task.description,
        start: start,
        end: start.add(Duration(minutes: task.duration)),
      );
      if (!context.mounted) return;
      if (opened) {
        AppFeedback.info(
          ScaffoldMessenger.of(context),
          'Review the event and save it in your calendar app.',
        );
      } else {
        AppFeedback.error(
          ScaffoldMessenger.of(context),
          'No calendar app is available on this device.',
        );
      }
    } on PlatformException catch (error) {
      if (context.mounted) {
        AppFeedback.error(
          ScaffoldMessenger.of(context),
          error.message ?? 'Could not open the calendar app.',
        );
      }
    } catch (error) {
      if (context.mounted) {
        AppFeedback.error(
          ScaffoldMessenger.of(context),
          'Could not open the calendar app: $error',
        );
      }
    }
  }

  Future<void> _markComplete(
    BuildContext context,
    WidgetRef ref,
    Task task,
  ) async {
    final notifier = ref.read(taskProvider.notifier);
    final changed = await notifier.toggleCompletion(task.id, true);
    if (changed) {
      await WidgetService.refresh(
        ref.read(taskProvider).valueOrNull ?? const <Task>[],
        scheduledTaskIds:
            ref.read(scheduleProvider).slots.map((slot) => slot.taskId),
      );
    }
    if (!context.mounted) return;
    if (changed) {
      AppFeedback.success(
        ScaffoldMessenger.of(context),
        'Task marked complete.',
      );
    } else {
      AppFeedback.error(
        ScaffoldMessenger.of(context),
        notifier.lastOperationError ?? 'Could not update this task.',
      );
    }
  }

  String _duration(int minutes) {
    if (minutes < 60) return '$minutes minutes';
    final hours = minutes ~/ 60;
    final remainder = minutes % 60;
    return remainder == 0 ? '$hours hours' : '$hours h $remainder min';
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Row(
          children: [
            Icon(icon, size: 16, color: CaliMindColors.mutedForeground),
            const SizedBox(width: 10),
            SizedBox(
              width: 108,
              child: Text(label, style: CaliMindTypography.bodySmall),
            ),
            Expanded(
              child: Text(value, style: CaliMindTypography.bodyMedium),
            ),
          ],
        ),
      );
}
