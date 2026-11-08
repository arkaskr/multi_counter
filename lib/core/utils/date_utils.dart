import 'package:intl/intl.dart';

class AppDateUtils {
  AppDateUtils._();

  static final DateFormat _isoFormat = DateFormat('yyyy-MM-dd');
  static final DateFormat _dayOfWeekAbbr = DateFormat('EEE');
  static final DateFormat _dayOfWeekFull = DateFormat('EEEE');
  static final DateFormat _displayFormat = DateFormat('EEEE, d MMMM');
  static final DateFormat _shortDisplayFormat = DateFormat('d MMM');
  static final DateFormat _monthYearFormat = DateFormat('MMMM yyyy');

  /// Returns today's date formatted as YYYY-MM-DD
  static String getTodayDateString([DateTime? now]) {
    final date = now ?? DateTime.now();
    return _isoFormat.format(date);
  }

  /// Formats any DateTime object into YYYY-MM-DD string
  static String formatDate(DateTime date) {
    return _isoFormat.format(date);
  }

  /// Formats date string (YYYY-MM-DD) into DateTime object
  static DateTime parseDate(String dateStr) {
    return _isoFormat.parse(dateStr);
  }

  /// Formats date string into human-friendly string (e.g. "Monday, 2 November")
  static String formatDisplayDate(String dateStr) {
    try {
      final dt = parseDate(dateStr);
      return _displayFormat.format(dt);
    } catch (_) {
      return dateStr;
    }
  }

  /// Formats date string into short display (e.g. "2 Nov")
  static String formatShortDate(String dateStr) {
    try {
      final dt = parseDate(dateStr);
      return _shortDisplayFormat.format(dt);
    } catch (_) {
      return dateStr;
    }
  }

  /// Returns 3-letter uppercase day of week (e.g. "MON")
  static String getDayOfWeekAbbr(String dateStr) {
    try {
      final dt = parseDate(dateStr);
      return _dayOfWeekAbbr.format(dt).toUpperCase();
    } catch (_) {
      return '';
    }
  }

  /// Returns full day of week (e.g. "Monday")
  static String getDayOfWeekFull(String dateStr) {
    try {
      final dt = parseDate(dateStr);
      return _dayOfWeekFull.format(dt);
    } catch (_) {
      return '';
    }
  }

  /// Checks if given date string is today
  static bool isToday(String dateStr, [DateTime? now]) {
    return dateStr == getTodayDateString(now);
  }

  /// Returns list of 7 date strings (YYYY-MM-DD) for the week containing [anchorDate].
  /// [weekStart] can be 'monday' or 'sunday'.
  static List<String> getWeekDates(DateTime anchorDate, String weekStart) {
    // DateTime.weekday: Monday=1, Sunday=7
    final cleanAnchor = DateTime(anchorDate.year, anchorDate.month, anchorDate.day);
    int daysFromStart;

    if (weekStart.toLowerCase() == 'sunday') {
      // If Sunday, weekday is 7 -> daysFromStart = 0
      // Monday is 1 -> daysFromStart = 1
      daysFromStart = cleanAnchor.weekday % 7;
    } else {
      // Monday start: Monday is 1 -> daysFromStart = 0
      // Sunday is 7 -> daysFromStart = 6
      daysFromStart = cleanAnchor.weekday - 1;
    }

    final startDate = cleanAnchor.subtract(Duration(days: daysFromStart));
    return List.generate(7, (index) {
      final d = startDate.add(Duration(days: index));
      return _isoFormat.format(d);
    });
  }

  /// Formats a week date range string (e.g. "27 Oct - 2 Nov 2026")
  static String formatWeekRange(List<String> weekDates) {
    if (weekDates.isEmpty) return '';
    try {
      final start = parseDate(weekDates.first);
      final end = parseDate(weekDates.last);

      if (start.year != end.year) {
        return '${_shortDisplayFormat.format(start)} ${start.year} - ${_shortDisplayFormat.format(end)} ${end.year}';
      }
      if (start.month != end.month) {
        return '${_shortDisplayFormat.format(start)} - ${_shortDisplayFormat.format(end)} ${end.year}';
      }
      return '${start.day} - ${end.day} ${_monthYearFormat.format(end)}';
    } catch (_) {
      return '${weekDates.first} to ${weekDates.last}';
    }
  }

  /// Checks if the week containing [anchorDate] is strictly after the current week
  static bool isFutureWeek(DateTime anchorDate, String weekStart, [DateTime? now]) {
    final currentDates = getWeekDates(now ?? DateTime.now(), weekStart);
    final targetDates = getWeekDates(anchorDate, weekStart);
    final currentStart = parseDate(currentDates.first);
    final targetStart = parseDate(targetDates.first);
    return targetStart.isAfter(currentStart);
  }

  /// Returns previous week anchor date
  static DateTime getPreviousWeekAnchor(DateTime anchorDate) {
    return anchorDate.subtract(const Duration(days: 7));
  }

  /// Returns next week anchor date
  static DateTime getNextWeekAnchor(DateTime anchorDate) {
    return anchorDate.add(const Duration(days: 7));
  }
}
