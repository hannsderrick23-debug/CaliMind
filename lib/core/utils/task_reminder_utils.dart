DateTime? defaultTaskReminderAt({
  required String? specificTime,
  required DateTime? deadline,
  DateTime? now,
}) {
  if (specificTime == null) return null;

  final timeParts = specificTime.split(':');
  if (timeParts.length != 2) return null;
  final hour = int.tryParse(timeParts[0]);
  final minute = int.tryParse(timeParts[1]);
  if (hour == null ||
      minute == null ||
      hour < 0 ||
      hour > 23 ||
      minute < 0 ||
      minute > 59) {
    return null;
  }

  final activityDate = deadline?.toLocal() ?? (now ?? DateTime.now());
  return DateTime(
    activityDate.year,
    activityDate.month,
    activityDate.day,
    hour,
    minute,
  ).subtract(const Duration(minutes: 30));
}
