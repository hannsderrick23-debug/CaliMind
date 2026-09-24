import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../domain/models/schedule_slot.dart';

class NeedsAttentionSheet extends StatelessWidget {
  final List<UnscheduledTask> unscheduled;

  const NeedsAttentionSheet({super.key, required this.unscheduled});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: CaliMindColors.card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: CaliMindColors.cardBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: CaliMindColors.warning.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(LucideIcons.alertTriangle, color: CaliMindColors.warning, size: 18),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Needs Attention', style: CaliMindTypography.h3),
                  Text(
                    '${unscheduled.length} task${unscheduled.length > 1 ? 's' : ''} could not be scheduled',
                    style: CaliMindTypography.label,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...unscheduled.asMap().entries.map((e) {
            final task = e.value;
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: CaliMindColors.background,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: CaliMindColors.warning.withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(task.title, style: CaliMindTypography.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(LucideIcons.info, size: 12, color: CaliMindColors.warning),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(task.reason, style: CaliMindTypography.bodySmall.copyWith(color: CaliMindColors.warning)),
                      ),
                    ],
                  ),
                ],
              ),
            ).animate(delay: Duration(milliseconds: e.key * 80)).fadeIn().slideY(begin: 0.1);
          }),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: CaliMindColors.cardBorder),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text('Dismiss', style: CaliMindTypography.bodyMedium),
            ),
          ),
        ],
      ),
    );
  }
}
