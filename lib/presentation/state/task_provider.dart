import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:calimind/data/repositories/task_repository_impl.dart';
import 'package:calimind/domain/models/task.dart';

class TaskNotifier extends StateNotifier<AsyncValue<List<Task>>> {
  final TaskRepositoryImpl _repo;

  TaskNotifier(this._repo) : super(const AsyncValue.loading()) {
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
    try {
      final created = await _repo.createTask(newTask);
      final current = state.valueOrNull ?? [];
      state = AsyncValue.data([created, ...current]);
      return created;
    } catch (e) {
      return null;
    }
  }

  Future<void> updateTask(Task task) async {
    try {
      final updated = await _repo.updateTask(task);
      final current = state.valueOrNull ?? [];
      state = AsyncValue.data(
        current.map((t) => t.id == updated.id ? updated : t).toList(),
      );
    } catch (_) {}
  }

  Future<void> deleteTask(String id) async {
    final previous = state.valueOrNull ?? [];
    // Optimistic removal
    state = AsyncValue.data(previous.where((t) => t.id != id).toList());
    try {
      await _repo.deleteTask(id);
    } catch (_) {
      // Rollback on failure
      state = AsyncValue.data(previous);
    }
  }

  Future<void> toggleCompletion(String id, bool completed) async {
    try {
      final updated = await _repo.toggleCompletion(id, completed);
      final current = state.valueOrNull ?? [];
      state = AsyncValue.data(
        current.map((t) => t.id == updated.id ? updated : t).toList(),
      );
    } catch (_) {}
  }
}

final taskRepositoryProvider = Provider<TaskRepositoryImpl>((ref) => TaskRepositoryImpl());

final taskProvider = StateNotifierProvider<TaskNotifier, AsyncValue<List<Task>>>((ref) {
  final repo = ref.watch(taskRepositoryProvider);
  return TaskNotifier(repo);
});
