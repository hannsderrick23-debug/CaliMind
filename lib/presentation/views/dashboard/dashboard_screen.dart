import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:intl/intl.dart';
import 'package:calimind/core/constants/app_colors.dart';
import 'package:calimind/core/constants/app_typography.dart';
import 'package:calimind/core/utils/haptic_feedback_utils.dart';
import 'package:calimind/domain/models/parsed_command.dart';
import 'package:calimind/presentation/state/role_focus_provider.dart';
import 'package:calimind/presentation/state/schedule_provider.dart';
import 'package:calimind/presentation/state/voice_assistant_provider.dart';
import 'package:calimind/presentation/state/task_provider.dart';
import '../schedule/schedule_tab.dart';
import '../tasks/task_input_sheet.dart';
import '../tasks/task_list_tab.dart';
import 'widgets/role_focus_bar.dart';
import 'widgets/voice_assistant_fab.dart';
import '../tasks/widgets/voice_confirm_sheet.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  bool _showVoiceSheet = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _handleFabTap() async {
    final voice = ref.read(voiceAssistantProvider);
    final activeRole = ref.read(roleFocusProvider)?.label;
    if (voice.voiceState == VoiceState.listening) {
      await ref.read(voiceAssistantProvider.notifier).stopListening(currentFocusRole: activeRole);
    } else {
      await ref.read(voiceAssistantProvider.notifier).startListening(currentFocusRole: activeRole);
    }
  }

  Future<void> _pickDate() async {
    final schedule = ref.read(scheduleProvider);
    final picked = await showDatePicker(
      context: context,
      initialDate: schedule.activeDate,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 90)),
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
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
    // Listen for voice parse completion
    ref.listen(voiceAssistantProvider, (prev, next) {
      if (next.draftTask != null && !_showVoiceSheet) {
        setState(() => _showVoiceSheet = true);
      } else if (next.parsedCommand is GenerateScheduleCommand) {
        final tasks = ref.read(taskProvider).valueOrNull ?? [];
        ref.read(scheduleProvider.notifier).generateSchedule(tasks);
        ref.read(voiceAssistantProvider.notifier).dismiss();
        _tabController.animateTo(1);
      }
    });

    final schedule = ref.watch(scheduleProvider);
    final dateLabel = DateFormat('EEE, MMM d').format(schedule.activeDate);

    return Scaffold(
      backgroundColor: CaliMindColors.background,
      appBar: _buildAppBar(dateLabel),
      body: Stack(
        children: [
          Column(
            children: [
              // Tab Bar
              _buildTabBar(),
              // Role Focus Bar
              const SizedBox(height: 10),
              const RoleFocusBar(),
              const SizedBox(height: 4),
              // Tab views
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: const [
                    TaskListTab(),
                    ScheduleTab(),
                  ],
                ),
              ),
            ],
          ),
          // Voice Confirm Sheet overlay
          if (_showVoiceSheet)
            Positioned.fill(
              child: GestureDetector(
                onTap: () {},
                child: Container(
                  color: Colors.black54,
                  alignment: Alignment.bottomCenter,
                  child: VoiceConfirmSheet(
                    onConfirmed: () {
                      setState(() => _showVoiceSheet = false);
                      ref.read(voiceAssistantProvider.notifier).dismiss();
                    },
                    onDismissed: () {
                      setState(() => _showVoiceSheet = false);
                      ref.read(voiceAssistantProvider.notifier).dismiss();
                    },
                  ),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  PreferredSizeWidget _buildAppBar(String dateLabel) {
    return AppBar(
      backgroundColor: CaliMindColors.background,
      elevation: 0,
      titleSpacing: 20,
      title: Row(
        children: [
          // Logo
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: CaliMindColors.mindGradient,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(LucideIcons.brain, color: Colors.white, size: 18),
          ),
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
                const Icon(LucideIcons.calendar, size: 12, color: CaliMindColors.mutedForeground),
                const SizedBox(width: 5),
                Text(dateLabel, style: CaliMindTypography.bodySmall.copyWith(fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
        // + button
        IconButton(
          icon: const Icon(LucideIcons.plus, color: CaliMindColors.primary, size: 22),
          tooltip: 'Add Task',
          onPressed: () => showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) => const TaskInputSheet(),
          ),
        ),
        // Settings
        IconButton(
          icon: const Icon(LucideIcons.settings, color: CaliMindColors.mutedForeground, size: 20),
          onPressed: () => context.push('/settings'),
        ),
      ],
    );
  }

  Widget _buildTabBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        height: 38,
        decoration: BoxDecoration(
          color: CaliMindColors.card,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: CaliMindColors.cardBorder),
        ),
        child: TabBar(
          controller: _tabController,
          indicator: BoxDecoration(
            gradient: CaliMindColors.mindGradient,
            borderRadius: BorderRadius.circular(8),
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          labelStyle: CaliMindTypography.bodySmall.copyWith(fontWeight: FontWeight.w600),
          unselectedLabelStyle: CaliMindTypography.bodySmall,
          labelColor: Colors.white,
          unselectedLabelColor: CaliMindColors.mutedForeground,
          dividerColor: Colors.transparent,
          tabs: const [
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(LucideIcons.listTodo, size: 13),
                  SizedBox(width: 5),
                  Text('Tasks'),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(LucideIcons.calendarDays, size: 13),
                  SizedBox(width: 5),
                  Text('Schedule'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      height: 90,
      decoration: const BoxDecoration(
        color: CaliMindColors.background,
        border: Border(top: BorderSide(color: CaliMindColors.cardBorder)),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          // Voice interim transcript
          Consumer(builder: (context, ref, _) {
            final voice = ref.watch(voiceAssistantProvider);
            if (voice.voiceState == VoiceState.listening && voice.interimTranscript.isNotEmpty) {
              return Positioned(
                top: 8,
                left: 24,
                right: 24,
                child: Text(
                  voice.interimTranscript,
                  style: CaliMindTypography.bodySmall.copyWith(color: CaliMindColors.primary),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }
            return const SizedBox.shrink();
          }),
          // Centered FAB (tap = voice, long-press = manual input)
          Consumer(builder: (context, ref, _) {
            return GestureDetector(
              onLongPress: () {
                HapticFeedbackUtils.mediumImpact();
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => const TaskInputSheet(),
                );
              },
              child: VoiceAssistantFab(onTap: _handleFabTap),
            );
          }),
        ],
      ),
    );
  }
}
