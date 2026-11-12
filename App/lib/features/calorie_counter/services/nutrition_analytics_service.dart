import '../models/meal_log_model.dart';
import '../models/nutrition_goal_models.dart';
import 'meal_log_service.dart';
import 'nutrition_goal_service.dart';

class DailyTrendPoint {
  final String date;
  final int entryCount;
  final double calories;
  final double protein;
  final double carbs;
  final double fat;
  final double fibre;
  final double dailyTargetCalories;
  final bool withinTarget;

  const DailyTrendPoint({
    required this.date,
    required this.entryCount,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.fibre,
    required this.dailyTargetCalories,
    required this.withinTarget,
  });

  bool get hasRecords => entryCount > 0;
}

class PeriodNutritionAnalytics {
  final String periodLabel;
  final String startDate;
  final String endDate;
  final int totalCalendarDays;
  final int daysLogged;
  final int daysWithinTarget;
  final double totalCalories;
  final double totalProtein;
  final double totalCarbs;
  final double totalFat;
  final double totalFibre;
  final double averageDailyCalories;
  final double averageDailyProtein;
  final double averageDailyCarbs;
  final double averageDailyFat;
  final double averageDailyFibre;
  final double? monthlyGoalCalories;
  final double? monthlyProgressPercent;
  final double? previousPeriodAvgCalories;
  final List<DailyTrendPoint> dailyPoints;

  const PeriodNutritionAnalytics({
    required this.periodLabel,
    required this.startDate,
    required this.endDate,
    required this.totalCalendarDays,
    required this.daysLogged,
    required this.daysWithinTarget,
    required this.totalCalories,
    required this.totalProtein,
    required this.totalCarbs,
    required this.totalFat,
    required this.totalFibre,
    required this.averageDailyCalories,
    required this.averageDailyProtein,
    required this.averageDailyCarbs,
    required this.averageDailyFat,
    required this.averageDailyFibre,
    this.monthlyGoalCalories,
    this.monthlyProgressPercent,
    this.previousPeriodAvgCalories,
    required this.dailyPoints,
  });

  double get mealConsistencyPercent =>
      totalCalendarDays == 0 ? 0 : (daysLogged / totalCalendarDays) * 100.0;
}

class NutritionAnalyticsService {
  static final NutritionAnalyticsService instance =
      NutritionAnalyticsService._internal();
  NutritionAnalyticsService._internal();

  factory NutritionAnalyticsService.createForTesting(
    MealLogService mealLogService,
    NutritionGoalService goalService,
  ) =>
      NutritionAnalyticsService._withDeps(mealLogService, goalService);

  MealLogService _mealLogService = MealLogService.instance;
  NutritionGoalService _goalService = NutritionGoalService.instance;
  NutritionAnalyticsService._withDeps(this._mealLogService, this._goalService);

  static String formatDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<PeriodNutritionAnalytics> getWeeklyAnalytics(
    String userId,
    DateTime endDate,
  ) async {
    final end = DateTime(endDate.year, endDate.month, endDate.day);
    final start = end.subtract(const Duration(days: 6));
    final prevEnd = start.subtract(const Duration(days: 1));
    final prevStart = prevEnd.subtract(const Duration(days: 6));

    final current = await _computeRangeAnalytics(
      userId: userId,
      periodLabel: 'Last 7 Days',
      start: start,
      end: end,
    );
    final previous = await _computeRangeAnalytics(
      userId: userId,
      periodLabel: 'Previous 7 Days',
      start: prevStart,
      end: prevEnd,
    );

    return PeriodNutritionAnalytics(
      periodLabel: current.periodLabel,
      startDate: current.startDate,
      endDate: current.endDate,
      totalCalendarDays: current.totalCalendarDays,
      daysLogged: current.daysLogged,
      daysWithinTarget: current.daysWithinTarget,
      totalCalories: current.totalCalories,
      totalProtein: current.totalProtein,
      totalCarbs: current.totalCarbs,
      totalFat: current.totalFat,
      totalFibre: current.totalFibre,
      averageDailyCalories: current.averageDailyCalories,
      averageDailyProtein: current.averageDailyProtein,
      averageDailyCarbs: current.averageDailyCarbs,
      averageDailyFat: current.averageDailyFat,
      averageDailyFibre: current.averageDailyFibre,
      previousPeriodAvgCalories:
          previous.daysLogged > 0 ? previous.averageDailyCalories : null,
      dailyPoints: current.dailyPoints,
    );
  }

  Future<PeriodNutritionAnalytics> getMonthlyAnalytics(
    String userId,
    int year,
    int month,
  ) async {
    final yearMonth =
        '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}';
    final totalDays = MonthlyNutritionGoal.daysInCalendarMonth(year, month);
    final start = DateTime(year, month, 1);
    final end = DateTime(year, month, totalDays);

    final prevDate = month == 1 ? DateTime(year - 1, 12, 1) : DateTime(year, month - 1, 1);
    final prevDays = MonthlyNutritionGoal.daysInCalendarMonth(
        prevDate.year, prevDate.month);
    final prevEnd = DateTime(prevDate.year, prevDate.month, prevDays);

    final rangeStats = await _computeRangeAnalytics(
      userId: userId,
      periodLabel: yearMonth,
      start: start,
      end: end,
    );
    final prevStats = await _computeRangeAnalytics(
      userId: userId,
      periodLabel: 'Prev',
      start: prevDate,
      end: prevEnd,
    );

    final monthlyGoal = await _goalService.getMonthlyGoal(userId, yearMonth);
    final double? goalCalories = monthlyGoal?.totalCalories;
    final double? progressPct = goalCalories != null && goalCalories > 0
        ? (rangeStats.totalCalories / goalCalories) * 100.0
        : null;

    return PeriodNutritionAnalytics(
      periodLabel: rangeStats.periodLabel,
      startDate: rangeStats.startDate,
      endDate: rangeStats.endDate,
      totalCalendarDays: totalDays,
      daysLogged: rangeStats.daysLogged,
      daysWithinTarget: rangeStats.daysWithinTarget,
      totalCalories: rangeStats.totalCalories,
      totalProtein: rangeStats.totalProtein,
      totalCarbs: rangeStats.totalCarbs,
      totalFat: rangeStats.totalFat,
      totalFibre: rangeStats.totalFibre,
      averageDailyCalories: rangeStats.averageDailyCalories,
      averageDailyProtein: rangeStats.averageDailyProtein,
      averageDailyCarbs: rangeStats.averageDailyCarbs,
      averageDailyFat: rangeStats.averageDailyFat,
      averageDailyFibre: rangeStats.averageDailyFibre,
      monthlyGoalCalories: goalCalories,
      monthlyProgressPercent: progressPct,
      previousPeriodAvgCalories:
          prevStats.daysLogged > 0 ? prevStats.averageDailyCalories : null,
      dailyPoints: rangeStats.dailyPoints,
    );
  }

  Future<PeriodNutritionAnalytics> _computeRangeAnalytics({
    required String userId,
    required String periodLabel,
    required DateTime start,
    required DateTime end,
  }) async {
    final startStr = formatDate(start);
    final endStr = formatDate(end);
    final logs = await _mealLogService.getLogsInDateRange(
      userId,
      startDate: startStr,
      endDate: endStr,
    );
    final goalHistory = await _goalService.getAllDailyGoalsHistory(userId);
    final fallbackGoal = DailyNutritionGoal.fallbackDefault(userId);

    DailyNutritionGoal resolveGoal(String date) {
      // goalHistory is sorted DESC by effective_from_date
      for (final g in goalHistory) {
        if (g.effectiveFromDate.compareTo(date) <= 0) {
          return g;
        }
      }
      if (goalHistory.isNotEmpty) return goalHistory.last;
      return fallbackGoal;
    }

    final byDate = <String, List<FoodLog>>{};
    for (final log in logs) {
      byDate.putIfAbsent(log.date, () => <FoodLog>[]).add(log);
    }

    final totalCalendarDays = end.difference(start).inDays + 1;
    final points = <DailyTrendPoint>[];
    int daysLogged = 0;
    int daysWithinTarget = 0;
    double sumCal = 0, sumProt = 0, sumCarbs = 0, sumFat = 0, sumFibre = 0;

    for (var i = 0; i < totalCalendarDays; i++) {
      final d = start.add(Duration(days: i));
      final dateStr = formatDate(d);
      final dayLogs = byDate[dateStr] ?? const <FoodLog>[];
      final goal = resolveGoal(dateStr);

      final dayCal = dayLogs.fold(0.0, (s, l) => s + l.calories);
      final dayProt = dayLogs.fold(0.0, (s, l) => s + l.protein);
      final dayCarbs = dayLogs.fold(0.0, (s, l) => s + l.carbs);
      final dayFat = dayLogs.fold(0.0, (s, l) => s + l.fat);
      final dayFibre = dayLogs.fold(0.0, (s, l) => s + l.fibre);

      final hasRec = dayLogs.isNotEmpty;
      // Within target tolerance: logged that day and within ±10% of daily goal (or <= 105% & >= 70%)
      final within = hasRec &&
          dayCal <= goal.calories * 1.10 &&
          dayCal >= goal.calories * 0.70;

      if (hasRec) {
        daysLogged++;
        if (within) daysWithinTarget++;
        sumCal += dayCal;
        sumProt += dayProt;
        sumCarbs += dayCarbs;
        sumFat += dayFat;
        sumFibre += dayFibre;
      }

      points.add(DailyTrendPoint(
        date: dateStr,
        entryCount: dayLogs.length,
        calories: (dayCal * 10).roundToDouble() / 10,
        protein: (dayProt * 10).roundToDouble() / 10,
        carbs: (dayCarbs * 10).roundToDouble() / 10,
        fat: (dayFat * 10).roundToDouble() / 10,
        fibre: (dayFibre * 10).roundToDouble() / 10,
        dailyTargetCalories: goal.calories,
        withinTarget: within,
      ));
    }

    double avg(double total) =>
        daysLogged == 0 ? 0 : ((total / daysLogged) * 10).roundToDouble() / 10;

    return PeriodNutritionAnalytics(
      periodLabel: periodLabel,
      startDate: startStr,
      endDate: endStr,
      totalCalendarDays: totalCalendarDays,
      daysLogged: daysLogged,
      daysWithinTarget: daysWithinTarget,
      totalCalories: (sumCal * 10).roundToDouble() / 10,
      totalProtein: (sumProt * 10).roundToDouble() / 10,
      totalCarbs: (sumCarbs * 10).roundToDouble() / 10,
      totalFat: (sumFat * 10).roundToDouble() / 10,
      totalFibre: (sumFibre * 10).roundToDouble() / 10,
      averageDailyCalories: avg(sumCal),
      averageDailyProtein: avg(sumProt),
      averageDailyCarbs: avg(sumCarbs),
      averageDailyFat: avg(sumFat),
      averageDailyFibre: avg(sumFibre),
      dailyPoints: points,
    );
  }
}

