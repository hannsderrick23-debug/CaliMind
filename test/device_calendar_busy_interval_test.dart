import 'package:flutter_test/flutter_test.dart';
import 'package:calimind/domain/models/calendar_busy_interval.dart';

void main() {
  group('CalendarBusyInterval.fromEventTimes', () {
    final dayStart = DateTime(2026, 10, 3);
    final nextDay = DateTime(2026, 10, 4);

    test('clips an event that begins before the selected day', () {
      final interval = CalendarBusyInterval.fromEventTimes(
        start: DateTime(2026, 10, 2, 23),
        end: DateTime(2026, 10, 3, 1),
        rangeStart: dayStart,
        rangeEnd: nextDay,
      );

      expect(interval?.start, dayStart);
      expect(interval?.end, DateTime(2026, 10, 3, 1));
    });

    test('clips an event that ends after the selected day', () {
      final interval = CalendarBusyInterval.fromEventTimes(
        start: DateTime(2026, 10, 3, 23),
        end: DateTime(2026, 10, 4, 1),
        rangeStart: dayStart,
        rangeEnd: nextDay,
      );

      expect(interval?.start, DateTime(2026, 10, 3, 23));
      expect(interval?.end, nextDay);
    });

    test('ignores non-overlapping and malformed events', () {
      expect(
        CalendarBusyInterval.fromEventTimes(
          start: DateTime(2026, 10, 2, 8),
          end: DateTime(2026, 10, 2, 9),
          rangeStart: dayStart,
          rangeEnd: nextDay,
        ),
        isNull,
      );
      expect(
        CalendarBusyInterval.fromEventTimes(
          start: DateTime(2026, 10, 3, 9),
          end: DateTime(2026, 10, 3, 9),
          rangeStart: dayStart,
          rangeEnd: nextDay,
        ),
        isNull,
      );
      expect(
        CalendarBusyInterval.fromEventTimes(
          start: null,
          end: DateTime(2026, 10, 3, 9),
          rangeStart: dayStart,
          rangeEnd: nextDay,
        ),
        isNull,
      );
    });
  });
}
