import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:calimind/core/network/supabase_client.dart';
import 'package:calimind/domain/models/task.dart';

abstract class TaskRemoteDatasource {
  Future<List<Task>> fetchTasks({int? retentionDays});
  Future<Task> createTask(NewTask newTask);
  Future<Task> updateTask(Task task);
  Future<void> deleteTask(String id);
  Future<Task> toggleTaskCompletion(String id, bool completed);
  Future<int> purgeCompletedTasks(int retentionDays);
}

class TaskRemoteDatasourceImpl implements TaskRemoteDatasource {
  // In-memory fallback repository when running offline / mock mode
  final List<Task> _mockTasks = [
    Task(
      id: 'demo-1',
      userId: 'mock-user',
      title: 'Cohort lecture notes distribution',
      description: 'Format PDF and forward to WhatsApp group',
      category: TaskCategory.classRep,
      duration: 30,
      priority: 1,
      specificTime: '09:00',
      completed: false,
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      updatedAt: DateTime.now().subtract(const Duration(hours: 2)),
    ),
    Task(
      id: 'demo-2',
      userId: 'mock-user',
      title: 'Club sponsorship proposal review',
      description: 'Review pitch deck and line-item budget',
      category: TaskCategory.clubPresident,
      duration: 60,
      priority: 1,
      preferredTime: PreferredTime.afternoon,
      completed: false,
      createdAt: DateTime.now().subtract(const Duration(hours: 4)),
      updatedAt: DateTime.now().subtract(const Duration(hours: 4)),
    ),
    Task(
      id: 'demo-3',
      userId: 'mock-user',
      title: 'Advanced Calculus problem set',
      description: 'Complete problem sets 4.1 to 4.5',
      category: TaskCategory.study,
      duration: 150, // >120m to trigger study capping in scheduler!
      priority: 1,
      preferredTime: PreferredTime.morning,
      completed: false,
      createdAt: DateTime.now().subtract(const Duration(hours: 5)),
      updatedAt: DateTime.now().subtract(const Duration(hours: 5)),
    ),
    Task(
      id: 'demo-4',
      userId: 'mock-user',
      title: 'Evening gym and mobility routine',
      description: 'Upper body hypertrophy and stretch',
      category: TaskCategory.personal,
      duration: 45,
      priority: 2,
      preferredTime: PreferredTime.evening,
      completed: false,
      createdAt: DateTime.now().subtract(const Duration(hours: 6)),
      updatedAt: DateTime.now().subtract(const Duration(hours: 6)),
    ),
    Task(
      id: 'demo-5',
      userId: 'mock-user',
      title: 'Executive committee weekly sync',
      description: 'Weekly club status sync and event planning',
      category: TaskCategory.clubPresident,
      duration: 45,
      priority: 2,
      specificTime: '15:00',
      completed: false,
      createdAt: DateTime.now().subtract(const Duration(hours: 8)),
      updatedAt: DateTime.now().subtract(const Duration(hours: 8)),
    ),
  ];

  SupabaseClient? get _client {
    try {
      if (SupabaseConfig.isConfigured && Supabase.instance.client.auth.currentUser != null) {
        return Supabase.instance.client;
      }
    } catch (_) {}
    return null;
  }

  @override
  Future<List<Task>> fetchTasks({int? retentionDays}) async {
    final client = _client;
    if (client != null) {
      try {
        final query = client.from('tasks').select().order('created_at', ascending: false);
        final res = await query;
        final tasks = (res as List).map((row) => Task.fromJson(row as Map<String, dynamic>)).toList();
        
        if (retentionDays != null) {
          final cutoff = DateTime.now().subtract(Duration(days: retentionDays));
          return tasks.where((t) => !t.completed || t.completedAt == null || t.completedAt!.isAfter(cutoff)).toList();
        }
        return tasks;
      } catch (e) {
        debugPrint('Fetch tasks remote error: $e. Falling back to local store.');
      }
    }

    if (retentionDays != null) {
      final cutoff = DateTime.now().subtract(Duration(days: retentionDays));
      return _mockTasks.where((t) => !t.completed || t.completedAt == null || t.completedAt!.isAfter(cutoff)).toList();
    }
    return List.unmodifiable(_mockTasks);
  }

  @override
  Future<Task> createTask(NewTask newTask) async {
    final client = _client;
    final user = client?.auth.currentUser;
    final userId = user?.id ?? 'mock-user';

    if (client != null && user != null) {
      try {
        final res = await client.from('tasks').insert(newTask.toInsertJson(userId)).select().single();
        return Task.fromJson(res);
      } catch (e) {
        debugPrint('Create task remote error: $e');
      }
    }

    final created = Task(
      id: 'local-${DateTime.now().millisecondsSinceEpoch}',
      userId: userId,
      title: newTask.title,
      description: newTask.description,
      category: newTask.category,
      duration: newTask.duration,
      deadline: newTask.deadline,
      preferredTime: newTask.preferredTime,
      specificTime: newTask.specificTime,
      priority: newTask.priority,
      completed: false,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    _mockTasks.insert(0, created);
    return created;
  }

  @override
  Future<Task> updateTask(Task task) async {
    final client = _client;
    if (client != null) {
      try {
        final res = await client.from('tasks').update(task.toJson()).eq('id', task.id).select().single();
        return Task.fromJson(res);
      } catch (e) {
        debugPrint('Update task remote error: $e');
      }
    }

    final index = _mockTasks.indexWhere((t) => t.id == task.id);
    if (index >= 0) {
      _mockTasks[index] = task.copyWith();
      return _mockTasks[index];
    }
    _mockTasks.insert(0, task);
    return task;
  }

  @override
  Future<void> deleteTask(String id) async {
    final client = _client;
    if (client != null) {
      try {
        await client.from('tasks').delete().eq('id', id);
        return;
      } catch (e) {
        debugPrint('Delete task remote error: $e');
      }
    }

    _mockTasks.removeWhere((t) => t.id == id);
  }

  @override
  Future<Task> toggleTaskCompletion(String id, bool completed) async {
    final client = _client;
    final now = DateTime.now();
    if (client != null) {
      try {
        final res = await client.from('tasks').update({
          'completed': completed,
          'completed_at': completed ? now.toIso8601String() : null,
          'updated_at': now.toIso8601String(),
        }).eq('id', id).select().single();
        return Task.fromJson(res);
      } catch (e) {
        debugPrint('Toggle completion remote error: $e');
      }
    }

    final index = _mockTasks.indexWhere((t) => t.id == id);
    if (index >= 0) {
      final updated = _mockTasks[index].copyWith(
        completed: completed,
      );
      _mockTasks[index] = Task(
        id: updated.id,
        userId: updated.userId,
        title: updated.title,
        description: updated.description,
        category: updated.category,
        duration: updated.duration,
        deadline: updated.deadline,
        preferredTime: updated.preferredTime,
        specificTime: updated.specificTime,
        priority: updated.priority,
        completed: completed,
        completedAt: completed ? now : null,
        createdAt: updated.createdAt,
        updatedAt: now,
      );
      return _mockTasks[index];
    }
    throw Exception('Task not found: $id');
  }

  @override
  Future<int> purgeCompletedTasks(int retentionDays) async {
    final cutoff = DateTime.now().subtract(Duration(days: retentionDays));
    final client = _client;
    if (client != null) {
      try {
        final res = await client.from('tasks').delete().eq('completed', true).lt('completed_at', cutoff.toIso8601String()).select();
        return (res as List).length;
      } catch (e) {
        debugPrint('Purge remote error: $e');
      }
    }

    final before = _mockTasks.length;
    _mockTasks.removeWhere((t) => t.completed && t.completedAt != null && t.completedAt!.isBefore(cutoff));
    return before - _mockTasks.length;
  }
}
