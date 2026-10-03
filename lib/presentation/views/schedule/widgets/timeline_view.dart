import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:calimind/core/constants/app_colors.dart';
import 'package:calimind/core/constants/app_typography.dart';
import 'package:calimind/domain/models/schedule_slot.dart';

class TimelineView extends StatelessWidget {
  final List<ScheduleSlot> slots;
  final ValueChanged<ScheduleSlot>? onSlotTap;

  const TimelineView({super.key, required this.slots, this.onSlotTap});

  @override
  Widget build(BuildContext context) {
    if (slots.isEmpty) {
      return const Center(
        child: Text('No slots scheduled',
            style: TextStyle(color: CaliMindColors.mutedForeground)),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
      itemCount: slots.length * 2 - 1,
      itemBuilder: (context, i) {
        if (i.isEven) {
          final slot = slots[i ~/ 2];
          return _TimelineSlotCard(
            slot: slot,
            index: i ~/ 2,
            onTap: onSlotTap == null ? null : () => onSlotTap!(slot),
          );
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
  final VoidCallback? onTap;

  const _TimelineSlotCard({
    required this.slot,
    required this.index,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = slot.category.color;

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: CaliMindColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: CaliMindColors.cardBorder),
        boxShadow: [
          BoxShadow(
            color: CaliMindColors.foreground.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    slot.startTime,
                    style: CaliMindTypography.timeMonospace.copyWith(
                      fontSize: 13,
                      color: CaliMindColors.foreground,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    slot.endTime,
                    style: CaliMindTypography.timeMonospace.copyWith(
                      fontSize: 11,
                      color: CaliMindColors.mutedForeground,
                    ),
                  ),
                ],
                ),
                const SizedBox(width: 14),
                Container(
                width: 1,
                height: 32,
                color: CaliMindColors.cardBorder,
                ),
                const SizedBox(width: 14),
                Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      slot.taskTitle,
                      style: CaliMindTypography.bodyMedium.copyWith(
                        fontWeight: FontWeight.w700,
                        color: CaliMindColors.foreground,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 10,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Icon(
                          slot.category.icon,
                          size: 11,
                          color: color,
                        ),
                        Text(
                          slot.category.label,
                          style: CaliMindTypography.bodySmall.copyWith(
                            color: color,
                            fontSize: 11,
                          ),
                        ),
                        const Icon(
                          LucideIcons.clock,
                          size: 11,
                          color: CaliMindColors.mutedForeground,
                        ),
                        Text(
                          '${slot.duration}m',
                          style: CaliMindTypography.bodySmall.copyWith(
                            color: CaliMindColors.foreground,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                ),
                if (onTap != null) ...[
                  const SizedBox(width: 8),
                  const Icon(
                    LucideIcons.moreVertical,
                    size: 18,
                    color: CaliMindColors.mutedForeground,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    )
        .animate(delay: Duration(milliseconds: index * 60))
        .fadeIn(duration: 350.ms)
        .slideX(begin: 0.05);
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
          color: CaliMindColors.primary.withValues(alpha: 0.2),
          style: BorderStyle.solid,
        ),
      ),
      child: Row(
        children: [
          Icon(LucideIcons.coffee,
              size: 11, color: CaliMindColors.primary.withValues(alpha: 0.5)),
          const SizedBox(width: 8),
          Text(
            '15 min buffer',
            style: CaliMindTypography.bodySmall.copyWith(
              fontSize: 10,
              color: CaliMindColors.primary.withValues(alpha: 0.5),
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}
