import 'package:flutter_test/flutter_test.dart';
import 'package:calimind/core/utils/task_reminder_utils.dart';

void main() {
  group('defaultTaskReminderAt', () {
    test('defaults to 30 minutes before exact start time on the due date', () {
      final reminder = defaultTaskReminderAt(
        specificTime: '14:15',
        deadline: DateTime(2026, 10, 12, 23, 59),
      );

      expect(reminder, DateTime(2026, 10, 12, 13, 45));
    });

    test('uses today when no due date is set', () {
      final reminder = defaultTaskReminderAt(
        specificTime: '09:00',
        deadline: null,
        now: DateTime(2026, 10, 4, 8, 0),
      );

      expect(reminder, DateTime(2026, 10, 4, 8, 30));
    });

    test('returns no default when the activity has no exact start time', () {
      expect(
        defaultTaskReminderAt(
          specificTime: null,
          deadline: DateTime(2026, 10, 12),
        ),
        isNull,
      );
    });

    test('rejects malformed exact start times', () {
      expect(
        defaultTaskReminderAt(
          specificTime: '25:70',
          deadline: null,
          now: DateTime(2026, 10, 4),
        ),
        isNull,
      );
    });
  });
}
