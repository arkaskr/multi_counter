import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:sqflite/sqflite.dart';
import '../../../core/config/app_config.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/database/nutrition_database_schema.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/utils/uuid_utils.dart';
import '../models/diet_plan_models.dart';
import '../models/food_models.dart';
import '../models/meal_log_model.dart';
import '../models/nutrition_goal_models.dart';
import 'food_catalogue_service.dart';
import 'meal_log_service.dart';

class DietGenerationResult {
  final DietPlan plan;
  final bool usedFallback;
  final String notice;

  const DietGenerationResult({
    required this.plan,
    required this.usedFallback,
    required this.notice,
  });
}

class DietPlannerService {
  static final DietPlannerService instance = DietPlannerService._internal();
  DietPlannerService._internal()
      : _dbHelper = DatabaseHelper.instance,
        _catalogueService = FoodCatalogueService.instance,
        _mealLogService = MealLogService.instance,
        _httpClient = http.Client(),
        _authService = AuthService.instance;

  factory DietPlannerService.createForTesting({
    required DatabaseHelper dbHelper,
    required FoodCatalogueService catalogueService,
    required MealLogService mealLogService,
    http.Client? httpClient,
    AuthService? authService,
  }) =>
      DietPlannerService._withDeps(
        dbHelper: dbHelper,
        catalogueService: catalogueService,
        mealLogService: mealLogService,
        httpClient: httpClient,
        authService: authService,
      );

  final DatabaseHelper _dbHelper;
  final FoodCatalogueService _catalogueService;
  final MealLogService _mealLogService;
  final http.Client _httpClient;
  final AuthService _authService;

  DietPlannerService._withDeps({
    required DatabaseHelper dbHelper,
    required FoodCatalogueService catalogueService,
    required MealLogService mealLogService,
    http.Client? httpClient,
    AuthService? authService,
  })  : _dbHelper = dbHelper,
        _catalogueService = catalogueService,
        _mealLogService = mealLogService,
        _httpClient = httpClient ?? http.Client(),
        _authService = authService ?? AuthService.instance;

  Future<Database> _db() async {
    final db = await _dbHelper.database;
    await NutritionDatabaseSchema.createTables(db);
    return db;
  }

  /// Generates a personalized diet plan via backend Gemini service when online
  /// and signed in; seamlessly falls back to verified rules-based planner if
  /// offline, in guest mode, rate-limited, or Gemini quota is unavailable.
  Future<DietGenerationResult> generatePlan({
    required String userId,
    required DailyNutritionGoal goal,
    required UserNutritionPreferences preferences,
    String customInstructions = '',
  }) async {
    final token = _authService.token;
    final canCallBackend =
        _authService.isLoggedIn && !_authService.isGuestMode && token != null;

    if (canCallBackend) {
      try {
        final response = await _httpClient
            .post(
              Uri.parse('${AppConfig.apiBaseUrl}/nutrition/diet-plans/generate'),
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer $token',
              },
              body: jsonEncode({
                'dailyGoal': {
                  'calories': goal.calories,
                  'protein': goal.protein,
                  'carbs': goal.carbs,
                  'fat': goal.fat,
                  'fibre': goal.fibre,
                },
                'preferences': preferences.toApiJson(),
                'instructions': customInstructions,
              }),
            )
            .timeout(const Duration(seconds: 25));

        if (response.statusCode == 200 || response.statusCode == 201) {
          final body = jsonDecode(response.body) as Map<String, dynamic>;
          final planJson = body['plan'] as Map<String, dynamic>;
          final plan = DietPlan.fromApiJson(planJson, userId);
          final usedFallback = body['usedFallback'] == true ||
              plan.generatedBy == 'fallback';
          final notice = (body['notice'] ??
                  (usedFallback
                      ? 'Generated using rules-based verified planner.'
                      : 'Generated with Gemini AI & validated against verified catalogue.'))
              as String;
          return DietGenerationResult(
            plan: plan,
            usedFallback: usedFallback,
            notice: notice,
          );
        }

        if (response.statusCode == 429) {
          final fallbackPlan = await buildRulesBasedFallbackPlan(
            userId: userId,
            goal: goal,
            preferences: preferences,
          );
          return DietGenerationResult(
            plan: fallbackPlan,
            usedFallback: true,
            notice:
                'AI rate limit or free-tier quota reached. Generated a rules-based plan using verified catalogue foods instead.',
          );
        }
      } catch (_) {
        // Offline or network timeout -> local rules-based fallback below
      }
    }

    final fallbackPlan = await buildRulesBasedFallbackPlan(
      userId: userId,
      goal: goal,
      preferences: preferences,
    );
    return DietGenerationResult(
      plan: fallbackPlan,
      usedFallback: true,
      notice: canCallBackend
          ? 'Server unavailable. Created an offline balanced plan from our verified catalogue.'
          : 'Sign in for Gemini AI personalization. Created an offline balanced plan from our verified catalogue.',
    );
  }

  /// Deterministic rules-based diet planner using strictly verified catalogue foods.
  Future<DietPlan> buildRulesBasedFallbackPlan({
    required String userId,
    required DailyNutritionGoal goal,
    required UserNutritionPreferences preferences,
  }) async {
    await _catalogueService.ensureSeeded();
    final excluded = preferences.excludedFoodIds.toSet();
    final allergies =
        preferences.allergies.map((a) => a.toLowerCase().trim()).toSet();

    Future<FoodItem?> pickFood(List<String> candidateIds) async {
      for (final fid in candidateIds) {
        if (excluded.contains(fid)) continue;
        final f = await _catalogueService.getFoodById(fid, userId: userId);
        if (f == null || !f.isVerified) continue;
        if (!f.matchesDietaryPreference(preferences.dietaryPreference)) continue;
        final hasAllergen = f.allergenTags.any((tag) {
          final lower = tag.toLowerCase();
          return allergies.any(
            (a) => lower == a || lower.contains(a) || a.contains(lower),
          );
        });
        if (hasAllergen) continue;
        return f;
      }
      return null;
    }

    final now = DateTime.now().toIso8601String();
    final planId = UuidUtils.v4();
    final scaleFactor = (goal.calories / 2000.0).clamp(0.6, 1.8);

    double snapCount(double raw) {
      final halfSteps = (raw * 2).round() / 2.0;
      return halfSteps.clamp(0.5, 4.0);
    }

    Future<DietPlanItem?> makeItem(
      String mealId,
      List<String> foodIds,
      String preferredServingId,
      double baseCount,
      int sortOrder,
    ) async {
      final food = await pickFood(foodIds);
      if (food == null) return null;
      FoodServing serving = food.defaultServing;
      for (final s in food.servings) {
        if (s.id == preferredServingId) {
          serving = s;
          break;
        }
      }
      final count = snapCount(baseCount * scaleFactor);
      final calc = NutritionCalculator.calculateForServing(
        per100g: food.nutritionPer100g,
        serving: serving,
        servingCount: count,
      );
      return DietPlanItem(
        id: UuidUtils.v4(),
        mealId: mealId,
        foodId: food.id,
        foodNameSnapshot: food.name,
        illustrationSnapshot: food.illustrationId,
        servingId: serving.id,
        servingLabelSnapshot: serving.label,
        servingCount: count,
        gramsPerUnit: serving.gramsPerUnit,
        totalGrams: calc.totalGrams,
        calories: calc.calories,
        protein: calc.protein,
        carbs: calc.carbs,
        fat: calc.fat,
        fibre: calc.fibre,
        sortOrder: sortOrder,
      );
    }

    final timings = preferences.preferredMealTimings;
    final mealSpecs = <({
      MealCategory cat,
      String explanation,
      List<Future<DietPlanItem?> Function(String mealId)> builders,
    })>[
      (
        cat: MealCategory.breakfast,
        explanation:
            'Balanced complex carbohydrates and morning protein to kickstart energy.',
        builders: [
          (mId) => makeItem(
                mId,
                ['poha_veg', 'oats_cooked_water', 'idli_steamed'],
                'bowl_poha',
                1.0,
                0,
              ),
          (mId) => makeItem(
                mId,
                ['egg_boiled', 'paneer_fresh', 'tofu_firm', 'milk_toned'],
                'one_boiled_egg',
                2.0,
                1,
              ),
        ],
      ),
      (
        cat: MealCategory.morningSnack,
        explanation: 'Light micronutrient and healthy-fat mid-morning boost.',
        builders: [
          (mId) => makeItem(
                mId,
                ['apple_raw', 'banana_ripe', 'orange_raw', 'guava_raw'],
                'med_apple',
                1.0,
                0,
              ),
          (mId) => makeItem(
                mId,
                ['almonds_raw', 'walnuts_raw', 'chia_seeds', 'peanuts_roasted'],
                'ten_almonds',
                1.0,
                1,
              ),
        ],
      ),
      (
        cat: MealCategory.lunch,
        explanation:
            'Steady energy lunch combining grain, legume/lean protein and fibre.',
        builders: [
          (mId) => makeItem(mId, ['roti_plain', 'rice_brown_cooked'], 'med_roti', 2.0, 0),
          (mId) => makeItem(
                mId,
                ['dal_plain', 'rajma_curry', 'chole_curry', 'dal_tadka'],
                'bowl_dal',
                1.0,
                1,
              ),
          (mId) => makeItem(
                mId,
                ['curd_dahi', 'cucumber_raw', 'carrot_raw'],
                'bowl_curd',
                1.0,
                2,
              ),
        ],
      ),
      (
        cat: MealCategory.eveningSnack,
        explanation: 'Low-calorie beverage paired with light roasted/whole snack.',
        builders: [
          (mId) => makeItem(
                mId,
                ['tea_green_plain', 'coffee_black', 'buttermilk_chaas', 'coconut_water'],
                'cup_green_tea',
                1.0,
                0,
              ),
          (mId) => makeItem(
                mId,
                ['peanuts_roasted', 'papaya_raw', 'watermelon_raw'],
                'handful_peanuts',
                1.0,
                1,
              ),
        ],
      ),
      (
        cat: MealCategory.dinner,
        explanation: 'Satiating dinner supporting recovery and overnight protein needs.',
        builders: [
          (mId) => makeItem(mId, ['roti_plain', 'khichdi_moong', 'rice_white_cooked'], 'med_roti', 2.0, 0),
          (mId) => makeItem(
                mId,
                [
                  if (preferences.dietaryPreference == 'non_vegetarian')
                    'chicken_breast_cooked',
                  if (preferences.dietaryPreference == 'non_vegetarian')
                    'chicken_curry',
                  'paneer_bhurji',
                  'tofu_firm',
                  'dal_plain',
                ],
                'bowl_paneer_bhurji',
                1.0,
                1,
              ),
        ],
      ),
    ];

    final meals = <DietPlanMeal>[];
    for (var i = 0; i < mealSpecs.length; i++) {
      final spec = mealSpecs[i];
      final mealId = UuidUtils.v4();
      final items = <DietPlanItem>[];
      for (final b in spec.builders) {
        final item = await b(mealId);
        if (item != null) items.add(item);
      }
      if (items.isNotEmpty) {
        meals.add(DietPlanMeal(
          id: mealId,
          planId: planId,
          mealCategory: spec.cat,
          mealTiming: timings[spec.cat.key] ?? '',
          explanation: spec.explanation,
          sortOrder: i,
          items: items,
        ));
      }
    }

    return DietPlan(
      id: planId,
      userId: userId,
      title: 'Balanced ${preferences.fitnessObjective.replaceAll('_', ' ')} Plan',
      targetCalories: goal.calories,
      targetProtein: goal.protein,
      targetCarbs: goal.carbs,
      targetFat: goal.fat,
      targetFibre: goal.fibre,
      dietaryPreference: preferences.dietaryPreference,
      fitnessObjective: preferences.fitnessObjective,
      generatedBy: 'fallback',
      modelName: 'rules-v1',
      aiNotes:
          'Calculated strictly from verified food nutrition data matching your dietary preferences.',
      createdAt: now,
      updatedAt: now,
      syncStatus: 'pending',
      meals: meals,
    );
  }

  /// Replaces an item inside a draft/saved plan with another verified food & recalculates macros.
  Future<DietPlan> replacePlanItem({
    required DietPlan plan,
    required String mealId,
    required String itemId,
    required FoodItem replacementFood,
    FoodServing? serving,
    double servingCount = 1.0,
  }) async {
    if (!replacementFood.isVerified) {
      throw StateError('Only verified catalogue foods can be added to a plan.');
    }
    final chosenServing = serving ?? replacementFood.defaultServing;
    final calc = NutritionCalculator.calculateForServing(
      per100g: replacementFood.nutritionPer100g,
      serving: chosenServing,
      servingCount: servingCount,
    );

    final updatedMeals = plan.meals.map((meal) {
      if (meal.id != mealId) return meal;
      final newItems = meal.items.map((item) {
        if (item.id != itemId) return item;
        return DietPlanItem(
          id: item.id,
          mealId: meal.id,
          foodId: replacementFood.id,
          foodNameSnapshot: replacementFood.name,
          illustrationSnapshot: replacementFood.illustrationId,
          servingId: chosenServing.id,
          servingLabelSnapshot: chosenServing.label,
          servingCount: servingCount,
          gramsPerUnit: chosenServing.gramsPerUnit,
          totalGrams: calc.totalGrams,
          calories: calc.calories,
          protein: calc.protein,
          carbs: calc.carbs,
          fat: calc.fat,
          fibre: calc.fibre,
          sortOrder: item.sortOrder,
        );
      }).toList();

      return DietPlanMeal(
        id: meal.id,
        planId: meal.planId,
        mealCategory: meal.mealCategory,
        mealTiming: meal.mealTiming,
        explanation: meal.explanation,
        sortOrder: meal.sortOrder,
        items: newItems,
      );
    }).toList();

    return plan.copyWith(
      meals: updatedMeals,
      updatedAt: DateTime.now().toIso8601String(),
      syncStatus: 'pending',
    );
  }

  /// Adjusts serving count on a plan item, recalculating verified nutrition.
  Future<DietPlan> adjustPlanItemQuantity({
    required DietPlan plan,
    required String mealId,
    required String itemId,
    required double newServingCount,
  }) async {
    if (newServingCount <= 0) {
      throw ArgumentError.value(newServingCount, 'newServingCount', 'Must be > 0');
    }

    final updatedMeals = <DietPlanMeal>[];
    for (final meal in plan.meals) {
      if (meal.id != mealId) {
        updatedMeals.add(meal);
        continue;
      }
      final newItems = <DietPlanItem>[];
      for (final item in meal.items) {
        if (item.id != itemId) {
          newItems.add(item);
          continue;
        }
        final food =
            await _catalogueService.getFoodById(item.foodId, userId: plan.userId);
        double cal, prot, carbs, fat, fibre, grams;
        if (food != null) {
          final calc = NutritionCalculator.calculateForGrams(
            per100g: food.nutritionPer100g,
            totalGrams: item.gramsPerUnit * newServingCount,
          );
          cal = calc.calories;
          prot = calc.protein;
          carbs = calc.carbs;
          fat = calc.fat;
          fibre = calc.fibre;
          grams = calc.totalGrams;
        } else {
          final ratio = newServingCount / item.servingCount;
          double r1(double v) => (v * 10).roundToDouble() / 10;
          grams = r1(item.gramsPerUnit * newServingCount);
          cal = r1(item.calories * ratio);
          prot = r1(item.protein * ratio);
          carbs = r1(item.carbs * ratio);
          fat = r1(item.fat * ratio);
          fibre = r1(item.fibre * ratio);
        }

        newItems.add(DietPlanItem(
          id: item.id,
          mealId: meal.id,
          foodId: item.foodId,
          foodNameSnapshot: item.foodNameSnapshot,
          illustrationSnapshot: item.illustrationSnapshot,
          servingId: item.servingId,
          servingLabelSnapshot: item.servingLabelSnapshot,
          servingCount: newServingCount,
          gramsPerUnit: item.gramsPerUnit,
          totalGrams: grams,
          calories: cal,
          protein: prot,
          carbs: carbs,
          fat: fat,
          fibre: fibre,
          sortOrder: item.sortOrder,
        ));
      }
      updatedMeals.add(DietPlanMeal(
        id: meal.id,
        planId: meal.planId,
        mealCategory: meal.mealCategory,
        mealTiming: meal.mealTiming,
        explanation: meal.explanation,
        sortOrder: meal.sortOrder,
        items: newItems,
      ));
    }

    return plan.copyWith(
      meals: updatedMeals,
      updatedAt: DateTime.now().toIso8601String(),
      syncStatus: 'pending',
    );
  }

  Future<DietPlan> savePlan(
    DietPlan plan, {
    bool isAccepted = false,
    bool isSaved = true,
  }) async {
    final db = await _db();
    final updated = plan.copyWith(
      isAccepted: isAccepted || plan.isAccepted,
      isSaved: isSaved,
      updatedAt: DateTime.now().toIso8601String(),
      syncStatus: 'pending',
    );

    await db.transaction((txn) async {
      await txn.insert(
        NutritionDatabaseSchema.tableDietPlans,
        updated.toDbMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await txn.delete(
        NutritionDatabaseSchema.tableDietPlanMeals,
        where: 'plan_id = ?',
        whereArgs: [updated.id],
      );
      for (final meal in updated.meals) {
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
    });
    return updated;
  }

  Future<List<DietPlan>> getSavedPlans(String userId) async {
    final db = await _db();
    final planRows = await db.query(
      NutritionDatabaseSchema.tableDietPlans,
      where: 'user_id = ? AND is_deleted = 0',
      whereArgs: [userId],
      orderBy: 'updated_at DESC',
    );
    if (planRows.isEmpty) return const [];

    final plans = <DietPlan>[];
    for (final pRow in planRows) {
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
      plans.add(DietPlan.fromDbMap(pRow, meals));
    }
    return plans;
  }

  Future<void> deleteSavedPlan(String userId, String planId) async {
    final db = await _db();
    await db.update(
      NutritionDatabaseSchema.tableDietPlans,
      {
        'is_deleted': 1,
        'sync_status': 'pending',
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ? AND user_id = ?',
      whereArgs: [planId, userId],
    );
  }

  /// Explicitly logs a confirmed meal from a diet plan into actual consumption.
  Future<List<FoodLog>> confirmAndLogPlanMeal({
    required String userId,
    required String date,
    required DietPlanMeal meal,
  }) async {
    final inputs = meal.items
        .map((i) => MealLogInput(
              foodId: i.foodId,
              servingId: i.servingId,
              servingCount: i.servingCount,
              notes: 'Logged from diet plan',
            ))
        .toList();
    return _mealLogService.logMultipleFoods(
      userId: userId,
      date: date,
      mealCategory: meal.mealCategory,
      items: inputs,
    );
  }
}
