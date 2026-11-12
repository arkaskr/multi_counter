import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:daily_counter/core/constants/database_constants.dart';
import 'package:daily_counter/core/database/database_helper.dart';
import 'package:daily_counter/core/database/database_schema.dart';
import 'package:daily_counter/core/database/nutrition_database_schema.dart';
import 'package:daily_counter/features/calorie_counter/models/food_models.dart';
import 'package:daily_counter/features/calorie_counter/services/food_catalogue_service.dart';

void main() {
  sqfliteFfiInit();

  late Database db;
  late DatabaseHelper dbHelper;
  late FoodCatalogueService catalogueService;
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
  });

  tearDown(() async {
    await db.close();
    DatabaseHelper.resetForTesting();
  });

  test('seeds 8 categories and verified Indian & International foods', () async {
    final categories = await catalogueService.getCategories();
    expect(categories.length, 8);
    expect(
      categories.map((c) => c.id),
      containsAll([
        'indian_meals',
        'fruits',
        'vegetables',
        'dairy',
        'nuts_seeds',
        'protein',
        'beverages',
        'international',
      ]),
    );

    final allFoods = await catalogueService.searchFoods(limit: 500);
    expect(allFoods.length, greaterThanOrEqualTo(80));
    expect(allFoods.every((f) => f.isVerified), isTrue);
    expect(allFoods.every((f) => f.sourceName.isNotEmpty), isTrue);
  });

  test('distinguishes preparation methods accurately', () async {
    final riceRaw = await catalogueService.getFoodById('rice_white_raw');
    final riceCooked = await catalogueService.getFoodById('rice_white_cooked');
    expect(riceRaw, isNotNull);
    expect(riceCooked, isNotNull);
    expect(riceRaw!.nutritionPer100g.calories, greaterThan(riceCooked!.nutritionPer100g.calories));

    final chickenRaw = await catalogueService.getFoodById('chicken_breast_raw');
    final chickenCooked = await catalogueService.getFoodById('chicken_breast_cooked');
    expect(chickenRaw, isNotNull);
    expect(chickenCooked, isNotNull);
    expect(chickenCooked!.nutritionPer100g.protein, greaterThan(chickenRaw!.nutritionPer100g.protein));

    final roti = await catalogueService.getFoodById('roti_plain');
    final paratha = await catalogueService.getFoodById('paratha_plain');
    expect(paratha!.nutritionPer100g.fat, greaterThan(roti!.nutritionPer100g.fat));

    final dalPlain = await catalogueService.getFoodById('dal_plain');
    final dalTadka = await catalogueService.getFoodById('dal_tadka');
    expect(dalTadka!.nutritionPer100g.calories, greaterThan(dalPlain!.nutritionPer100g.calories));

    final eggBoiled = await catalogueService.getFoodById('egg_boiled');
    final eggFried = await catalogueService.getFoodById('egg_fried');
    expect(eggFried!.nutritionPer100g.calories, greaterThan(eggBoiled!.nutritionPer100g.calories));
  });

  test('calculates nutrients strictly using per100g * grams / 100', () async {
    final roti = (await catalogueService.getFoodById('roti_plain'))!;
    final medRoti = roti.servings.firstWhere((s) => s.id == 'med_roti'); // 35g
    final calc = NutritionCalculator.calculateForServing(
      per100g: roti.nutritionPer100g,
      serving: medRoti,
      servingCount: 2, // 70g
    );

    expect(calc.totalGrams, 70.0);
    expect(calc.calories, closeTo(roti.nutritionPer100g.calories * 0.7, 0.2));
    expect(calc.protein, closeTo(roti.nutritionPer100g.protein * 0.7, 0.2));
    expect(calc.carbs, closeTo(roti.nutritionPer100g.carbs * 0.7, 0.2));
    expect(calc.fat, closeTo(roti.nutritionPer100g.fat * 0.7, 0.2));
    expect(calc.fibre, closeTo(roti.nutritionPer100g.fibre * 0.7, 0.2));
  });

  test('rejects logging unverified or nonexistent foods and allows pending requests', () async {
    const unverified = FoodItem(
      id: 'unverified_custom_x',
      name: 'Random Street Mystery',
      commonNames: 'mystery',
      categoryId: 'indian_meals',
      illustrationId: 'generic',
      preparationState: 'Unknown',
      dietaryTags: ['vegetarian'],
      allergenTags: [],
      sourceName: 'User submission',
      sourceReference: 'Pending verification',
      sourceLicense: '',
      isVerified: false,
      isComplete: false,
      verificationNotes: 'Pending review',
      catalogueVersion: 1,
      nutritionPer100g: FoodNutrition.zero,
      servings: [
        FoodServing(
          id: 'g_100',
          foodId: 'unverified_custom_x',
          label: '100 g',
          unitType: 'gram',
          gramsPerUnit: 100,
          isDefault: true,
          sortOrder: 1,
        ),
      ],
    );
    await catalogueService.insertCustomFoodRecordForTesting(unverified);

    // Search verifiedOnly excludes unverified items
    final visibleSearch =
        await catalogueService.searchFoods(query: 'Mystery', verifiedOnly: true);
    expect(visibleSearch, isEmpty);

    await expectLater(
      () => catalogueService.assertFoodLoggable('unverified_custom_x'),
      throwsStateError,
    );
    await expectLater(
      () => catalogueService.assertFoodLoggable('nonexistent_food'),
      throwsStateError,
    );

    final req = await catalogueService.submitFoodRequest(
      userId: 'user_1',
      foodName: 'Masala Chaas',
      categoryHint: 'beverages',
      servingDescription: '1 glass (250 ml)',
    );
    expect(req.status, 'pending');
    final requests = await catalogueService.getFoodRequests('user_1');
    expect(requests.length, 1);
    expect(requests.first.foodName, 'Masala Chaas');
  });

  test('supports search, dietary filter, and favorites per user', () async {
    final vegResults = await catalogueService.searchFoods(
      categoryId: 'protein',
      dietaryPreference: 'vegan',
    );
    expect(vegResults.any((f) => f.id == 'chicken_breast_cooked'), isFalse);
    expect(vegResults.any((f) => f.id == 'tofu_firm'), isTrue);

    await catalogueService.toggleFavorite('user_a', 'roti_plain');
    final favsA = await catalogueService.searchFoods(
      favoritesOnly: true,
      userId: 'user_a',
    );
    final favsB = await catalogueService.searchFoods(
      favoritesOnly: true,
      userId: 'user_b',
    );
    expect(favsA.map((e) => e.id), ['roti_plain']);
    expect(favsB, isEmpty);
  });
}
