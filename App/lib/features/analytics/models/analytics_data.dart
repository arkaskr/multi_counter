import '../../../shared/models/daily_record.dart';

enum AnalyticsRangeType {
  weekly,
  fifteenDays,
  monthly,
  custom,
}

class DailyAnalyticsItem {
  final String date;
  final int count;
  final double amount;
  final bool isOverride;

  const DailyAnalyticsItem({
    required this.date,
    required this.count,
    required this.amount,
    required this.isOverride,
  });
}

class AnalyticsReport {
  final AnalyticsRangeType rangeType;
  final String title;
  final String startDate;
  final String endDate;
  final double totalSpending;
  final int totalMeals;
  final int activeDays;
  final int totalDaysInRange;
  final double averageSpendingPerDay;
  final double averageMealsPerDay;
  final int completedDays;
  final List<DailyAnalyticsItem> dailyItems;

  const AnalyticsReport({
    required this.rangeType,
    required this.title,
    required this.startDate,
    required this.endDate,
    required this.totalSpending,
    required this.totalMeals,
    required this.activeDays,
    required this.totalDaysInRange,
    required this.averageSpendingPerDay,
    required this.averageMealsPerDay,
    required this.completedDays,
    required this.dailyItems,
  });

  static AnalyticsReport calculate({
    required AnalyticsRangeType rangeType,
    required String title,
    required String startDate,
    required String endDate,
    required List<String> allDatesInRange,
    required Map<String, DailyRecord> recordsMap,
    required double unitAmount,
    required int dailyLimit,
  }) {
    double spending = 0.0;
    int meals = 0;
    int active = 0;
    int completed = 0;
    final items = <DailyAnalyticsItem>[];

    for (final d in allDatesInRange) {
      final rec = recordsMap[d] ?? DailyRecord.empty(d);
      final count = rec.count;
      final amount = rec.calculateAmount(unitAmount);
      final isOverride = rec.amountOverride != null;

      spending += amount;
      meals += count;
      if (count > 0) active++;
      if (dailyLimit > 0 && count >= dailyLimit) completed++;

      items.add(DailyAnalyticsItem(
        date: d,
        count: count,
        amount: amount,
        isOverride: isOverride,
      ));
    }

    final totalDays = allDatesInRange.isEmpty ? 1 : allDatesInRange.length;
    final avgSpending = totalDays > 0 ? (spending / totalDays) : 0.0;
    final avgMeals = totalDays > 0 ? (meals / totalDays) : 0.0;

    return AnalyticsReport(
      rangeType: rangeType,
      title: title,
      startDate: startDate,
      endDate: endDate,
      totalSpending: spending,
      totalMeals: meals,
      activeDays: active,
      totalDaysInRange: allDatesInRange.length,
      averageSpendingPerDay: avgSpending,
      averageMealsPerDay: avgMeals,
      completedDays: completed,
      dailyItems: items,
    );
  }
}

