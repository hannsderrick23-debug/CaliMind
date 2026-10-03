import 'package:calimind/core/services/widget_service.dart';
import 'package:calimind/domain/models/task.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final createdAt = DateTime(2026, 10, 3);

  test('task-title sharing is disabled unless the user opts in', () async {
    SharedPreferences.setMockInitialValues({});

    expect(await WidgetService.isTaskTitleSharingEnabled(), isFalse);
  });

  test('publishes the agreed widget voice action URI contract', () {
    expect(
      WidgetService.voiceCaptureDeepLink,
      'io.supabase.calimind://voice-capture',
    );
  });

  Task task({
    required String id,
    required String title,
    bool completed = false,
    DateTime? deadline,
    int priority = 2,
  }) =>
      Task(
        id: id,
        userId: 'user',
        title: title,
        description: 'Private description',
        category: TaskCategory.personal,
        duration: 30,
        deadline: deadline,
        priority: priority,
        completed: completed,
        createdAt: createdAt,
        updatedAt: createdAt,
      );

  test('selects earliest deadline and ignores completed tasks', () {
    final selected = selectNextIncompleteTask([
      task(
        id: 'later',
        title: 'Later',
        deadline: DateTime(2026, 10, 5),
      ),
      task(
        id: 'done',
        title: 'Completed',
        completed: true,
        deadline: DateTime(2026, 10, 3),
      ),
      task(
        id: 'soon',
        title: 'Soon',
        deadline: DateTime(2026, 10, 4),
      ),
    ]);

    expect(selected?.id, 'soon');
  });

  test('uses schedule order before deadline and never selects completed task',
      () {
    final selected = selectNextIncompleteTask(
      [
        task(
          id: 'scheduled-first',
          title: 'First on schedule',
          deadline: DateTime(2026, 10, 8),
        ),
        task(
          id: 'scheduled-done',
          title: 'Completed on schedule',
          completed: true,
          deadline: DateTime(2026, 10, 3),
        ),
        task(
          id: 'earlier-deadline',
          title: 'Earlier deadline',
          deadline: DateTime(2026, 10, 4),
        ),
      ],
      scheduledTaskIds: ['scheduled-done', 'scheduled-first'],
    );

    expect(selected?.id, 'scheduled-first');
  });

  test('returns no task for empty or all-completed input', () {
    expect(selectNextIncompleteTask([]), isNull);
    expect(
      selectNextIncompleteTask([
        task(id: 'done', title: 'Done', completed: true),
      ]),
      isNull,
    );
  });
}
