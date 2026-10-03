import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:calimind/core/constants/app_colors.dart';

enum TaskCategory {
  classRep('Class Rep'),
  clubPresident('Club President'),
  study('Study'),
  work('Work'),
  health('Health & Fitness'),
  errands('Errands'),
  family('Family'),
  finance('Finance'),
  social('Social'),
  personal('Personal');

  const TaskCategory(this.label);
  final String label;

  static TaskCategory fromString(String val) {
    final normalized = val.trim().toLowerCase();
    return TaskCategory.values.firstWhere(
      (category) => category.label.toLowerCase() == normalized,
      orElse: () => switch (normalized) {
        'class_rep' => TaskCategory.classRep,
        'club_president' => TaskCategory.clubPresident,
        'health' => TaskCategory.health,
        _ => TaskCategory.personal,
      },
    );
  }

  IconData get icon => switch (this) {
        TaskCategory.classRep => LucideIcons.megaphone,
        TaskCategory.clubPresident => LucideIcons.gavel,
        TaskCategory.study => LucideIcons.bookOpen,
        TaskCategory.work => LucideIcons.briefcaseBusiness,
        TaskCategory.health => LucideIcons.heartPulse,
        TaskCategory.errands => LucideIcons.shoppingCart,
        TaskCategory.family => LucideIcons.house,
        TaskCategory.finance => LucideIcons.wallet,
        TaskCategory.social => LucideIcons.usersRound,
        TaskCategory.personal => LucideIcons.user,
      };

  Color get color => switch (this) {
        TaskCategory.classRep => CaliMindColors.catClass,
        TaskCategory.clubPresident => CaliMindColors.catClub,
        TaskCategory.study => CaliMindColors.catStudy,
        TaskCategory.work => const Color(0xFF326A9D),
        TaskCategory.health => const Color(0xFFB5475E),
        TaskCategory.errands => const Color(0xFF8A5A00),
        TaskCategory.family => const Color(0xFF70428F),
        TaskCategory.finance => const Color(0xFF287A55),
        TaskCategory.social => const Color(0xFFA04F2B),
        TaskCategory.personal => CaliMindColors.catPersonal,
      };
}

enum PreferredTime {
  morning('Morning', 480, 720),      // 08:00 - 12:00
  afternoon('Afternoon', 720, 1020), // 12:00 - 17:00
  evening('Evening', 1020, 1200),    // 17:00 - 20:00
  night('Night', 1200, 1320);        // 20:00 - 22:00

  const PreferredTime(this.label, this.startMinute, this.endMinute);
  final String label;
  final int startMinute;
  final int endMinute;

  static PreferredTime? fromString(String? val) => switch (val?.trim()) {
        'Morning' => PreferredTime.morning,
        'Afternoon' => PreferredTime.afternoon,
        'Evening' => PreferredTime.evening,
        'Night' => PreferredTime.night,
        _ => null,
      };
}

class Task {
  final String id;
  final String userId;
  final String title;
  final String? description;
  final TaskCategory category;
  final int duration;
  final DateTime? deadline;
  final PreferredTime? preferredTime;
  final String? specificTime;
  final DateTime? reminderAt;
  final int priority; // 1 (High), 2 (Medium), 3 (Low)
  final bool completed;
  final DateTime? completedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Task({
    required this.id,
    required this.userId,
    required this.title,
    this.description,
    required this.category,
    required this.duration,
    this.deadline,
    this.preferredTime,
    this.specificTime,
    this.reminderAt,
    required this.priority,
    required this.completed,
    this.completedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Task.fromJson(Map<String, dynamic> json) => Task(
        id: json['id'] as String,
        userId: json['user_id'] as String? ?? '',
        title: json['title'] as String,
        description: json['description'] as String?,
        category: TaskCategory.fromString(json['category'] as String? ?? 'Personal'),
        duration: json['duration'] as int? ?? 30,
        deadline: json['deadline'] != null ? DateTime.parse(json['deadline'] as String) : null,
        preferredTime: PreferredTime.fromString(json['preferred_time'] as String?),
        specificTime: json['specific_time'] as String?,
        reminderAt: json['reminder_at'] == null
            ? null
            : DateTime.parse(json['reminder_at'] as String),
        priority: json['priority'] as int? ?? 2,
        completed: json['completed'] as bool? ?? false,
        completedAt: json['completed_at'] != null ? DateTime.parse(json['completed_at'] as String) : null,
        createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : DateTime.now(),
        updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at'] as String) : DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'title': title,
        'description': description,
        'category': category.label,
        'duration': duration,
        'deadline': deadline?.toUtc().toIso8601String(),
        'preferred_time': preferredTime?.label,
        'specific_time': specificTime,
        'reminder_at': reminderAt?.toUtc().toIso8601String(),
        'priority': priority,
        'completed': completed,
        'completed_at': completedAt?.toIso8601String(),
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  Task copyWith({
    String? id,
    String? userId,
    String? title,
    String? description,
    TaskCategory? category,
    int? duration,
    DateTime? deadline,
    PreferredTime? preferredTime,
    String? specificTime,
    DateTime? reminderAt,
    bool clearReminder = false,
    bool clearSpecificTime = false,
    bool clearDeadline = false,
    bool clearPreferredTime = false,
    int? priority,
    bool? completed,
    DateTime? completedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      Task(
        id: id ?? this.id,
        userId: userId ?? this.userId,
        title: title ?? this.title,
        description: description ?? this.description,
        category: category ?? this.category,
        duration: duration ?? this.duration,
        deadline: clearDeadline ? null : (deadline ?? this.deadline),
        preferredTime:
            clearPreferredTime ? null : (preferredTime ?? this.preferredTime),
        specificTime:
            clearSpecificTime ? null : (specificTime ?? this.specificTime),
        reminderAt: clearReminder ? null : (reminderAt ?? this.reminderAt),
        priority: priority ?? this.priority,
        completed: completed ?? this.completed,
        completedAt: completedAt ?? this.completedAt,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}

class NewTask {
  final String title;
  final String? description;
  final TaskCategory category;
  final int duration;
  final DateTime? deadline;
  final PreferredTime? preferredTime;
  final String? specificTime;
  final DateTime? reminderAt;
  final int priority;

  const NewTask({
    required this.title,
    this.description,
    required this.category,
    required this.duration,
    this.deadline,
    this.preferredTime,
    this.specificTime,
    this.reminderAt,
    required this.priority,
  });

  Map<String, dynamic> toInsertJson(String userId) => {
        'user_id': userId,
        'title': title,
        'description': description,
        'category': category.label,
        'duration': duration,
        'deadline': deadline?.toUtc().toIso8601String(),
        'preferred_time': preferredTime?.label,
        'specific_time': specificTime,
        'reminder_at': reminderAt?.toUtc().toIso8601String(),
        'priority': priority,
        'completed': false,
      };

  NewTask copyWith({
    String? title,
    String? description,
    TaskCategory? category,
    int? duration,
    DateTime? deadline,
    PreferredTime? preferredTime,
    String? specificTime,
    DateTime? reminderAt,
    bool clearReminder = false,
    bool clearSpecificTime = false,
    bool clearDeadline = false,
    bool clearPreferredTime = false,
    int? priority,
  }) =>
      NewTask(
        title: title ?? this.title,
        description: description ?? this.description,
        category: category ?? this.category,
        duration: duration ?? this.duration,
        deadline: clearDeadline ? null : (deadline ?? this.deadline),
        preferredTime:
            clearPreferredTime ? null : (preferredTime ?? this.preferredTime),
        specificTime:
            clearSpecificTime ? null : (specificTime ?? this.specificTime),
        reminderAt: clearReminder ? null : (reminderAt ?? this.reminderAt),
        priority: priority ?? this.priority,
      );
}
