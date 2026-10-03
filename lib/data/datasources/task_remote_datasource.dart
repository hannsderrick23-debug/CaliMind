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
  SupabaseClient _requireClient() {
    try {
      if (!SupabaseConfig.isConfigured) {
        throw StateError('Supabase is not configured for this app.');
      }
      final client = Supabase.instance.client;
      if (client.auth.currentUser == null) {
        throw StateError('Sign in before accessing your tasks.');
      }
      return client;
    } on StateError {
      rethrow;
    } catch (error) {
      throw StateError('Supabase is not available: $error');
    }
  }

  @override
  Future<List<Task>> fetchTasks({int? retentionDays}) async {
    try {
      final rows = await _requireClient()
          .from('tasks')
          .select()
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
      final client = _requireClient();
      final user = client.auth.currentUser;
      if (user == null) {
        throw StateError('Sign in before saving a task to your account.');
      }
      final response = await client
          .from('tasks')
          .insert(newTask.toInsertJson(user.id))
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
      final response = await _requireClient()
          .from('tasks')
          .update(task.toJson())
          .eq('id', task.id)
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
      await _requireClient().from('tasks').delete().eq('id', id);
    } catch (error, stackTrace) {
      debugPrint('Could not delete task from Supabase: $error');
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  @override
  Future<Task> toggleTaskCompletion(String id, bool completed) async {
    try {
      final response = await _requireClient()
          .from('tasks')
          .update({
            'completed': completed,
            'completed_at':
                completed ? DateTime.now().toUtc().toIso8601String() : null,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', id)
          .select()
          .single();
      return Task.fromJson(response);
    } catch (error, stackTrace) {
      debugPrint('Could not toggle task completion in Supabase: $error');
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  @override
  Future<int> purgeCompletedTasks(int retentionDays) async {
    try {
      final cutoff = DateTime.now().subtract(Duration(days: retentionDays));
      final response = await _requireClient()
          .from('tasks')
          .delete()
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
