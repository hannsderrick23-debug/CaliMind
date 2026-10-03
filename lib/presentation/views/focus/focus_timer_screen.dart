import 'package:flutter/material.dart';

import '../../../domain/services/focus_session_controller.dart';

/// A standalone focus timer screen. The parent can supply and own the
/// controller; task completion remains the responsibility of its integration.
class FocusTimerScreen extends StatefulWidget {
  const FocusTimerScreen({
    required this.controller,
    this.taskId,
    this.taskTitle = 'Focus session',
    this.focusTarget = const Duration(minutes: 25),
    this.breaksEnabled = true,
    this.breakTarget = const Duration(minutes: 5),
    super.key,
  });

  final FocusSessionController controller;
  final String? taskId;
  final String taskTitle;
  final Duration focusTarget;
  final bool breaksEnabled;
  final Duration breakTarget;

  @override
  State<FocusTimerScreen> createState() => _FocusTimerScreenState();
}

class _FocusTimerScreenState extends State<FocusTimerScreen> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
    widget.controller.restore();
  }

  @override
  void didUpdateWidget(FocusTimerScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onChanged);
      widget.controller.addListener(_onChanged);
      widget.controller.restore();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _start() => widget.controller.start(
        taskId: widget.taskId,
        taskTitle: widget.taskTitle,
        focusTarget: widget.focusTarget,
        breaksEnabled: widget.breaksEnabled,
        breakTarget: widget.breakTarget,
      );

  @override
  Widget build(BuildContext context) {
    final snapshot = widget.controller.snapshot;
    final elapsed = snapshot.phase == FocusSessionPhase.onBreak
        ? snapshot.breakElapsed
        : snapshot.focusElapsed;
    final title = snapshot.taskTitle ?? widget.taskTitle;
    final phaseLabel = switch (snapshot.phase) {
      FocusSessionPhase.idle => 'Ready to focus',
      FocusSessionPhase.focusing => 'Focus',
      FocusSessionPhase.paused => 'Paused',
      FocusSessionPhase.onBreak => 'Break',
      FocusSessionPhase.completed => 'Session complete',
    };

    return Scaffold(
      appBar: AppBar(title: const Text('Focus timer')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              Text(phaseLabel, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Semantics(
                label: 'Elapsed time',
                child: Text(
                  _formatDuration(elapsed),
                  key: const ValueKey('focus-timer-elapsed'),
                  style: Theme.of(context)
                      .textTheme
                      .displayMedium,
                ),
              ),
              const SizedBox(height: 24),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 12,
                runSpacing: 12,
                children: _controls(snapshot.phase),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _controls(FocusSessionPhase phase) {
    switch (phase) {
      case FocusSessionPhase.idle:
        return [
          FilledButton(
            key: const ValueKey('focus-start'),
            onPressed: _start,
            child: const Text('Start'),
          ),
        ];
      case FocusSessionPhase.focusing:
        return [
          OutlinedButton(
            key: const ValueKey('focus-pause'),
            onPressed: widget.controller.pause,
            child: const Text('Pause'),
          ),
          if (widget.controller.snapshot.breaksEnabled)
            OutlinedButton(
              key: const ValueKey('focus-start-break'),
              onPressed: widget.controller.startBreak,
              child: const Text('Take break'),
            ),
          FilledButton(
            key: const ValueKey('focus-finish'),
            onPressed: widget.controller.finish,
            child: const Text('Finish session'),
          ),
        ];
      case FocusSessionPhase.paused:
        return [
          FilledButton(
            key: const ValueKey('focus-resume'),
            onPressed: widget.controller.resume,
            child: const Text('Resume'),
          ),
          OutlinedButton(
            key: const ValueKey('focus-finish'),
            onPressed: widget.controller.finish,
            child: const Text('Finish session'),
          ),
        ];
      case FocusSessionPhase.onBreak:
        return [
          FilledButton(
            key: const ValueKey('focus-end-break'),
            onPressed: widget.controller.endBreak,
            child: const Text('End break'),
          ),
          OutlinedButton(
            key: const ValueKey('focus-finish'),
            onPressed: widget.controller.finish,
            child: const Text('Finish session'),
          ),
        ];
      case FocusSessionPhase.completed:
        return [
          FilledButton(
            key: const ValueKey('focus-reset'),
            onPressed: widget.controller.reset,
            child: const Text('New session'),
          ),
        ];
    }
  }

  static String _formatDuration(Duration duration) {
    final seconds = duration.inSeconds;
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final remainingSeconds = seconds % 60;
    String twoDigits(int value) => value.toString().padLeft(2, '0');
    return hours > 0
        ? '${twoDigits(hours)}:${twoDigits(minutes)}:${twoDigits(remainingSeconds)}'
        : '${twoDigits(minutes)}:${twoDigits(remainingSeconds)}';
  }
}
