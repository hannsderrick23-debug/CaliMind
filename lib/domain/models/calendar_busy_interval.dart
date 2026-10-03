class CalendarBusyInterval {
  final DateTime start;
  final DateTime end;

  const CalendarBusyInterval({
    required this.start,
    required this.end,
  });

  static CalendarBusyInterval? fromEventTimes({
    required DateTime? start,
    required DateTime? end,
    required DateTime rangeStart,
    required DateTime rangeEnd,
  }) {
    if (start == null || end == null || !end.isAfter(start)) return null;
    if (!end.isAfter(rangeStart) || !start.isBefore(rangeEnd)) return null;

    final clippedStart =
        start.isAfter(rangeStart) ? start : rangeStart;
    final clippedEnd = end.isBefore(rangeEnd) ? end : rangeEnd;
    if (!clippedEnd.isAfter(clippedStart)) return null;

    return CalendarBusyInterval(
      start: clippedStart.toLocal(),
      end: clippedEnd.toLocal(),
    );
  }
}
