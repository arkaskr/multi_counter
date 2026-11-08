import 'daily_record.dart';

class WeeklySummary {
  final List<String> weekDates;
  final Map<String, DailyRecord> records;
  final int totalCount;
  final double totalAmount;
  final int completedDays;
  final double averageDailyCount;

  const WeeklySummary({
    required this.weekDates,
    required this.records,
    required this.totalCount,
    required this.totalAmount,
    required this.completedDays,
    required this.averageDailyCount,
  });

  factory WeeklySummary.calculate({
    required List<String> weekDates,
    required Map<String, DailyRecord> records,
    required double unitAmount,
    required int dailyLimit,
  }) {
    int totalCount = 0;
    double totalAmount = 0.0;
    int completedDays = 0;

    for (final date in weekDates) {
      final record = records[date] ?? DailyRecord.empty(date);
      totalCount += record.count;
      totalAmount += record.calculateAmount(unitAmount);
      if (record.count >= dailyLimit && dailyLimit > 0) {
        completedDays++;
      }
    }

    final average = weekDates.isEmpty ? 0.0 : totalCount / weekDates.length;

    return WeeklySummary(
      weekDates: weekDates,
      records: records,
      totalCount: totalCount,
      totalAmount: totalAmount,
      completedDays: completedDays,
      averageDailyCount: average,
    );
  }
}
