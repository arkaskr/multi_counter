enum MealCategory {
  breakfast('breakfast', 'Breakfast', 1),
  morningSnack('morning_snack', 'Morning Snack', 2),
  lunch('lunch', 'Lunch', 3),
  eveningSnack('evening_snack', 'Evening Snack', 4),
  dinner('dinner', 'Dinner', 5),
  other('other', 'Other', 6);

  final String key;
  final String label;
  final int sortOrder;

  const MealCategory(this.key, this.label, this.sortOrder);

  static MealCategory fromKey(String key) {
    for (final value in values) {
      if (value.key == key) return value;
    }
    return MealCategory.other;
  }
}

class FoodLog {
  final String id;
  final String userId;
  final String date; // YYYY-MM-DD
  final MealCategory mealCategory;
  final String foodId;
  final String foodNameSnapshot;
  final String preparationSnapshot;
  final String illustrationSnapshot;
  final String servingId;
  final String servingLabelSnapshot;
  final double servingCount;
  final double gramsPerUnit;
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
  final String sourceSnapshot;
  final String loggedAt;
  final String updatedAt;
  final String syncStatus; // 'pending' | 'synced'
  final bool isDeleted;
  final int serverVersion;
  final String notes;

  const FoodLog({
    required this.id,
    required this.userId,
    required this.date,
    required this.mealCategory,
    required this.foodId,
    required this.foodNameSnapshot,
    required this.preparationSnapshot,
    required this.illustrationSnapshot,
    required this.servingId,
    required this.servingLabelSnapshot,
    required this.servingCount,
    required this.gramsPerUnit,
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
    required this.sourceSnapshot,
    required this.loggedAt,
    required this.updatedAt,
    this.syncStatus = 'pending',
    this.isDeleted = false,
    this.serverVersion = 1,
    this.notes = '',
  });

  static double? _nullableDouble(dynamic v) =>
      v == null ? null : (v as num).toDouble();

  factory FoodLog.fromDbMap(Map<String, dynamic> map) {
    return FoodLog(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      date: map['date'] as String,
      mealCategory: MealCategory.fromKey(map['meal_category'] as String),
      foodId: map['food_id'] as String,
      foodNameSnapshot: map['food_name_snapshot'] as String,
      preparationSnapshot: (map['preparation_snapshot'] ?? '') as String,
      illustrationSnapshot:
          (map['illustration_snapshot'] ?? 'generic') as String,
      servingId: map['serving_id'] as String,
      servingLabelSnapshot: map['serving_label_snapshot'] as String,
      servingCount: (map['serving_count'] as num).toDouble(),
      gramsPerUnit: (map['grams_per_unit'] as num).toDouble(),
      totalGrams: (map['total_grams'] as num).toDouble(),
      calories: (map['calories'] as num).toDouble(),
      protein: (map['protein'] as num).toDouble(),
      carbs: (map['carbs'] as num).toDouble(),
      fat: (map['fat'] as num).toDouble(),
      fibre: (map['fibre'] as num).toDouble(),
      sugar: _nullableDouble(map['sugar']),
      sodiumMg: _nullableDouble(map['sodium_mg']),
      saturatedFat: _nullableDouble(map['saturated_fat']),
      potassiumMg: _nullableDouble(map['potassium_mg']),
      calciumMg: _nullableDouble(map['calcium_mg']),
      ironMg: _nullableDouble(map['iron_mg']),
      vitaminCMg: _nullableDouble(map['vitamin_c_mg']),
      sourceSnapshot: (map['source_snapshot'] ?? '') as String,
      loggedAt: map['logged_at'] as String,
      updatedAt: map['updated_at'] as String,
      syncStatus: (map['sync_status'] ?? 'pending') as String,
      isDeleted: (map['is_deleted'] ?? 0) == 1,
      serverVersion: (map['server_version'] ?? 1) as int,
      notes: (map['notes'] ?? '') as String,
    );
  }

  Map<String, dynamic> toDbMap() => {
        'id': id,
        'user_id': userId,
        'date': date,
        'meal_category': mealCategory.key,
        'food_id': foodId,
        'food_name_snapshot': foodNameSnapshot,
        'preparation_snapshot': preparationSnapshot,
        'illustration_snapshot': illustrationSnapshot,
        'serving_id': servingId,
        'serving_label_snapshot': servingLabelSnapshot,
        'serving_count': servingCount,
        'grams_per_unit': gramsPerUnit,
        'total_grams': totalGrams,
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
        'source_snapshot': sourceSnapshot,
        'logged_at': loggedAt,
        'updated_at': updatedAt,
        'sync_status': syncStatus,
        'is_deleted': isDeleted ? 1 : 0,
        'server_version': serverVersion,
        'notes': notes,
      };

  Map<String, dynamic> toApiJson() => {
        'id': id,
        'date': date,
        'mealCategory': mealCategory.key,
        'foodId': foodId,
        'foodNameSnapshot': foodNameSnapshot,
        'preparationSnapshot': preparationSnapshot,
        'illustrationSnapshot': illustrationSnapshot,
        'servingId': servingId,
        'servingLabelSnapshot': servingLabelSnapshot,
        'servingCount': servingCount,
        'gramsPerUnit': gramsPerUnit,
        'totalGrams': totalGrams,
        'calories': calories,
        'protein': protein,
        'carbs': carbs,
        'fat': fat,
        'fibre': fibre,
        'sugar': sugar,
        'sodiumMg': sodiumMg,
        'saturatedFat': saturatedFat,
        'potassiumMg': potassiumMg,
        'calciumMg': calciumMg,
        'ironMg': ironMg,
        'vitaminCMg': vitaminCMg,
        'sourceSnapshot': sourceSnapshot,
        'loggedAt': loggedAt,
        'updatedAt': updatedAt,
        'isDeleted': isDeleted,
        'serverVersion': serverVersion,
        'notes': notes,
      };

  factory FoodLog.fromApiJson(Map<String, dynamic> json, String userId) {
    return FoodLog(
      id: (json['id'] ?? json['clientId']) as String,
      userId: userId,
      date: json['date'] as String,
      mealCategory: MealCategory.fromKey(json['mealCategory'] as String),
      foodId: json['foodId'] as String,
      foodNameSnapshot: json['foodNameSnapshot'] as String,
      preparationSnapshot: (json['preparationSnapshot'] ?? '') as String,
      illustrationSnapshot:
          (json['illustrationSnapshot'] ?? 'generic') as String,
      servingId: json['servingId'] as String,
      servingLabelSnapshot: json['servingLabelSnapshot'] as String,
      servingCount: (json['servingCount'] as num).toDouble(),
      gramsPerUnit: (json['gramsPerUnit'] as num).toDouble(),
      totalGrams: (json['totalGrams'] as num).toDouble(),
      calories: (json['calories'] as num).toDouble(),
      protein: (json['protein'] as num).toDouble(),
      carbs: (json['carbs'] as num).toDouble(),
      fat: (json['fat'] as num).toDouble(),
      fibre: (json['fibre'] as num).toDouble(),
      sugar: _nullableDouble(json['sugar']),
      sodiumMg: _nullableDouble(json['sodiumMg']),
      saturatedFat: _nullableDouble(json['saturatedFat']),
      potassiumMg: _nullableDouble(json['potassiumMg']),
      calciumMg: _nullableDouble(json['calciumMg']),
      ironMg: _nullableDouble(json['ironMg']),
      vitaminCMg: _nullableDouble(json['vitaminCMg']),
      sourceSnapshot: (json['sourceSnapshot'] ?? '') as String,
      loggedAt: json['loggedAt'] as String,
      updatedAt: json['updatedAt'] as String,
      syncStatus: 'synced',
      isDeleted: json['isDeleted'] == true,
      serverVersion: (json['serverVersion'] ?? 1) as int,
      notes: (json['notes'] ?? '') as String,
    );
  }

  FoodLog copyWith({
    MealCategory? mealCategory,
    String? servingId,
    String? servingLabelSnapshot,
    double? servingCount,
    double? gramsPerUnit,
    double? totalGrams,
    double? calories,
    double? protein,
    double? carbs,
    double? fat,
    double? fibre,
    double? sugar,
    double? sodiumMg,
    double? saturatedFat,
    double? potassiumMg,
    double? calciumMg,
    double? ironMg,
    double? vitaminCMg,
    String? updatedAt,
    String? syncStatus,
    bool? isDeleted,
    String? notes,
  }) {
    return FoodLog(
      id: id,
      userId: userId,
      date: date,
      mealCategory: mealCategory ?? this.mealCategory,
      foodId: foodId,
      foodNameSnapshot: foodNameSnapshot,
      preparationSnapshot: preparationSnapshot,
      illustrationSnapshot: illustrationSnapshot,
      servingId: servingId ?? this.servingId,
      servingLabelSnapshot: servingLabelSnapshot ?? this.servingLabelSnapshot,
      servingCount: servingCount ?? this.servingCount,
      gramsPerUnit: gramsPerUnit ?? this.gramsPerUnit,
      totalGrams: totalGrams ?? this.totalGrams,
      calories: calories ?? this.calories,
      protein: protein ?? this.protein,
      carbs: carbs ?? this.carbs,
      fat: fat ?? this.fat,
      fibre: fibre ?? this.fibre,
      sugar: sugar ?? this.sugar,
      sodiumMg: sodiumMg ?? this.sodiumMg,
      saturatedFat: saturatedFat ?? this.saturatedFat,
      potassiumMg: potassiumMg ?? this.potassiumMg,
      calciumMg: calciumMg ?? this.calciumMg,
      ironMg: ironMg ?? this.ironMg,
      vitaminCMg: vitaminCMg ?? this.vitaminCMg,
      sourceSnapshot: sourceSnapshot,
      loggedAt: loggedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      syncStatus: syncStatus ?? this.syncStatus,
      isDeleted: isDeleted ?? this.isDeleted,
      serverVersion: serverVersion,
      notes: notes ?? this.notes,
    );
  }
}

class DailyNutritionTotals {
  final String date;
  final int entryCount;
  final double calories;
  final double protein;
  final double carbs;
  final double fat;
  final double fibre;
  final double sugar;
  final double sodiumMg;
  final double saturatedFat;
  final double potassiumMg;
  final double calciumMg;
  final double ironMg;
  final double vitaminCMg;
  final int hydrationMl;
  final Map<MealCategory, List<FoodLog>> logsByMeal;

  const DailyNutritionTotals({
    required this.date,
    required this.entryCount,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.fibre,
    required this.sugar,
    required this.sodiumMg,
    required this.saturatedFat,
    required this.potassiumMg,
    required this.calciumMg,
    required this.ironMg,
    required this.vitaminCMg,
    required this.hydrationMl,
    required this.logsByMeal,
  });

  /// Clearly distinguishes days with no records from days with explicit 0 kcal intake.
  bool get hasRecords => entryCount > 0;
  bool get hasRecordedZeroCalories => entryCount > 0 && calories == 0;

  double mealCalories(MealCategory cat) =>
      (logsByMeal[cat] ?? const []).fold(0.0, (sum, e) => sum + e.calories);

  factory DailyNutritionTotals.fromLogs({
    required String date,
    required List<FoodLog> logs,
    int hydrationMl = 0,
  }) {
    final grouped = <MealCategory, List<FoodLog>>{
      for (final c in MealCategory.values) c: <FoodLog>[],
    };
    double cal = 0,
        prot = 0,
        carbs = 0,
        fat = 0,
        fibre = 0,
        sugar = 0,
        sodium = 0,
        satFat = 0,
        potassium = 0,
        calcium = 0,
        iron = 0,
        vitC = 0;

    for (final log in logs) {
      grouped[log.mealCategory]?.add(log);
      cal += log.calories;
      prot += log.protein;
      carbs += log.carbs;
      fat += log.fat;
      fibre += log.fibre;
      sugar += log.sugar ?? 0;
      sodium += log.sodiumMg ?? 0;
      satFat += log.saturatedFat ?? 0;
      potassium += log.potassiumMg ?? 0;
      calcium += log.calciumMg ?? 0;
      iron += log.ironMg ?? 0;
      vitC += log.vitaminCMg ?? 0;
    }

    double r1(double v) => (v * 10).roundToDouble() / 10;

    return DailyNutritionTotals(
      date: date,
      entryCount: logs.length,
      calories: r1(cal),
      protein: r1(prot),
      carbs: r1(carbs),
      fat: r1(fat),
      fibre: r1(fibre),
      sugar: r1(sugar),
      sodiumMg: r1(sodium),
      saturatedFat: r1(satFat),
      potassiumMg: r1(potassium),
      calciumMg: r1(calcium),
      ironMg: r1(iron),
      vitaminCMg: r1(vitC),
      hydrationMl: hydrationMl,
      logsByMeal: grouped,
    );
  }
}

