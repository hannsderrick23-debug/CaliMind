class ScheduleConstants {
  static const int dayStart = 480; // 08:00 AM in minutes from midnight
  static const int dayEnd = 1320; // 10:00 PM in minutes from midnight
  static const int bufferMinutes = 15; // 15-minute rest buffer between slots
  static const int studyBlockCap = 120; // Max 120 minutes per continuous study block

  static const String dayStartFormatted = '08:00';
  static const String dayEndFormatted = '22:00';
  static const String planningHoursLabel = '08:00–22:00';

  // Quadrants
  static const int morningStart = 480;
  static const int morningEnd = 720;
  static const int afternoonStart = 720;
  static const int afternoonEnd = 1020;
  static const int eveningStart = 1020;
  static const int eveningEnd = 1200;
  static const int nightStart = 1200;
  static const int nightEnd = 1320;
}
