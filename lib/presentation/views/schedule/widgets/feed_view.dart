import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../domain/models/schedule_slot.dart';
import '../../../../core/utils/date_time_utils.dart';

class FeedView extends StatelessWidget {
  final List<ScheduleSlot> slots;

  const FeedView({super.key, required this.slots});

  int _currentSlotIndex() {
    final now = DateTime.now();
    final nowMin = now.hour * 60 + now.minute;
    for (var i = 0; i < slots.length; i++) {
      final start = DateTimeUtils.toMinutes(slots[i].startTime);
      final end = DateTimeUtils.toMinutes(slots[i].endTime);
      if (nowMin >= start && nowMin < end) return i;
      if (nowMin < start) return i; // upcoming
    }
    return -1; // all done
  }

  @override
  Widget build(BuildContext context) {
    if (slots.isEmpty) {
      return const Center(
        child: Text('No tasks scheduled', style: TextStyle(color: CaliMindColors.mutedForeground)),
      );
    }

    final upNextIndex = _currentSlotIndex();

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
      itemCount: slots.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final slot = slots[index];
        final isUpNext = index == upNextIndex;
        final isDone = upNextIndex >= 0 && index < upNextIndex;

        return _FeedCard(
          slot: slot,
          index: index,
          isUpNext: isUpNext,
          isDone: isDone,
        );
      },
    );
  }
}

class _FeedCard extends StatelessWidget {
  final ScheduleSlot slot;
  final int index;
  final bool isUpNext;
  final bool isDone;

  const _FeedCard({
    required this.slot,
    required this.index,
    required this.isUpNext,
    required this.isDone,
  });

  @override
  Widget build(BuildContext context) {
    final color = slot.category.color;

    return Container(
      decoration: BoxDecoration(
        color: isUpNext ? CaliMindColors.primary.withOpacity(0.08) : CaliMindColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isUpNext ? CaliMindColors.primary.withOpacity(0.5) : CaliMindColors.cardBorder,
          width: isUpNext ? 1.5 : 1,
        ),
        boxShadow: isUpNext
            ? [BoxShadow(color: CaliMindColors.primary.withOpacity(0.15), blurRadius: 20, spreadRadius: 1)]
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Up Next badge
            if (isUpNext)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  gradient: CaliMindColors.mindGradient,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(LucideIcons.zap, size: 11, color: Colors.white),
                    const SizedBox(width: 5),
                    Text('UP NEXT', style: CaliMindTypography.bodySmall.copyWith(
                      fontSize: 10,
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                    )),
                  ],
                ),
              ).animate(onPlay: (c) => c.repeat(reverse: true)).shimmer(duration: 1500.ms),
            // Title row
            Row(
              children: [
                Expanded(
                  child: Text(
                    slot.taskTitle,
                    style: CaliMindTypography.h3.copyWith(
                      fontSize: isUpNext ? 18 : 15,
                      color: isDone ? CaliMindColors.mutedForeground : CaliMindColors.foreground,
                      decoration: isDone ? TextDecoration.lineThrough : null,
                    ),
                  ),
                ),
                if (isDone)
                  const Icon(LucideIcons.checkCircle2, size: 18, color: CaliMindColors.success),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(slot.category.icon, size: 12, color: color),
                const SizedBox(width: 5),
                Text(slot.category.label, style: CaliMindTypography.bodySmall.copyWith(color: color)),
                const SizedBox(width: 14),
                Icon(LucideIcons.clock, size: 12, color: CaliMindColors.mutedForeground),
                const SizedBox(width: 5),
                Text('${slot.startTime} – ${slot.endTime}', style: CaliMindTypography.timeMonospace.copyWith(fontSize: 12)),
                const SizedBox(width: 14),
                Text('${slot.duration}m', style: CaliMindTypography.bodySmall.copyWith(fontSize: 11)),
              ],
            ),
          ],
        ),
      ),
    ).animate(delay: Duration(milliseconds: index * 60)).fadeIn(duration: 350.ms).slideY(begin: 0.05);
  }
}
