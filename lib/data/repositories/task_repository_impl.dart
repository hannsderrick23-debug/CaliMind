import '../../data/datasources/task_remote_datasource.dart';
import '../../domain/models/task.dart';

class TaskRepositoryImpl {
  final TaskRemoteDatasource _datasource;

  TaskRepositoryImpl({TaskRemoteDatasource? datasource})
      : _datasource = datasource ?? TaskRemoteDatasourceImpl();

  Future<List<Task>> getTasks({int? retentionDays}) =>
      _datasource.fetchTasks(retentionDays: retentionDays);

  Future<Task> createTask(NewTask task) => _datasource.createTask(task);

  Future<Task> updateTask(Task task) => _datasource.updateTask(task);

  Future<void> deleteTask(String id) => _datasource.deleteTask(id);

  Future<Task> toggleCompletion(String id, bool completed) =>
      _datasource.toggleTaskCompletion(id, completed);

  Future<int> purgeCompletedTasks(int retentionDays) =>
      _datasource.purgeCompletedTasks(retentionDays);
}
