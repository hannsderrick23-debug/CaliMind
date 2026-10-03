import 'package:flutter_test/flutter_test.dart';
import 'package:calimind/domain/models/task.dart';

void main() {
  test('legacy task JSON defaults to nonrecurring', () {
    final task = Task.fromJson({
      'id': 'task-1',
      'user_id': 'user-1',
      'title': 'Read',
      'category': 'Study',
      'duration': 30,
      'priority': 2,
      'completed': false,
    });

    expect(task.recurrence, isNull);
    expect(task.recurrenceSourceId, isNull);
  });

  test('recurrence choices serialize to the database values', () {
    const task = NewTask(
      title: 'Review notes',
      category: TaskCategory.study,
      duration: 30,
      priority: 2,
      recurrence: TaskRecurrence.weekly,
    );

    expect(task.toInsertJson('user-1')['recurrence_rule'], 'weekly');
    expect(
      const NewTask(
        title: 'One off',
        category: TaskCategory.personal,
        duration: 30,
        priority: 2,
      ).toInsertJson('user-1')['recurrence_rule'],
      isNull,
    );
  });

  test('task round-trips recurrence and can clear it while editing', () {
    final task = Task.fromJson({
      'id': 'task-1',
      'user_id': 'user-1',
      'title': 'Review notes',
      'category': 'Study',
      'duration': 30,
      'priority': 2,
      'completed': false,
      'recurrence_rule': 'daily',
      'recurrence_source_id': 'task-previous',
    });

    final decoded = Task.fromJson(task.toJson());

    expect(decoded.recurrence, TaskRecurrence.daily);
    expect(decoded.recurrenceSourceId, 'task-previous');
    expect(decoded.copyWith(clearRecurrence: true).recurrence, isNull);
  });

  test('unsupported recurrence values are treated as nonrecurring', () {
    expect(TaskRecurrence.fromString('monthly'), isNull);
  });
}
