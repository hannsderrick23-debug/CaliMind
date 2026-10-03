import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:calimind/core/services/task_reminder_service.dart';
import 'package:calimind/data/repositories/task_repository_impl.dart';
import 'package:calimind/domain/models/task.dart';

String taskOperationErrorMessage(Object error) {
  if (error is PostgrestException) {
    return [
      error.message,
      if (error.details != null) error.details.toString(),
      if (error.hint != null) error.hint!,
    ].where((part) => part.trim().isNotEmpty).join(' ');
  }
  if (error is AuthException) return error.message;
  if (error is StateError) return error.message.toString();
  return error.toString();
}

class TaskNotifier extends StateNotifier<AsyncValue<List<Task>>> {
  final TaskRepositoryImpl _repo;
  final TaskReminderService _reminders;
  String? _lastOperationError;

  String? get lastOperationError => _lastOperationError;

  TaskNotifier(this._repo, this._reminders) : super(const AsyncValue.loading()) {
    loadTasks();
  }

  Future<void> loadTasks({int? retentionDays}) async {
    state = const AsyncValue.loading();
    try {
      final tasks = await _repo.getTasks(retentionDays: retentionDays);
      state = AsyncValue.data(tasks);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<Task?> createTask(NewTask newTask) async {
    _lastOperationError = null;
    try {
      final created = await _repo.createTask(newTask);
      final current = state.valueOrNull ?? [];
      state = AsyncValue.data([created, ...current]);
      return created;
    } catch (e) {
      debugPrint('Could not create task "${newTask.title}": $e');
      _lastOperationError = taskOperationErrorMessage(e);
      return null;
    }
  }

  Future<bool> updateTask(Task task) async {
    _lastOperationError = null;
    try {
      final updated = await _repo.updateTask(task);
      final current = state.valueOrNull ?? [];
      state = AsyncValue.data(
        current.map((t) => t.id == updated.id ? updated : t).toList(),
      );
      return true;
    } catch (error) {
      debugPrint('Could not update task ${task.id}: $error');
      _lastOperationError = taskOperationErrorMessage(error);
      return false;
    }
  }

  Future<bool> deleteTask(String id) async {
    _lastOperationError = null;
    final previous = state.valueOrNull ?? [];
    // Optimistic removal
    state = AsyncValue.data(previous.where((t) => t.id != id).toList());
    try {
      await _repo.deleteTask(id);
    } catch (error) {
      // Rollback on failure
      state = AsyncValue.data(previous);
      debugPrint('Could not delete task $id: $error');
      _lastOperationError = taskOperationErrorMessage(error);
      return false;
    }
    try {
      final hadReminder = previous.any(
        (task) => task.id == id && task.reminderAt != null,
      );
      if (hadReminder) {
        await _reminders.cancelTaskReminder(id);
      }
    } catch (error) {
      debugPrint('Could not cancel reminder for deleted task $id: $error');
    }
    return true;
  }

  Future<bool> toggleCompletion(String id, bool completed) async {
    _lastOperationError = null;
    late Task updated;
    try {
      updated = await _repo.toggleCompletion(id, completed);
    } catch (error) {
      debugPrint('Could not update task completion for $id: $error');
      _lastOperationError = taskOperationErrorMessage(error);
      return false;
    }
    final current = state.valueOrNull ?? [];
    state = AsyncValue.data(
      current.map((t) => t.id == updated.id ? updated : t).toList(),
    );
    try {
      if (updated.reminderAt != null && updated.completed) {
        await _reminders.cancelTaskReminder(id);
      } else if (updated.reminderAt != null) {
        await _reminders.scheduleTaskReminder(
          taskId: updated.id,
          title: updated.title,
          reminderAt: updated.reminderAt!,
        );
      }
    } catch (error) {
      debugPrint('Could not update reminder for task $id: $error');
    }
    if (completed && updated.recurrence != null) {
      try {
        final refreshed = await _repo.getTasks();
        final currentTasks = state.valueOrNull ?? [];
        final matchingOccurrences = refreshed
            .where((task) => task.recurrenceSourceId == updated.id);
        final nextOccurrence =
            matchingOccurrences.isEmpty ? null : matchingOccurrences.first;
        if (nextOccurrence != null &&
            !currentTasks.any((task) => task.id == nextOccurrence.id)) {
          state = AsyncValue.data([nextOccurrence, ...currentTasks]);
        }
      } catch (error) {
        debugPrint('Could not refresh recurring task ${updated.id}: $error');
      }
    }
    return true;
  }
}

final taskRepositoryProvider = Provider<TaskRepositoryImpl>((ref) => TaskRepositoryImpl());

final taskProvider =
    StateNotifierProvider<TaskNotifier, AsyncValue<List<Task>>>((ref) {
  final repo = ref.watch(taskRepositoryProvider);
  return TaskNotifier(repo, TaskReminderService());
});
