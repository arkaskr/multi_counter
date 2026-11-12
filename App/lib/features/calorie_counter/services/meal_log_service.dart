import 'package:sqflite/sqflite.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/database/nutrition_database_schema.dart';
import '../../../core/utils/uuid_utils.dart';
import '../models/food_models.dart';
import '../models/meal_log_model.dart';
import 'food_catalogue_service.dart';

class MealLogInput {
  final String foodId;
  final String servingId;
  final double servingCount;
  final String notes;

  const MealLogInput({
    required this.foodId,
    required this.servingId,
    this.servingCount = 1.0,
    this.notes = '',
  });
}

class MealLogService {
  static final MealLogService instance = MealLogService._internal();
  MealLogService._internal();

  factory MealLogService.createForTesting(
    DatabaseHelper dbHelper,
    FoodCatalogueService catalogueService,
  ) =>
      MealLogService._withDeps(dbHelper, catalogueService);

  DatabaseHelper _dbHelper = DatabaseHelper.instance;
  FoodCatalogueService _catalogueService = FoodCatalogueService.instance;
  MealLogService._withDeps(this._dbHelper, this._catalogueService);

  Future<Database> _db() async {
    final db = await _dbHelper.database;
    await NutritionDatabaseSchema.createTables(db);
    return db;
  }

  Future<FoodLog> logFood({
    required String userId,
    required String date, // YYYY-MM-DD
    required MealCategory mealCategory,
    required String foodId,
    required String servingId,
    double servingCount = 1.0,
    String notes = '',
  }) async {
    if (servingCount <= 0) {
      throw ArgumentError.value(servingCount, 'servingCount', 'Must be > 0');
    }
    final food = await _catalogueService.assertFoodLoggable(
      foodId,
      userId: userId,
    );
    final serving = _resolveServing(food, servingId);
    final calc = NutritionCalculator.calculateForServing(
      per100g: food.nutritionPer100g,
      serving: serving,
      servingCount: servingCount,
    );

    final now = DateTime.now().toIso8601String();
    final log = FoodLog(
      id: UuidUtils.v4(),
      userId: userId,
      date: date,
      mealCategory: mealCategory,
      foodId: food.id,
      foodNameSnapshot: food.name,
      preparationSnapshot: food.preparationState,
      illustrationSnapshot: food.illustrationId,
      servingId: serving.id,
      servingLabelSnapshot: serving.label,
      servingCount: servingCount,
      gramsPerUnit: serving.gramsPerUnit,
      totalGrams: calc.totalGrams,
      calories: calc.calories,
      protein: calc.protein,
      carbs: calc.carbs,
      fat: calc.fat,
      fibre: calc.fibre,
      sugar: calc.sugar,
      sodiumMg: calc.sodiumMg,
      saturatedFat: calc.saturatedFat,
      potassiumMg: calc.potassiumMg,
      calciumMg: calc.calciumMg,
      ironMg: calc.ironMg,
      vitaminCMg: calc.vitaminCMg,
      sourceSnapshot: food.sourceName,
      loggedAt: now,
      updatedAt: now,
      syncStatus: 'pending',
      isDeleted: false,
      notes: notes,
    );

    final db = await _db();
    await db.insert(
      NutritionDatabaseSchema.tableFoodLogs,
      log.toDbMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return log;
  }

  Future<List<FoodLog>> logMultipleFoods({
    required String userId,
    required String date,
    required MealCategory mealCategory,
    required List<MealLogInput> items,
  }) async {
    if (items.isEmpty) return const [];
    final created = <FoodLog>[];
    for (final item in items) {
      final log = await logFood(
        userId: userId,
        date: date,
        mealCategory: mealCategory,
        foodId: item.foodId,
        servingId: item.servingId,
        servingCount: item.servingCount,
        notes: item.notes,
      );
      created.add(log);
    }
    return created;
  }

  Future<FoodLog?> getLogById(String userId, String logId) async {
    final db = await _db();
    final rows = await db.query(
      NutritionDatabaseSchema.tableFoodLogs,
      where: 'id = ? AND user_id = ? AND is_deleted = 0',
      whereArgs: [logId, userId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return FoodLog.fromDbMap(rows.first);
  }

  Future<FoodLog> updateLogEntry({
    required String userId,
    required String logId,
    MealCategory? mealCategory,
    String? servingId,
    double? servingCount,
    String? notes,
  }) async {
    final existing = await getLogById(userId, logId);
    if (existing == null) {
      throw StateError('Log entry "$logId" not found.');
    }

    final targetServingId = servingId ?? existing.servingId;
    final targetCount = servingCount ?? existing.servingCount;
    if (targetCount <= 0) {
      throw ArgumentError.value(targetCount, 'servingCount', 'Must be > 0');
    }

    String newServingLabel = existing.servingLabelSnapshot;
    double newGramsPerUnit = existing.gramsPerUnit;
    double newTotalGrams = existing.totalGrams;
    double newCal = existing.calories;
    double newProt = existing.protein;
    double newCarbs = existing.carbs;
    double newFat = existing.fat;
    double newFibre = existing.fibre;
    double? newSugar = existing.sugar;
    double? newSodium = existing.sodiumMg;
    double? newSatFat = existing.saturatedFat;
    double? newPot = existing.potassiumMg;
    double? newCalc = existing.calciumMg;
    double? newIron = existing.ironMg;
    double? newVitC = existing.vitaminCMg;

    final servingChanged =
        targetServingId != existing.servingId ||
        targetCount != existing.servingCount;

    if (servingChanged) {
      if (targetServingId == existing.servingId && existing.totalGrams > 0) {
        // Scale proportionally from existing snapshot to preserve historical accuracy
        final ratio = (targetCount * existing.gramsPerUnit) / existing.totalGrams;
        double r1(double v) => (v * 10).roundToDouble() / 10;
        double? scaleOpt(double? v) =>
            v == null ? null : ((v * ratio * 100).roundToDouble() / 100);

        newTotalGrams = r1(targetCount * existing.gramsPerUnit);
        newCal = r1(existing.calories * ratio);
        newProt = r1(existing.protein * ratio);
        newCarbs = r1(existing.carbs * ratio);
        newFat = r1(existing.fat * ratio);
        newFibre = r1(existing.fibre * ratio);
        newSugar = scaleOpt(existing.sugar);
        newSodium = scaleOpt(existing.sodiumMg);
        newSatFat = scaleOpt(existing.saturatedFat);
        newPot = scaleOpt(existing.potassiumMg);
        newCalc = scaleOpt(existing.calciumMg);
        newIron = scaleOpt(existing.ironMg);
        newVitC = scaleOpt(existing.vitaminCMg);
      } else {
        final food = await _catalogueService.assertFoodLoggable(
          existing.foodId,
          userId: userId,
        );
        final serving = _resolveServing(food, targetServingId);
        final calc = NutritionCalculator.calculateForServing(
          per100g: food.nutritionPer100g,
          serving: serving,
          servingCount: targetCount,
        );
        newServingLabel = serving.label;
        newGramsPerUnit = serving.gramsPerUnit;
        newTotalGrams = calc.totalGrams;
        newCal = calc.calories;
        newProt = calc.protein;
        newCarbs = calc.carbs;
        newFat = calc.fat;
        newFibre = calc.fibre;
        newSugar = calc.sugar;
        newSodium = calc.sodiumMg;
        newSatFat = calc.saturatedFat;
        newPot = calc.potassiumMg;
        newCalc = calc.calciumMg;
        newIron = calc.ironMg;
        newVitC = calc.vitaminCMg;
      }
    }

    final now = DateTime.now().toIso8601String();
    final updated = existing.copyWith(
      mealCategory: mealCategory ?? existing.mealCategory,
      servingId: targetServingId,
      servingLabelSnapshot: newServingLabel,
      servingCount: targetCount,
      gramsPerUnit: newGramsPerUnit,
      totalGrams: newTotalGrams,
      calories: newCal,
      protein: newProt,
      carbs: newCarbs,
      fat: newFat,
      fibre: newFibre,
      sugar: newSugar,
      sodiumMg: newSodium,
      saturatedFat: newSatFat,
      potassiumMg: newPot,
      calciumMg: newCalc,
      ironMg: newIron,
      vitaminCMg: newVitC,
      updatedAt: now,
      syncStatus: 'pending',
      notes: notes ?? existing.notes,
    );

    final db = await _db();
    await db.update(
      NutritionDatabaseSchema.tableFoodLogs,
      updated.toDbMap(),
      where: 'id = ? AND user_id = ?',
      whereArgs: [logId, userId],
    );
    return updated;
  }

  Future<void> deleteLogEntry({
    required String userId,
    required String logId,
  }) async {
    final db = await _db();
    final now = DateTime.now().toIso8601String();
    await db.update(
      NutritionDatabaseSchema.tableFoodLogs,
      {
        'is_deleted': 1,
        'sync_status': 'pending',
        'updated_at': now,
      },
      where: 'id = ? AND user_id = ?',
      whereArgs: [logId, userId],
    );
  }

  Future<List<FoodLog>> duplicateMeal({
    required String userId,
    required String fromDate,
    required MealCategory fromMeal,
    required String toDate,
    required MealCategory toMeal,
  }) async {
    final db = await _db();
    final rows = await db.query(
      NutritionDatabaseSchema.tableFoodLogs,
      where: 'user_id = ? AND date = ? AND meal_category = ? AND is_deleted = 0',
      whereArgs: [userId, fromDate, fromMeal.key],
      orderBy: 'logged_at ASC',
    );
    if (rows.isEmpty) return const [];

    final now = DateTime.now().toIso8601String();
    final inserted = <FoodLog>[];
    await db.transaction((txn) async {
      for (final row in rows) {
        final src = FoodLog.fromDbMap(row);
        final clone = FoodLog(
          id: UuidUtils.v4(),
          userId: userId,
          date: toDate,
          mealCategory: toMeal,
          foodId: src.foodId,
          foodNameSnapshot: src.foodNameSnapshot,
          preparationSnapshot: src.preparationSnapshot,
          illustrationSnapshot: src.illustrationSnapshot,
          servingId: src.servingId,
          servingLabelSnapshot: src.servingLabelSnapshot,
          servingCount: src.servingCount,
          gramsPerUnit: src.gramsPerUnit,
          totalGrams: src.totalGrams,
          calories: src.calories,
          protein: src.protein,
          carbs: src.carbs,
          fat: src.fat,
          fibre: src.fibre,
          sugar: src.sugar,
          sodiumMg: src.sodiumMg,
          saturatedFat: src.saturatedFat,
          potassiumMg: src.potassiumMg,
          calciumMg: src.calciumMg,
          ironMg: src.ironMg,
          vitaminCMg: src.vitaminCMg,
          sourceSnapshot: src.sourceSnapshot,
          loggedAt: now,
          updatedAt: now,
          syncStatus: 'pending',
          isDeleted: false,
          notes: src.notes,
        );
        await txn.insert(
          NutritionDatabaseSchema.tableFoodLogs,
          clone.toDbMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        inserted.add(clone);
      }
    });
    return inserted;
  }

  Future<List<FoodLog>> getLogsForDate(String userId, String date) async {
    final db = await _db();
    final rows = await db.query(
      NutritionDatabaseSchema.tableFoodLogs,
      where: 'user_id = ? AND date = ? AND is_deleted = 0',
      whereArgs: [userId, date],
      orderBy: 'logged_at ASC',
    );
    return rows.map(FoodLog.fromDbMap).toList();
  }

  Future<List<FoodLog>> getLogsInDateRange(
    String userId, {
    required String startDate,
    required String endDate,
  }) async {
    final db = await _db();
    final rows = await db.query(
      NutritionDatabaseSchema.tableFoodLogs,
      where: 'user_id = ? AND date >= ? AND date <= ? AND is_deleted = 0',
      whereArgs: [userId, startDate, endDate],
      orderBy: 'date ASC, logged_at ASC',
    );
    return rows.map(FoodLog.fromDbMap).toList();
  }

  Future<int> getHydrationForDate(String userId, String date) async {
    final db = await _db();
    final rows = await db.query(
      NutritionDatabaseSchema.tableDailyHydrationLogs,
      columns: ['amount_ml'],
      where: 'user_id = ? AND date = ?',
      whereArgs: [userId, date],
      limit: 1,
    );
    if (rows.isEmpty) return 0;
    return (rows.first['amount_ml'] as int?) ?? 0;
  }

  Future<int> setHydrationForDate(
    String userId,
    String date,
    int amountMl,
  ) async {
    final clamped = amountMl.clamp(0, 15000);
    final db = await _db();
    final existing = await db.query(
      NutritionDatabaseSchema.tableDailyHydrationLogs,
      where: 'user_id = ? AND date = ?',
      whereArgs: [userId, date],
      limit: 1,
    );
    final id = existing.isNotEmpty
        ? existing.first['id'] as String
        : UuidUtils.v4();
    await db.insert(
      NutritionDatabaseSchema.tableDailyHydrationLogs,
      {
        'id': id,
        'user_id': userId,
        'date': date,
        'amount_ml': clamped,
        'updated_at': DateTime.now().toIso8601String(),
        'sync_status': 'pending',
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return clamped;
  }

  Future<DailyNutritionTotals> getDailySummary(
    String userId,
    String date,
  ) async {
    final logs = await getLogsForDate(userId, date);
    final hydration = await getHydrationForDate(userId, date);
    return DailyNutritionTotals.fromLogs(
      date: date,
      logs: logs,
      hydrationMl: hydration,
    );
  }

  Future<List<FoodItem>> getRecentFoods(
    String userId, {
    int limit = 10,
  }) async {
    final db = await _db();
    final rows = await db.rawQuery('''
      SELECT food_id, MAX(logged_at) AS last_logged
      FROM ${NutritionDatabaseSchema.tableFoodLogs}
      WHERE user_id = ? AND is_deleted = 0
      GROUP BY food_id
      ORDER BY last_logged DESC
      LIMIT ?
    ''', [userId, limit]);

    final items = <FoodItem>[];
    for (final r in rows) {
      final fid = r['food_id'] as String;
      final food = await _catalogueService.getFoodById(fid, userId: userId);
      if (food != null && food.isVerified) {
        items.add(food);
      }
    }
    return items;
  }

  FoodServing _resolveServing(FoodItem food, String servingId) {
    for (final s in food.servings) {
      if (s.id == servingId) return s;
    }
    if (servingId == 'g_100') {
      return FoodServing(
        id: 'g_100',
        foodId: food.id,
        label: '100 g',
        unitType: 'gram',
        gramsPerUnit: 100,
        isDefault: false,
        sortOrder: 99,
      );
    }
    throw ArgumentError('Serving "$servingId" is invalid for "${food.id}".');
  }
}

