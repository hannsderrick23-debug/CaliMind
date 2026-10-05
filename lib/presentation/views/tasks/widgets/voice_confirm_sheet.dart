import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:calimind/core/constants/app_colors.dart';
import 'package:calimind/core/constants/app_typography.dart';
import 'package:calimind/core/services/task_reminder_service.dart';
import 'package:calimind/core/services/widget_service.dart';
import 'package:calimind/core/utils/haptic_feedback_utils.dart';
import 'package:calimind/core/utils/app_feedback.dart';
import 'package:calimind/core/utils/task_reminder_utils.dart';
import 'package:calimind/domain/models/task.dart';
import 'package:calimind/presentation/state/schedule_provider.dart';
import 'package:calimind/presentation/state/task_provider.dart';
import 'package:calimind/presentation/state/voice_assistant_provider.dart';

class VoiceConfirmSheet extends ConsumerStatefulWidget {
  final VoidCallback onConfirmed;
  final VoidCallback onDismissed;

  const VoiceConfirmSheet({
    super.key,
    required this.onConfirmed,
    required this.onDismissed,
  });

  @override
  ConsumerState<VoiceConfirmSheet> createState() => _VoiceConfirmSheetState();
}

class _VoiceConfirmSheetState extends ConsumerState<VoiceConfirmSheet> {
  late TextEditingController _titleCtrl;
  late NewTask _draft;
  bool _isSaving = false;
  bool _reminderCustomized = false;
  bool _reminderDisabled = false;

  @override
  void initState() {
    super.initState();
    _draft = ref.read(voiceAssistantProvider).draftTask!;
    _reminderCustomized = _draft.reminderAt != null;
    if (_draft.reminderAt == null && _draft.specificTime != null) {
      _draft = _draft.copyWith(
        reminderAt: defaultTaskReminderAt(
          specificTime: _draft.specificTime,
          deadline: _draft.deadline,
        ),
      );
    }
    _titleCtrl = TextEditingController(text: _draft.title);
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    if (_titleCtrl.text.trim().isEmpty || _isSaving) return;
    setState(() => _isSaving = true);
    final updated = _draft.copyWith(title: _titleCtrl.text.trim());
    ref.read(voiceAssistantProvider.notifier).updateDraftTask(updated);

    final created = await ref.read(taskProvider.notifier).createTask(updated);
    if (created == null) {
      if (mounted) {
        setState(() => _isSaving = false);
        AppFeedback.error(
          ScaffoldMessenger.of(context),
          'Could not save this task. Check your connection and try again.',
        );
      }
      return;
    }

    await WidgetService.refresh(
      ref.read(taskProvider).valueOrNull ?? const <Task>[],
      scheduledTaskIds: ref
          .read(scheduleProvider)
          .slots
          .map((slot) => slot.taskId),
    );

    var reminderWarning = false;
    if (created.reminderAt != null) {
      var scheduled = false;
      try {
        scheduled = await TaskReminderService().scheduleTaskReminder(
          taskId: created.id,
          title: created.title,
          reminderAt: created.reminderAt!,
        );
      } catch (error) {
        debugPrint('Could not schedule voice task reminder: $error');
      }
      if (!scheduled && mounted) {
        reminderWarning = true;
      }
    }

    try {
      await ref
          .read(voiceAssistantProvider.notifier)
          .speakConfirmation(created.title);
    } catch (error) {
      debugPrint('Could not speak task confirmation: $error');
    }
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    widget.onConfirmed();
    final message = reminderWarning
        ? 'Task added: ${created.title}. Reminder could not be scheduled; check notification permissions.'
        : 'Task added: ${created.title}';
    AppFeedback.success(messenger, message);
  }

  Future<void> _chooseExactTime() async {
    final initial = _draft.specificTime?.split(':');
    final result = await showTimePicker(
      context: context,
      initialTime: initial == null
          ? TimeOfDay.now()
          : TimeOfDay(
              hour: int.parse(initial[0]),
              minute: int.parse(initial[1]),
            ),
    );
    if (result == null) return;
    final value =
        '${result.hour.toString().padLeft(2, '0')}:${result.minute.toString().padLeft(2, '0')}';
    setState(() {
      _draft = _draft.copyWith(specificTime: value);
      _updateDefaultReminder();
    });
  }

  Future<void> _chooseDeadline() async {
    final initial = _draft.deadline ?? DateTime.now();
    final result = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now().subtract(const Duration(days: 3650)),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (result == null) return;
    setState(() {
      _draft = _draft.copyWith(
        deadline: DateTime(result.year, result.month, result.day, 23, 59),
      );
      _updateDefaultReminder();
    });
  }

  void _updateDefaultReminder() {
    if (_reminderCustomized || _reminderDisabled) return;
    _draft = _draft.copyWith(
      reminderAt: defaultTaskReminderAt(
        specificTime: _draft.specificTime,
        deadline: _draft.deadline,
      ),
      clearReminder: _draft.specificTime == null,
    );
  }

  String get _defaultReminderLabel {
    final reminder = defaultTaskReminderAt(
      specificTime: _draft.specificTime,
      deadline: _draft.deadline,
    );
    return reminder == null
        ? 'Set a reminder'
        : '30 min before · ${DateFormat('EEE, MMM d · h:mm a').format(reminder)}';
  }

  Future<void> _chooseReminder() async {
    final initial =
        _draft.reminderAt ??
        defaultTaskReminderAt(
          specificTime: _draft.specificTime,
          deadline: _draft.deadline,
        ) ??
        DateTime.now().add(const Duration(hours: 1));
    final now = DateTime.now();
    final initialDate = initial.isBefore(now) ? now : initial;
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime(
        initialDate.year,
        initialDate.month,
        initialDate.day,
      ),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null) return;
    setState(() {
      _draft = _draft.copyWith(
        reminderAt: DateTime(
          date.year,
          date.month,
          date.day,
          time.hour,
          time.minute,
        ),
      );
      _reminderCustomized = true;
      _reminderDisabled = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: CaliMindColors.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: CaliMindColors.cardBorder),
      ),
      padding: EdgeInsets.only(
        top: 20,
        left: 24,
        right: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 28,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.88,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: CaliMindColors.cardBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: CaliMindColors.primary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      LucideIcons.mic,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Review your request',
                            style: CaliMindTypography.h3.copyWith(fontSize: 16),
                          ),
                          Consumer(
                            builder: (context, ref, _) {
                              final usedAi = ref
                                  .watch(voiceAssistantProvider)
                                  .usedAiParser;
                              if (!usedAi) return const SizedBox.shrink();
                              return Container(
                                margin: const EdgeInsets.only(left: 8),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: CaliMindColors.primary.withValues(
                                    alpha: 0.15,
                                  ),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: CaliMindColors.primary.withValues(
                                      alpha: 0.3,
                                    ),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      LucideIcons.sparkles,
                                      size: 10,
                                      color: CaliMindColors.primary,
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      'Groq AI',
                                      style: CaliMindTypography.bodySmall
                                          .copyWith(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w700,
                                            color: CaliMindColors.primary,
                                          ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                      Text(
                        'Review & confirm before saving',
                        style: CaliMindTypography.label,
                      ),
                    ],
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: widget.onDismissed,
                    icon: const Icon(
                      LucideIcons.x,
                      color: CaliMindColors.mutedForeground,
                      size: 20,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                'What I heard',
                style: CaliMindTypography.label.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Consumer(
                builder: (context, ref, child) {
                  final transcript = ref
                      .watch(voiceAssistantProvider)
                      .finalTranscript;
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: CaliMindColors.surfaceOverlay,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      transcript.isEmpty
                          ? 'Review or edit the task details below.'
                          : '“$transcript”',
                      style: CaliMindTypography.bodySmall.copyWith(
                        color: CaliMindColors.foreground,
                        height: 1.4,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              // Title field
              Text(
                'Task Title',
                style: CaliMindTypography.label.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: CaliMindColors.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: CaliMindColors.cardFocusBorder),
                ),
                child: TextField(
                  controller: _titleCtrl,
                  maxLength: 200,
                  style: CaliMindTypography.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 14,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Category + Duration row
              Row(
                children: [
                  Expanded(child: _buildCategorySelector()),
                  const SizedBox(width: 12),
                  Expanded(child: _buildPrioritySelector()),
                ],
              ),
              const SizedBox(height: 16),
              // Duration stepper
              _buildDurationStepper(),
              const SizedBox(height: 18),
              _buildScheduleControl(
                label: 'Exact start time',
                value: _draft.specificTime ?? 'Choose a time',
                icon: LucideIcons.clock,
                onPressed: _chooseExactTime,
                onClear: _draft.specificTime == null
                    ? null
                    : () => setState(() {
                        _draft = _draft.copyWith(clearSpecificTime: true);
                        _updateDefaultReminder();
                      }),
              ),
              const SizedBox(height: 12),
              _buildScheduleControl(
                label: 'Due date',
                value: _draft.deadline == null
                    ? 'Choose a due date'
                    : DateFormat('EEE, MMM d').format(_draft.deadline!),
                icon: LucideIcons.calendarClock,
                onPressed: _chooseDeadline,
                onClear: _draft.deadline == null
                    ? null
                    : () => setState(() {
                        _draft = _draft.copyWith(clearDeadline: true);
                        _updateDefaultReminder();
                      }),
              ),
              const SizedBox(height: 12),
              _buildScheduleControl(
                label: 'Reminder',
                value: _draft.reminderAt == null
                    ? _reminderDisabled
                          ? 'No reminder'
                          : _defaultReminderLabel
                    : '${_reminderCustomized ? 'Custom' : '30 min before'} · ${DateFormat('EEE, MMM d · h:mm a').format(_draft.reminderAt!)}',
                icon: LucideIcons.bell,
                onPressed: _chooseReminder,
                onClear: _draft.reminderAt == null && !_reminderDisabled
                    ? null
                    : () => setState(() {
                        _draft = _draft.copyWith(clearReminder: true);
                        _reminderCustomized = true;
                        _reminderDisabled = true;
                      }),
              ),
              const SizedBox(height: 5),
              Text(
                'Defaults to 30 minutes before the exact start time. Tap to choose another time or clear to turn it off.',
                style: CaliMindTypography.bodySmall.copyWith(
                  color: CaliMindColors.mutedForeground,
                ),
              ),
              const SizedBox(height: 24),
              // Confirm button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: CaliMindColors.primary,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: ElevatedButton.icon(
                    onPressed: _isSaving ? null : _confirm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: const Icon(
                      LucideIcons.check,
                      color: Colors.white,
                      size: 18,
                    ),
                    label: Text(
                      _isSaving ? 'Saving…' : 'Add Task',
                      style: CaliMindTypography.bodyMedium.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ).animate().slideY(begin: 1, duration: 350.ms, curve: Curves.easeOutCubic);
  }

  Widget _buildScheduleControl({
    required String label,
    required String value,
    required IconData icon,
    required VoidCallback onPressed,
    VoidCallback? onClear,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: CaliMindTypography.label),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onPressed,
                icon: Icon(icon, size: 16),
                label: Text(value, overflow: TextOverflow.ellipsis),
                style: OutlinedButton.styleFrom(
                  foregroundColor: CaliMindColors.foreground,
                  alignment: Alignment.centerLeft,
                  side: const BorderSide(color: CaliMindColors.cardBorder),
                ),
              ),
            ),
            if (onClear != null)
              IconButton(
                tooltip: 'Clear',
                onPressed: onClear,
                icon: const Icon(LucideIcons.x, size: 16),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildCategorySelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Category',
          style: CaliMindTypography.label.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<TaskCategory>(
          initialValue: _draft.category,
          dropdownColor: CaliMindColors.card,
          style: CaliMindTypography.bodySmall.copyWith(
            color: CaliMindColors.foreground,
          ),
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            filled: true,
            fillColor: CaliMindColors.background,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: CaliMindColors.cardBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: CaliMindColors.cardBorder),
            ),
          ),
          items: TaskCategory.values
              .map(
                (cat) => DropdownMenuItem(
                  value: cat,
                  child: Row(
                    children: [
                      Icon(cat.icon, size: 13, color: cat.color),
                      const SizedBox(width: 6),
                      Text(
                        cat.label,
                        style: CaliMindTypography.bodySmall.copyWith(
                          color: CaliMindColors.foreground,
                        ),
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
          onChanged: (cat) {
            if (cat != null)
              setState(() => _draft = _draft.copyWith(category: cat));
          },
        ),
      ],
    );
  }

  Widget _buildPrioritySelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Priority',
          style: CaliMindTypography.label.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Row(
          children: [1, 2, 3].map((p) {
            final isSelected = _draft.priority == p;
            final (label, description, color) = switch (p) {
              1 => ('P1', 'High', CaliMindColors.destructive),
              2 => ('P2', 'Medium', CaliMindColors.warning),
              _ => ('P3', 'Low', CaliMindColors.mutedForeground),
            };
            return Expanded(
              child: GestureDetector(
                onTap: () {
                  HapticFeedbackUtils.selectionClick();
                  setState(() => _draft = _draft.copyWith(priority: p));
                },
                child: Container(
                  margin: EdgeInsets.only(right: p < 3 ? 6 : 0),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? color.withValues(alpha: 0.15)
                        : CaliMindColors.background,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected ? color : CaliMindColors.cardBorder,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Column(
                    children: [
                      Text(
                        label,
                        style: CaliMindTypography.bodySmall.copyWith(
                          color: isSelected
                              ? color
                              : CaliMindColors.mutedForeground,
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                        ),
                      ),
                      Text(
                        description,
                        style: CaliMindTypography.bodySmall.copyWith(
                          color: isSelected
                              ? color
                              : CaliMindColors.mutedForeground,
                          fontSize: 9,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildDurationStepper() {
    final quickDurations = [15, 30, 45, 60];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Duration',
              style: CaliMindTypography.label.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            // Stepper
            _StepperButton(
              icon: LucideIcons.minus,
              onTap: () {
                if (_draft.duration > 5)
                  setState(
                    () =>
                        _draft = _draft.copyWith(duration: _draft.duration - 5),
                  );
              },
            ),
            const SizedBox(width: 12),
            Text(
              _formatDuration(_draft.duration),
              style: CaliMindTypography.timeMonospace.copyWith(fontSize: 15),
            ),
            const SizedBox(width: 12),
            _StepperButton(
              icon: LucideIcons.plus,
              onTap: () {
                if (_draft.duration < 480)
                  setState(
                    () =>
                        _draft = _draft.copyWith(duration: _draft.duration + 5),
                  );
              },
            ),
          ],
        ),
        const SizedBox(height: 10),
        // Quick chips
        Wrap(
          spacing: 8,
          children: quickDurations.map((d) {
            final isSelected = _draft.duration == d;
            return GestureDetector(
              onTap: () =>
                  setState(() => _draft = _draft.copyWith(duration: d)),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? CaliMindColors.primary.withValues(alpha: 0.15)
                      : CaliMindColors.background,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected
                        ? CaliMindColors.primary
                        : CaliMindColors.cardBorder,
                  ),
                ),
                child: Text(
                  '${d}m',
                  style: CaliMindTypography.bodySmall.copyWith(
                    color: isSelected
                        ? CaliMindColors.primary
                        : CaliMindColors.mutedForeground,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  String _formatDuration(int minutes) {
    if (minutes < 60) return '${minutes}m';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return m == 0 ? '${h}h' : '${h}h ${m}m';
  }
}

class _StepperButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _StepperButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: CaliMindColors.background,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: CaliMindColors.cardBorder),
        ),
        child: Icon(icon, size: 14, color: CaliMindColors.foreground),
      ),
    );
  }
}
