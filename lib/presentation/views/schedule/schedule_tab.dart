import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:calimind/core/constants/app_colors.dart';
import 'package:calimind/core/constants/app_typography.dart';
import 'package:calimind/domain/models/schedule_slot.dart';
import 'package:calimind/presentation/state/schedule_provider.dart';
import 'package:calimind/presentation/state/task_provider.dart';
import 'widgets/timeline_view.dart';
import 'widgets/grid_view.dart';
import 'widgets/feed_view.dart';
import 'widgets/needs_attention_sheet.dart';

enum ScheduleViewMode { timeline, grid, feed }

class ScheduleTab extends ConsumerStatefulWidget {
  const ScheduleTab({super.key});

  @override
  ConsumerState<ScheduleTab> createState() => _ScheduleTabState();
}

class _ScheduleTabState extends ConsumerState<ScheduleTab> {
  ScheduleViewMode _mode = ScheduleViewMode.timeline;

  Future<void> _generate() async {
    final tasks = ref.read(taskProvider).valueOrNull ?? [];
    final result = await ref.read(scheduleProvider.notifier).generateSchedule(tasks);
    await ref.read(voiceScheduleSummaryProvider.notifier).announce(result);
    if (mounted && result.hasUnscheduled) {
      _showNeedsAttention(result.unscheduled);
    }
  }

  void _showNeedsAttention(List<UnscheduledTask> items) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => NeedsAttentionSheet(unscheduled: items),
    );
  }

  @override
  Widget build(BuildContext context) {
    final schedule = ref.watch(scheduleProvider);

    return Column(
      children: [
        // View Mode Switcher
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: Row(
            children: [
              Expanded(child: _buildViewSwitcher()),
              const SizedBox(width: 12),
              _buildGenerateButton(schedule),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Unscheduled warning banner
        if (schedule.unscheduled.isNotEmpty)
          _buildUnscheduledBanner(schedule.unscheduled),
        // Schedule view
        Expanded(
          child: schedule.isGenerating
              ? const Center(child: CircularProgressIndicator(color: CaliMindColors.primary))
              : _buildCurrentView(schedule),
        ),
      ],
    );
  }

  Widget _buildViewSwitcher() {
    final modes = [
      (ScheduleViewMode.timeline, LucideIcons.alignLeft, 'Timeline'),
      (ScheduleViewMode.grid, LucideIcons.layoutGrid, 'Grid'),
      (ScheduleViewMode.feed, LucideIcons.messageSquare, 'Feed'),
    ];

    return Container(
      height: 36,
      decoration: BoxDecoration(
        color: CaliMindColors.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: CaliMindColors.cardBorder),
      ),
      child: Row(
        children: modes.map((m) {
          final (mode, icon, label) = m;
          final isSelected = _mode == mode;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _mode = mode),
              child: AnimatedContainer(
                duration: 200.ms,
                margin: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  gradient: isSelected ? CaliMindColors.mindGradient : null,
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, size: 12, color: isSelected ? Colors.white : CaliMindColors.mutedForeground),
                    const SizedBox(width: 4),
                    Text(
                      label,
                      style: CaliMindTypography.bodySmall.copyWith(
                        fontSize: 11,
                        color: isSelected ? Colors.white : CaliMindColors.mutedForeground,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
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

  Widget _buildGenerateButton(ScheduleState schedule) {
    return GestureDetector(
      onTap: schedule.isGenerating ? null : _generate,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          gradient: CaliMindColors.mindGradient,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(LucideIcons.zap, size: 13, color: Colors.white),
            const SizedBox(width: 5),
            Text('Generate', style: CaliMindTypography.bodySmall.copyWith(color: Colors.white, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _buildUnscheduledBanner(List<UnscheduledTask> unscheduled) {
    return GestureDetector(
      onTap: () => _showNeedsAttention(unscheduled),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: CaliMindColors.warning.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: CaliMindColors.warning.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            const Icon(LucideIcons.alertTriangle, size: 14, color: CaliMindColors.warning),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${unscheduled.length} task${unscheduled.length > 1 ? 's' : ''} couldn\'t be scheduled. Tap to see why.',
                style: CaliMindTypography.bodySmall.copyWith(color: CaliMindColors.warning),
              ),
            ),
            const Icon(LucideIcons.chevronRight, size: 14, color: CaliMindColors.warning),
          ],
        ),
      ).animate().shake(delay: 100.ms),
    );
  }

  Widget _buildCurrentView(ScheduleState schedule) {
    if (schedule.slots.isEmpty && !schedule.isLoaded) {
      return _buildEmptySchedule();
    }
    return switch (_mode) {
      ScheduleViewMode.timeline => TimelineView(slots: schedule.slots),
      ScheduleViewMode.grid => ScheduleGridView(slots: schedule.slots),
      ScheduleViewMode.feed => FeedView(slots: schedule.slots),
    };
  }

  Widget _buildEmptySchedule() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              gradient: CaliMindColors.cardGlowGradient,
              shape: BoxShape.circle,
              border: Border.all(color: CaliMindColors.cardBorder),
            ),
            child: const Icon(LucideIcons.calendar, color: CaliMindColors.primary, size: 30),
          ),
          const SizedBox(height: 16),
          Text('No schedule yet', style: CaliMindTypography.h3),
          const SizedBox(height: 8),
          Text(
            'Tap Generate to compute your\ndeterministic daily schedule',
            style: CaliMindTypography.label,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: _generate,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                gradient: CaliMindColors.mindGradient,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(LucideIcons.zap, size: 16, color: Colors.white),
                  const SizedBox(width: 8),
                  Text('Generate Schedule', style: CaliMindTypography.bodyMedium.copyWith(color: Colors.white, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
        ],
      ).animate().fadeIn(duration: 500.ms),
    );
  }
}

// Provider to handle TTS announcement after schedule generation
final voiceScheduleSummaryProvider = StateNotifierProvider<_VoiceSummaryNotifier, void>(
  (ref) => _VoiceSummaryNotifier(),
);

class _VoiceSummaryNotifier extends StateNotifier<void> {
  _VoiceSummaryNotifier() : super(null);

  Future<void> announce(scheduleResult) async {
    // TTS via the voice assistant service
  }
}
