import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/utils/date_utils.dart';
import '../../../shared/models/daily_record.dart';
import '../../home/providers/home_providers.dart';
import '../../settings/providers/settings_providers.dart';
import '../models/analytics_data.dart';

class AnalyticsFilterState {
  final AnalyticsRangeType rangeType;
  final DateTime anchorDate;
  final int fifteenDayCycle; // 1 for 1-15, 2 for 16-end of month
  final DateTime? customStartDate;
  final DateTime? customEndDate;

  const AnalyticsFilterState({
    this.rangeType = AnalyticsRangeType.fifteenDays,
    required this.anchorDate,
    this.fifteenDayCycle = 1,
    this.customStartDate,
    this.customEndDate,
  });

  AnalyticsFilterState copyWith({
    AnalyticsRangeType? rangeType,
    DateTime? anchorDate,
    int? fifteenDayCycle,
    DateTime? customStartDate,
    DateTime? customEndDate,
  }) {
    return AnalyticsFilterState(
      rangeType: rangeType ?? this.rangeType,
      anchorDate: anchorDate ?? this.anchorDate,
      fifteenDayCycle: fifteenDayCycle ?? this.fifteenDayCycle,
      customStartDate: customStartDate ?? this.customStartDate,
      customEndDate: customEndDate ?? this.customEndDate,
    );
  }
}

class AnalyticsFilterNotifier extends Notifier<AnalyticsFilterState> {
  @override
  AnalyticsFilterState build() {
    final now = DateTime.now();
    final cycle = now.day <= 15 ? 1 : 2;
    return AnalyticsFilterState(
      rangeType: AnalyticsRangeType.fifteenDays,
      anchorDate: now,
      fifteenDayCycle: cycle,
      customStartDate: now.subtract(const Duration(days: 14)),
      customEndDate: now,
    );
  }

  void setRangeType(AnalyticsRangeType type) {
    state = state.copyWith(rangeType: type);
  }

  void previous() {
    switch (state.rangeType) {
      case AnalyticsRangeType.weekly:
        state = state.copyWith(
          anchorDate: state.anchorDate.subtract(const Duration(days: 7)),
        );
        break;
      case AnalyticsRangeType.fifteenDays:
        if (state.fifteenDayCycle == 2) {
          state = state.copyWith(fifteenDayCycle: 1);
        } else {
          final prevMonth = DateTime(state.anchorDate.year, state.anchorDate.month - 1, 1);
          state = state.copyWith(anchorDate: prevMonth, fifteenDayCycle: 2);
        }
        break;
      case AnalyticsRangeType.monthly:
        state = state.copyWith(
          anchorDate: DateTime(state.anchorDate.year, state.anchorDate.month - 1, 1),
        );
        break;
      case AnalyticsRangeType.custom:
        break;
    }
  }

  void next() {
    switch (state.rangeType) {
      case AnalyticsRangeType.weekly:
        state = state.copyWith(
          anchorDate: state.anchorDate.add(const Duration(days: 7)),
        );
        break;
      case AnalyticsRangeType.fifteenDays:
        if (state.fifteenDayCycle == 1) {
          state = state.copyWith(fifteenDayCycle: 2);
        } else {
          final nextMonth = DateTime(state.anchorDate.year, state.anchorDate.month + 1, 1);
          state = state.copyWith(anchorDate: nextMonth, fifteenDayCycle: 1);
        }
        break;
      case AnalyticsRangeType.monthly:
        state = state.copyWith(
          anchorDate: DateTime(state.anchorDate.year, state.anchorDate.month + 1, 1),
        );
        break;
      case AnalyticsRangeType.custom:
        break;
    }
  }

  void setCustomRange(DateTime start, DateTime end) {
    state = state.copyWith(
      rangeType: AnalyticsRangeType.custom,
      customStartDate: start,
      customEndDate: end,
    );
  }
}

final analyticsFilterProvider =
    NotifierProvider<AnalyticsFilterNotifier, AnalyticsFilterState>(
  AnalyticsFilterNotifier.new,
);

final analyticsReportProvider = FutureProvider<AnalyticsReport>((ref) async {
  // Re-run whenever today's record or settings change
  ref.watch(todayRecordProvider);
  final filter = ref.watch(analyticsFilterProvider);
  final settings = ref.watch(settingsNotifierProvider).value;
  final unitAmount = settings?.unitAmount ?? AppConstants.defaultUnitAmount;
  final dailyLimit = settings?.dailyLimit ?? AppConstants.defaultDailyLimit;
  final weekStart = settings?.weekStart ?? AppConstants.defaultWeekStart;

  final dbHelper = DatabaseHelper.instance;

  List<String> dateStrings = [];
  String title = '';
  String startStr = '';
  String endStr = '';

  switch (filter.rangeType) {
    case AnalyticsRangeType.weekly:
      final weekDates = AppDateUtils.getWeekDates(filter.anchorDate, weekStart);
      dateStrings = weekDates;
      startStr = weekDates.first;
      endStr = weekDates.last;
      title = 'Week (${AppDateUtils.formatShortDate(startStr)} - ${AppDateUtils.formatShortDate(endStr)})';
      break;

    case AnalyticsRangeType.fifteenDays:
      final year = filter.anchorDate.year;
      final month = filter.anchorDate.month;
      final monthName = _getMonthName(month);
      if (filter.fifteenDayCycle == 1) {
        startStr = '$year-${month.toString().padLeft(2, '0')}-01';
        endStr = '$year-${month.toString().padLeft(2, '0')}-15';
        title = '$monthName 1 – 15, $year';
      } else {
        final lastDay = DateTime(year, month + 1, 0).day;
        startStr = '$year-${month.toString().padLeft(2, '0')}-16';
        endStr = '$year-${month.toString().padLeft(2, '0')}-${lastDay.toString().padLeft(2, '0')}';
        title = '$monthName 16 – $lastDay, $year';
      }
      dateStrings = _generateDateRange(startStr, endStr);
      break;

    case AnalyticsRangeType.monthly:
      final year = filter.anchorDate.year;
      final month = filter.anchorDate.month;
      final lastDay = DateTime(year, month + 1, 0).day;
      final monthName = _getMonthName(month);
      startStr = '$year-${month.toString().padLeft(2, '0')}-01';
      endStr = '$year-${month.toString().padLeft(2, '0')}-${lastDay.toString().padLeft(2, '0')}';
      title = '$monthName $year';
      dateStrings = _generateDateRange(startStr, endStr);
      break;

    case AnalyticsRangeType.custom:
      final start = filter.customStartDate ?? filter.anchorDate.subtract(const Duration(days: 14));
      final end = filter.customEndDate ?? filter.anchorDate;
      startStr = AppDateUtils.formatDate(start);
      endStr = AppDateUtils.formatDate(end);
      title = '${AppDateUtils.formatShortDate(startStr)} - ${AppDateUtils.formatShortDate(endStr)}';
      dateStrings = _generateDateRange(startStr, endStr);
      break;
  }

  // Fetch records for dates
  final records = await dbHelper.getRecordsBetween(startStr, endStr);
  final map = <String, DailyRecord>{};
  for (final r in records) {
    map[r.date] = r;
  }

  return AnalyticsReport.calculate(
    rangeType: filter.rangeType,
    title: title,
    startDate: startStr,
    endDate: endStr,
    allDatesInRange: dateStrings,
    recordsMap: map,
    unitAmount: unitAmount,
    dailyLimit: dailyLimit,
  );
});

List<String> _generateDateRange(String startStr, String endStr) {
  final start = DateTime.parse(startStr);
  final end = DateTime.parse(endStr);
  final dates = <String>[];
  var curr = start;
  while (!curr.isAfter(end)) {
    dates.add(AppDateUtils.formatDate(curr));
    curr = curr.add(const Duration(days: 1));
  }
  return dates;
}

String _getMonthName(int month) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];
  return months[(month - 1).clamp(0, 11)];
}

