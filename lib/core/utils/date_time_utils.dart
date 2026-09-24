import 'package:intl/intl.dart';

class DateTimeUtils {
  static final DateFormat _isoDateFormat = DateFormat('yyyy-MM-dd');
  static final DateFormat _displayDateFormat = DateFormat('EEEE, MMM d');
  static final DateFormat _shortDateFormat = DateFormat('MMM d');

  static String toIsoDate(DateTime dt) => _isoDateFormat.format(dt);

  static String toDisplayDate(DateTime dt) => _displayDateFormat.format(dt);

  static String toShortDate(DateTime dt) => _shortDateFormat.format(dt);

  static String formatMinutes(int minutes) {
    final h = (minutes ~/ 60).toString().padLeft(2, '0');
    final m = (minutes % 60).toString().padLeft(2, '0');
    return '$h:$m';
  }

  static int toMinutes(String hhMm) {
    final parts = hhMm.split(':').map(int.parse).toList();
    return parts[0] * 60 + parts[1];
  }

  static String formatDuration(int minutes) {
    if (minutes < 60) {
      return '${minutes}m';
    }
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (m == 0) {
      return '${h}h';
    }
    return '${h}h ${m}m';
  }
}
