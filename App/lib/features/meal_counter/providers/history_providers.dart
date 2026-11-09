import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:daily_counter/core/utils/date_utils.dart';
import 'package:daily_counter/shared/models/weekly_summary.dart';
import 'home_providers.dart';
import 'settings_providers.dart';

class HistoryAnchorNotifier extends Notifier<DateTime> {
  @override
  DateTime build() => DateTime.now();

  void setAnchor(DateTime dt) => state = dt;
}

final historyAnchorDateProvider =
    NotifierProvider<HistoryAnchorNotifier, DateTime>(HistoryAnchorNotifier.new);

final historyWeeklySummaryProvider = FutureProvider<WeeklySummary>((ref) async {
  ref.watch(todayRecordProvider);
  final anchorDate = ref.watch(historyAnchorDateProvider);
  final settingsAsync = ref.watch(settingsNotifierProvider);
  final settings = settingsAsync.value;

  if (settings == null) {
    return WeeklySummary(
      weekDates: [],
      records: {},
      totalCount: 0,
      totalAmount: 0,
      completedDays: 0,
      averageDailyCount: 0,
    );
  }

  final service = ref.watch(counterServiceProvider);
  final weekDates = AppDateUtils.getWeekDates(anchorDate, settings.weekStart);
  return await service.getWeekSummary(weekDates, settings);
});
