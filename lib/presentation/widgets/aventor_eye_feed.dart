import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_typography.dart';
import '../../core/services/aventor_eye_service.dart';
import '../../core/services/device_calendar_service.dart';
import '../../domain/models/calendar_busy_interval.dart';
import '../../domain/models/schedule_slot.dart';
import '../../domain/models/task.dart';
import '../state/device_calendar_provider.dart';

class AventorEyeFeed extends ConsumerStatefulWidget {
  const AventorEyeFeed({
    required this.tasks,
    required this.slots,
    required this.date,
    super.key,
  });

  final List<Task> tasks;
  final List<ScheduleSlot> slots;
  final DateTime date;

  @override
  ConsumerState<AventorEyeFeed> createState() => _AventorEyeFeedState();
}

class _AventorEyeFeedState extends ConsumerState<AventorEyeFeed> {
  static const _refreshInterval = AventorEyeService.refreshInterval;

  bool? _enabled;
  bool _loading = false;
  bool _loadingPreference = true;
  String? _error;
  String? _cacheNotice;
  List<AventorEyeInsight> _cards = const [];
  String? _requestedKey;
  DateTime? _snapshotTime;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    AventorEyeService.enabled.addListener(_onPreferenceChanged);
    unawaited(_loadPreference());
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    AventorEyeService.enabled.removeListener(_onPreferenceChanged);
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant AventorEyeFeed oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tasks != widget.tasks ||
        oldWidget.slots != widget.slots ||
        oldWidget.date != widget.date) {
      _requestedKey = null;
      _snapshotTime = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _requestIfNeeded();
      });
    }
  }

  Future<void> _loadPreference() async {
    try {
      final enabled = await AventorEyeService.instance.isEnabled();
      if (!mounted) return;
      setState(() {
        _enabled = enabled;
        _loadingPreference = false;
      });
      _requestIfNeeded();
    } catch (error) {
      debugPrint('Could not load Aventor Eye preference: $error');
      if (mounted) {
        setState(() {
          _loadingPreference = false;
          _error = 'Could not load Aventor Eye settings.';
        });
      }
    }
  }

  void _onPreferenceChanged() {
    final enabled = AventorEyeService.enabled.value;
    if (!mounted || enabled == null || enabled == _enabled) return;
    setState(() {
      _enabled = enabled;
      _requestedKey = null;
      _snapshotTime = null;
      _error = null;
      _cacheNotice = null;
      if (!enabled) {
        _cards = const [];
        _refreshTimer?.cancel();
      }
    });
    if (enabled) _requestIfNeeded();
  }

  void _requestIfNeeded({bool forceRefresh = false}) {
    if (!mounted || _enabled != true || _loading) return;
    final now = _snapshotTime ?? DateTime.now();
    final key = AventorEyeService.instance.snapshotKey(
      tasks: widget.tasks,
      slots: widget.slots,
      date: widget.date,
      now: now,
    );
    if (!forceRefresh && key == _requestedKey) return;
    _requestedKey = key;
    _snapshotTime = now;
    unawaited(_loadInsights(now: now, forceRefresh: forceRefresh));
  }

  Future<void> _loadInsights({
    required DateTime now,
    bool forceRefresh = false,
  }) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      var busyIntervals = <CalendarBusyInterval>[];
      if (ref.read(deviceCalendarProvider).enabled) {
        final busyResult = await ref
            .read(deviceCalendarProvider.notifier)
            .getBusyIntervalsForDay(widget.date);
        if (busyResult.status != DeviceCalendarAccessStatus.granted) {
          throw StateError(
            'Calendar access is unavailable. Check calendar access in Settings.',
          );
        }
        busyIntervals = busyResult.intervals;
      }
      final result = await AventorEyeService.instance.getInsights(
        tasks: widget.tasks,
        slots: widget.slots,
        date: widget.date,
        now: now,
        busyIntervals: busyIntervals,
        forceRefresh: forceRefresh,
      );
      if (!mounted) return;
      setState(() {
        _cards = result.cards;
        _loading = false;
        _error = null;
        _cacheNotice = result.isStale
            ? result.refreshFailed
                ? 'Refresh failed. Showing saved insights for now.'
                : 'Showing saved insights until the next refresh.'
            : null;
      });
      _scheduleNextRefresh(_refreshInterval);
    } catch (error) {
      debugPrint('Aventor Eye could not load schedule insights: $error');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error =
            error is StateError && error.message.startsWith('Calendar access')
            ? error.message.toString()
            : 'Aventor Eye could not refresh your insights.';
        _cacheNotice = _cards.isEmpty
            ? null
            : 'Refresh failed. Showing saved insights for now.';
      });
      _scheduleNextRefresh(_refreshInterval);
    }
  }

  void _scheduleNextRefresh(Duration delay) {
    _refreshTimer?.cancel();
    if (_enabled != true) return;
    _refreshTimer = Timer(delay, () {
      if (!mounted || _enabled != true) return;
      _requestedKey = null;
      _snapshotTime = DateTime.now();
      _requestIfNeeded(forceRefresh: true);
    });
  }

  Future<void> _setEnabled(bool enabled) async {
    try {
      await AventorEyeService.instance.setEnabled(enabled);
    } catch (error) {
      debugPrint('Could not update Aventor Eye preference: $error');
      if (mounted) {
        setState(() => _error = 'Could not update Aventor Eye settings.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    _requestIfNeeded();
    if (_loadingPreference) return const SizedBox.shrink();
    if (_enabled != true) {
      return _optInCard();
    }
    if (_loading && _cards.isEmpty) return _loadingCard();
    if (_error != null && _cards.isEmpty) return _errorCard();
    if (_cards.isEmpty) return _emptyCard();
    return _insightCards();
  }

  Widget _optInCard() => _shell(
    key: const ValueKey('aventor-eye-opt-in'),
    child: Row(
      children: [
        _eyeIcon(),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Aventor Eye', style: CaliMindTypography.h3),
              const SizedBox(height: 4),
              Text(
                'Get a few gentle, schedule-aware suggestions. If enabled, task titles and timing are sent to Groq; calendar busy times are included only when calendar access is enabled.',
                style: CaliMindTypography.bodySmall.copyWith(
                  color: CaliMindColors.mutedForeground,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        FilledButton(
          onPressed: () => _setEnabled(true),
          child: const Text('Turn on'),
        ),
      ],
    ),
  );

  Widget _loadingCard() => _shell(
    key: const ValueKey('aventor-eye-loading'),
    child: Row(
      children: [
        _eyeIcon(),
        const SizedBox(width: 12),
        const Expanded(child: Text('Aventor Eye is checking today’s plan…')),
        const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: CaliMindColors.primary,
          ),
        ),
      ],
    ),
  );

  Widget _errorCard() => _shell(
    key: const ValueKey('aventor-eye-error'),
    child: Row(
      children: [
        _eyeIcon(),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            '$_error We’ll try again automatically.',
            style: CaliMindTypography.bodySmall.copyWith(
              color: CaliMindColors.mutedForeground,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _emptyCard() => _shell(
    key: const ValueKey('aventor-eye-empty'),
    child: Row(
      children: [
        _eyeIcon(),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            'No extra nudge right now. Your plan is ready when you are.',
            style: CaliMindTypography.bodySmall.copyWith(
              color: CaliMindColors.mutedForeground,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _insightCards() =>
      Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _eyeIcon(),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text('Aventor Eye', style: CaliMindTypography.h3),
                  ),
                ],
              ),
              if (_cacheNotice != null) ...[
                const SizedBox(height: 4),
                Text(
                  _cacheNotice!,
                  style: CaliMindTypography.bodySmall.copyWith(
                    color: CaliMindColors.mutedForeground,
                    fontSize: 11,
                  ),
                ),
              ],
              const SizedBox(height: 10),
              SizedBox(
                height: 150,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _cards.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (context, index) =>
                      _insightCard(_cards[index], index),
                ),
              ),
            ],
          )
          .animate(key: ValueKey(_cards.map((card) => card.title).join('|')))
          .fadeIn(duration: 320.ms)
          .slideY(begin: 0.06, curve: Curves.easeOutBack);

  Widget _insightCard(AventorEyeInsight insight, int index) {
    final (icon, color) = switch (insight.kind) {
      AventorEyeInsightKind.focus => (
        LucideIcons.target,
        CaliMindColors.primary,
      ),
      AventorEyeInsightKind.balance => (
        LucideIcons.scale,
        CaliMindColors.catClass,
      ),
      AventorEyeInsightKind.celebrate => (
        LucideIcons.sparkles,
        CaliMindColors.success,
      ),
      AventorEyeInsightKind.reset => (
        LucideIcons.coffee,
        CaliMindColors.warning,
      ),
    };
    return Container(
          width: 286,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.18),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: Colors.white, size: 20)
                  .animate(
                    onPlay: (controller) => controller.repeat(reverse: true),
                  )
                  .moveY(
                    begin: -1.5,
                    end: 1.5,
                    duration: (1400 + index * 130).ms,
                    curve: Curves.easeInOut,
                  ),
              const Spacer(),
              Text(
                insight.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: CaliMindTypography.bodyMedium.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                insight.message,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: CaliMindTypography.bodySmall.copyWith(
                  color: Colors.white.withValues(alpha: 0.92),
                  height: 1.4,
                ),
              ),
            ],
          ),
        )
        .animate(key: ValueKey('${insight.kind.name}-${insight.title}'))
        .fadeIn(delay: (index * 70).ms, duration: 300.ms)
        .scale(
          begin: const Offset(0.96, 0.96),
          curve: Curves.easeOutBack,
          duration: 420.ms,
        );
  }

  Widget _eyeIcon() => Container(
    width: 40,
    height: 40,
    decoration: BoxDecoration(
      color: CaliMindColors.primary.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(13),
    ),
    child: const Icon(LucideIcons.eye, size: 20, color: CaliMindColors.primary)
        .animate(onPlay: (controller) => controller.repeat(reverse: true))
        .scale(
          begin: const Offset(0.95, 0.95),
          end: const Offset(1.04, 1.04),
          duration: 1200.ms,
          curve: Curves.easeInOut,
        ),
  );

  Widget _shell({required Key key, required Widget child}) =>
      Container(
            key: key,
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: CaliMindColors.card,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: CaliMindColors.cardBorder),
              boxShadow: [
                BoxShadow(
                  color: CaliMindColors.primary.withValues(alpha: 0.04),
                  blurRadius: 16,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: child,
          )
          .animate(key: key)
          .fadeIn(duration: 280.ms)
          .slideY(begin: 0.05, curve: Curves.easeOutBack);
}
