import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:calimind/core/constants/app_colors.dart';
import 'package:calimind/core/constants/app_typography.dart';
import 'package:calimind/core/utils/task_reminder_utils.dart';
import 'package:calimind/core/utils/haptic_feedback_utils.dart';
import 'package:calimind/core/utils/app_feedback.dart';
import 'package:calimind/core/services/task_reminder_service.dart';
import 'package:calimind/core/services/widget_service.dart';
import 'package:calimind/domain/models/task.dart';
import 'package:calimind/presentation/state/schedule_provider.dart';
import 'package:calimind/presentation/state/task_provider.dart';
import 'package:calimind/presentation/widgets/star_loading_indicator.dart';

class TaskInputSheet extends ConsumerStatefulWidget {
  final Task? taskToEdit;

  const TaskInputSheet({super.key, this.taskToEdit});

  @override
  ConsumerState<TaskInputSheet> createState() => _TaskInputSheetState();
}

class _TaskInputSheetState extends ConsumerState<TaskInputSheet> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  TaskCategory _category = TaskCategory.personal;
  int _duration = 30;
  int _priority = 2;
  PreferredTime? _preferredTime;
  String? _specificTime;
  DateTime? _deadline;
  DateTime? _reminderAt;
  bool _reminderCustomized = false;
  bool _reminderDisabled = false;
  bool _showDefaultReminder = false;
  TaskRecurrence? _recurrence;
  bool _isSaving = false;
  bool _allowExit = false;

  bool get _isEditing => widget.taskToEdit != null;

  bool get _hasUnsavedChanges {
    final original = widget.taskToEdit;
    if (original == null) {
      return _titleCtrl.text.trim().isNotEmpty ||
          _descCtrl.text.trim().isNotEmpty ||
          _deadline != null ||
          _reminderAt != null ||
          _specificTime != null ||
          _preferredTime != null ||
          _recurrence != null ||
          _category != TaskCategory.personal ||
          _duration != 30 ||
          _priority != 2;
    }
    return _titleCtrl.text.trim() != original.title ||
        _descCtrl.text.trim() != (original.description ?? '') ||
        _category != original.category ||
        _duration != original.duration ||
        _priority != original.priority ||
        _preferredTime != original.preferredTime ||
        _specificTime != original.specificTime ||
        _deadline != original.deadline ||
        _reminderAt != original.reminderAt ||
        _recurrence != original.recurrence;
  }

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final t = widget.taskToEdit!;
      _titleCtrl.text = t.title;
      _descCtrl.text = t.description ?? '';
      _category = t.category;
      _duration = t.duration;
      _priority = t.priority;
      _preferredTime = t.preferredTime;
      _specificTime = t.specificTime;
      _deadline = t.deadline;
      _reminderAt = t.reminderAt;
      final defaultReminder = defaultTaskReminderAt(
        specificTime: t.specificTime,
        deadline: t.deadline,
      );
      _reminderCustomized =
          t.reminderAt != null && t.reminderAt != defaultReminder;
      _showDefaultReminder =
          t.reminderAt != null && t.reminderAt == defaultReminder;
      _recurrence = t.recurrence;
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      AppFeedback.error(
        ScaffoldMessenger.of(context),
        'Enter a title before saving.',
      );
      return;
    }

    setState(() => _isSaving = true);
    await HapticFeedbackUtils.heavyImpact();

    String? taskId;
    if (_isEditing) {
      final updated = widget.taskToEdit!.copyWith(
        title: title,
        description: _descCtrl.text.trim().isEmpty
            ? null
            : _descCtrl.text.trim(),
        category: _category,
        duration: _duration,
        priority: _priority,
        preferredTime: _preferredTime,
        clearPreferredTime: _preferredTime == null,
        specificTime: _specificTime,
        clearSpecificTime: _specificTime == null,
        deadline: _deadline,
        clearDeadline: _deadline == null,
        reminderAt: _reminderAt,
        clearReminder: _reminderAt == null,
        recurrence: _recurrence,
        clearRecurrence: _recurrence == null,
      );
      if (await ref.read(taskProvider.notifier).updateTask(updated)) {
        taskId = updated.id;
      }
    } else {
      final created = await ref
          .read(taskProvider.notifier)
          .createTask(
            NewTask(
              title: title,
              description: _descCtrl.text.trim().isEmpty
                  ? null
                  : _descCtrl.text.trim(),
              category: _category,
              duration: _duration,
              priority: _priority,
              preferredTime: _preferredTime,
              specificTime: _specificTime,
              deadline: _deadline,
              reminderAt: _reminderAt,
              recurrence: _recurrence,
            ),
          );
      taskId = created?.id;
    }

    if (taskId == null) {
      if (mounted) {
        setState(() => _isSaving = false);
        final error = ref.read(taskProvider.notifier).lastOperationError;
        AppFeedback.error(
          ScaffoldMessenger.of(context),
          error == null || error.isEmpty
              ? 'Could not save this task. Check your connection and try again.'
              : 'Could not save task: $error',
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

    final reminders = TaskReminderService();
    if (_reminderAt == null &&
        _isEditing &&
        widget.taskToEdit!.reminderAt != null) {
      try {
        await reminders.cancelTaskReminder(taskId);
      } catch (error) {
        debugPrint('Could not cancel reminder for task $taskId: $error');
        if (mounted) {
          AppFeedback.info(
            ScaffoldMessenger.of(context),
            'Task saved, but its old reminder could not be cancelled.',
          );
        }
      }
    } else if (_reminderAt != null) {
      var scheduled = false;
      try {
        scheduled = await reminders.scheduleTaskReminder(
          taskId: taskId,
          title: title,
          reminderAt: _reminderAt!,
        );
      } catch (error) {
        debugPrint('Could not schedule reminder for task $taskId: $error');
      }
      if (!scheduled && mounted) {
        AppFeedback.info(
          ScaffoldMessenger.of(context),
          'Task saved, but the reminder could not be scheduled. Choose a future time and allow notifications.',
        );
      }
    }

    if (mounted) {
      final messenger = ScaffoldMessenger.of(context);
      setState(() => _allowExit = true);
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      Navigator.pop(context);
      AppFeedback.success(
        messenger,
        _isEditing ? 'Task updated.' : 'Task added.',
      );
    }
  }

  Future<void> _requestClose() async {
    if (_allowExit || _isSaving) return;
    if (!_hasUnsavedChanges) {
      Navigator.pop(context);
      return;
    }
    final discard = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Discard changes?'),
        content: const Text('Your unsaved task changes will be lost.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep editing'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    if (discard != true || !mounted) return;
    setState(() => _allowExit = true);
    AppFeedback.info(
      ScaffoldMessenger.of(context),
      'Unsaved changes discarded.',
    );
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    Navigator.pop(context);
  }

  Future<void> _selectSpecificTime() async {
    final selected = await showTimePicker(
      context: context,
      initialTime: _specificTime == null
          ? TimeOfDay.now()
          : TimeOfDay(
              hour: int.parse(_specificTime!.split(':')[0]),
              minute: int.parse(_specificTime!.split(':')[1]),
            ),
    );
    if (selected != null) {
      setState(() {
        _specificTime =
            '${selected.hour.toString().padLeft(2, '0')}:${selected.minute.toString().padLeft(2, '0')}';
        _updateDefaultReminder();
      });
    }
  }

  Future<void> _selectDeadline() async {
    final initialDate = _deadline ?? DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime.now().subtract(const Duration(days: 3650)),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (selected != null) {
      setState(() {
        _deadline = DateTime(
          selected.year,
          selected.month,
          selected.day,
          23,
          59,
        );
        _updateDefaultReminder();
      });
    }
  }

  String get _defaultReminderLabel {
    final reminder = defaultTaskReminderAt(
      specificTime: _specificTime,
      deadline: _deadline,
    );
    return reminder == null
        ? 'Set a reminder'
        : '30 min before · ${DateFormat('EEE, MMM d · h:mm a').format(reminder)}';
  }

  void _updateDefaultReminder() {
    if (_reminderCustomized || _reminderDisabled) return;
    _showDefaultReminder = true;
    _reminderAt = defaultTaskReminderAt(
      specificTime: _specificTime,
      deadline: _deadline,
    );
  }

  Future<void> _selectReminder() async {
    final initial =
        _reminderAt ??
        defaultTaskReminderAt(
          specificTime: _specificTime,
          deadline: _deadline,
        ) ??
        DateTime.now().add(const Duration(hours: 1));
    final now = DateTime.now();
    final initialDate = initial.isBefore(now) ? now : initial;
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: DateTime(
        initialDate.year,
        initialDate.month,
        initialDate.day,
      ),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (selectedDate == null || !mounted) return;

    final selectedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (selectedTime != null) {
      setState(() {
        _reminderAt = DateTime(
          selectedDate.year,
          selectedDate.month,
          selectedDate.day,
          selectedTime.hour,
          selectedTime.minute,
        );
        _reminderCustomized = true;
        _reminderDisabled = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _allowExit || !_hasUnsavedChanges,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _requestClose();
      },
      child: Container(
        decoration: const BoxDecoration(
          color: CaliMindColors.card,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.only(
          top: 20,
          left: 24,
          right: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom + 28,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
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
                    child: Icon(
                      _isEditing ? LucideIcons.pencil : LucideIcons.plus,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    _isEditing ? 'Edit Task' : 'New Task',
                    style: CaliMindTypography.h3,
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: _requestClose,
                    icon: const Icon(
                      LucideIcons.x,
                      color: CaliMindColors.mutedForeground,
                      size: 20,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),

              // Title
              _buildLabel('Title *'),
              const SizedBox(height: 8),
              _buildTextField(
                controller: _titleCtrl,
                hint: 'What do you need to do?',
                autofocus: !_isEditing,
                maxLength: 200,
              ),
              const SizedBox(height: 16),

              // Keep notes in the existing task description field for backwards compatibility.
              _buildLabel('Short notes (optional)'),
              const SizedBox(height: 8),
              _buildTextField(
                controller: _descCtrl,
                hint: 'Write a quick note about this task...',
                maxLines: 3,
                maxLength: 300,
              ),
              const SizedBox(height: 18),

              // Category
              _buildLabel('Category'),
              const SizedBox(height: 8),
              _buildCategoryChips(),
              const SizedBox(height: 18),

              // Duration + Priority row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _buildDurationControl()),
                  const SizedBox(width: 16),
                  Expanded(child: _buildPriorityControl()),
                ],
              ),
              const SizedBox(height: 18),

              // Preferred time
              _buildLabel('Preferred Time'),
              const SizedBox(height: 8),
              _buildPreferredTimeChips(),
              const SizedBox(height: 18),

              _buildLabel('Exact time'),
              const SizedBox(height: 8),
              _buildDateAction(
                icon: LucideIcons.clock,
                label: _specificTime ?? 'Choose a start time',
                onPressed: _selectSpecificTime,
                onClear: _specificTime == null
                    ? null
                    : () => setState(() {
                        _specificTime = null;
                        _updateDefaultReminder();
                      }),
              ),
              const SizedBox(height: 14),
              _buildLabel('Due date'),
              const SizedBox(height: 8),
              _buildDateAction(
                icon: LucideIcons.calendarClock,
                label: _deadline == null
                    ? 'Choose a due date'
                    : DateFormat('EEE, MMM d').format(_deadline!),
                onPressed: _selectDeadline,
                onClear: _deadline == null
                    ? null
                    : () => setState(() {
                        _deadline = null;
                        _updateDefaultReminder();
                      }),
              ),
              const SizedBox(height: 14),
              _buildLabel('Reminder'),
              const SizedBox(height: 8),
              _buildDateAction(
                icon: LucideIcons.bell,
                label: _reminderAt == null
                    ? _reminderDisabled
                          ? 'No reminder'
                          : _showDefaultReminder
                          ? _defaultReminderLabel
                          : 'Set a reminder'
                    : '${_reminderCustomized ? 'Custom' : '30 min before'} · ${DateFormat('EEE, MMM d · h:mm a').format(_reminderAt!)}',
                onPressed: _selectReminder,
                onClear: _reminderAt == null && !_reminderDisabled
                    ? null
                    : () => setState(() {
                        _reminderAt = null;
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
              const SizedBox(height: 14),
              _buildLabel('Repeat'),
              const SizedBox(height: 4),
              Text(
                'Create the next task only after you complete this one.',
                style: CaliMindTypography.bodySmall.copyWith(
                  color: CaliMindColors.mutedForeground,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  _TimeChip(
                    label: 'Does not repeat',
                    isSelected: _recurrence == null,
                    onTap: () => setState(() => _recurrence = null),
                  ),
                  ...TaskRecurrence.values.map(
                    (recurrence) => _TimeChip(
                      label: recurrence.label,
                      isSelected: _recurrence == recurrence,
                      onTap: () => setState(() => _recurrence = recurrence),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 26),

              // Save button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: CaliMindColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: const StarLoadingIndicator(
                            size: 22,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          _isEditing ? 'Save Changes' : 'Add Task',
                          style: CaliMindTypography.bodyLarge.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ).animate().slideY(begin: 1, duration: 350.ms, curve: Curves.easeOutCubic),
    );
  }

  Widget _buildLabel(String text) => Text(
    text,
    style: CaliMindTypography.label.copyWith(fontWeight: FontWeight.w600),
  );

  Widget _buildDateAction({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    VoidCallback? onClear,
  }) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onPressed,
            icon: Icon(icon, size: 17),
            label: Text(label, overflow: TextOverflow.ellipsis),
            style: OutlinedButton.styleFrom(
              alignment: Alignment.centerLeft,
              foregroundColor: CaliMindColors.foreground,
              side: const BorderSide(color: CaliMindColors.cardBorder),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    int maxLines = 1,
    bool autofocus = false,
    int? maxLength,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: CaliMindColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: CaliMindColors.cardBorder),
      ),
      child: TextField(
        controller: controller,
        onChanged: (_) => setState(() {}),
        autofocus: autofocus,
        maxLines: maxLines,
        maxLength: maxLength,
        style: CaliMindTypography.bodyMedium,
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: hint,
          hintStyle: CaliMindTypography.bodyMedium.copyWith(
            color: CaliMindColors.mutedForeground,
          ),
          counterText: '',
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryChips() {
    return LayoutBuilder(
      builder: (context, constraints) => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: TaskCategory.values.map((cat) {
          final isSelected = _category == cat;
          return ConstrainedBox(
            constraints: BoxConstraints(maxWidth: constraints.maxWidth),
            child: GestureDetector(
              onTap: () {
                HapticFeedbackUtils.selectionClick();
                setState(() => _category = cat);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? cat.color.withValues(alpha: 0.15)
                      : CaliMindColors.background,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected ? cat.color : CaliMindColors.cardBorder,
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      cat.icon,
                      size: 12,
                      color: isSelected
                          ? cat.color
                          : CaliMindColors.mutedForeground,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        cat.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: CaliMindTypography.bodySmall.copyWith(
                          color: isSelected
                              ? cat.color
                              : CaliMindColors.mutedForeground,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildDurationControl() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel('Duration'),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: CaliMindColors.background,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: CaliMindColors.cardBorder),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                onTap: () =>
                    setState(() => _duration = (_duration - 15).clamp(5, 480)),
                child: const Icon(
                  LucideIcons.minus,
                  size: 16,
                  color: CaliMindColors.mutedForeground,
                ),
              ),
              Text(
                _formatDur(_duration),
                style: CaliMindTypography.timeMonospace.copyWith(fontSize: 14),
              ),
              GestureDetector(
                onTap: () =>
                    setState(() => _duration = (_duration + 15).clamp(5, 480)),
                child: const Icon(
                  LucideIcons.plus,
                  size: 16,
                  color: CaliMindColors.mutedForeground,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPriorityControl() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel('Priority'),
        const SizedBox(height: 8),
        Row(
          children: [1, 2, 3].map((p) {
            final isSelected = _priority == p;
            final (label, description, color) = switch (p) {
              1 => ('P1', 'High', CaliMindColors.destructive),
              2 => ('P2', 'Medium', CaliMindColors.warning),
              _ => ('P3', 'Low', CaliMindColors.mutedForeground),
            };
            return Expanded(
              child: GestureDetector(
                onTap: () {
                  HapticFeedbackUtils.selectionClick();
                  setState(() => _priority = p);
                },
                child: Container(
                  margin: EdgeInsets.only(right: p < 3 ? 4 : 0),
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

  Widget _buildPreferredTimeChips() {
    return Wrap(
      spacing: 8,
      children: [
        _TimeChip(
          label: 'Any',
          isSelected: _preferredTime == null,
          onTap: () => setState(() => _preferredTime = null),
        ),
        ...PreferredTime.values.map(
          (pt) => _TimeChip(
            label: pt.label,
            isSelected: _preferredTime == pt,
            onTap: () => setState(() => _preferredTime = pt),
          ),
        ),
      ],
    );
  }

  String _formatDur(int min) {
    if (min < 60) return '${min}m';
    final h = min ~/ 60;
    final m = min % 60;
    return m == 0 ? '${h}h' : '${h}h ${m}m';
  }
}

class _TimeChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _TimeChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? CaliMindColors.primary.withValues(alpha: 0.15)
              : CaliMindColors.background,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? CaliMindColors.primary
                : CaliMindColors.cardBorder,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: CaliMindTypography.bodySmall.copyWith(
            color: isSelected
                ? CaliMindColors.primary
                : CaliMindColors.mutedForeground,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}
