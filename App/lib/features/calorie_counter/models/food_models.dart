import 'dart:convert';

class FoodCategory {
  final String id;
  final String slug;
  final String name;
  final String description;
  final String iconKey;
  final int sortOrder;

  const FoodCategory({
    required this.id,
    required this.slug,
    required this.name,
    required this.description,
    required this.iconKey,
    required this.sortOrder,
  });

  factory FoodCategory.fromJson(Map<String, dynamic> json) {
    return FoodCategory(
      id: json['id'] as String,
      slug: (json['slug'] ?? json['id']) as String,
      name: json['name'] as String,
      description: (json['description'] ?? '') as String,
      iconKey: (json['iconKey'] ?? json['icon_key'] ?? 'intl_plate') as String,
      sortOrder: (json['sortOrder'] ?? json['sort_order'] ?? 0) as int,
    );
  }

  Map<String, dynamic> toDbMap(String updatedAt) => {
        'id': id,
        'slug': slug,
        'name': name,
        'description': description,
        'icon_key': iconKey,
        'sort_order': sortOrder,
        'updated_at': updatedAt,
      };
}

class FoodNutrition {
  final double calories;
  final double protein;
  final double carbs;
  final double fat;
  final double fibre;
  final double? sugar;
  final double? sodiumMg;
  final double? saturatedFat;
  final double? potassiumMg;
  final double? calciumMg;
  final double? ironMg;
  final double? vitaminCMg;

  const FoodNutrition({
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.fibre,
    this.sugar,
    this.sodiumMg,
    this.saturatedFat,
    this.potassiumMg,
    this.calciumMg,
    this.ironMg,
    this.vitaminCMg,
  });

  static const FoodNutrition zero = FoodNutrition(
    calories: 0,
    protein: 0,
    carbs: 0,
    fat: 0,
    fibre: 0,
  );

  static double? _toNullableDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  static double _toDouble(dynamic v, [double fallback = 0]) {
    if (v == null) return fallback;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? fallback;
  }

  factory FoodNutrition.fromJson(Map<String, dynamic> json) {
    return FoodNutrition(
      calories: _toDouble(json['calories']),
      protein: _toDouble(json['protein']),
      carbs: _toDouble(json['carbs']),
      fat: _toDouble(json['fat']),
      fibre: _toDouble(json['fibre']),
      sugar: _toNullableDouble(json['sugar']),
      sodiumMg: _toNullableDouble(json['sodiumMg'] ?? json['sodium_mg']),
      saturatedFat:
          _toNullableDouble(json['saturatedFat'] ?? json['saturated_fat']),
      potassiumMg:
          _toNullableDouble(json['potassiumMg'] ?? json['potassium_mg']),
      calciumMg: _toNullableDouble(json['calciumMg'] ?? json['calcium_mg']),
      ironMg: _toNullableDouble(json['ironMg'] ?? json['iron_mg']),
      vitaminCMg: _toNullableDouble(json['vitaminCMg'] ?? json['vitamin_c_mg']),
    );
  }

  Map<String, dynamic> toDbMap(String foodId) => {
        'food_id': foodId,
        'calories': calories,
        'protein': protein,
        'carbs': carbs,
        'fat': fat,
        'fibre': fibre,
        'sugar': sugar,
        'sodium_mg': sodiumMg,
        'saturated_fat': saturatedFat,
        'potassium_mg': potassiumMg,
        'calcium_mg': calciumMg,
        'iron_mg': ironMg,
        'vitamin_c_mg': vitaminCMg,
        'extra_nutrients_json': '{}',
      };
}

class FoodServing {
  final String id;
  final String foodId;
  final String label;
  final String unitType;
  final double gramsPerUnit;
  final bool isDefault;
  final int sortOrder;

  const FoodServing({
    required this.id,
    required this.foodId,
    required this.label,
    required this.unitType,
    required this.gramsPerUnit,
    required this.isDefault,
    required this.sortOrder,
  });

  factory FoodServing.fromJson(Map<String, dynamic> json, {String? foodId}) {
    return FoodServing(
      id: json['id'] as String,
      foodId: (foodId ?? json['foodId'] ?? json['food_id'] ?? '') as String,
      label: json['label'] as String,
      unitType: (json['unitType'] ?? json['unit_type'] ?? 'piece') as String,
      gramsPerUnit:
          ((json['gramsPerUnit'] ?? json['grams_per_unit']) as num).toDouble(),
      isDefault: (json['isDefault'] ?? json['is_default']) == true ||
          (json['isDefault'] ?? json['is_default']) == 1,
      sortOrder: (json['sortOrder'] ?? json['sort_order'] ?? 0) as int,
    );
  }

  Map<String, dynamic> toDbMap() => {
        'id': id,
        'food_id': foodId,
        'label': label,
        'unit_type': unitType,
        'grams_per_unit': gramsPerUnit,
        'is_default': isDefault ? 1 : 0,
        'sort_order': sortOrder,
      };
}

class CalculatedNutrition {
  final double totalGrams;
  final double calories;
  final double protein;
  final double carbs;
  final double fat;
  final double fibre;
  final double? sugar;
  final double? sodiumMg;
  final double? saturatedFat;
  final double? potassiumMg;
  final double? calciumMg;
  final double? ironMg;
  final double? vitaminCMg;

  const CalculatedNutrition({
    required this.totalGrams,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.fibre,
    this.sugar,
    this.sodiumMg,
    this.saturatedFat,
    this.potassiumMg,
    this.calciumMg,
    this.ironMg,
    this.vitaminCMg,
  });
}

class NutritionCalculator {
  NutritionCalculator._();

  static double _round1(double value) => (value * 10).roundToDouble() / 10;
  static double _round2(double value) => (value * 100).roundToDouble() / 100;

  /// Nutrient amount = Nutrient per 100 g * selected quantity in grams / 100
  static CalculatedNutrition calculateForGrams({
    required FoodNutrition per100g,
    required double totalGrams,
  }) {
    if (totalGrams < 0) {
      throw ArgumentError.value(totalGrams, 'totalGrams', 'Must be >= 0');
    }
    final factor = totalGrams / 100.0;
    double? scale(double? val) => val == null ? null : _round2(val * factor);

    return CalculatedNutrition(
      totalGrams: _round1(totalGrams),
      calories: _round1(per100g.calories * factor),
      protein: _round1(per100g.protein * factor),
      carbs: _round1(per100g.carbs * factor),
      fat: _round1(per100g.fat * factor),
      fibre: _round1(per100g.fibre * factor),
      sugar: scale(per100g.sugar),
      sodiumMg: scale(per100g.sodiumMg),
      saturatedFat: scale(per100g.saturatedFat),
      potassiumMg: scale(per100g.potassiumMg),
      calciumMg: scale(per100g.calciumMg),
      ironMg: scale(per100g.ironMg),
      vitaminCMg: scale(per100g.vitaminCMg),
    );
  }

  static CalculatedNutrition calculateForServing({
    required FoodNutrition per100g,
    required FoodServing serving,
    required double servingCount,
  }) {
    if (servingCount <= 0) {
      throw ArgumentError.value(
          servingCount, 'servingCount', 'Must be > 0');
    }
    return calculateForGrams(
      per100g: per100g,
      totalGrams: serving.gramsPerUnit * servingCount,
    );
  }
}

class FoodItem {
  final String id;
  final String name;
  final String commonNames;
  final String categoryId;
  final String illustrationId;
  final String preparationState;
  final List<String> dietaryTags;
  final List<String> allergenTags;
  final String sourceName;
  final String sourceReference;
  final String sourceLicense;
  final bool isVerified;
  final bool isComplete;
  final String verificationNotes;
  final int catalogueVersion;
  final FoodNutrition nutritionPer100g;
  final List<FoodServing> servings;
  final bool isFavorite;

  const FoodItem({
    required this.id,
    required this.name,
    required this.commonNames,
    required this.categoryId,
    required this.illustrationId,
    required this.preparationState,
    required this.dietaryTags,
    required this.allergenTags,
    required this.sourceName,
    required this.sourceReference,
    required this.sourceLicense,
    required this.isVerified,
    required this.isComplete,
    required this.verificationNotes,
    required this.catalogueVersion,
    required this.nutritionPer100g,
    required this.servings,
    this.isFavorite = false,
  });

  FoodServing get defaultServing {
    for (final s in servings) {
      if (s.isDefault) return s;
    }
    if (servings.isNotEmpty) return servings.first;
    return FoodServing(
      id: 'g_100',
      foodId: id,
      label: '100 g',
      unitType: 'gram',
      gramsPerUnit: 100,
      isDefault: true,
      sortOrder: 99,
    );
  }

  double get caloriesPerDefaultServing =>
      NutritionCalculator.calculateForServing(
        per100g: nutritionPer100g,
        serving: defaultServing,
        servingCount: 1,
      ).calories;

  bool matchesDietaryPreference(String preference) {
    switch (preference) {
      case 'vegan':
        return dietaryTags.contains('vegan');
      case 'vegetarian':
        return dietaryTags.contains('vegetarian') ||
            dietaryTags.contains('vegan');
      case 'eggetarian':
        return dietaryTags.contains('vegetarian') ||
            dietaryTags.contains('vegan') ||
            dietaryTags.contains('eggetarian');
      case 'non_vegetarian':
      default:
        return true;
    }
  }

  static List<String> _decodeTags(dynamic raw) {
    if (raw == null) return const [];
    if (raw is List) return raw.map((e) => e.toString()).toList();
    if (raw is String && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) return decoded.map((e) => e.toString()).toList();
      } catch (_) {}
    }
    return const [];
  }

  factory FoodItem.fromJson(
    Map<String, dynamic> json, {
    int catalogueVersion = 1,
  }) {
    final id = json['id'] as String;
    final rawServings = (json['servings'] as List<dynamic>?) ?? const [];
    return FoodItem(
      id: id,
      name: json['name'] as String,
      commonNames: (json['commonNames'] ?? json['common_names'] ?? '') as String,
      categoryId: (json['categoryId'] ?? json['category_id']) as String,
      illustrationId:
          (json['illustrationId'] ?? json['illustration_id'] ?? 'generic')
              as String,
      preparationState: (json['preparationState'] ??
              json['preparation_state'] ??
              '')
          as String,
      dietaryTags: _decodeTags(json['dietaryTags'] ?? json['dietary_tags']),
      allergenTags: _decodeTags(json['allergenTags'] ?? json['allergen_tags']),
      sourceName: (json['sourceName'] ?? json['source_name'] ?? '') as String,
      sourceReference:
          (json['sourceReference'] ?? json['source_reference'] ?? '') as String,
      sourceLicense:
          (json['sourceLicense'] ?? json['source_license'] ?? '') as String,
      isVerified: json['isVerified'] == true || json['is_verified'] == 1,
      isComplete: json['isComplete'] != false && json['is_complete'] != 0,
      verificationNotes: (json['verificationNotes'] ??
              json['verification_notes'] ??
              '')
          as String,
      catalogueVersion: catalogueVersion,
      nutritionPer100g: FoodNutrition.fromJson(
          json['nutritionPer100g'] as Map<String, dynamic>),
      servings: rawServings
          .map((s) => FoodServing.fromJson(s as Map<String, dynamic>, foodId: id))
          .toList(),
    );
  }

  Map<String, dynamic> toFoodDbMap(String timestamp) => {
        'id': id,
        'name': name,
        'common_names': commonNames,
        'category_id': categoryId,
        'illustration_id': illustrationId,
        'preparation_state': preparationState,
        'dietary_tags': jsonEncode(dietaryTags),
        'allergen_tags': jsonEncode(allergenTags),
        'source_name': sourceName,
        'source_reference': sourceReference,
        'source_license': sourceLicense,
        'is_verified': isVerified ? 1 : 0,
        'is_complete': isComplete ? 1 : 0,
        'verification_notes': verificationNotes,
        'catalogue_version': catalogueVersion,
        'created_at': timestamp,
        'updated_at': timestamp,
      };

  FoodItem copyWith({bool? isFavorite}) => FoodItem(
        id: id,
        name: name,
        commonNames: commonNames,
        categoryId: categoryId,
        illustrationId: illustrationId,
        preparationState: preparationState,
        dietaryTags: dietaryTags,
        allergenTags: allergenTags,
        sourceName: sourceName,
        sourceReference: sourceReference,
        sourceLicense: sourceLicense,
        isVerified: isVerified,
        isComplete: isComplete,
        verificationNotes: verificationNotes,
        catalogueVersion: catalogueVersion,
        nutritionPer100g: nutritionPer100g,
        servings: servings,
        isFavorite: isFavorite ?? this.isFavorite,
      );
}

