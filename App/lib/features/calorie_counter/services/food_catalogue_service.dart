import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:sqflite/sqflite.dart';
import '../../../core/constants/database_constants.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/database/nutrition_database_schema.dart';
import '../../../core/utils/uuid_utils.dart';
import '../models/food_models.dart';
import '../models/food_request_model.dart';

class FoodCatalogueService {
  static final FoodCatalogueService instance = FoodCatalogueService._internal();
  FoodCatalogueService._internal();

  /// Exposed constructor for isolated test instances.
  factory FoodCatalogueService.createForTesting(DatabaseHelper dbHelper) =>
      FoodCatalogueService._withHelper(dbHelper);

  DatabaseHelper _dbHelper = DatabaseHelper.instance;
  FoodCatalogueService._withHelper(this._dbHelper);

  static const String catalogueAssetPath = 'assets/data/food_catalogue.json';
  static const String _catalogueVersionSettingKey =
      'nutrition_catalogue_version';

  bool _seededInSession = false;

  Future<Database> _db() async {
    final db = await _dbHelper.database;
    await NutritionDatabaseSchema.createTables(db);
    return db;
  }

  /// Ensures the verified local food catalogue is seeded into SQLite.
  /// Passing [jsonOverride] is useful for fast unit tests without asset loading.
  Future<void> ensureSeeded({
    String? jsonOverride,
    bool forceReload = false,
  }) async {
    if (_seededInSession && !forceReload && jsonOverride == null) return;

    final db = await _db();
    final rawJson =
        jsonOverride ?? await rootBundle.loadString(catalogueAssetPath);
    final decoded = jsonDecode(rawJson) as Map<String, dynamic>;
    final bundleVersion = (decoded['catalogueVersion'] ?? 1) as int;

    if (!forceReload) {
      final countRows = await db.rawQuery(
        'SELECT COUNT(*) AS cnt FROM ${NutritionDatabaseSchema.tableFoods}',
      );
      final count = (countRows.first['cnt'] as int?) ?? 0;

      int installedVersion = 0;
      try {
        final verRows = await db.query(
          DatabaseConstants.tableAppSettings,
          columns: [DatabaseConstants.columnValue],
          where: '${DatabaseConstants.columnKey} = ?',
          whereArgs: [_catalogueVersionSettingKey],
          limit: 1,
        );
        if (verRows.isNotEmpty) {
          installedVersion =
              int.tryParse(verRows.first[DatabaseConstants.columnValue].toString()) ??
                  0;
        }
      } catch (_) {}

      if (count > 0 && installedVersion >= bundleVersion) {
        _seededInSession = true;
        return;
      }
    }

    await seedFromDecodedJson(db, decoded, bundleVersion: bundleVersion);
    _seededInSession = true;
  }

  Future<void> seedFromDecodedJson(
    Database db,
    Map<String, dynamic> decoded, {
    int? bundleVersion,
  }) async {
    final version =
        bundleVersion ?? (decoded['catalogueVersion'] as int? ?? 1);
    final now = DateTime.now().toIso8601String();
    final categories = (decoded['categories'] as List<dynamic>? ?? const [])
        .map((e) => FoodCategory.fromJson(e as Map<String, dynamic>))
        .toList();
    final foods = (decoded['foods'] as List<dynamic>? ?? const [])
        .map((e) => FoodItem.fromJson(
              e as Map<String, dynamic>,
              catalogueVersion: version,
            ))
        .toList();

    await db.transaction((txn) async {
      final batch = txn.batch();

      for (final cat in categories) {
        batch.insert(
          NutritionDatabaseSchema.tableFoodCategories,
          cat.toDbMap(now),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      for (final food in foods) {
        batch.insert(
          NutritionDatabaseSchema.tableFoods,
          food.toFoodDbMap(now),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        batch.insert(
          NutritionDatabaseSchema.tableFoodNutrition,
          food.nutritionPer100g.toDbMap(food.id),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        batch.delete(
          NutritionDatabaseSchema.tableFoodServings,
          where: 'food_id = ?',
          whereArgs: [food.id],
        );
        for (final serving in food.servings) {
          batch.insert(
            NutritionDatabaseSchema.tableFoodServings,
            serving.toDbMap(),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }

      batch.insert(
        DatabaseConstants.tableAppSettings,
        {
          DatabaseConstants.columnKey: _catalogueVersionSettingKey,
          DatabaseConstants.columnValue: version.toString(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      await batch.commit(noResult: true);
    });
  }

  /// Inserts an arbitrary catalogue record directly (mainly for testing verification guards).
  Future<void> insertCustomFoodRecordForTesting(FoodItem food) async {
    final db = await _db();
    final now = DateTime.now().toIso8601String();
    await db.transaction((txn) async {
      await txn.insert(
        NutritionDatabaseSchema.tableFoods,
        food.toFoodDbMap(now),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await txn.insert(
        NutritionDatabaseSchema.tableFoodNutrition,
        food.nutritionPer100g.toDbMap(food.id),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      for (final serving in food.servings) {
        await txn.insert(
          NutritionDatabaseSchema.tableFoodServings,
          serving.toDbMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  Future<List<FoodCategory>> getCategories() async {
    await ensureSeeded();
    final db = await _db();
    final rows = await db.query(
      NutritionDatabaseSchema.tableFoodCategories,
      orderBy: 'sort_order ASC, name ASC',
    );
    return rows
        .map((r) => FoodCategory(
              id: r['id'] as String,
              slug: r['slug'] as String,
              name: r['name'] as String,
              description: (r['description'] ?? '') as String,
              iconKey: (r['icon_key'] ?? 'intl_plate') as String,
              sortOrder: (r['sort_order'] ?? 0) as int,
            ))
        .toList();
  }

  Future<Set<String>> getFavoriteFoodIds(String userId) async {
    final db = await _db();
    final rows = await db.query(
      NutritionDatabaseSchema.tableFoodFavorites,
      columns: ['food_id'],
      where: 'user_id = ?',
      whereArgs: [userId],
    );
    return rows.map((r) => r['food_id'] as String).toSet();
  }

  Future<bool> toggleFavorite(String userId, String foodId) async {
    final db = await _db();
    final existing = await db.query(
      NutritionDatabaseSchema.tableFoodFavorites,
      where: 'user_id = ? AND food_id = ?',
      whereArgs: [userId, foodId],
      limit: 1,
    );
    if (existing.isNotEmpty) {
      await db.delete(
        NutritionDatabaseSchema.tableFoodFavorites,
        where: 'user_id = ? AND food_id = ?',
        whereArgs: [userId, foodId],
      );
      return false;
    } else {
      await db.insert(
        NutritionDatabaseSchema.tableFoodFavorites,
        {
          'user_id': userId,
          'food_id': foodId,
          'created_at': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      return true;
    }
  }

  Future<List<FoodItem>> searchFoods({
    String query = '',
    String? categoryId,
    String? dietaryPreference,
    bool verifiedOnly = true,
    bool favoritesOnly = false,
    String userId = 'local_guest',
    int limit = 250,
  }) async {
    await ensureSeeded();
    final db = await _db();
    final favIds = await getFavoriteFoodIds(userId);

    final whereClauses = <String>[];
    final whereArgs = <dynamic>[];

    if (verifiedOnly) {
      whereClauses.add('f.is_verified = 1');
    }
    if (categoryId != null && categoryId.isNotEmpty && categoryId != 'all') {
      whereClauses.add('f.category_id = ?');
      whereArgs.add(categoryId);
    }
    final trimmed = query.trim().toLowerCase();
    if (trimmed.isNotEmpty) {
      final like = '%$trimmed%';
      whereClauses.add(
        '(LOWER(f.name) LIKE ? OR LOWER(f.common_names) LIKE ? OR LOWER(f.preparation_state) LIKE ?)',
      );
      whereArgs.addAll([like, like, like]);
    }

    final whereSql =
        whereClauses.isEmpty ? '' : 'WHERE ${whereClauses.join(' AND ')}';

    final rows = await db.rawQuery('''
      SELECT
        f.*,
        n.calories AS n_calories,
        n.protein AS n_protein,
        n.carbs AS n_carbs,
        n.fat AS n_fat,
        n.fibre AS n_fibre,
        n.sugar AS n_sugar,
        n.sodium_mg AS n_sodium_mg,
        n.saturated_fat AS n_saturated_fat,
        n.potassium_mg AS n_potassium_mg,
        n.calcium_mg AS n_calcium_mg,
        n.iron_mg AS n_iron_mg,
        n.vitamin_c_mg AS n_vitamin_c_mg
      FROM ${NutritionDatabaseSchema.tableFoods} f
      INNER JOIN ${NutritionDatabaseSchema.tableFoodNutrition} n
        ON n.food_id = f.id
      $whereSql
      ORDER BY f.name ASC
      LIMIT ?
    ''', [...whereArgs, limit]);

    if (rows.isEmpty) return const [];

    final foodIds = rows.map((r) => r['id'] as String).toList();
    final placeholders = List.filled(foodIds.length, '?').join(',');
    final servingRows = await db.rawQuery('''
      SELECT * FROM ${NutritionDatabaseSchema.tableFoodServings}
      WHERE food_id IN ($placeholders)
      ORDER BY sort_order ASC, is_default DESC
    ''', foodIds);

    final servingsByFood = <String, List<FoodServing>>{};
    for (final s in servingRows) {
      final fid = s['food_id'] as String;
      servingsByFood.putIfAbsent(fid, () => <FoodServing>[]).add(
            FoodServing(
              id: s['id'] as String,
              foodId: fid,
              label: s['label'] as String,
              unitType: (s['unit_type'] ?? 'piece') as String,
              gramsPerUnit: (s['grams_per_unit'] as num).toDouble(),
              isDefault: (s['is_default'] ?? 0) == 1,
              sortOrder: (s['sort_order'] ?? 0) as int,
            ),
          );
    }

    final items = <FoodItem>[];
    for (final r in rows) {
      final fid = r['id'] as String;
      final isFav = favIds.contains(fid);
      if (favoritesOnly && !isFav) continue;

      final item = _mapRowToFoodItem(
        r,
        servingsByFood[fid] ?? const [],
        isFavorite: isFav,
      );
      if (dietaryPreference != null &&
          dietaryPreference.isNotEmpty &&
          !item.matchesDietaryPreference(dietaryPreference)) {
        continue;
      }
      items.add(item);
    }

    // Sort prefix matches before substring matches when searching
    if (trimmed.isNotEmpty) {
      items.sort((a, b) {
        final aStarts = a.name.toLowerCase().startsWith(trimmed) ? 0 : 1;
        final bStarts = b.name.toLowerCase().startsWith(trimmed) ? 0 : 1;
        if (aStarts != bStarts) return aStarts.compareTo(bStarts);
        return a.name.compareTo(b.name);
      });
    }

    return items;
  }

  Future<FoodItem?> getFoodById(
    String foodId, {
    String userId = 'local_guest',
  }) async {
    await ensureSeeded();
    final db = await _db();
    final rows = await db.rawQuery('''
      SELECT
        f.*,
        n.calories AS n_calories,
        n.protein AS n_protein,
        n.carbs AS n_carbs,
        n.fat AS n_fat,
        n.fibre AS n_fibre,
        n.sugar AS n_sugar,
        n.sodium_mg AS n_sodium_mg,
        n.saturated_fat AS n_saturated_fat,
        n.potassium_mg AS n_potassium_mg,
        n.calcium_mg AS n_calcium_mg,
        n.iron_mg AS n_iron_mg,
        n.vitamin_c_mg AS n_vitamin_c_mg
      FROM ${NutritionDatabaseSchema.tableFoods} f
      INNER JOIN ${NutritionDatabaseSchema.tableFoodNutrition} n
        ON n.food_id = f.id
      WHERE f.id = ?
      LIMIT 1
    ''', [foodId]);

    if (rows.isEmpty) return null;

    final servingRows = await db.query(
      NutritionDatabaseSchema.tableFoodServings,
      where: 'food_id = ?',
      whereArgs: [foodId],
      orderBy: 'sort_order ASC, is_default DESC',
    );

    final favRows = await db.query(
      NutritionDatabaseSchema.tableFoodFavorites,
      where: 'user_id = ? AND food_id = ?',
      whereArgs: [userId, foodId],
      limit: 1,
    );

    final servings = servingRows
        .map((s) => FoodServing(
              id: s['id'] as String,
              foodId: foodId,
              label: s['label'] as String,
              unitType: (s['unit_type'] ?? 'piece') as String,
              gramsPerUnit: (s['grams_per_unit'] as num).toDouble(),
              isDefault: (s['is_default'] ?? 0) == 1,
              sortOrder: (s['sort_order'] ?? 0) as int,
            ))
        .toList();

    return _mapRowToFoodItem(
      rows.first,
      servings,
      isFavorite: favRows.isNotEmpty,
    );
  }

  /// Guard: only verified catalogue foods can be logged.
  Future<FoodItem> assertFoodLoggable(
    String foodId, {
    String userId = 'local_guest',
  }) async {
    final food = await getFoodById(foodId, userId: userId);
    if (food == null) {
      throw StateError('Food "$foodId" does not exist in the verified catalogue.');
    }
    if (!food.isVerified) {
      throw StateError(
        'Food "${food.name}" is unverified and cannot be logged until approved.',
      );
    }
    return food;
  }

  Future<FoodRequest> submitFoodRequest({
    required String userId,
    required String foodName,
    String categoryHint = '',
    String brandOrPreparation = '',
    String servingDescription = '',
    String referenceUrlOrNote = '',
  }) async {
    final cleanName = foodName.trim();
    if (cleanName.isEmpty) {
      throw ArgumentError('Food name cannot be empty.');
    }
    final db = await _db();
    final now = DateTime.now().toIso8601String();
    final request = FoodRequest(
      id: UuidUtils.v4(),
      userId: userId,
      foodName: cleanName,
      categoryHint: categoryHint.trim(),
      brandOrPreparation: brandOrPreparation.trim(),
      servingDescription: servingDescription.trim(),
      referenceUrlOrNote: referenceUrlOrNote.trim(),
      status: 'pending',
      createdAt: now,
      updatedAt: now,
      syncStatus: 'pending',
    );

    await db.insert(
      NutritionDatabaseSchema.tableFoodRequests,
      request.toDbMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return request;
  }

  Future<List<FoodRequest>> getFoodRequests(String userId) async {
    final db = await _db();
    final rows = await db.query(
      NutritionDatabaseSchema.tableFoodRequests,
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'created_at DESC',
    );
    return rows.map(FoodRequest.fromDbMap).toList();
  }

  FoodItem _mapRowToFoodItem(
    Map<String, dynamic> r,
    List<FoodServing> servings, {
    required bool isFavorite,
  }) {
    double? opt(String k) => r[k] == null ? null : (r[k] as num).toDouble();
    double req(String k) => ((r[k] as num?) ?? 0).toDouble();

    List<String> decodeTags(dynamic raw) {
      if (raw is String && raw.isNotEmpty) {
        try {
          final parsed = jsonDecode(raw);
          if (parsed is List) {
            return parsed.map((e) => e.toString()).toList();
          }
        } catch (_) {}
      }
      return const [];
    }

    return FoodItem(
      id: r['id'] as String,
      name: r['name'] as String,
      commonNames: (r['common_names'] ?? '') as String,
      categoryId: r['category_id'] as String,
      illustrationId: (r['illustration_id'] ?? 'generic') as String,
      preparationState: (r['preparation_state'] ?? '') as String,
      dietaryTags: decodeTags(r['dietary_tags']),
      allergenTags: decodeTags(r['allergen_tags']),
      sourceName: (r['source_name'] ?? '') as String,
      sourceReference: (r['source_reference'] ?? '') as String,
      sourceLicense: (r['source_license'] ?? '') as String,
      isVerified: (r['is_verified'] ?? 0) == 1,
      isComplete: (r['is_complete'] ?? 1) == 1,
      verificationNotes: (r['verification_notes'] ?? '') as String,
      catalogueVersion: (r['catalogue_version'] ?? 1) as int,
      nutritionPer100g: FoodNutrition(
        calories: req('n_calories'),
        protein: req('n_protein'),
        carbs: req('n_carbs'),
        fat: req('n_fat'),
        fibre: req('n_fibre'),
        sugar: opt('n_sugar'),
        sodiumMg: opt('n_sodium_mg'),
        saturatedFat: opt('n_saturated_fat'),
        potassiumMg: opt('n_potassium_mg'),
        calciumMg: opt('n_calcium_mg'),
        ironMg: opt('n_iron_mg'),
        vitaminCMg: opt('n_vitamin_c_mg'),
      ),
      servings: servings,
      isFavorite: isFavorite,
    );
  }
}

