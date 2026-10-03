import 'dart:convert';

import 'package:calimind/domain/services/focus_session_controller.dart';
import 'package:calimind/presentation/views/focus/focus_timer_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FocusSessionController', () {
    late _MemoryStorage storage;
    late DateTime now;
    late FocusSessionController controller;

    setUp(() {
      storage = _MemoryStorage();
      now = DateTime(2026, 10, 3, 9);
      controller = FocusSessionController(
        storage: storage,
        clock: () => now,
        tickInterval: const Duration(days: 1),
      );
    });

    tearDown(() => controller.dispose());

    test('restores elapsed focus time from its persisted timestamp', () async {
      await controller.start(
        taskId: 'task-1',
        taskTitle: 'Read',
        focusTarget: const Duration(minutes: 25),
      );
      now = now.add(const Duration(minutes: 7, seconds: 12));

      final restored = FocusSessionController(
        storage: storage,
        clock: () => now,
        tickInterval: const Duration(days: 1),
      );
      addTearDown(restored.dispose);
      await restored.restore();

      expect(restored.snapshot.phase, FocusSessionPhase.focusing);
      expect(restored.snapshot.focusElapsed,
          const Duration(minutes: 7, seconds: 12));
      expect(restored.snapshot.taskId, 'task-1');
    });

    test('pauses and resumes elapsed focus without counting paused time',
        () async {
      await controller.start();
      now = now.add(const Duration(minutes: 3));
      await controller.pause();
      now = now.add(const Duration(minutes: 30));
      await controller.resume();
      now = now.add(const Duration(minutes: 2));

      expect(controller.snapshot.focusElapsed, const Duration(minutes: 5));
    });

    test('tracks optional breaks and finishing does not complete a task',
        () async {
      await controller.start(
        taskId: 'task-1',
        breaksEnabled: true,
        breakTarget: const Duration(minutes: 5),
      );
      now = now.add(const Duration(minutes: 10));
      await controller.startBreak();
      now = now.add(const Duration(minutes: 4));
      await controller.endBreak();
      now = now.add(const Duration(minutes: 2));
      await controller.finish();

      expect(controller.snapshot.phase, FocusSessionPhase.completed);
      expect(controller.snapshot.focusElapsed, const Duration(minutes: 12));
      expect(controller.snapshot.breakElapsed, const Duration(minutes: 4));
      expect(jsonDecode(storage.value!)['taskCompleted'], isNull);
    });

    test('pausing and resuming during a break resumes the break', () async {
      await controller.start(breaksEnabled: true);
      await controller.startBreak();
      now = now.add(const Duration(minutes: 2));
      await controller.pause();
      now = now.add(const Duration(minutes: 10));
      await controller.resume();
      now = now.add(const Duration(minutes: 1));

      expect(controller.snapshot.phase, FocusSessionPhase.onBreak);
      expect(controller.snapshot.breakElapsed, const Duration(minutes: 3));
    });
  });

  testWidgets('timer screen starts a session without task-completion controls',
      (tester) async {
    final storage = _MemoryStorage();
    final controller = FocusSessionController(
      storage: storage,
      tickInterval: const Duration(days: 1),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: FocusTimerScreen(
          controller: controller,
          taskId: 'task-1',
          taskTitle: 'Read',
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('focus-start')));
    await tester.pumpAndSettle();

    expect(controller.snapshot.phase, FocusSessionPhase.focusing);
    expect(controller.snapshot.taskId, 'task-1');
    expect(find.byKey(const ValueKey('focus-pause')), findsOneWidget);
    expect(find.text('Complete task'), findsNothing);
    await controller.finish();
    await tester.pumpAndSettle();
  });
}

class _MemoryStorage implements FocusSessionStorage {
  String? value;

  @override
  Future<void> clear() async => value = null;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String value) async => this.value = value;
}
