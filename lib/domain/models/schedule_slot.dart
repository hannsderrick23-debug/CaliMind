import 'task.dart';

class ScheduleSlot {
  final String taskId;
  final String taskTitle;
  final TaskCategory category;
  final String startTime; // "HH:mm"
  final String endTime;   // "HH:mm"
  final int duration;     // minutes

  const ScheduleSlot({
    required this.taskId,
    required this.taskTitle,
    required this.category,
    required this.startTime,
    required this.endTime,
    required this.duration,
  });

  factory ScheduleSlot.fromJson(Map<String, dynamic> json) {
    final taskData = json['tasks'] as Map<String, dynamic>? ?? {};
    return ScheduleSlot(
      taskId: json['task_id'] as String? ?? json['id'] as String? ?? '',
      startTime: ((json['start_time'] as String?) ?? '08:00').substring(0, 5),
      endTime: ((json['end_time'] as String?) ?? '08:30').substring(0, 5),
      taskTitle: (taskData['title'] as String?) ?? (json['task_title'] as String?) ?? 'Task',
      category: TaskCategory.fromString((taskData['category'] as String?) ?? (json['category'] as String?) ?? 'Personal'),
      duration: json['duration'] as int? ?? 30,
    );
  }

  Map<String, dynamic> toJson(String userId, String date) => {
        'user_id': userId,
        'task_id': taskId,
        'schedule_date': date,
        'start_time': startTime,
        'end_time': endTime,
      };
}

class UnscheduledTask {
  final String taskId;
  final String title;
  final String reason;

  const UnscheduledTask({
    required this.taskId,
    required this.title,
    required this.reason,
  });

  Map<String, dynamic> toJson() => {
        'task_id': taskId,
        'title': title,
        'reason': reason,
      };
}

class ScheduleResult {
  final List<ScheduleSlot> slots;
  final List<UnscheduledTask> unscheduled;

  const ScheduleResult({
    required this.slots,
    required this.unscheduled,
  });

  bool get hasUnscheduled => unscheduled.isNotEmpty;
}
