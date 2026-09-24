import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/constants/schedule_constants.dart';
import '../../../../core/utils/date_time_utils.dart';
import '../../../../domain/models/schedule_slot.dart';

class ScheduleGridView extends StatelessWidget {
  final List<ScheduleSlot> slots;

  const ScheduleGridView({super.key, required this.slots});

  @override
  Widget build(BuildContext context) {
    final quadrants = [
      ('Morning', LucideIcons.sunrise, ScheduleConstants.morningStart, ScheduleConstants.morningEnd),
      ('Afternoon', LucideIcons.sun, ScheduleConstants.afternoonStart, ScheduleConstants.afternoonEnd),
      ('Evening', LucideIcons.sunset, ScheduleConstants.eveningStart, ScheduleConstants.eveningEnd),
      ('Night', LucideIcons.moon, ScheduleConstants.nightStart, ScheduleConstants.nightEnd),
    ];

    return GridView.count(
      crossAxisCount: 2,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 0.85,
      children: quadrants.asMap().entries.map((entry) {
        final index = entry.key;
        final (label, icon, start, end) = entry.value;
        final quadrantSlots = slots.where((s) {
          final startMin = DateTimeUtils.toMinutes(s.startTime);
          return startMin >= start && startMin < end;
        }).toList();

        return _QuadrantCard(
          label: label,
          icon: icon,
          startLabel: DateTimeUtils.formatMinutes(start),
          endLabel: DateTimeUtils.formatMinutes(end),
          slots: quadrantSlots,
          index: index,
        );
      }).toList(),
    );
  }
}

class _QuadrantCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final String startLabel;
  final String endLabel;
  final List<ScheduleSlot> slots;
  final int index;

  const _QuadrantCard({
    required this.label,
    required this.icon,
    required this.startLabel,
    required this.endLabel,
    required this.slots,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: CaliMindColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: CaliMindColors.cardBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 14, color: CaliMindColors.primary),
                const SizedBox(width: 6),
                Text(label, style: CaliMindTypography.label.copyWith(
                  fontWeight: FontWeight.w700,
                  color: CaliMindColors.foreground,
                )),
              ],
            ),
            Text(
              '$startLabel – $endLabel',
              style: CaliMindTypography.bodySmall.copyWith(fontSize: 10),
            ),
            const SizedBox(height: 10),
            Divider(color: CaliMindColors.cardBorder, height: 1),
            const SizedBox(height: 10),
            Expanded(
              child: slots.isEmpty
                  ? Center(
                      child: Text('Free', style: CaliMindTypography.bodySmall.copyWith(
                        fontStyle: FontStyle.italic,
                        color: CaliMindColors.primary.withOpacity(0.4),
                      )),
                    )
                  : ListView(
                      children: slots.map((s) => _SlotPill(slot: s)).toList(),
                    ),
            ),
          ],
        ),
      ),
    ).animate(delay: Duration(milliseconds: index * 80))
        .fadeIn(duration: 400.ms)
        .scale(begin: const Offset(0.95, 0.95));
  }
}

class _SlotPill extends StatelessWidget {
  final ScheduleSlot slot;

  const _SlotPill({required this.slot});

  @override
  Widget build(BuildContext context) {
    final color = slot.category.color;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Text(
            slot.startTime,
            style: CaliMindTypography.timeMonospace.copyWith(fontSize: 9, color: color),
          ),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              slot.taskTitle,
              style: CaliMindTypography.bodySmall.copyWith(
                  fontSize: 10, fontWeight: FontWeight.w500),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
