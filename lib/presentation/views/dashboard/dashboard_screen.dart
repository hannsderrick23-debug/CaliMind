import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:intl/intl.dart';
import 'package:calimind/core/constants/app_colors.dart';
import 'package:calimind/core/constants/app_typography.dart';
import 'package:calimind/core/utils/app_feedback.dart';
import 'package:calimind/core/services/widget_service.dart';
import 'package:calimind/domain/models/parsed_command.dart';
import 'package:calimind/presentation/state/role_focus_provider.dart';
import 'package:calimind/presentation/state/schedule_provider.dart';
import 'package:calimind/presentation/state/voice_assistant_provider.dart';
import 'package:calimind/presentation/state/task_provider.dart';
import 'package:calimind/presentation/widgets/calimind_mark.dart';
import '../schedule/schedule_tab.dart';
import '../tasks/task_list_tab.dart';
import 'widgets/role_focus_bar.dart';
import 'widgets/voice_assistant_fab.dart';
import '../tasks/widgets/voice_confirm_sheet.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  final bool voiceShortcutRequested;
  final int initialTabIndex;

  const DashboardScreen({
    super.key,
    this.voiceShortcutRequested = false,
    this.initialTabIndex = 0,
  });

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _scheduleTabKey = GlobalKey<ScheduleTabState>();
  bool _voiceReviewOpen = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      initialIndex: widget.initialTabIndex,
      vsync: this,
    );
    _tabController.addListener(() => setState(() {}));
    if (widget.voiceShortcutRequested) _showVoiceShortcutPrompt();
  }

  @override
  void didUpdateWidget(DashboardScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialTabIndex != oldWidget.initialTabIndex &&
        _tabController.index != widget.initialTabIndex) {
      _tabController.animateTo(widget.initialTabIndex);
    }
    if (widget.voiceShortcutRequested &&
        !oldWidget.voiceShortcutRequested) {
      _showVoiceShortcutPrompt();
    }
  }

  void _showVoiceShortcutPrompt() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      AppFeedback.info(
        ScaffoldMessenger.of(context),
        'Tap the microphone when you are ready to start voice capture.',
      );
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _handleFabTap() async {
    final voice = ref.read(voiceAssistantProvider);
    final activeRole = ref.read(roleFocusProvider)?.label;
    if (voice.voiceState == VoiceState.processing) {
      AppFeedback.info(
        ScaffoldMessenger.of(context),
        'I’m preparing the task I heard. Please wait a moment.',
      );
      return;
    }
    if (voice.voiceState == VoiceState.listening) {
      await ref
          .read(voiceAssistantProvider.notifier)
          .stopListening(currentFocusRole: activeRole);
    } else {
      await ref
          .read(voiceAssistantProvider.notifier)
          .startListening(currentFocusRole: activeRole);
    }
  }

  void _presentVoiceReview() {
    if (_voiceReviewOpen) return;
    _voiceReviewOpen = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || ref.read(voiceAssistantProvider).draftTask == null) {
        _voiceReviewOpen = false;
        return;
      }
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        builder: (sheetContext) => VoiceConfirmSheet(
          onConfirmed: () {
            Navigator.of(sheetContext).pop();
            ref.read(voiceAssistantProvider.notifier).dismiss();
          },
          onDismissed: () {
            Navigator.of(sheetContext).pop();
            ref.read(voiceAssistantProvider.notifier).dismiss();
          },
        ),
      ).whenComplete(() {
        _voiceReviewOpen = false;
        if (mounted && ref.read(voiceAssistantProvider).draftTask != null) {
          ref.read(voiceAssistantProvider.notifier).dismiss();
        }
      });
    });
  }

  Future<void> _pickDate() async {
    final schedule = ref.read(scheduleProvider);
    final picked = await showDatePicker(
      context: context,
      initialDate: schedule.activeDate,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 90)),
      builder: (ctx, child) => Theme(
        data: ThemeData.light().copyWith(
          colorScheme: const ColorScheme.light(
            primary: CaliMindColors.primary,
            onSurface: CaliMindColors.foreground,
            surface: CaliMindColors.card,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      ref.read(scheduleProvider.notifier).changeDate(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(taskProvider, (previous, next) {
      final tasks = next.valueOrNull;
      if (tasks == null) return;
      final scheduledTaskIds =
          ref.read(scheduleProvider).slots.map((slot) => slot.taskId);
      unawaited(
        WidgetService.refresh(
          tasks,
          scheduledTaskIds: scheduledTaskIds,
        ),
      );
    });
    ref.listen(scheduleProvider, (previous, next) {
      if (identical(previous?.slots, next.slots)) return;
      final tasks = ref.read(taskProvider).valueOrNull;
      if (tasks == null) return;
      unawaited(
        WidgetService.refresh(
          tasks,
          scheduledTaskIds: next.slots.map((slot) => slot.taskId),
        ),
      );
    });

    // Listen for voice parse completion
    ref.listen(voiceAssistantProvider, (previous, next) {
      if (next.draftTask != null && !_voiceReviewOpen) {
        _presentVoiceReview();
      } else if (next.parsedCommand is GenerateScheduleCommand &&
          previous?.parsedCommand is! GenerateScheduleCommand) {
        _generateScheduleFromVoice();
        ref.read(voiceAssistantProvider.notifier).dismiss();
        _tabController.animateTo(1);
        AppFeedback.success(
          ScaffoldMessenger.of(context),
          'Reviewing your proposed schedule before saving it.',
        );
      } else if (next.errorMessage != null &&
          next.errorMessage != previous?.errorMessage) {
        AppFeedback.error(
          ScaffoldMessenger.of(context),
          next.errorMessage!,
        );
      }
    });

    final schedule = ref.watch(scheduleProvider);
    final voice = ref.watch(voiceAssistantProvider);
    final dateLabel = DateFormat('EEE, MMM d').format(schedule.activeDate);

    return Scaffold(
      backgroundColor: CaliMindColors.background,
      appBar: _buildAppBar(dateLabel),
      body: Column(
        children: [
          const SizedBox(height: 10),
          const RoleFocusBar(),
          if (voice.voiceState == VoiceState.listening ||
              voice.voiceState == VoiceState.processing)
            _buildVoiceStatus(voice),
          const SizedBox(height: 4),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                const TaskListTab(),
                ScheduleTab(key: _scheduleTabKey),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  void _generateScheduleFromVoice() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final scheduleTab = _scheduleTabKey.currentState;
      if (scheduleTab != null) {
        unawaited(scheduleTab.generateFromVoice());
      }
    });
  }

  PreferredSizeWidget _buildAppBar(String dateLabel) {
    return AppBar(
      backgroundColor: CaliMindColors.background,
      elevation: 0,
      titleSpacing: 20,
      title: Row(
        children: [
          // Logo
          const CaliMindMark(size: 36),
          const SizedBox(width: 10),
          Text('CaliMind', style: CaliMindTypography.h2.copyWith(fontSize: 20)),
        ],
      ),
      actions: [
        // Date pill
        GestureDetector(
          onTap: _pickDate,
          child: Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: CaliMindColors.card,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: CaliMindColors.cardBorder),
            ),
            child: Row(
              children: [
                const Icon(LucideIcons.calendar,
                    size: 12, color: CaliMindColors.mutedForeground),
                const SizedBox(width: 5),
                Text(dateLabel,
                    style: CaliMindTypography.bodySmall
                        .copyWith(fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
        // Settings
        IconButton(
          icon: const Icon(LucideIcons.settings,
              color: CaliMindColors.mutedForeground, size: 20),
          onPressed: () => context.push('/settings'),
        ),
      ],
    );
  }

  Widget _buildBottomBar() {
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(16, 8, 16, 14),
      child: SizedBox(
        height: 76,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                height: 64,
                decoration: BoxDecoration(
                  color: CaliMindColors.card,
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(color: CaliMindColors.cardBorder),
                  boxShadow: [
                    BoxShadow(
                      color: CaliMindColors.foreground.withValues(alpha: 0.08),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildNavigationItem(
                        label: 'Tasks',
                        icon: LucideIcons.listTodo,
                        selected: _tabController.index == 0,
                        onTap: () => _tabController.animateTo(0),
                      ),
                    ),
                    const Expanded(child: SizedBox.shrink()),
                    Expanded(
                      child: _buildNavigationItem(
                        label: 'Schedule',
                        icon: LucideIcons.calendarDays,
                        selected: _tabController.index == 1,
                        onTap: () => _tabController.animateTo(1),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    VoiceAssistantFab(onTap: _handleFabTap),
                    Text(
                      _voiceButtonLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: CaliMindTypography.bodySmall.copyWith(
                        fontSize: 9,
                        color: ref.watch(voiceAssistantProvider).voiceState ==
                                VoiceState.listening
                            ? CaliMindColors.destructive
                            : CaliMindColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String get _voiceButtonLabel {
    final voice = ref.read(voiceAssistantProvider);
    return switch (voice.voiceState) {
      VoiceState.listening => 'Listening · tap to finish',
      VoiceState.processing => 'Processing…',
      VoiceState.error => 'Try voice again',
      VoiceState.idle => 'Voice',
    };
  }

  Widget _buildVoiceStatus(VoiceAssistantState voice) {
    final isListening = voice.voiceState == VoiceState.listening;
    final transcript = voice.interimTranscript.isNotEmpty
        ? voice.interimTranscript
        : voice.finalTranscript;
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 8, 20, 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: isListening
            ? CaliMindColors.destructive.withValues(alpha: 0.08)
            : CaliMindColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isListening
              ? CaliMindColors.destructive.withValues(alpha: 0.3)
              : CaliMindColors.primary.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isListening ? LucideIcons.mic : LucideIcons.sparkles,
            size: 17,
            color: isListening
                ? CaliMindColors.destructive
                : CaliMindColors.primary,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              isListening
                  ? (transcript.isEmpty
                      ? 'Listening… Tap the red mic when you are done.'
                      : 'Listening: “$transcript”')
                  : 'Sending your recording for transcription and task details…',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: CaliMindTypography.bodySmall.copyWith(
                color: CaliMindColors.foreground,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationItem({
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final color =
        selected ? CaliMindColors.primary : CaliMindColors.mutedForeground;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 5),
        child: Material(
          color: selected ? CaliMindColors.surfaceOverlay : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: SizedBox.expand(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 21, color: color),
                  const SizedBox(height: 3),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: CaliMindTypography.bodySmall.copyWith(
                      fontSize: 10,
                      color: color,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
