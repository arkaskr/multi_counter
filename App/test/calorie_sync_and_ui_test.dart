import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:daily_counter/core/constants/database_constants.dart';
import 'package:daily_counter/core/database/database_helper.dart';
import 'package:daily_counter/core/database/database_schema.dart';
import 'package:daily_counter/core/database/nutrition_database_schema.dart';
import 'package:daily_counter/core/services/auth_service.dart';
import 'package:daily_counter/features/auth/providers/auth_providers.dart';
import 'package:daily_counter/features/calorie_counter/models/food_models.dart';
import 'package:daily_counter/features/calorie_counter/models/meal_log_model.dart';
import 'package:daily_counter/features/calorie_counter/models/nutrition_goal_models.dart';
import 'package:daily_counter/features/calorie_counter/providers/calorie_providers.dart';
import 'package:daily_counter/features/calorie_counter/screens/calorie_counter_screen.dart';
import 'package:daily_counter/features/calorie_counter/services/calorie_sync_service.dart';
import 'package:daily_counter/features/calorie_counter/services/diet_planner_service.dart';
import 'package:daily_counter/features/calorie_counter/services/food_catalogue_service.dart';
import 'package:daily_counter/features/calorie_counter/services/meal_log_service.dart';
import 'package:daily_counter/features/calorie_counter/services/nutrition_analytics_service.dart';
import 'package:daily_counter/features/calorie_counter/services/nutrition_goal_service.dart';
import 'package:daily_counter/shared/models/user_model.dart';

class _TestAuthService extends AuthService {
  final String _uid;
  _TestAuthService(this._uid) : super.internal();

  @override
  Future<void> init() async {}
  @override
  bool get isInitialized => true;
  @override
  bool get isLoggedIn => true;
  @override
  bool get isGuestMode => false;
  @override
  String? get token => 'jwt_test_token';
  @override
  UserModel? get currentUser =>
      UserModel(id: _uid, name: 'Test User', email: 'test@example.com');
}

void main() {
  sqfliteFfiInit();

  late Database db;
  late DatabaseHelper dbHelper;
  late FoodCatalogueService catalogueService;
  late MealLogService mealLogService;
  late NutritionGoalService goalService;
  late String catalogueJson;

  setUpAll(() {
    catalogueJson = File('assets/data/food_catalogue.json').readAsStringSync();
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
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
  });

  tearDown(() async {
    await db.close();
    DatabaseHelper.resetForTesting();
  });

  test('offline-first sync uploads pending items, pulls deltas without duplicates, isolates users', () async {
    const uid = 'sync_user_1';
    final log = await mealLogService.logFood(
      userId: uid,
      date: '2026-11-12',
      mealCategory: MealCategory.lunch,
      foodId: 'roti_plain',
      servingId: 'med_roti',
      servingCount: 2,
    );

    late Map<String, dynamic> capturedRequest;
    final mockClient = MockClient((request) async {
      capturedRequest = jsonDecode(request.body) as Map<String, dynamic>;
      return http.Response(
        jsonEncode({
          'success': true,
          'serverTime': '2026-11-12T10:00:00.000Z',
          // Echo back log + add one remote log from another device
          'foodLogs': [
            log.toApiJson(),
            {
              'id': 'remote-uuid-1234',
              'date': '2026-11-12',
              'mealCategory': 'breakfast',
              'foodId': 'apple_fresh',
              'foodNameSnapshot': 'Apple (Fresh, Raw)',
              'preparationSnapshot': 'Raw',
              'illustrationSnapshot': 'apple',
              'servingId': '1_med',
              'servingLabelSnapshot': '1 medium apple',
              'servingCount': 1.0,
              'gramsPerUnit': 182.0,
              'totalGrams': 182.0,
              'calories': 94.6,
              'protein': 0.5,
              'carbs': 25.1,
              'fat': 0.3,
              'fibre': 4.4,
              'sourceSnapshot': 'USDA',
              'loggedAt': '2026-11-12T08:00:00.000Z',
              'updatedAt': '2026-11-12T08:00:00.000Z',
              'isDeleted': false,
              'serverVersion': 1,
              'notes': '',
            },
          ],
          'dailyGoals': [],
          'monthlyGoals': [],
          'dietPlans': [],
          'foodRequests': [],
          'hydrationLogs': [],
        }),
        200,
      );
    });

    final syncService = CalorieSyncService.createForTesting(
      dbHelper: dbHelper,
      httpClient: mockClient,
      authService: _TestAuthService(uid),
    );

    final result = await syncService.syncNow();
    expect(result.success, isTrue);
    expect(result.uploadedCount, 1);
    expect((capturedRequest['foodLogs'] as List).length, 1);

    // Syncing again must NOT create duplicates and uploads 0 pending items
    final secondResult = await syncService.syncNow();
    expect(secondResult.success, isTrue);
    expect(secondResult.uploadedCount, 0);

    final localLogs = await mealLogService.getLogsForDate(uid, '2026-11-12');
    expect(localLogs.length, 2);

    // Other user has zero access to sync_user_1's records
    final otherUserLogs =
        await mealLogService.getLogsForDate('other_user_2', '2026-11-12');
    expect(otherUserLogs, isEmpty);
  });

  test('AI Diet Planner fallback, food replace, quantity adjust, offline save & explicit log confirmation', () async {
    const uid = 'planner_user';
    final planner = DietPlannerService.createForTesting(
      dbHelper: dbHelper,
      catalogueService: catalogueService,
      mealLogService: mealLogService,
      authService: _TestAuthService(uid),
      httpClient: MockClient((_) async => http.Response('{"error":"quota"}', 429)),
    );

    final goal = DailyNutritionGoal.fallbackDefault(uid);
    final prefs = UserNutritionPreferences.initial(uid);

    // Generates fallback gracefully on 429 quota error
    final gen = await planner.generatePlan(
      userId: uid,
      goal: goal,
      preferences: prefs,
    );
    expect(gen.usedFallback, isTrue);
    expect(gen.plan.meals.length, greaterThanOrEqualTo(4));

    // Must NOT automatically create food logs!
    expect(await mealLogService.getLogsForDate(uid, '2026-11-12'), isEmpty);

    // Replace food item & adjust quantity
    final firstMeal = gen.plan.meals.first;
    final firstItem = firstMeal.items.first;
    final apple = (await catalogueService.getFoodById('apple_raw'))!;
    var editedPlan = await planner.replacePlanItem(
      plan: gen.plan,
      mealId: firstMeal.id,
      itemId: firstItem.id,
      replacementFood: apple,
      servingCount: 2,
    );
    expect(editedPlan.meals.first.items.first.foodId, 'apple_raw');

    editedPlan = await planner.adjustPlanItemQuantity(
      plan: editedPlan,
      mealId: editedPlan.meals.first.id,
      itemId: editedPlan.meals.first.items.first.id,
      newServingCount: 1,
    );
    expect(editedPlan.meals.first.items.first.servingCount, 1.0);

    // Save offline & verify persistence
    await planner.savePlan(editedPlan, isAccepted: true, isSaved: true);
    final savedPlans = await planner.getSavedPlans(uid);
    expect(savedPlans.length, 1);
    expect(savedPlans.first.isAccepted, isTrue);

    // Still zero consumed logs until explicit meal confirmation!
    expect(await mealLogService.getLogsForDate(uid, '2026-11-12'), isEmpty);

    // Explicit confirm logs meal items accurately
    final logged = await planner.confirmAndLogPlanMeal(
      userId: uid,
      date: '2026-11-12',
      meal: savedPlans.first.meals.first,
    );
    expect(logged.isNotEmpty, isTrue);
    expect(
      (await mealLogService.getLogsForDate(uid, '2026-11-12')).length,
      logged.length,
    );
  });

  testWidgets('CalorieCounterScreen dashboard renders offline verified data and tabs cleanly', (tester) async {
    late List<FoodCategory> cats;
    late List<FoodItem> foods;
    late AnalyticsBundle analyticsBundle;

    await tester.runAsync(() async {
      cats = await catalogueService.getCategories();
      foods = await catalogueService.searchFoods(limit: 5);
      final analyticsService =
          NutritionAnalyticsService.createForTesting(mealLogService, goalService);
      final weekly =
          await analyticsService.getWeeklyAnalytics('ui_user', DateTime(2026, 11, 12));
      final monthly = await analyticsService.getMonthlyAnalytics('ui_user', 2026, 11);
      analyticsBundle = AnalyticsBundle(
        weekly: weekly,
        monthly: monthly,
        monthlyGoal: null,
        yearMonth: '2026-11',
      );
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authServiceProvider.overrideWithValue(_TestAuthService('ui_user')),
          dailyDashboardProvider.overrideWith(() => _FakeUiDashboardNotifier()),
          foodCategoriesProvider.overrideWith((_) async => cats),
          nutritionAnalyticsProvider.overrideWith((_) async => analyticsBundle),
          foodCatalogueServiceProvider.overrideWithValue(
            _InMemoryUiCatalogueService(cats, foods),
          ),
        ],
        child: const MaterialApp(
          home: CalorieCounterScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Calorie Counter'), findsOneWidget);
    expect(find.text('Quick Add Food'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Breakfast'), 300);
    expect(find.text('Breakfast'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Lunch'), 300);
    expect(find.text('Lunch'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Dinner'), 300);
    expect(find.text('Dinner'), findsOneWidget);

    // Switch to Food Catalogue tab
    await tester.tap(find.text('Foods'));
    await tester.pumpAndSettle();
    expect(find.text('All Categories'), findsOneWidget);
    expect(find.text(foods.first.name), findsOneWidget);

    // Switch to AI Plan tab
    await tester.tap(find.text('AI Plan'));
    await tester.pumpAndSettle();
    expect(find.text('Generate Diet Plan'), findsOneWidget);

    // Switch to Analytics tab
    await tester.tap(find.text('Analytics'));
    await tester.pumpAndSettle();
    expect(find.text('Last 7 Days Trend'), findsOneWidget);
  });
}

class _FakeUiDashboardNotifier extends DailyDashboardNotifier {
  @override
  Future<DailyDashboardState> build() async {
    const uid = 'ui_user';
    const date = '2026-11-12';
    return DailyDashboardState(
      dateString: date,
      totals: DailyNutritionTotals.fromLogs(date: date, logs: const []),
      goal: DailyNutritionGoal.fallbackDefault(uid),
      recentFoods: const [],
      preferences: UserNutritionPreferences.initial(uid),
    );
  }
}

class _InMemoryUiCatalogueService implements FoodCatalogueService {
  final List<FoodCategory> _cats;
  final List<FoodItem> _foods;
  _InMemoryUiCatalogueService(this._cats, this._foods);

  @override
  Future<void> ensureSeeded({String? jsonOverride, bool forceReload = false}) async {}

  @override
  Future<List<FoodCategory>> getCategories() async => _cats;

  @override
  Future<List<FoodItem>> searchFoods({
    String query = '',
    String? categoryId,
    String? dietaryPreference,
    bool verifiedOnly = true,
    bool favoritesOnly = false,
    String userId = 'local_guest',
    int limit = 250,
  }) async =>
      _foods;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
