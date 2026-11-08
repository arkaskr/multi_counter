import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/counter_service.dart';
import '../../../core/utils/date_utils.dart';
import '../../../shared/models/daily_record.dart';
import '../../../shared/models/weekly_summary.dart';
import '../../settings/providers/settings_providers.dart';

final counterServiceProvider = Provider<CounterService>((ref) {
  return CounterService();
});

class TodayRecordNotifier extends AsyncNotifier<DailyRecord> {
  @override
  Future<DailyRecord> build() async {
    final service = ref.watch(counterServiceProvider);
    return await service.getTodayRecord();
  }

  Future<CounterResult> increment() async {
    final service = ref.read(counterServiceProvider);
    final result = await service.incrementToday();
    if (result.success) {
      state = AsyncData(result.record);
    }
    return result;
  }

  Future<CounterResult> decrement() async {
    final service = ref.read(counterServiceProvider);
    final result = await service.decrementToday();
    if (result.success) {
      state = AsyncData(result.record);
    }
    return result;
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
  }
}

final todayRecordProvider =
    AsyncNotifierProvider<TodayRecordNotifier, DailyRecord>(TodayRecordNotifier.new);

/// Provider for the 7-day overview on the Home screen
final homeWeeklySummaryProvider = FutureProvider<WeeklySummary>((ref) async {
  // Invalidate when today's record changes or settings change
  ref.watch(todayRecordProvider);
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
  final weekDates = AppDateUtils.getWeekDates(DateTime.now(), settings.weekStart);
  return await service.getWeekSummary(weekDates, settings);
});

/// Provider for the total count of distinct days on which food was consumed
final foodDaysCountProvider = FutureProvider<int>((ref) async {
  ref.watch(todayRecordProvider);
  final service = ref.watch(counterServiceProvider);
  return await service.getFoodDaysCount();
});
