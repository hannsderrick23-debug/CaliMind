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
  ({SupabaseClient client, String userId}) _requireSession() {
    try {
      if (!SupabaseConfig.isConfigured) {
        throw StateError('Supabase is not configured for this app.');
      }
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;
      if (user == null) {
        throw StateError('Sign in before accessing your tasks.');
      }
      return (client: client, userId: user.id);
    } on StateError {
      rethrow;
    } catch (error) {
      throw StateError('Supabase is not available: $error');
    }
  }

  @override
  Future<List<Task>> fetchTasks({int? retentionDays}) async {
    try {
      final session = _requireSession();
      final rows = await session.client
          .from('tasks')
          .select()
          .eq('user_id', session.userId)
          .order('created_at', ascending: false);
      final tasks = rows.map((row) => Task.fromJson(row)).toList();
      if (retentionDays == null) return tasks;

      final cutoff = DateTime.now().subtract(Duration(days: retentionDays));
      return tasks
          .where((task) =>
              !task.completed ||
              task.completedAt == null ||
              task.completedAt!.isAfter(cutoff))
          .toList();
    } catch (error) {
      debugPrint('Could not fetch tasks from Supabase: $error');
      rethrow;
    }
  }

  @override
  Future<Task> createTask(NewTask newTask) async {
    try {
      final session = _requireSession();
      final response = await session.client
          .from('tasks')
          .insert(newTask.toInsertJson(session.userId))
          .select()
          .single();
      return Task.fromJson(response);
    } catch (error, stackTrace) {
      debugPrint('Could not save task to Supabase: $error');
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  @override
  Future<Task> updateTask(Task task) async {
    try {
      final session = _requireSession();
      final response = await session.client
          .from('tasks')
          .update(task.toJson())
          .eq('id', task.id)
          .eq('user_id', session.userId)
          .select()
          .single();
      return Task.fromJson(response);
    } catch (error, stackTrace) {
      debugPrint('Could not update task in Supabase: $error');
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  @override
  Future<void> deleteTask(String id) async {
    try {
      final session = _requireSession();
      await session.client
          .from('tasks')
          .delete()
          .eq('id', id)
          .eq('user_id', session.userId);
    } catch (error, stackTrace) {
      debugPrint('Could not delete task from Supabase: $error');
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  @override
  Future<Task> toggleTaskCompletion(String id, bool completed) async {
    try {
      final response = await _requireSession().client.rpc(
        'complete_task',
        params: {'p_task_id': id, 'p_completed': completed},
      ).single();
      return Task.fromJson(response);
    } catch (error, stackTrace) {
      debugPrint('Could not toggle task completion in Supabase: $error');
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  @override
  Future<int> purgeCompletedTasks(int retentionDays) async {
    try {
      final session = _requireSession();
      final cutoff = DateTime.now().subtract(Duration(days: retentionDays));
      final response = await session.client
          .from('tasks')
          .delete()
          .eq('user_id', session.userId)
          .eq('completed', true)
          .lt('completed_at', cutoff.toIso8601String())
          .select('id');
      return response.length;
    } catch (error, stackTrace) {
      debugPrint('Could not purge tasks from Supabase: $error');
      Error.throwWithStackTrace(error, stackTrace);
    }
  }
}
