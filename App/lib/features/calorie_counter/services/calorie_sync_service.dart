import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import '../../../core/config/app_config.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/database/nutrition_database_schema.dart';
import '../../../core/services/auth_service.dart';
import '../models/diet_plan_models.dart';
import '../models/food_request_model.dart';
import '../models/meal_log_model.dart';
import '../models/nutrition_goal_models.dart';

class NutritionSyncResult {
  final bool success;
  final int uploadedCount;
  final int downloadedCount;
  final String message;

  const NutritionSyncResult({
    required this.success,
    required this.uploadedCount,
    required this.downloadedCount,
    required this.message,
  });
}

/// Offline-first synchronization engine for the Calorie Counter module.
///
/// Strictly isolated from Meal Counter (`daily_records`) and Expense Counter.
class CalorieSyncService {
  static final CalorieSyncService instance = CalorieSyncService._internal();

  final DatabaseHelper _dbHelper;
  final http.Client _httpClient;
  final AuthService _authService;

  CalorieSyncService._internal()
      : _dbHelper = DatabaseHelper.instance,
        _httpClient = http.Client(),
        _authService = AuthService.instance;

  factory CalorieSyncService.createForTesting({
    required DatabaseHelper dbHelper,
    required http.Client httpClient,
    required AuthService authService,
  }) =>
      CalorieSyncService._withDeps(
        dbHelper: dbHelper,
        httpClient: httpClient,
        authService: authService,
      );

  CalorieSyncService._withDeps({
    required DatabaseHelper dbHelper,
    required http.Client httpClient,
    required AuthService authService,
  })  : _dbHelper = dbHelper,
        _httpClient = httpClient,
        _authService = authService;

  bool _isSyncing = false;
  static const String _lastSyncPrefix = 'nutrition_last_sync_';

  Future<Database> _db() async {
    final db = await _dbHelper.database;
    await NutritionDatabaseSchema.createTables(db);
    return db;
  }

  Future<NutritionSyncResult> syncNow() async {
    if (!_authService.isLoggedIn ||
        _authService.isGuestMode ||
        _authService.token == null) {
      return const NutritionSyncResult(
        success: false,
        uploadedCount: 0,
        downloadedCount: 0,
        message: 'Offline / guest mode active. Sign in to sync nutrition data.',
      );
    }
    if (_isSyncing) {
      return const NutritionSyncResult(
        success: false,
        uploadedCount: 0,
        downloadedCount: 0,
        message: 'Nutrition sync already in progress.',
      );
    }

    _isSyncing = true;
    try {
      final userId = _authService.currentUser?.id ?? 'local_guest';
      final db = await _db();
      final prefs = await SharedPreferences.getInstance();
      final lastSyncAt = prefs.getString('$_lastSyncPrefix$userId');

      final pendingLogsRows = await db.query(
        NutritionDatabaseSchema.tableFoodLogs,
        where: 'user_id = ? AND sync_status = ?',
        whereArgs: [userId, 'pending'],
      );
      final pendingLogs = pendingLogsRows.map(FoodLog.fromDbMap).toList();

      final pendingDailyGoalRows = await db.query(
        NutritionDatabaseSchema.tableDailyNutritionGoals,
        where: 'user_id = ? AND sync_status = ?',
        whereArgs: [userId, 'pending'],
      );
      final pendingDailyGoals =
          pendingDailyGoalRows.map(DailyNutritionGoal.fromDbMap).toList();

      final pendingMonthlyGoalRows = await db.query(
        NutritionDatabaseSchema.tableMonthlyNutritionGoals,
        where: 'user_id = ? AND sync_status = ?',
        whereArgs: [userId, 'pending'],
      );
      final pendingMonthlyGoals =
          pendingMonthlyGoalRows.map(MonthlyNutritionGoal.fromDbMap).toList();

      final pendingPrefRows = await db.query(
        NutritionDatabaseSchema.tableUserNutritionPreferences,
        where: 'user_id = ? AND sync_status = ?',
        whereArgs: [userId, 'pending'],
        limit: 1,
      );
      final pendingPrefs = pendingPrefRows.isNotEmpty
          ? UserNutritionPreferences.fromDbMap(pendingPrefRows.first)
          : null;

      final pendingPlanRows = await db.query(
        NutritionDatabaseSchema.tableDietPlans,
        where: 'user_id = ? AND sync_status = ?',
        whereArgs: [userId, 'pending'],
      );
      final pendingPlans = <DietPlan>[];
      for (final pRow in pendingPlanRows) {
        final pid = pRow['id'] as String;
        final mealRows = await db.query(
          NutritionDatabaseSchema.tableDietPlanMeals,
          where: 'plan_id = ?',
          whereArgs: [pid],
          orderBy: 'sort_order ASC',
        );
        final meals = <DietPlanMeal>[];
        for (final mRow in mealRows) {
          final mid = mRow['id'] as String;
          final itemRows = await db.query(
            NutritionDatabaseSchema.tableDietPlanItems,
            where: 'meal_id = ?',
            whereArgs: [mid],
            orderBy: 'sort_order ASC',
          );
          meals.add(DietPlanMeal.fromDbMap(
            mRow,
            itemRows.map(DietPlanItem.fromDbMap).toList(),
          ));
        }
        pendingPlans.add(DietPlan.fromDbMap(pRow, meals));
      }

      final pendingReqRows = await db.query(
        NutritionDatabaseSchema.tableFoodRequests,
        where: 'user_id = ? AND sync_status = ?',
        whereArgs: [userId, 'pending'],
      );
      final pendingRequests =
          pendingReqRows.map(FoodRequest.fromDbMap).toList();

      final pendingHydrationRows = await db.query(
        NutritionDatabaseSchema.tableDailyHydrationLogs,
        where: 'user_id = ? AND sync_status = ?',
        whereArgs: [userId, 'pending'],
      );

      final uploadedCount = pendingLogs.length +
          pendingDailyGoals.length +
          pendingMonthlyGoals.length +
          (pendingPrefs != null ? 1 : 0) +
          pendingPlans.length +
          pendingRequests.length +
          pendingHydrationRows.length;

      final payload = {
        'lastSyncAt': lastSyncAt,
        'foodLogs': pendingLogs.map((e) => e.toApiJson()).toList(),
        'dailyGoals': pendingDailyGoals.map((e) => e.toApiJson()).toList(),
        'monthlyGoals': pendingMonthlyGoals.map((e) => e.toApiJson()).toList(),
        'preferences': pendingPrefs?.toApiJson(),
        'dietPlans': pendingPlans.map((e) => e.toApiJson()).toList(),
        'foodRequests': pendingRequests.map((e) => e.toApiJson()).toList(),
        'hydrationLogs': pendingHydrationRows
            .map((r) => {
                  'id': r['id'],
                  'date': r['date'],
                  'amountMl': r['amount_ml'],
                  'updatedAt': r['updated_at'],
                })
            .toList(),
      };

      final response = await _httpClient
          .post(
            Uri.parse('${AppConfig.apiBaseUrl}/nutrition/sync'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer ${_authService.token}',
            },
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode != 200) {
        return NutritionSyncResult(
          success: false,
          uploadedCount: 0,
          downloadedCount: 0,
          message: 'Sync failed (${response.statusCode}). Data remains safe locally.',
        );
      }

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      int downloadedCount = 0;

      await db.transaction((txn) async {
        // Mark uploaded entities as synced
        for (final log in pendingLogs) {
          await txn.update(
            NutritionDatabaseSchema.tableFoodLogs,
            {'sync_status': 'synced'},
            where: 'id = ? AND updated_at <= ?',
            whereArgs: [log.id, log.updatedAt],
          );
        }
        for (final dg in pendingDailyGoals) {
          await txn.update(
            NutritionDatabaseSchema.tableDailyNutritionGoals,
            {'sync_status': 'synced'},
            where: 'id = ?',
            whereArgs: [dg.id],
          );
        }
        for (final mg in pendingMonthlyGoals) {
          await txn.update(
            NutritionDatabaseSchema.tableMonthlyNutritionGoals,
            {'sync_status': 'synced'},
            where: 'id = ?',
            whereArgs: [mg.id],
          );
        }
        if (pendingPrefs != null) {
          await txn.update(
            NutritionDatabaseSchema.tableUserNutritionPreferences,
            {'sync_status': 'synced'},
            where: 'user_id = ?',
            whereArgs: [userId],
          );
        }
        for (final dp in pendingPlans) {
          await txn.update(
            NutritionDatabaseSchema.tableDietPlans,
            {'sync_status': 'synced'},
            where: 'id = ?',
            whereArgs: [dp.id],
          );
        }
        for (final req in pendingRequests) {
          await txn.update(
            NutritionDatabaseSchema.tableFoodRequests,
            {'sync_status': 'synced'},
            where: 'id = ?',
            whereArgs: [req.id],
          );
        }
        for (final hyd in pendingHydrationRows) {
          await txn.update(
            NutritionDatabaseSchema.tableDailyHydrationLogs,
            {'sync_status': 'synced'},
            where: 'id = ?',
            whereArgs: [hyd['id']],
          );
        }

        // Apply server merged changes (newer updatedAt wins)
        final serverLogs = (body['foodLogs'] as List<dynamic>? ?? const []);
        for (final raw in serverLogs) {
          final remote =
              FoodLog.fromApiJson(raw as Map<String, dynamic>, userId);
          final local = await txn.query(
            NutritionDatabaseSchema.tableFoodLogs,
            columns: ['updated_at'],
            where: 'id = ?',
            whereArgs: [remote.id],
            limit: 1,
          );
          if (local.isEmpty ||
              (local.first['updated_at'] as String)
                      .compareTo(remote.updatedAt) <=
                  0) {
            await txn.insert(
              NutritionDatabaseSchema.tableFoodLogs,
              remote.toDbMap(),
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
            downloadedCount++;
          }
        }

        final serverDailyGoals =
            (body['dailyGoals'] as List<dynamic>? ?? const []);
        for (final raw in serverDailyGoals) {
          final remote = DailyNutritionGoal.fromApiJson(
              raw as Map<String, dynamic>, userId);
          final local = await txn.query(
            NutritionDatabaseSchema.tableDailyNutritionGoals,
            columns: ['updated_at'],
            where: 'user_id = ? AND effective_from_date = ?',
            whereArgs: [userId, remote.effectiveFromDate],
            limit: 1,
          );
          if (local.isEmpty ||
              (local.first['updated_at'] as String)
                      .compareTo(remote.updatedAt) <=
                  0) {
            await txn.insert(
              NutritionDatabaseSchema.tableDailyNutritionGoals,
              remote.toDbMap(),
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
            downloadedCount++;
          }
        }

        final serverMonthlyGoals =
            (body['monthlyGoals'] as List<dynamic>? ?? const []);
        for (final raw in serverMonthlyGoals) {
          final remote = MonthlyNutritionGoal.fromApiJson(
              raw as Map<String, dynamic>, userId);
          final local = await txn.query(
            NutritionDatabaseSchema.tableMonthlyNutritionGoals,
            columns: ['updated_at'],
            where: 'user_id = ? AND year_month = ?',
            whereArgs: [userId, remote.yearMonth],
            limit: 1,
          );
          if (local.isEmpty ||
              (local.first['updated_at'] as String)
                      .compareTo(remote.updatedAt) <=
                  0) {
            await txn.insert(
              NutritionDatabaseSchema.tableMonthlyNutritionGoals,
              remote.toDbMap(),
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
            downloadedCount++;
          }
        }

        final serverPrefsRaw = body['preferences'];
        if (serverPrefsRaw is Map<String, dynamic>) {
          final remote = UserNutritionPreferences.fromApiJson(
              serverPrefsRaw, userId);
          final local = await txn.query(
            NutritionDatabaseSchema.tableUserNutritionPreferences,
            columns: ['updated_at'],
            where: 'user_id = ?',
            whereArgs: [userId],
            limit: 1,
          );
          if (local.isEmpty ||
              (local.first['updated_at'] as String)
                      .compareTo(remote.updatedAt) <=
                  0) {
            await txn.insert(
              NutritionDatabaseSchema.tableUserNutritionPreferences,
              remote.toDbMap(),
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
            downloadedCount++;
          }
        }

        final serverPlans = (body['dietPlans'] as List<dynamic>? ?? const []);
        for (final raw in serverPlans) {
          final remote =
              DietPlan.fromApiJson(raw as Map<String, dynamic>, userId);
          final local = await txn.query(
            NutritionDatabaseSchema.tableDietPlans,
            columns: ['updated_at'],
            where: 'id = ?',
            whereArgs: [remote.id],
            limit: 1,
          );
          if (local.isEmpty ||
              (local.first['updated_at'] as String)
                      .compareTo(remote.updatedAt) <=
                  0) {
            await txn.insert(
              NutritionDatabaseSchema.tableDietPlans,
              remote.toDbMap(),
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
            await txn.delete(
              NutritionDatabaseSchema.tableDietPlanMeals,
              where: 'plan_id = ?',
              whereArgs: [remote.id],
            );
            for (final meal in remote.meals) {
              await txn.insert(
                NutritionDatabaseSchema.tableDietPlanMeals,
                meal.toDbMap(),
                conflictAlgorithm: ConflictAlgorithm.replace,
              );
              for (final item in meal.items) {
                await txn.insert(
                  NutritionDatabaseSchema.tableDietPlanItems,
                  item.toDbMap(),
                  conflictAlgorithm: ConflictAlgorithm.replace,
                );
              }
            }
            downloadedCount++;
          }
        }

        final serverReqs =
            (body['foodRequests'] as List<dynamic>? ?? const []);
        for (final raw in serverReqs) {
          final remote =
              FoodRequest.fromApiJson(raw as Map<String, dynamic>, userId);
          await txn.insert(
            NutritionDatabaseSchema.tableFoodRequests,
            remote.toDbMap(),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
          downloadedCount++;
        }

        final serverHydration =
            (body['hydrationLogs'] as List<dynamic>? ?? const []);
        for (final raw in serverHydration) {
          final h = raw as Map<String, dynamic>;
          await txn.insert(
            NutritionDatabaseSchema.tableDailyHydrationLogs,
            {
              'id': h['id'],
              'user_id': userId,
              'date': h['date'],
              'amount_ml': h['amountMl'],
              'updated_at': h['updatedAt'],
              'sync_status': 'synced',
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
          downloadedCount++;
        }
      });

      final serverTime = body['serverTime'] as String? ??
          DateTime.now().toIso8601String();
      await prefs.setString('$_lastSyncPrefix$userId', serverTime);

      return NutritionSyncResult(
        success: true,
        uploadedCount: uploadedCount,
        downloadedCount: downloadedCount,
        message: 'Nutrition sync complete.',
      );
    } catch (e) {
      return NutritionSyncResult(
        success: false,
        uploadedCount: 0,
        downloadedCount: 0,
        message: 'Sync deferred (offline): $e',
      );
    } finally {
      _isSyncing = false;
    }
  }
}
