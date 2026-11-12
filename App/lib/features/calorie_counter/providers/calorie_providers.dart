import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/providers/auth_providers.dart';
import '../models/diet_plan_models.dart';
import '../models/food_models.dart';
import '../models/food_request_model.dart';
import '../models/meal_log_model.dart';
import '../models/nutrition_goal_models.dart';
import '../services/calorie_sync_service.dart';
import '../services/diet_planner_service.dart';
import '../services/food_catalogue_service.dart';
import '../services/meal_log_service.dart';
import '../services/nutrition_analytics_service.dart';
import '../services/nutrition_goal_service.dart';

final foodCatalogueServiceProvider =
    Provider<FoodCatalogueService>((ref) => FoodCatalogueService.instance);

final mealLogServiceProvider =
    Provider<MealLogService>((ref) => MealLogService.instance);

final nutritionGoalServiceProvider =
    Provider<NutritionGoalService>((ref) => NutritionGoalService.instance);

final nutritionAnalyticsServiceProvider = Provider<NutritionAnalyticsService>(
    (ref) => NutritionAnalyticsService.instance);

final dietPlannerServiceProvider =
    Provider<DietPlannerService>((ref) => DietPlannerService.instance);

final calorieSyncServiceProvider =
    Provider<CalorieSyncService>((ref) => CalorieSyncService.instance);

final nutritionUserIdProvider = Provider<String>((ref) {
  final auth = ref.watch(authStateProvider);
  return auth.user?.id ?? 'local_guest';
});

class SelectedCalorieDateNotifier extends Notifier<DateTime> {
  @override
  DateTime build() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  void setDate(DateTime date) {
    state = DateTime(date.year, date.month, date.day);
  }

  void shiftDays(int delta) {
    state = state.add(Duration(days: delta));
  }

  void resetToday() {
    final now = DateTime.now();
    state = DateTime(now.year, now.month, now.day);
  }
}

final selectedCalorieDateProvider =
    NotifierProvider<SelectedCalorieDateNotifier, DateTime>(
        SelectedCalorieDateNotifier.new);

class DailyDashboardState {
  final String dateString;
  final DailyNutritionTotals totals;
  final DailyNutritionGoal goal;
  final List<FoodItem> recentFoods;
  final UserNutritionPreferences preferences;

  const DailyDashboardState({
    required this.dateString,
    required this.totals,
    required this.goal,
    required this.recentFoods,
    required this.preferences,
  });
}

class DailyDashboardNotifier extends AsyncNotifier<DailyDashboardState> {
  @override
  Future<DailyDashboardState> build() async {
    final userId = ref.watch(nutritionUserIdProvider);
    final selectedDate = ref.watch(selectedCalorieDateProvider);
    final dateStr = NutritionAnalyticsService.formatDate(selectedDate);

    await ref.read(foodCatalogueServiceProvider).ensureSeeded();
    return _load(userId, dateStr);
  }

  Future<DailyDashboardState> _load(String userId, String dateStr) async {
    final mealService = ref.read(mealLogServiceProvider);
    final goalService = ref.read(nutritionGoalServiceProvider);

    final results = await Future.wait([
      mealService.getDailySummary(userId, dateStr),
      goalService.getDailyGoalForDate(userId, dateStr),
      mealService.getRecentFoods(userId, limit: 8),
      goalService.getPreferences(userId),
    ]);

    return DailyDashboardState(
      dateString: dateStr,
      totals: results[0] as DailyNutritionTotals,
      goal: results[1] as DailyNutritionGoal,
      recentFoods: results[2] as List<FoodItem>,
      preferences: results[3] as UserNutritionPreferences,
    );
  }

  Future<void> refresh() async {
    final userId = ref.read(nutritionUserIdProvider);
    final dateStr =
        NutritionAnalyticsService.formatDate(ref.read(selectedCalorieDateProvider));
    state = AsyncData(await _load(userId, dateStr));
  }

  void _triggerBackgroundSync() {
    unawaited(
      ref.read(calorieSyncServiceProvider).syncNow().then((res) {
        if (res.success && res.downloadedCount > 0) {
          refresh();
        }
      }),
    );
  }

  Future<void> logFood({
    required MealCategory mealCategory,
    required String foodId,
    required String servingId,
    double servingCount = 1.0,
    String notes = '',
  }) async {
    final userId = ref.read(nutritionUserIdProvider);
    final dateStr =
        NutritionAnalyticsService.formatDate(ref.read(selectedCalorieDateProvider));
    await ref.read(mealLogServiceProvider).logFood(
          userId: userId,
          date: dateStr,
          mealCategory: mealCategory,
          foodId: foodId,
          servingId: servingId,
          servingCount: servingCount,
          notes: notes,
        );
    await refresh();
    ref.invalidate(nutritionAnalyticsProvider);
    _triggerBackgroundSync();
  }

  Future<void> logMultipleFoods({
    required MealCategory mealCategory,
    required List<MealLogInput> items,
  }) async {
    final userId = ref.read(nutritionUserIdProvider);
    final dateStr =
        NutritionAnalyticsService.formatDate(ref.read(selectedCalorieDateProvider));
    await ref.read(mealLogServiceProvider).logMultipleFoods(
          userId: userId,
          date: dateStr,
          mealCategory: mealCategory,
          items: items,
        );
    await refresh();
    ref.invalidate(nutritionAnalyticsProvider);
    _triggerBackgroundSync();
  }

  Future<void> updateLogEntry({
    required String logId,
    MealCategory? mealCategory,
    String? servingId,
    double? servingCount,
    String? notes,
  }) async {
    final userId = ref.read(nutritionUserIdProvider);
    await ref.read(mealLogServiceProvider).updateLogEntry(
          userId: userId,
          logId: logId,
          mealCategory: mealCategory,
          servingId: servingId,
          servingCount: servingCount,
          notes: notes,
        );
    await refresh();
    ref.invalidate(nutritionAnalyticsProvider);
    _triggerBackgroundSync();
  }

  Future<void> deleteLogEntry(String logId) async {
    final userId = ref.read(nutritionUserIdProvider);
    await ref.read(mealLogServiceProvider).deleteLogEntry(
          userId: userId,
          logId: logId,
        );
    await refresh();
    ref.invalidate(nutritionAnalyticsProvider);
    _triggerBackgroundSync();
  }

  Future<int> duplicateMeal({
    required String fromDate,
    required MealCategory fromMeal,
    required MealCategory toMeal,
  }) async {
    final userId = ref.read(nutritionUserIdProvider);
    final dateStr =
        NutritionAnalyticsService.formatDate(ref.read(selectedCalorieDateProvider));
    final cloned = await ref.read(mealLogServiceProvider).duplicateMeal(
          userId: userId,
          fromDate: fromDate,
          fromMeal: fromMeal,
          toDate: dateStr,
          toMeal: toMeal,
        );
    await refresh();
    ref.invalidate(nutritionAnalyticsProvider);
    _triggerBackgroundSync();
    return cloned.length;
  }

  Future<void> setHydration(int amountMl) async {
    final userId = ref.read(nutritionUserIdProvider);
    final dateStr =
        NutritionAnalyticsService.formatDate(ref.read(selectedCalorieDateProvider));
    await ref
        .read(mealLogServiceProvider)
        .setHydrationForDate(userId, dateStr, amountMl);
    await refresh();
    _triggerBackgroundSync();
  }

  Future<void> saveDailyGoal({
    required String effectiveFromDate,
    required double calories,
    required double protein,
    required double carbs,
    required double fat,
    required double fibre,
    int? hydrationMl,
    String sourceMode = 'manual',
    String notes = '',
  }) async {
    final userId = ref.read(nutritionUserIdProvider);
    await ref.read(nutritionGoalServiceProvider).saveDailyGoal(
          userId: userId,
          effectiveFromDate: effectiveFromDate,
          calories: calories,
          protein: protein,
          carbs: carbs,
          fat: fat,
          fibre: fibre,
          hydrationMl: hydrationMl,
          sourceMode: sourceMode,
          notes: notes,
        );
    await refresh();
    ref.invalidate(nutritionAnalyticsProvider);
    _triggerBackgroundSync();
  }

  Future<void> savePreferences(UserNutritionPreferences prefs) async {
    await ref.read(nutritionGoalServiceProvider).savePreferences(prefs);
    await refresh();
    _triggerBackgroundSync();
  }

  Future<NutritionSyncResult> manualSync() async {
    final result = await ref.read(calorieSyncServiceProvider).syncNow();
    if (result.success) {
      await refresh();
      ref.invalidate(nutritionAnalyticsProvider);
      ref.invalidate(savedDietPlansProvider);
      ref.invalidate(foodRequestsProvider);
    }
    return result;
  }
}

final dailyDashboardProvider =
    AsyncNotifierProvider<DailyDashboardNotifier, DailyDashboardState>(
        DailyDashboardNotifier.new);

// Analytics Month Selector + Provider
class SelectedAnalyticsMonthNotifier extends Notifier<DateTime> {
  @override
  DateTime build() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, 1);
  }

  void shiftMonth(int delta) {
    state = DateTime(state.year, state.month + delta, 1);
  }

  void setMonth(int year, int month) {
    state = DateTime(year, month, 1);
  }
}

final selectedAnalyticsMonthProvider =
    NotifierProvider<SelectedAnalyticsMonthNotifier, DateTime>(
        SelectedAnalyticsMonthNotifier.new);

class AnalyticsBundle {
  final PeriodNutritionAnalytics weekly;
  final PeriodNutritionAnalytics monthly;
  final MonthlyNutritionGoal? monthlyGoal;
  final String yearMonth;

  const AnalyticsBundle({
    required this.weekly,
    required this.monthly,
    required this.monthlyGoal,
    required this.yearMonth,
  });
}

final nutritionAnalyticsProvider =
    FutureProvider<AnalyticsBundle>((ref) async {
  final userId = ref.watch(nutritionUserIdProvider);
  final selectedMonth = ref.watch(selectedAnalyticsMonthProvider);
  final analyticsService = ref.read(nutritionAnalyticsServiceProvider);
  final goalService = ref.read(nutritionGoalServiceProvider);

  final ym =
      '${selectedMonth.year.toString().padLeft(4, '0')}-${selectedMonth.month.toString().padLeft(2, '0')}';

  final weekly = await analyticsService.getWeeklyAnalytics(
      userId, DateTime.now());
  final monthly = await analyticsService.getMonthlyAnalytics(
      userId, selectedMonth.year, selectedMonth.month);
  final monthlyGoal = await goalService.getMonthlyGoal(userId, ym);

  return AnalyticsBundle(
    weekly: weekly,
    monthly: monthly,
    monthlyGoal: monthlyGoal,
    yearMonth: ym,
  );
});

final savedDietPlansProvider = FutureProvider<List<DietPlan>>((ref) async {
  final userId = ref.watch(nutritionUserIdProvider);
  return ref.read(dietPlannerServiceProvider).getSavedPlans(userId);
});

final foodRequestsProvider = FutureProvider<List<FoodRequest>>((ref) async {
  final userId = ref.watch(nutritionUserIdProvider);
  return ref.read(foodCatalogueServiceProvider).getFoodRequests(userId);
});

final foodCategoriesProvider =
    FutureProvider<List<FoodCategory>>((ref) async {
  return ref.read(foodCatalogueServiceProvider).getCategories();
});

