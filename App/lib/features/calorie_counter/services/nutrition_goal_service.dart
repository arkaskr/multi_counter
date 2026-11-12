import 'package:sqflite/sqflite.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/database/nutrition_database_schema.dart';
import '../../../core/utils/uuid_utils.dart';
import '../models/nutrition_goal_models.dart';

class NutritionGoalService {
  static final NutritionGoalService instance = NutritionGoalService._internal();
  NutritionGoalService._internal();

  factory NutritionGoalService.createForTesting(DatabaseHelper dbHelper) =>
      NutritionGoalService._withHelper(dbHelper);

  DatabaseHelper _dbHelper = DatabaseHelper.instance;
  NutritionGoalService._withHelper(this._dbHelper);

  Future<Database> _db() async {
    final db = await _dbHelper.database;
    await NutritionDatabaseSchema.createTables(db);
    return db;
  }

  /// Resolves the daily goal active on [date] (`YYYY-MM-DD`) by taking the
  /// most recent non-deleted goal with `effective_from_date <= date`.
  /// Preserves historical goals when newer goals are saved later.
  Future<DailyNutritionGoal> getDailyGoalForDate(
    String userId,
    String date,
  ) async {
    final db = await _db();
    final rows = await db.query(
      NutritionDatabaseSchema.tableDailyNutritionGoals,
      where:
          'user_id = ? AND effective_from_date <= ? AND is_deleted = 0',
      whereArgs: [userId, date],
      orderBy: 'effective_from_date DESC, updated_at DESC',
      limit: 1,
    );
    if (rows.isNotEmpty) {
      return DailyNutritionGoal.fromDbMap(rows.first);
    }

    // If user only has a future-dated goal configured earlier, check any active goal as fallback
    final anyRows = await db.query(
      NutritionDatabaseSchema.tableDailyNutritionGoals,
      where: 'user_id = ? AND is_deleted = 0',
      whereArgs: [userId],
      orderBy: 'effective_from_date ASC',
      limit: 1,
    );
    if (anyRows.isNotEmpty) {
      return DailyNutritionGoal.fromDbMap(anyRows.first);
    }

    return DailyNutritionGoal.fallbackDefault(userId);
  }

  /// Saves a daily goal starting at [effectiveFromDate] (defaults to today).
  /// Previous dates retain their historical goal rows intact.
  Future<DailyNutritionGoal> saveDailyGoal({
    required String userId,
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
    if (calories < 800 || calories > 10000) {
      throw ArgumentError(
          'Daily calories target must be between 800 and 10,000 kcal.');
    }
    final db = await _db();
    final existing = await db.query(
      NutritionDatabaseSchema.tableDailyNutritionGoals,
      where: 'user_id = ? AND effective_from_date = ?',
      whereArgs: [userId, effectiveFromDate],
      limit: 1,
    );

    final now = DateTime.now().toIso8601String();
    final goal = DailyNutritionGoal(
      id: existing.isNotEmpty ? existing.first['id'] as String : UuidUtils.v4(),
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
      createdAt: existing.isNotEmpty
          ? existing.first['created_at'] as String
          : now,
      updatedAt: now,
      syncStatus: 'pending',
      isDeleted: false,
    );

    await db.insert(
      NutritionDatabaseSchema.tableDailyNutritionGoals,
      goal.toDbMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return goal;
  }

  Future<List<DailyNutritionGoal>> getAllDailyGoalsHistory(String userId) async {
    final db = await _db();
    final rows = await db.query(
      NutritionDatabaseSchema.tableDailyNutritionGoals,
      where: 'user_id = ? AND is_deleted = 0',
      whereArgs: [userId],
      orderBy: 'effective_from_date DESC',
    );
    return rows.map(DailyNutritionGoal.fromDbMap).toList();
  }

  /// Gets the independently configured monthly goal for [yearMonth] (`YYYY-MM`).
  /// Returns null if the user has not explicitly configured one for that month.
  Future<MonthlyNutritionGoal?> getMonthlyGoal(
    String userId,
    String yearMonth,
  ) async {
    final db = await _db();
    final rows = await db.query(
      NutritionDatabaseSchema.tableMonthlyNutritionGoals,
      where: 'user_id = ? AND year_month = ? AND is_deleted = 0',
      whereArgs: [userId, yearMonth],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return MonthlyNutritionGoal.fromDbMap(rows.first);
  }

  /// Saves an independent monthly goal (does NOT force daily * 30).
  Future<MonthlyNutritionGoal> saveMonthlyGoal({
    required String userId,
    required String yearMonth,
    required double totalCalories,
    double? protein,
    double? carbs,
    double? fat,
    double? fibre,
    int? targetDaysWithinGoal,
    String notes = '',
  }) async {
    if (totalCalories <= 0) {
      throw ArgumentError('Monthly calorie target must be positive.');
    }
    final db = await _db();
    final existing = await db.query(
      NutritionDatabaseSchema.tableMonthlyNutritionGoals,
      where: 'user_id = ? AND year_month = ?',
      whereArgs: [userId, yearMonth],
      limit: 1,
    );

    final now = DateTime.now().toIso8601String();
    final goal = MonthlyNutritionGoal(
      id: existing.isNotEmpty ? existing.first['id'] as String : UuidUtils.v4(),
      userId: userId,
      yearMonth: yearMonth,
      totalCalories: totalCalories,
      protein: protein,
      carbs: carbs,
      fat: fat,
      fibre: fibre,
      targetDaysWithinGoal: targetDaysWithinGoal,
      notes: notes,
      createdAt: existing.isNotEmpty
          ? existing.first['created_at'] as String
          : now,
      updatedAt: now,
      syncStatus: 'pending',
      isDeleted: false,
    );

    await db.insert(
      NutritionDatabaseSchema.tableMonthlyNutritionGoals,
      goal.toDbMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return goal;
  }

  Future<UserNutritionPreferences> getPreferences(String userId) async {
    final db = await _db();
    final rows = await db.query(
      NutritionDatabaseSchema.tableUserNutritionPreferences,
      where: 'user_id = ?',
      whereArgs: [userId],
      limit: 1,
    );
    if (rows.isEmpty) return UserNutritionPreferences.initial(userId);
    return UserNutritionPreferences.fromDbMap(rows.first);
  }

  Future<UserNutritionPreferences> savePreferences(
    UserNutritionPreferences prefs,
  ) async {
    final db = await _db();
    final updated = prefs.copyWith(
      updatedAt: DateTime.now().toIso8601String(),
      syncStatus: 'pending',
    );
    await db.insert(
      NutritionDatabaseSchema.tableUserNutritionPreferences,
      updated.toDbMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return updated;
  }
}

