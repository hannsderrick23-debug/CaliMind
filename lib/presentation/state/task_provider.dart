import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:calimind/core/utils/network_error_utils.dart';
import 'package:calimind/core/services/task_reminder_service.dart';
import 'package:calimind/data/repositories/task_repository_impl.dart';
import 'package:calimind/domain/models/task.dart';
import 'package:calimind/presentation/state/auth_provider.dart';

String taskOperationErrorMessage(Object error) {
  final networkMessage = networkErrorMessage(error);
  if (networkMessage != null) return networkMessage;
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
  final String? _userId;
  final Map<String, Task> _pendingDeletes = {};
  String? _lastOperationError;
  bool _disposed = false;

  String? get lastOperationError => _lastOperationError;

  TaskNotifier(this._repo, this._reminders, {required String? userId})
    : _userId = userId,
      super(const AsyncValue.loading()) {
    if (userId == null) {
      state = const AsyncValue.data([]);
    } else {
      loadTasks();
    }
  }

  Future<void> loadTasks({int? retentionDays}) async {
    if (_userId == null) {
      state = const AsyncValue.data([]);
      return;
    }
    state = const AsyncValue.loading();
    try {
      final tasks = await _repo.getTasks(retentionDays: retentionDays);
      if (_disposed) return;
      state = AsyncValue.data(
        tasks
            .where((task) => !_pendingDeletes.containsKey(task.id))
            .toList(),
      );
    } catch (e, st) {
      if (_disposed) return;
      state = AsyncValue.error(e, st);
    }
  }

  Future<Task?> createTask(NewTask newTask) async {
    _lastOperationError = null;
    try {
      final created = await _repo.createTask(newTask);
      if (_disposed) return null;
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
      if (_disposed) return false;
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
      if (_disposed) return true;
    } catch (error) {
      if (_disposed) return false;
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

  bool stageTaskDeletion(String id) {
    final current = state.valueOrNull ?? [];
    final matches = current.where((candidate) => candidate.id == id);
    final task = matches.isEmpty ? null : matches.first;
    if (task == null || _pendingDeletes.containsKey(id)) return false;

    _pendingDeletes[id] = task;
    state = AsyncValue.data(
      current.where((candidate) => candidate.id != id).toList(),
    );
    return true;
  }

  bool undoTaskDeletion(String id) {
    final task = _pendingDeletes.remove(id);
    if (task == null) return false;
    final current = state.valueOrNull ?? [];
    state = AsyncValue.data([task, ...current]);
    return true;
  }

  Future<bool> commitTaskDeletion(String id) async {
    final task = _pendingDeletes.remove(id);
    if (task == null) return false;

    _lastOperationError = null;
    try {
      await _repo.deleteTask(id);
      if (_disposed) return false;
    } catch (error) {
      if (_disposed) return false;
      final current = state.valueOrNull ?? [];
      state = AsyncValue.data([task, ...current]);
      debugPrint('Could not delete task $id: $error');
      _lastOperationError = taskOperationErrorMessage(error);
      return false;
    }

    try {
      if (task.reminderAt != null) {
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
      if (_disposed) return false;
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
        if (_disposed) return true;
        final currentTasks = state.valueOrNull ?? [];
        final matchingOccurrences =
          refreshed.where((task) => task.recurrenceSourceId == updated.id);
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

  @override
  void dispose() {
    _disposed = true;
    _pendingDeletes.clear();
    super.dispose();
  }
}

final taskRepositoryProvider =
    Provider<TaskRepositoryImpl>((ref) => TaskRepositoryImpl());

final taskProvider =
    StateNotifierProvider<TaskNotifier, AsyncValue<List<Task>>>((ref) {
      final userId = ref.watch(authProvider.select((auth) => auth.user?.id));
      final repo = ref.watch(taskRepositoryProvider);
      return TaskNotifier(repo, TaskReminderService(), userId: userId);
    });
