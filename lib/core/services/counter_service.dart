import '../database/database_helper.dart';
import '../utils/date_utils.dart';
import '../../shared/models/app_settings.dart';
import '../../shared/models/daily_record.dart';
import '../../shared/models/weekly_summary.dart';
import 'widget_service.dart';

class CounterResult {
  final bool success;
  final DailyRecord record;
  final String? message;

  const CounterResult({
    required this.success,
    required this.record,
    this.message,
  });
}

class CounterService {
  final DatabaseHelper _dbHelper;
  final WidgetService _widgetService;

  CounterService({
    DatabaseHelper? dbHelper,
    WidgetService? widgetService,
  })  : _dbHelper = dbHelper ?? DatabaseHelper.instance,
        _widgetService = widgetService ?? WidgetService.instance;

  /// Gets the record for a given date, or empty record if none exists.
  Future<DailyRecord> getRecord(String date) async {
    return await _dbHelper.getRecord(date);
  }

  /// Gets today's record.
  Future<DailyRecord> getTodayRecord() async {
    final today = AppDateUtils.getTodayDateString();
    return await getRecord(today);
  }

  /// Increments today's counter transactionally.
  /// Enforces daily limit. Refreshes the home-screen widget on success.
  Future<CounterResult> incrementToday() async {
    final today = AppDateUtils.getTodayDateString();
    return await incrementDate(today);
  }

  /// Increments counter for a specific date transactionally.
  Future<CounterResult> incrementDate(String date) async {
    final record = await _dbHelper.incrementDailyCount(date);
    if (record == null) {
      final current = await _dbHelper.getRecord(date);
      return CounterResult(
        success: false,
        record: current,
        message: 'Daily limit reached!',
      );
    }

    if (AppDateUtils.isToday(date)) {
      await _widgetService.notifyWidgetUpdate();
    }

    return CounterResult(
      success: true,
      record: record,
    );
  }

  /// Decrements today's counter. Cannot go below 0.
  Future<CounterResult> decrementToday() async {
    final today = AppDateUtils.getTodayDateString();
    return await decrementDate(today);
  }

  /// Decrements counter for a specific date.
  Future<CounterResult> decrementDate(String date) async {
    final record = await _dbHelper.decrementDailyCount(date);

    if (AppDateUtils.isToday(date)) {
      await _widgetService.notifyWidgetUpdate();
    }

    return CounterResult(
      success: true,
      record: record,
    );
  }

  /// Sets count manually for a date, validating that 0 <= count <= dailyLimit.
  Future<CounterResult> setCount(String date, int count, int dailyLimit) async {
    if (count < 0) {
      final current = await _dbHelper.getRecord(date);
      return CounterResult(
        success: false,
        record: current,
        message: 'Count cannot be negative',
      );
    }
    if (count > dailyLimit) {
      final current = await _dbHelper.getRecord(date);
      return CounterResult(
        success: false,
        record: current,
        message: 'Count cannot exceed daily limit of $dailyLimit',
      );
    }

    final current = await _dbHelper.getRecord(date);
    final updated = current.copyWith(
      count: count,
      updatedAt: DateTime.now().toIso8601String(),
    );

    await _dbHelper.saveRecord(updated);

    if (AppDateUtils.isToday(date)) {
      await _widgetService.notifyWidgetUpdate();
    }

    return CounterResult(
      success: true,
      record: updated,
    );
  }

  /// Sets or clears custom amount override for a date.
  Future<DailyRecord> setAmountOverride(String date, double? override) async {
    final current = await _dbHelper.getRecord(date);
    final updated = current.copyWith(
      amountOverride: override,
      clearAmountOverride: override == null,
      updatedAt: DateTime.now().toIso8601String(),
    );

    await _dbHelper.saveRecord(updated);

    if (AppDateUtils.isToday(date)) {
      await _widgetService.notifyWidgetUpdate();
    }

    return updated;
  }

  /// Resets a single day's count and override.
  Future<void> resetDay(String date) async {
    await _dbHelper.resetDay(date);
    if (AppDateUtils.isToday(date)) {
      await _widgetService.notifyWidgetUpdate();
    }
  }

  /// Resets all days in a given week.
  Future<void> resetWeek(List<String> weekDates) async {
    await _dbHelper.resetDays(weekDates);
    await _widgetService.notifyWidgetUpdate();
  }

  /// Resets all recorded daily data.
  Future<void> resetAllData() async {
    await _dbHelper.resetAllDailyRecords();
    await _widgetService.notifyWidgetUpdate();
  }

  /// Gets weekly summary for the given week dates.
  Future<WeeklySummary> getWeekSummary(
    List<String> weekDates,
    AppSettings settings,
  ) async {
    final records = await _dbHelper.getRecordsForDates(weekDates);
    return WeeklySummary.calculate(
      weekDates: weekDates,
      records: records,
      unitAmount: settings.unitAmount,
      dailyLimit: settings.dailyLimit,
    );
  }
}
