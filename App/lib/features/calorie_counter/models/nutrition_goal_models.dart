import 'dart:convert';

class DailyNutritionGoal {
  final String id;
  final String userId;
  final String effectiveFromDate; // YYYY-MM-DD
  final double calories;
  final double protein;
  final double carbs;
  final double fat;
  final double fibre;
  final int? hydrationMl;
  final String sourceMode; // 'manual' | 'guided' | 'default'
  final String notes;
  final String createdAt;
  final String updatedAt;
  final String syncStatus;
  final bool isDeleted;

  const DailyNutritionGoal({
    required this.id,
    required this.userId,
    required this.effectiveFromDate,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.fibre,
    this.hydrationMl,
    this.sourceMode = 'manual',
    this.notes = '',
    required this.createdAt,
    required this.updatedAt,
    this.syncStatus = 'pending',
    this.isDeleted = false,
  });

  factory DailyNutritionGoal.fallbackDefault(String userId) {
    final now = DateTime.now().toIso8601String();
    return DailyNutritionGoal(
      id: 'default_$userId',
      userId: userId,
      effectiveFromDate: '2000-01-01',
      calories: 2000,
      protein: 75,
      carbs: 260,
      fat: 65,
      fibre: 30,
      hydrationMl: 2500,
      sourceMode: 'default',
      notes: 'General balanced reference target',
      createdAt: now,
      updatedAt: now,
      syncStatus: 'synced',
    );
  }

  factory DailyNutritionGoal.fromDbMap(Map<String, dynamic> map) {
    return DailyNutritionGoal(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      effectiveFromDate: map['effective_from_date'] as String,
      calories: (map['calories'] as num).toDouble(),
      protein: (map['protein'] as num).toDouble(),
      carbs: (map['carbs'] as num).toDouble(),
      fat: (map['fat'] as num).toDouble(),
      fibre: (map['fibre'] as num).toDouble(),
      hydrationMl: map['hydration_ml'] as int?,
      sourceMode: (map['source_mode'] ?? 'manual') as String,
      notes: (map['notes'] ?? '') as String,
      createdAt: map['created_at'] as String,
      updatedAt: map['updated_at'] as String,
      syncStatus: (map['sync_status'] ?? 'pending') as String,
      isDeleted: (map['is_deleted'] ?? 0) == 1,
    );
  }

  Map<String, dynamic> toDbMap() => {
        'id': id,
        'user_id': userId,
        'effective_from_date': effectiveFromDate,
        'calories': calories,
        'protein': protein,
        'carbs': carbs,
        'fat': fat,
        'fibre': fibre,
        'hydration_ml': hydrationMl,
        'source_mode': sourceMode,
        'notes': notes,
        'created_at': createdAt,
        'updated_at': updatedAt,
        'sync_status': syncStatus,
        'is_deleted': isDeleted ? 1 : 0,
      };

  Map<String, dynamic> toApiJson() => {
        'id': id,
        'effectiveFromDate': effectiveFromDate,
        'calories': calories,
        'protein': protein,
        'carbs': carbs,
        'fat': fat,
        'fibre': fibre,
        'hydrationMl': hydrationMl,
        'sourceMode': sourceMode,
        'notes': notes,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
        'isDeleted': isDeleted,
      };

  factory DailyNutritionGoal.fromApiJson(
      Map<String, dynamic> json, String userId) {
    return DailyNutritionGoal(
      id: json['id'] as String,
      userId: userId,
      effectiveFromDate: json['effectiveFromDate'] as String,
      calories: (json['calories'] as num).toDouble(),
      protein: (json['protein'] as num).toDouble(),
      carbs: (json['carbs'] as num).toDouble(),
      fat: (json['fat'] as num).toDouble(),
      fibre: (json['fibre'] as num).toDouble(),
      hydrationMl: json['hydrationMl'] as int?,
      sourceMode: (json['sourceMode'] ?? 'manual') as String,
      notes: (json['notes'] ?? '') as String,
      createdAt: json['createdAt'] as String,
      updatedAt: json['updatedAt'] as String,
      syncStatus: 'synced',
      isDeleted: json['isDeleted'] == true,
    );
  }
}

class MonthlyNutritionGoal {
  final String id;
  final String userId;
  final String yearMonth; // YYYY-MM
  final double totalCalories;
  final double? protein;
  final double? carbs;
  final double? fat;
  final double? fibre;
  final int? targetDaysWithinGoal;
  final String notes;
  final String createdAt;
  final String updatedAt;
  final String syncStatus;
  final bool isDeleted;

  const MonthlyNutritionGoal({
    required this.id,
    required this.userId,
    required this.yearMonth,
    required this.totalCalories,
    this.protein,
    this.carbs,
    this.fat,
    this.fibre,
    this.targetDaysWithinGoal,
    this.notes = '',
    required this.createdAt,
    required this.updatedAt,
    this.syncStatus = 'pending',
    this.isDeleted = false,
  });

  static int daysInCalendarMonth(int year, int month) {
    // Handles 28, 29 (leap years), 30, and 31 accurately via Dart DateTime.
    return DateTime(year, month + 1, 0).day;
  }

  static int daysInYearMonthString(String yearMonth) {
    final parts = yearMonth.split('-');
    final year = int.parse(parts[0]);
    final month = int.parse(parts[1]);
    return daysInCalendarMonth(year, month);
  }

  static double? _nullableDouble(dynamic v) =>
      v == null ? null : (v as num).toDouble();

  factory MonthlyNutritionGoal.fromDbMap(Map<String, dynamic> map) {
    return MonthlyNutritionGoal(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      yearMonth: map['year_month'] as String,
      totalCalories: (map['total_calories'] as num).toDouble(),
      protein: _nullableDouble(map['protein']),
      carbs: _nullableDouble(map['carbs']),
      fat: _nullableDouble(map['fat']),
      fibre: _nullableDouble(map['fibre']),
      targetDaysWithinGoal: map['target_days_within_goal'] as int?,
      notes: (map['notes'] ?? '') as String,
      createdAt: map['created_at'] as String,
      updatedAt: map['updated_at'] as String,
      syncStatus: (map['sync_status'] ?? 'pending') as String,
      isDeleted: (map['is_deleted'] ?? 0) == 1,
    );
  }

  Map<String, dynamic> toDbMap() => {
        'id': id,
        'user_id': userId,
        'year_month': yearMonth,
        'total_calories': totalCalories,
        'protein': protein,
        'carbs': carbs,
        'fat': fat,
        'fibre': fibre,
        'target_days_within_goal': targetDaysWithinGoal,
        'notes': notes,
        'created_at': createdAt,
        'updated_at': updatedAt,
        'sync_status': syncStatus,
        'is_deleted': isDeleted ? 1 : 0,
      };

  Map<String, dynamic> toApiJson() => {
        'id': id,
        'yearMonth': yearMonth,
        'totalCalories': totalCalories,
        'protein': protein,
        'carbs': carbs,
        'fat': fat,
        'fibre': fibre,
        'targetDaysWithinGoal': targetDaysWithinGoal,
        'notes': notes,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
        'isDeleted': isDeleted,
      };

  factory MonthlyNutritionGoal.fromApiJson(
      Map<String, dynamic> json, String userId) {
    return MonthlyNutritionGoal(
      id: json['id'] as String,
      userId: userId,
      yearMonth: json['yearMonth'] as String,
      totalCalories: (json['totalCalories'] as num).toDouble(),
      protein: _nullableDouble(json['protein']),
      carbs: _nullableDouble(json['carbs']),
      fat: _nullableDouble(json['fat']),
      fibre: _nullableDouble(json['fibre']),
      targetDaysWithinGoal: json['targetDaysWithinGoal'] as int?,
      notes: (json['notes'] ?? '') as String,
      createdAt: json['createdAt'] as String,
      updatedAt: json['updatedAt'] as String,
      syncStatus: 'synced',
      isDeleted: json['isDeleted'] == true,
    );
  }
}

class UserNutritionPreferences {
  final String userId;
  final String dietaryPreference; // vegetarian | eggetarian | non_vegetarian | vegan
  final List<String> allergies;
  final List<String> excludedFoodIds;
  final Map<String, String> preferredMealTimings;
  final String fitnessObjective; // maintain_weight | lose_weight | gain_weight | improve_nutrition
  final int? age;
  final String? sex; // 'male' | 'female' | 'other'
  final double? heightCm;
  final double? weightKg;
  final String activityLevel; // sedentary | light | moderate | active | very_active
  final String updatedAt;
  final String syncStatus;

  const UserNutritionPreferences({
    required this.userId,
    this.dietaryPreference = 'vegetarian',
    this.allergies = const [],
    this.excludedFoodIds = const [],
    this.preferredMealTimings = const {
      'breakfast': '08:00',
      'morning_snack': '11:00',
      'lunch': '13:30',
      'evening_snack': '17:00',
      'dinner': '20:30',
    },
    this.fitnessObjective = 'maintain_weight',
    this.age,
    this.sex,
    this.heightCm,
    this.weightKg,
    this.activityLevel = 'moderate',
    required this.updatedAt,
    this.syncStatus = 'pending',
  });

  factory UserNutritionPreferences.initial(String userId) {
    return UserNutritionPreferences(
      userId: userId,
      updatedAt: DateTime.now().toIso8601String(),
      syncStatus: 'synced',
    );
  }

  static List<String> _decodeList(dynamic v) {
    if (v is List) return v.map((e) => e.toString()).toList();
    if (v is String && v.isNotEmpty) {
      try {
        final d = jsonDecode(v);
        if (d is List) return d.map((e) => e.toString()).toList();
      } catch (_) {}
    }
    return const [];
  }

  static Map<String, String> _decodeMap(dynamic v) {
    if (v is Map) {
      return v.map((k, val) => MapEntry(k.toString(), val.toString()));
    }
    if (v is String && v.isNotEmpty) {
      try {
        final d = jsonDecode(v);
        if (d is Map) {
          return d.map((k, val) => MapEntry(k.toString(), val.toString()));
        }
      } catch (_) {}
    }
    return const {
      'breakfast': '08:00',
      'morning_snack': '11:00',
      'lunch': '13:30',
      'evening_snack': '17:00',
      'dinner': '20:30',
    };
  }

  factory UserNutritionPreferences.fromDbMap(Map<String, dynamic> map) {
    return UserNutritionPreferences(
      userId: map['user_id'] as String,
      dietaryPreference: (map['dietary_preference'] ?? 'vegetarian') as String,
      allergies: _decodeList(map['allergies_json']),
      excludedFoodIds: _decodeList(map['excluded_food_ids_json']),
      preferredMealTimings: _decodeMap(map['preferred_meal_timings_json']),
      fitnessObjective:
          (map['fitness_objective'] ?? 'maintain_weight') as String,
      age: map['age'] as int?,
      sex: map['sex'] as String?,
      heightCm: (map['height_cm'] as num?)?.toDouble(),
      weightKg: (map['weight_kg'] as num?)?.toDouble(),
      activityLevel: (map['activity_level'] ?? 'moderate') as String,
      updatedAt: map['updated_at'] as String,
      syncStatus: (map['sync_status'] ?? 'pending') as String,
    );
  }

  Map<String, dynamic> toDbMap() => {
        'user_id': userId,
        'dietary_preference': dietaryPreference,
        'allergies_json': jsonEncode(allergies),
        'excluded_food_ids_json': jsonEncode(excludedFoodIds),
        'preferred_meal_timings_json': jsonEncode(preferredMealTimings),
        'fitness_objective': fitnessObjective,
        'age': age,
        'sex': sex,
        'height_cm': heightCm,
        'weight_kg': weightKg,
        'activity_level': activityLevel,
        'updated_at': updatedAt,
        'sync_status': syncStatus,
      };

  Map<String, dynamic> toApiJson() => {
        'dietaryPreference': dietaryPreference,
        'allergies': allergies,
        'excludedFoodIds': excludedFoodIds,
        'preferredMealTimings': preferredMealTimings,
        'fitnessObjective': fitnessObjective,
        'age': age,
        'sex': sex,
        'heightCm': heightCm,
        'weightKg': weightKg,
        'activityLevel': activityLevel,
        'updatedAt': updatedAt,
      };

  factory UserNutritionPreferences.fromApiJson(
      Map<String, dynamic> json, String userId) {
    return UserNutritionPreferences(
      userId: userId,
      dietaryPreference:
          (json['dietaryPreference'] ?? 'vegetarian') as String,
      allergies: _decodeList(json['allergies']),
      excludedFoodIds: _decodeList(json['excludedFoodIds']),
      preferredMealTimings: _decodeMap(json['preferredMealTimings']),
      fitnessObjective:
          (json['fitnessObjective'] ?? 'maintain_weight') as String,
      age: json['age'] as int?,
      sex: json['sex'] as String?,
      heightCm: (json['heightCm'] as num?)?.toDouble(),
      weightKg: (json['weightKg'] as num?)?.toDouble(),
      activityLevel: (json['activityLevel'] ?? 'moderate') as String,
      updatedAt:
          (json['updatedAt'] ?? DateTime.now().toIso8601String()) as String,
      syncStatus: 'synced',
    );
  }

  UserNutritionPreferences copyWith({
    String? dietaryPreference,
    List<String>? allergies,
    List<String>? excludedFoodIds,
    Map<String, String>? preferredMealTimings,
    String? fitnessObjective,
    int? age,
    String? sex,
    double? heightCm,
    double? weightKg,
    String? activityLevel,
    String? updatedAt,
    String? syncStatus,
  }) {
    return UserNutritionPreferences(
      userId: userId,
      dietaryPreference: dietaryPreference ?? this.dietaryPreference,
      allergies: allergies ?? this.allergies,
      excludedFoodIds: excludedFoodIds ?? this.excludedFoodIds,
      preferredMealTimings: preferredMealTimings ?? this.preferredMealTimings,
      fitnessObjective: fitnessObjective ?? this.fitnessObjective,
      age: age ?? this.age,
      sex: sex ?? this.sex,
      heightCm: heightCm ?? this.heightCm,
      weightKg: weightKg ?? this.weightKg,
      activityLevel: activityLevel ?? this.activityLevel,
      updatedAt: updatedAt ?? this.updatedAt,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }
}

class GuidedGoalEstimate {
  final double calories;
  final double protein;
  final double carbs;
  final double fat;
  final double fibre;
  final int hydrationMl;
  final double estimatedTdee;
  final bool safetyFloorApplied;

  const GuidedGoalEstimate({
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.fibre,
    required this.hydrationMl,
    required this.estimatedTdee,
    required this.safetyFloorApplied,
  });
}

class NutritionGoalCalculator {
  NutritionGoalCalculator._();

  static const String nonMedicalDisclaimer =
      'Estimated nutrition targets are general wellness references based on '
      'standard equations (Mifflin-St Jeor) and do not constitute medical advice. '
      'Consult a qualified healthcare professional or registered dietitian for '
      'personalized clinical guidance.';

  static const Map<String, double> activityMultipliers = {
    'sedentary': 1.2,
    'light': 1.375,
    'moderate': 1.55,
    'active': 1.725,
    'very_active': 1.9,
  };

  /// Suggests balanced daily targets with safe minimum calorie floors.
  static GuidedGoalEstimate suggestTargets({
    required int age,
    required String sex, // 'male' | 'female' | 'other'
    required double heightCm,
    required double weightKg,
    required String activityLevel,
    required String fitnessObjective,
  }) {
    final safeAge = age.clamp(14, 100);
    final safeHeight = heightCm.clamp(120.0, 230.0);
    final safeWeight = weightKg.clamp(35.0, 250.0);

    // Mifflin-St Jeor BMR
    double sexOffset;
    double safeMinimumFloor;
    if (sex == 'male') {
      sexOffset = 5.0;
      safeMinimumFloor = 1500.0;
    } else if (sex == 'female') {
      sexOffset = -161.0;
      safeMinimumFloor = 1200.0;
    } else {
      sexOffset = -78.0;
      safeMinimumFloor = 1350.0;
    }

    final bmr = (10 * safeWeight) + (6.25 * safeHeight) - (5 * safeAge) + sexOffset;
    final multiplier = activityMultipliers[activityLevel] ?? 1.55;
    final tdee = bmr * multiplier;

    double targetCalories;
    switch (fitnessObjective) {
      case 'lose_weight':
        targetCalories = tdee - 400; // modest ~0.35-0.4 kg/week pace
        break;
      case 'gain_weight':
        targetCalories = tdee + 350;
        break;
      case 'improve_nutrition':
      case 'maintain_weight':
      default:
        targetCalories = tdee;
        break;
    }

    var safetyFloorApplied = false;
    if (targetCalories < safeMinimumFloor) {
      targetCalories = safeMinimumFloor;
      safetyFloorApplied = true;
    }
    if (targetCalories > 4500) {
      targetCalories = 4500;
    }

    final roundedCalories = (targetCalories / 10).round() * 10.0;
    // Balanced macro split: Protein ~1.4g/kg (capped safely), Fat 27% kcal, remainder Carbs
    final protein =
        ((safeWeight * (fitnessObjective == 'gain_weight' ? 1.6 : 1.3))
                .clamp(45.0, (roundedCalories * 0.35) / 4))
            .roundToDouble();
    final fat = (((roundedCalories * 0.27) / 9).clamp(35.0, 140.0)).roundToDouble();
    final remainingForCarbs =
        (roundedCalories - (protein * 4) - (fat * 9)).clamp(roundedCalories * 0.3, roundedCalories * 0.65);
    final carbs = (remainingForCarbs / 4).roundToDouble();
    final fibre = ((roundedCalories / 1000) * 14).clamp(22.0, 48.0).roundToDouble();
    final hydrationMl = ((safeWeight * 35).clamp(1800.0, 4000.0) / 50).round() * 50;

    return GuidedGoalEstimate(
      calories: roundedCalories,
      protein: protein,
      carbs: carbs,
      fat: fat,
      fibre: fibre,
      hydrationMl: hydrationMl,
      estimatedTdee: tdee.roundToDouble(),
      safetyFloorApplied: safetyFloorApplied,
    );
  }
}

