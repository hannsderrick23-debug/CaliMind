import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:calimind/core/constants/app_colors.dart';
import 'package:calimind/core/constants/app_typography.dart';
import 'package:calimind/domain/models/schedule_slot.dart';
import 'package:calimind/domain/models/task.dart';

class MonthCalendarView extends StatelessWidget {
  final DateTime month;
  final DateTime selectedDate;
  final List<Task> tasks;
  final List<ScheduleSlot> scheduledSlots;
  final ValueChanged<DateTime> onDateSelected;
  final ValueChanged<int> onMonthChanged;

  const MonthCalendarView({
    super.key,
    required this.month,
    required this.selectedDate,
    required this.tasks,
    required this.scheduledSlots,
    required this.onDateSelected,
    required this.onMonthChanged,
  });

  @override
  Widget build(BuildContext context) {
    final firstDay = DateTime(month.year, month.month);
    final leadingDays = firstDay.weekday - DateTime.monday;
    final dayCount = DateUtils.getDaysInMonth(month.year, month.month);
    final weekCount = ((leadingDays + dayCount) / 7).ceil();
    final dateCount = weekCount * 7;
    final selectedTasks = tasks.where((task) => _hasDate(task, selectedDate)).toList();
    final selectedSlots = scheduledSlots
        .where((slot) => slot.scheduleDate == _dateKey(selectedDate))
        .length;
    final selectedSummary = [
      if (selectedTasks.isNotEmpty)
        '${selectedTasks.length} task${selectedTasks.length == 1 ? '' : 's'}',
      if (selectedSlots > 0)
        '$selectedSlots scheduled block${selectedSlots == 1 ? '' : 's'}',
    ].join('  ·  ');

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      decoration: BoxDecoration(
        color: CaliMindColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: CaliMindColors.cardBorder),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Text(
                DateFormat('MMMM yyyy').format(month),
                style: CaliMindTypography.bodyMedium.copyWith(
                  fontWeight: FontWeight.w700,
                  color: CaliMindColors.foreground,
                ),
              ),
              const Spacer(),
              _MonthArrow(
                tooltip: 'Previous month',
                icon: LucideIcons.chevronLeft,
                onPressed: () => onMonthChanged(-1),
              ),
              _MonthArrow(
                tooltip: 'Next month',
                icon: LucideIcons.chevronRight,
                onPressed: () => onMonthChanged(1),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: const ['M', 'T', 'W', 'T', 'F', 'S', 'S']
                .map(
                  (label) => Expanded(
                    child: Center(
                      child: Text(
                        label,
                        style: CaliMindTypography.bodySmall.copyWith(
                          fontSize: 10,
                          color: CaliMindColors.mutedForeground,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            itemCount: dateCount,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisExtent: 31,
            ),
            itemBuilder: (context, index) {
              final day = index - leadingDays + 1;
              if (day < 1 || day > dayCount) return const SizedBox.shrink();

              final date = DateTime(month.year, month.month, day);
              final isSelected = DateUtils.isSameDay(date, selectedDate);
              final isToday = DateUtils.isSameDay(date, DateTime.now());
              final hasTasks = tasks.any((task) => _hasDate(task, date));
              final hasSchedule = scheduledSlots.any(
                (slot) => slot.scheduleDate == _dateKey(date),
              );
              final hasActivity = hasTasks || hasSchedule;

              return Semantics(
                button: true,
                selected: isSelected,
                label: DateFormat('EEEE, MMMM d').format(date),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => onDateSelected(date),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 26,
                        height: 26,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? CaliMindColors.primary
                              : isToday
                                  ? CaliMindColors.surfaceOverlay
                                  : Colors.transparent,
                          shape: BoxShape.circle,
                          border: isToday && !isSelected
                              ? Border.all(color: CaliMindColors.primary)
                              : null,
                        ),
                        child: Text(
                          '$day',
                          style: CaliMindTypography.bodySmall.copyWith(
                            fontSize: 11,
                            fontWeight: isSelected || isToday
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: isSelected
                                ? Colors.white
                                : CaliMindColors.foreground,
                          ),
                        ),
                      ),
                      SizedBox(
                        height: 3,
                        child: hasActivity
                            ? Container(
                                width: 3,
                                decoration: const BoxDecoration(
                                  color: CaliMindColors.accent,
                                  shape: BoxShape.circle,
                                ),
                              )
                            : null,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 5),
          Row(
            children: [
              const Icon(
                LucideIcons.calendarDays,
                size: 13,
                color: CaliMindColors.primary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  selectedSummary.isEmpty
                      ? 'No tasks or activities on this day'
                      : selectedSummary,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: CaliMindTypography.bodySmall.copyWith(
                    color: CaliMindColors.mutedForeground,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          if (selectedTasks.isNotEmpty) ...[
            const SizedBox(height: 3),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                selectedTasks.take(2).map((task) => task.title).join('  ·  '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: CaliMindTypography.bodySmall.copyWith(
                  color: CaliMindColors.foreground,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  bool _hasDate(Task task, DateTime date) =>
      _sameDate(task.deadline, date) || _sameDate(task.reminderAt, date);

  bool _sameDate(DateTime? value, DateTime date) {
    if (value == null) return false;
    final localDate = value.toLocal();
    return localDate.year == date.year &&
        localDate.month == date.month &&
        localDate.day == date.day;
  }

  String _dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}

class _MonthArrow extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  const _MonthArrow({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) => IconButton(
        tooltip: tooltip,
        visualDensity: VisualDensity.compact,
        constraints: const BoxConstraints.tightFor(width: 34, height: 34),
        padding: EdgeInsets.zero,
        onPressed: onPressed,
        icon: Icon(icon, size: 17, color: CaliMindColors.primary),
      );
}
