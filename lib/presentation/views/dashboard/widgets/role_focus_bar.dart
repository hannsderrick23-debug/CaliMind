import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:calimind/core/constants/app_colors.dart';
import 'package:calimind/core/constants/app_typography.dart';
import 'package:calimind/core/utils/haptic_feedback_utils.dart';
import 'package:calimind/domain/models/task.dart';
import 'package:calimind/presentation/state/role_focus_provider.dart';
import 'package:calimind/presentation/state/task_provider.dart';

class RoleFocusBar extends ConsumerWidget {
  const RoleFocusBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final focus = ref.watch(roleFocusProvider);
    final tasksAsync = ref.watch(taskProvider);
    final tasks = tasksAsync.valueOrNull ?? [];

    int countForCategory(TaskCategory? cat) {
      if (cat == null) return tasks.where((t) => !t.completed).length;
      return tasks.where((t) => t.category == cat && !t.completed).length;
    }

    final items = <(String, TaskCategory?, IconData, Color)>[
      ('All', null, LucideIcons.layoutGrid, CaliMindColors.primary),
      ...TaskCategory.values.map(
        (category) => (
          category.label,
          category,
          category.icon,
          category.color,
        ),
      ),
    ];

    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final (label, cat, icon, color) = items[index];
          final isSelected = focus == cat;
          final count = countForCategory(cat);

          return GestureDetector(
            onTap: () async {
              await HapticFeedbackUtils.selectionClick();
              ref.read(roleFocusProvider.notifier).state = cat;
            },
            child: AnimatedContainer(
              duration: 200.ms,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? color.withValues(alpha: 0.15) : CaliMindColors.card,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: isSelected ? color : CaliMindColors.cardBorder,
                  width: isSelected ? 1.5 : 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 13, color: isSelected ? color : CaliMindColors.mutedForeground),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: CaliMindTypography.bodySmall.copyWith(
                      color: isSelected ? color : CaliMindColors.mutedForeground,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: isSelected ? color.withValues(alpha: 0.2) : CaliMindColors.background,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$count',
                      style: CaliMindTypography.bodySmall.copyWith(
                        fontSize: 10,
                        color: isSelected ? color : CaliMindColors.mutedForeground,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
