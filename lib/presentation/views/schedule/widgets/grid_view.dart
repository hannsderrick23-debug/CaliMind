import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:calimind/core/constants/app_colors.dart';
import 'package:calimind/core/constants/app_typography.dart';
import 'package:calimind/core/constants/schedule_constants.dart';
import 'package:calimind/core/utils/date_time_utils.dart';
import 'package:calimind/domain/models/schedule_slot.dart';

class ScheduleGridView extends StatelessWidget {
  final List<ScheduleSlot> slots;
  final ValueChanged<ScheduleSlot>? onSlotTap;

  const ScheduleGridView({super.key, required this.slots, this.onSlotTap});

  @override
  Widget build(BuildContext context) {
    final quadrants = [
      (
        'Morning',
        LucideIcons.sunrise,
        ScheduleConstants.morningStart,
        ScheduleConstants.morningEnd,
      ),
      (
        'Afternoon',
        LucideIcons.sun,
        ScheduleConstants.afternoonStart,
        ScheduleConstants.afternoonEnd,
      ),
      (
        'Evening',
        LucideIcons.sunset,
        ScheduleConstants.eveningStart,
        ScheduleConstants.eveningEnd,
      ),
      (
        'Night',
        LucideIcons.moon,
        ScheduleConstants.nightStart,
        ScheduleConstants.nightEnd,
      ),
    ];
    final quadrantSlots = quadrants.map((quadrant) {
      final (_, _, start, end) = quadrant;
      return slots.where((slot) {
        final startMin = DateTimeUtils.toMinutes(slot.startTime);
        return startMin >= start && startMin < end;
      }).toList();
    }).toList();
    final maxSlotCount = quadrantSlots.fold<int>(
      0,
      (maximum, items) => items.length > maximum ? items.length : maximum,
    );

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        mainAxisExtent: 112 + maxSlotCount * 52,
      ),
      itemCount: quadrants.length,
      itemBuilder: (context, index) {
        final (label, icon, start, end) = quadrants[index];
        return _QuadrantCard(
          label: label,
          icon: icon,
          startLabel: DateTimeUtils.formatMinutes(start),
          endLabel: DateTimeUtils.formatMinutes(end),
          slots: quadrantSlots[index],
          index: index,
          onSlotTap: onSlotTap,
        );
      },
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
  final ValueChanged<ScheduleSlot>? onSlotTap;

  const _QuadrantCard({
    required this.label,
    required this.icon,
    required this.startLabel,
    required this.endLabel,
    required this.slots,
    required this.index,
    required this.onSlotTap,
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
                    Text(
                      label,
                      style: CaliMindTypography.label.copyWith(
                        fontWeight: FontWeight.w700,
                        color: CaliMindColors.foreground,
                      ),
                    ),
                  ],
                ),
                Text(
                  '$startLabel – $endLabel',
                  style: CaliMindTypography.bodySmall.copyWith(fontSize: 10),
                ),
                const SizedBox(height: 10),
                const Divider(color: CaliMindColors.cardBorder, height: 1),
                const SizedBox(height: 10),
                if (slots.isEmpty)
                  Expanded(
                    child: Center(
                      child: Text(
                        'Free',
                        style: CaliMindTypography.bodySmall.copyWith(
                          fontStyle: FontStyle.italic,
                          color: CaliMindColors.primary.withValues(alpha: 0.4),
                        ),
                      ),
                    ),
                  )
                else
                  ...slots.map(
                    (slot) => _SlotPill(
                      slot: slot,
                      onTap: onSlotTap == null ? null : () => onSlotTap!(slot),
                    ),
                  ),
              ],
            ),
          ),
        )
        .animate(delay: Duration(milliseconds: index * 80))
        .fadeIn(duration: 400.ms)
        .scale(begin: const Offset(0.95, 0.95));
  }
}

class _SlotPill extends StatelessWidget {
  final ScheduleSlot slot;
  final VoidCallback? onTap;

  const _SlotPill({required this.slot, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = slot.category.color;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Text(
              slot.startTime,
              style: CaliMindTypography.timeMonospace.copyWith(
                fontSize: 10,
                color: color,
              ),
            ),
            const SizedBox(width: 5),
            Expanded(
              child: Text(
                slot.taskTitle,
                style: CaliMindTypography.bodySmall.copyWith(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: CaliMindColors.foreground,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (onTap != null)
              const Icon(
                LucideIcons.moreVertical,
                size: 15,
                color: CaliMindColors.mutedForeground,
              ),
          ],
        ),
      ),
    );
  }
}
