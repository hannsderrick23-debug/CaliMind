import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../domain/models/schedule_slot.dart';

class TimelineView extends StatelessWidget {
  final List<ScheduleSlot> slots;

  const TimelineView({super.key, required this.slots});

  @override
  Widget build(BuildContext context) {
    if (slots.isEmpty) {
      return const Center(
        child: Text('No slots scheduled', style: TextStyle(color: CaliMindColors.mutedForeground)),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
      itemCount: slots.length * 2 - 1,
      itemBuilder: (context, i) {
        if (i.isEven) {
          final slot = slots[i ~/ 2];
          return _TimelineSlotCard(slot: slot, index: i ~/ 2);
        } else {
          // 15-minute buffer indicator
          return _BufferCard();
        }
      },
    );
  }
}

class _TimelineSlotCard extends StatelessWidget {
  final ScheduleSlot slot;
  final int index;

  const _TimelineSlotCard({required this.slot, required this.index});

  @override
  Widget build(BuildContext context) {
    final color = slot.category.color;

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: CaliMindColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border(
          left: BorderSide(color: color, width: 4),
          top: BorderSide(color: CaliMindColors.cardBorder),
          right: BorderSide(color: CaliMindColors.cardBorder),
          bottom: BorderSide(color: CaliMindColors.cardBorder),
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Time column
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(slot.startTime, style: CaliMindTypography.timeMonospace.copyWith(fontSize: 13, color: color)),
                const SizedBox(height: 2),
                Text(slot.endTime, style: CaliMindTypography.timeMonospace.copyWith(fontSize: 11, color: CaliMindColors.mutedForeground)),
              ],
            ),
            const SizedBox(width: 14),
            Container(width: 1, height: 32, color: color.withOpacity(0.3)),
            const SizedBox(width: 14),
            // Task info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    slot.taskTitle,
                    style: CaliMindTypography.bodyMedium.copyWith(fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(slot.category.icon, size: 11, color: color),
                      const SizedBox(width: 5),
                      Text(slot.category.label, style: CaliMindTypography.bodySmall.copyWith(color: color, fontSize: 11)),
                      const SizedBox(width: 10),
                      Icon(LucideIcons.clock, size: 11, color: CaliMindColors.mutedForeground),
                      const SizedBox(width: 4),
                      Text('${slot.duration}m', style: CaliMindTypography.bodySmall.copyWith(fontSize: 11)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ).animate(delay: Duration(milliseconds: index * 60)).fadeIn(duration: 350.ms).slideX(begin: 0.05);
  }
}

class _BufferCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: CaliMindColors.primary.withOpacity(0.2),
          style: BorderStyle.solid,
        ),
      ),
      child: Row(
        children: [
          Icon(LucideIcons.coffee, size: 11, color: CaliMindColors.primary.withOpacity(0.5)),
          const SizedBox(width: 8),
          Text(
            '15 min buffer',
            style: CaliMindTypography.bodySmall.copyWith(
              fontSize: 10,
              color: CaliMindColors.primary.withOpacity(0.5),
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}
