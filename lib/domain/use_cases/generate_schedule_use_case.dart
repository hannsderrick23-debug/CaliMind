import 'dart:math';
import '../models/schedule_slot.dart';
import '../models/task.dart';

class GenerateScheduleUseCase {
  static const int dayStart = 480;       // 08:00 AM (in minutes from midnight)
  static const int dayEnd = 1320;        // 10:00 PM (in minutes from midnight)
  static const int bufferMinutes = 15;   // 15-minute rest buffer between slots
  static const int studyBlockCap = 120;  // Max 120 minutes per continuous study slot

  static String _formatTime(int minutes) {
    final h = (minutes ~/ 60).toString().padLeft(2, '0');
    final m = (minutes % 60).toString().padLeft(2, '0');
    return '$h:$m';
  }

  static int _toMinutes(String hhMm) {
    final parts = hhMm.split(':').map(int.parse).toList();
    return parts[0] * 60 + parts[1];
  }

  static String _datePart(DateTime dt) => dt.toIso8601String().substring(0, 10);

  static BigInt _priorityRank(Task task) {
    final priorityWeight = BigInt.from(task.priority) * BigInt.from(10).pow(15);
    final deadlineWeight = task.deadline != null
        ? BigInt.from(task.deadline!.millisecondsSinceEpoch)
        : BigInt.from(9223372036854775807); // Max int64
    return priorityWeight + deadlineWeight;
  }

  ScheduleResult execute(List<Task> tasks, String targetDate) {
    final slots = <ScheduleSlot>[];
    final unscheduled = <UnscheduledTask>[];
    final freeIntervals = <List<int>>[
      [dayStart, dayEnd]
    ];

    void markUnscheduled(Task task, String reason) {
      if (!unscheduled.any((u) => u.taskId == task.id)) {
        unscheduled.add(UnscheduledTask(taskId: task.id, title: task.title, reason: reason));
      }
    }

    bool reserveInterval(int start, int duration) {
      final end = start + duration;
      final index = freeIntervals.indexWhere((inv) => start >= inv[0] && end <= inv[1]);
      if (index < 0) return false;

      final original = freeIntervals[index];
      freeIntervals.removeAt(index);

      if (start > original[0]) {
        freeIntervals.add([original[0], start]);
      }
      if (end + bufferMinutes < original[1]) {
        freeIntervals.add([end + bufferMinutes, original[1]]);
      }
      freeIntervals.sort((a, b) => a[0].compareTo(b[0]));
      return true;
    }

    void placeFloatingTask(Task task, List<int> allowedRange) {
      // Study Rule: Chunk tasks > 120 minutes into slices
      final List<int> chunks;
      if (task.category == TaskCategory.study && task.duration > studyBlockCap) {
        final count = (task.duration / studyBlockCap).ceil();
        chunks = List.generate(count, (i) => min(studyBlockCap, task.duration - i * studyBlockCap));
      } else {
        chunks = [task.duration];
      }

      final snapshotFree = freeIntervals.map((i) => [i[0], i[1]]).toList();
      final currentSlotCount = slots.length;

      for (var i = 0; i < chunks.length; i++) {
        final duration = chunks[i];
        // Find first free interval that accommodates duration within allowedRange
        final intervalIndex = freeIntervals.indexWhere((inv) {
          final effectiveStart = max(inv[0], allowedRange[0]);
          final effectiveEnd = min(inv[1], allowedRange[1]);
          return effectiveEnd - effectiveStart >= duration;
        });

        if (intervalIndex < 0) {
          // Rollback any placed slices for this task
          freeIntervals.clear();
          freeIntervals.addAll(snapshotFree);
          slots.removeRange(currentSlotCount, slots.length);
          markUnscheduled(task, 'It does not fit in the available time window.');
          return;
        }

        final interval = freeIntervals[intervalIndex];
        final start = max(interval[0], allowedRange[0]);
        reserveInterval(start, duration);

        final chunkSuffix = chunks.length > 1 ? ' (Part ${i + 1}/${chunks.length})' : '';
        slots.add(ScheduleSlot(
          taskId: task.id,
          taskTitle: '${task.title}$chunkSuffix',
          category: task.category,
          startTime: _formatTime(start),
          endTime: _formatTime(start + duration),
          duration: duration,
        ));
      }
    }

    // Filter to active incomplete tasks
    final eligible = tasks.where((t) => !t.completed).toList();

    // Check for already passed deadlines
    for (final task in eligible) {
      if (task.deadline != null && _datePart(task.deadline!).compareTo(targetDate) < 0) {
        markUnscheduled(task, 'Its deadline has already passed.');
      }
    }

    final candidates = eligible.where((t) => !unscheduled.any((u) => u.taskId == t.id)).toList();

    // PHASE 1: Place Fixed / Exact Time Tasks First
    final exactTasks = candidates.where((t) => t.specificTime != null).toList()
      ..sort((a, b) => a.specificTime!.compareTo(b.specificTime!));

    for (final task in exactTasks) {
      final start = _toMinutes(task.specificTime!);
      if (start < dayStart || start + task.duration > dayEnd) {
        markUnscheduled(task, 'Its exact time falls outside your planning hours (08:00–22:00).');
      } else if (!reserveInterval(start, task.duration)) {
        markUnscheduled(task, 'Its exact time conflicts with another planned task.');
      } else {
        slots.add(ScheduleSlot(
          taskId: task.id,
          taskTitle: task.title,
          category: task.category,
          startTime: _formatTime(start),
          endTime: _formatTime(start + task.duration),
          duration: task.duration,
        ));
      }
    }

    // PHASE 2: Place Floating Tasks Sorted by Priority Rank
    final floatingTasks = candidates.where((t) => t.specificTime == null).toList()
      ..sort((a, b) => _priorityRank(a).compareTo(_priorityRank(b)));

    for (final task in floatingTasks) {
      List<int> range = task.preferredTime != null
          ? [task.preferredTime!.startMinute, task.preferredTime!.endMinute]
          : [dayStart, dayEnd];

      // If due today, constrain range end to deadline time
      if (task.deadline != null && _datePart(task.deadline!) == targetDate) {
        final dueMinute = task.deadline!.hour * 60 + task.deadline!.minute;
        range = [range[0], min(range[1], dueMinute)];
      }

      placeFloatingTask(task, range);
    }

    // Final chronological sort
    slots.sort((a, b) => a.startTime.compareTo(b.startTime));

    return ScheduleResult(slots: slots, unscheduled: unscheduled);
  }

  static String toSpokenSummary(List<ScheduleSlot> slots) {
    if (slots.isEmpty) return 'No tasks could be scheduled for this date.';
    final sequence = slots.map((s) => '${s.taskTitle} at ${s.startTime}').join(', then ');
    return 'Your schedule is ready. $sequence.';
  }
}
