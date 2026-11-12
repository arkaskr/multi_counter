import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:daily_counter/core/constants/database_constants.dart';
import 'package:daily_counter/core/database/database_helper.dart';
import 'package:daily_counter/core/database/database_schema.dart';
import 'package:daily_counter/core/database/nutrition_database_schema.dart';
import 'package:daily_counter/features/calorie_counter/models/food_models.dart';
import 'package:daily_counter/features/calorie_counter/models/meal_log_model.dart';
import 'package:daily_counter/features/calorie_counter/models/nutrition_goal_models.dart';
import 'package:daily_counter/features/calorie_counter/services/food_catalogue_service.dart';
import 'package:daily_counter/features/calorie_counter/services/meal_log_service.dart';
import 'package:daily_counter/features/calorie_counter/services/nutrition_analytics_service.dart';
import 'package:daily_counter/features/calorie_counter/services/nutrition_goal_service.dart';

void main() {
  sqfliteFfiInit();

  late Database db;
  late DatabaseHelper dbHelper;
  late FoodCatalogueService catalogueService;
  late MealLogService mealLogService;
  late NutritionGoalService goalService;
  late NutritionAnalyticsService analyticsService;
  late String catalogueJson;

  setUpAll(() {
    catalogueJson = File('assets/data/food_catalogue.json').readAsStringSync();
  });

  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: DatabaseConstants.databaseVersion,
        onCreate: (db, version) async {
          await db.execute(DatabaseSchema.createDailyRecordsTable);
          await db.execute(DatabaseSchema.createDailyRecordsDateIndex);
          await db.execute(DatabaseSchema.createAppSettingsTable);
          await NutritionDatabaseSchema.createTables(db);
        },
      ),
    );
    dbHelper = DatabaseHelper.withDatabase(db);
    catalogueService = FoodCatalogueService.createForTesting(dbHelper);
    await catalogueService.ensureSeeded(jsonOverride: catalogueJson);
    mealLogService =
        MealLogService.createForTesting(dbHelper, catalogueService);
    goalService = NutritionGoalService.createForTesting(dbHelper);
    analyticsService =
        NutritionAnalyticsService.createForTesting(mealLogService, goalService);
  });

  tearDown(() async {
    await db.close();
    DatabaseHelper.resetForTesting();
  });

  test('meal logging CRUD, multi-food add, edit, duplicate & soft delete', () async {
    const uid = 'user_1';
    const date = '2026-11-10';

    // Log 2 foods to breakfast
    final logs = await mealLogService.logMultipleFoods(
      userId: uid,
      date: date,
      mealCategory: MealCategory.breakfast,
      items: const [
        MealLogInput(foodId: 'roti_plain', servingId: 'med_roti', servingCount: 2),
        MealLogInput(foodId: 'dal_plain', servingId: 'bowl_dal', servingCount: 1),
      ],
    );
    expect(logs.length, 2);

    var summary = await mealLogService.getDailySummary(uid, date);
    expect(summary.entryCount, 2);
    expect(summary.hasRecords, isTrue);
    final initialCalories = summary.calories;

    // Edit quantity & category on first log
    await mealLogService.updateLogEntry(
      userId: uid,
      logId: logs.first.id,
      mealCategory: MealCategory.lunch,
      servingCount: 3,
    );
    summary = await mealLogService.getDailySummary(uid, date);
    expect(summary.calories, greaterThan(initialCalories));
    expect(summary.logsByMeal[MealCategory.lunch]?.length, 1);

    // Duplicate breakfast to 2026-11-11 dinner
    final cloned = await mealLogService.duplicateMeal(
      userId: uid,
      fromDate: date,
      fromMeal: MealCategory.breakfast,
      toDate: '2026-11-11',
      toMeal: MealCategory.dinner,
    );
    expect(cloned.length, 1);
    final nextDay = await mealLogService.getDailySummary(uid, '2026-11-11');
    expect(nextDay.logsByMeal[MealCategory.dinner]?.length, 1);

    // Soft delete leaves tombstone syncable while hiding from summaries
    await mealLogService.deleteLogEntry(userId: uid, logId: logs.last.id);
    summary = await mealLogService.getDailySummary(uid, date);
    expect(summary.entryCount, 1);

    // Verify recent foods returns distinct foods
    final recents = await mealLogService.getRecentFoods(uid);
    expect(recents.isNotEmpty, isTrue);
  });

  test('historical meal snapshot remains unchanged when food catalogue is updated', () async {
    const uid = 'user_1';
    const date = '2026-11-05';

    final logged = await mealLogService.logFood(
      userId: uid,
      date: date,
      mealCategory: MealCategory.lunch,
      foodId: 'roti_plain',
      servingId: 'med_roti',
      servingCount: 2,
    );
    final savedCalories = logged.calories;

    // Mutate catalogue nutrition directly in SQLite (simulating future catalogue revision)
    await db.update(
      NutritionDatabaseSchema.tableFoodNutrition,
      {'calories': 999.0},
      where: 'food_id = ?',
      whereArgs: ['roti_plain'],
    );

    final summaryAfterCatalogueUpdate =
        await mealLogService.getDailySummary(uid, date);
    expect(summaryAfterCatalogueUpdate.calories, savedCalories);
    expect(summaryAfterCatalogueUpdate.calories, isNot(closeTo(699.3, 1)));
  });

  test('distinguishes days with no records from days with explicit 0 kcal logs', () async {
    const uid = 'user_1';

    final emptySummary = await mealLogService.getDailySummary(uid, '2026-11-01');
    expect(emptySummary.hasRecords, isFalse);
    expect(emptySummary.hasRecordedZeroCalories, isFalse);

    const zeroCalVerified = FoodItem(
      id: 'water_plain_verified',
      name: 'Plain Drinking Water',
      commonNames: 'water',
      categoryId: 'beverages',
      illustrationId: 'coconut_water',
      preparationState: 'Plain water',
      dietaryTags: ['vegetarian', 'vegan'],
      allergenTags: [],
      sourceName: 'USDA FoodData Central',
      sourceReference: 'USDA FDC 173647 Water, tap',
      sourceLicense: 'USDA Public Domain (CC0)',
      isVerified: true,
      isComplete: true,
      verificationNotes: 'Zero calories',
      catalogueVersion: 1,
      nutritionPer100g: FoodNutrition.zero,
      servings: [
        FoodServing(
          id: '1_glass',
          foodId: 'water_plain_verified',
          label: '1 glass (250 ml)',
          unitType: 'ml',
          gramsPerUnit: 250,
          isDefault: true,
          sortOrder: 1,
        ),
      ],
    );
    await catalogueService.insertCustomFoodRecordForTesting(zeroCalVerified);

    await mealLogService.logFood(
      userId: uid,
      date: '2026-11-02',
      mealCategory: MealCategory.morningSnack,
      foodId: 'water_plain_verified',
      servingId: '1_glass',
      servingCount: 1,
    );
    final zeroDay = await mealLogService.getDailySummary(uid, '2026-11-02');
    expect(zeroDay.hasRecords, isTrue);
    expect(zeroDay.calories, 0.0);
    expect(zeroDay.hasRecordedZeroCalories, isTrue);
  });

  test('daily goals preserve history and monthly goals remain independent including leap years', () async {
    const uid = 'user_1';

    await goalService.saveDailyGoal(
      userId: uid,
      effectiveFromDate: '2026-11-01',
      calories: 2000,
      protein: 75,
      carbs: 250,
      fat: 65,
      fibre: 30,
    );
    await goalService.saveDailyGoal(
      userId: uid,
      effectiveFromDate: '2026-11-10',
      calories: 2450,
      protein: 110,
      carbs: 300,
      fat: 75,
      fibre: 35,
    );

    final nov05Goal = await goalService.getDailyGoalForDate(uid, '2026-11-05');
    final nov12Goal = await goalService.getDailyGoalForDate(uid, '2026-11-12');
    expect(nov05Goal.calories, 2000);
    expect(nov12Goal.calories, 2450);

    // Leap year calendar lengths
    expect(MonthlyNutritionGoal.daysInCalendarMonth(2024, 2), 29);
    expect(MonthlyNutritionGoal.daysInCalendarMonth(2026, 2), 28);
    expect(MonthlyNutritionGoal.daysInCalendarMonth(2026, 4), 30);
    expect(MonthlyNutritionGoal.daysInCalendarMonth(2026, 12), 31);

    // Independent monthly goal NOT forced to daily * 30
    await goalService.saveMonthlyGoal(
      userId: uid,
      yearMonth: '2024-02',
      totalCalories: 55000,
    );
    final febGoal = await goalService.getMonthlyGoal(uid, '2024-02');
    expect(febGoal!.totalCalories, 55000);
    expect(febGoal.totalCalories, isNot(2450 * 30));

    // Safe floor check in guided goal calculator
    final safeEstimate = NutritionGoalCalculator.suggestTargets(
      age: 35,
      sex: 'female',
      heightCm: 145,
      weightKg: 42,
      activityLevel: 'sedentary',
      fitnessObjective: 'lose_weight',
    );
    expect(safeEstimate.calories, greaterThanOrEqualTo(1200));
    expect(safeEstimate.safetyFloorApplied, isTrue);
  });

  test('analytics computes real logged days without inventing missing days', () async {
    const uid = 'user_1';
    await goalService.saveDailyGoal(
      userId: uid,
      effectiveFromDate: '2026-11-01',
      calories: 1000,
      protein: 40,
      carbs: 130,
      fat: 30,
      fibre: 15,
    );
    await goalService.saveMonthlyGoal(
      userId: uid,
      yearMonth: '2026-11',
      totalCalories: 19200,
    );

    // Log 2 days in Nov 2026
    await mealLogService.logFood(
      userId: uid,
      date: '2026-11-05',
      mealCategory: MealCategory.lunch,
      foodId: 'roti_plain',
      servingId: 'g_100',
      servingCount: 4, // 960 kcal (within target of 1000!)
    );
    await mealLogService.logFood(
      userId: uid,
      date: '2026-11-06',
      mealCategory: MealCategory.lunch,
      foodId: 'roti_plain',
      servingId: 'g_100',
      servingCount: 4, // 960 kcal
    );

    final monthly = await analyticsService.getMonthlyAnalytics(uid, 2026, 11);
    expect(monthly.totalCalendarDays, 30);
    expect(monthly.daysLogged, 2);
    expect(monthly.daysWithinTarget, 2);
    expect(monthly.totalCalories, closeTo(1920, 1.0));
    expect(monthly.averageDailyCalories, closeTo(960, 0.5));
    expect(monthly.monthlyProgressPercent, closeTo(10.0, 0.2));
  });
}
