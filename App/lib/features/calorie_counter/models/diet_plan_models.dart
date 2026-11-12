import 'meal_log_model.dart';

class DietPlanItem {
  final String id;
  final String mealId;
  final String foodId;
  final String foodNameSnapshot;
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
  final int sortOrder;

  const DietPlanItem({
    required this.id,
    required this.mealId,
    required this.foodId,
    required this.foodNameSnapshot,
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
    this.sortOrder = 0,
  });

  factory DietPlanItem.fromDbMap(Map<String, dynamic> map) {
    return DietPlanItem(
      id: map['id'] as String,
      mealId: map['meal_id'] as String,
      foodId: map['food_id'] as String,
      foodNameSnapshot: map['food_name_snapshot'] as String,
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
      sortOrder: (map['sort_order'] ?? 0) as int,
    );
  }

  Map<String, dynamic> toDbMap() => {
        'id': id,
        'meal_id': mealId,
        'food_id': foodId,
        'food_name_snapshot': foodNameSnapshot,
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
        'sort_order': sortOrder,
      };

  factory DietPlanItem.fromApiJson(
      Map<String, dynamic> json, String mealId, int sortOrder) {
    return DietPlanItem(
      id: (json['id'] ?? '${mealId}_$sortOrder') as String,
      mealId: mealId,
      foodId: json['foodId'] as String,
      foodNameSnapshot: (json['foodName'] ?? json['foodNameSnapshot']) as String,
      illustrationSnapshot:
          (json['illustrationId'] ?? json['illustrationSnapshot'] ?? 'generic')
              as String,
      servingId: json['servingId'] as String,
      servingLabelSnapshot:
          (json['servingLabel'] ?? json['servingLabelSnapshot']) as String,
      servingCount: (json['servingCount'] as num).toDouble(),
      gramsPerUnit: (json['gramsPerUnit'] as num).toDouble(),
      totalGrams: (json['totalGrams'] as num).toDouble(),
      calories: (json['calories'] as num).toDouble(),
      protein: (json['protein'] as num).toDouble(),
      carbs: (json['carbs'] as num).toDouble(),
      fat: (json['fat'] as num).toDouble(),
      fibre: (json['fibre'] as num).toDouble(),
      sortOrder: sortOrder,
    );
  }

  Map<String, dynamic> toApiJson() => {
        'id': id,
        'foodId': foodId,
        'foodNameSnapshot': foodNameSnapshot,
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
      };
}

class DietPlanMeal {
  final String id;
  final String planId;
  final MealCategory mealCategory;
  final String mealTiming;
  final String explanation;
  final int sortOrder;
  final List<DietPlanItem> items;

  const DietPlanMeal({
    required this.id,
    required this.planId,
    required this.mealCategory,
    required this.mealTiming,
    required this.explanation,
    required this.sortOrder,
    required this.items,
  });

  double get totalCalories => items.fold(0.0, (s, e) => s + e.calories);
  double get totalProtein => items.fold(0.0, (s, e) => s + e.protein);
  double get totalCarbs => items.fold(0.0, (s, e) => s + e.carbs);
  double get totalFat => items.fold(0.0, (s, e) => s + e.fat);
  double get totalFibre => items.fold(0.0, (s, e) => s + e.fibre);

  factory DietPlanMeal.fromDbMap(
      Map<String, dynamic> map, List<DietPlanItem> items) {
    return DietPlanMeal(
      id: map['id'] as String,
      planId: map['plan_id'] as String,
      mealCategory: MealCategory.fromKey(map['meal_category'] as String),
      mealTiming: (map['meal_timing'] ?? '') as String,
      explanation: (map['explanation'] ?? '') as String,
      sortOrder: (map['sort_order'] ?? 0) as int,
      items: items,
    );
  }

  Map<String, dynamic> toDbMap() => {
        'id': id,
        'plan_id': planId,
        'meal_category': mealCategory.key,
        'meal_timing': mealTiming,
        'explanation': explanation,
        'sort_order': sortOrder,
      };

  factory DietPlanMeal.fromApiJson(
      Map<String, dynamic> json, String planId, int index) {
    final mealId = (json['id'] ?? '${planId}_meal_$index') as String;
    final rawItems = (json['items'] as List<dynamic>?) ?? const [];
    return DietPlanMeal(
      id: mealId,
      planId: planId,
      mealCategory: MealCategory.fromKey(json['mealCategory'] as String),
      mealTiming: (json['mealTiming'] ?? '') as String,
      explanation: (json['explanation'] ?? '') as String,
      sortOrder: index,
      items: [
        for (var i = 0; i < rawItems.length; i++)
          DietPlanItem.fromApiJson(
              rawItems[i] as Map<String, dynamic>, mealId, i),
      ],
    );
  }

  Map<String, dynamic> toApiJson() => {
        'id': id,
        'mealCategory': mealCategory.key,
        'mealTiming': mealTiming,
        'explanation': explanation,
        'items': items.map((e) => e.toApiJson()).toList(),
      };
}

class DietPlan {
  final String id;
  final String userId;
  final String title;
  final double targetCalories;
  final double targetProtein;
  final double targetCarbs;
  final double targetFat;
  final double targetFibre;
  final String dietaryPreference;
  final String fitnessObjective;
  final String generatedBy; // 'gemini' | 'fallback' | 'edited'
  final String modelName;
  final String aiNotes;
  final bool isAccepted;
  final bool isSaved;
  final String createdAt;
  final String updatedAt;
  final String syncStatus;
  final bool isDeleted;
  final List<DietPlanMeal> meals;

  const DietPlan({
    required this.id,
    required this.userId,
    required this.title,
    required this.targetCalories,
    required this.targetProtein,
    required this.targetCarbs,
    required this.targetFat,
    required this.targetFibre,
    required this.dietaryPreference,
    required this.fitnessObjective,
    required this.generatedBy,
    this.modelName = '',
    this.aiNotes = '',
    this.isAccepted = false,
    this.isSaved = false,
    required this.createdAt,
    required this.updatedAt,
    this.syncStatus = 'pending',
    this.isDeleted = false,
    required this.meals,
  });

  double get totalCalories => meals.fold(0.0, (s, m) => s + m.totalCalories);
  double get totalProtein => meals.fold(0.0, (s, m) => s + m.totalProtein);
  double get totalCarbs => meals.fold(0.0, (s, m) => s + m.totalCarbs);
  double get totalFat => meals.fold(0.0, (s, m) => s + m.totalFat);
  double get totalFibre => meals.fold(0.0, (s, m) => s + m.totalFibre);

  factory DietPlan.fromDbMap(
      Map<String, dynamic> map, List<DietPlanMeal> meals) {
    return DietPlan(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      title: map['title'] as String,
      targetCalories: (map['target_calories'] as num).toDouble(),
      targetProtein: (map['target_protein'] as num).toDouble(),
      targetCarbs: (map['target_carbs'] as num).toDouble(),
      targetFat: (map['target_fat'] as num).toDouble(),
      targetFibre: (map['target_fibre'] as num).toDouble(),
      dietaryPreference: map['dietary_preference'] as String,
      fitnessObjective: map['fitness_objective'] as String,
      generatedBy: (map['generated_by'] ?? 'fallback') as String,
      modelName: (map['model_name'] ?? '') as String,
      aiNotes: (map['ai_notes'] ?? '') as String,
      isAccepted: (map['is_accepted'] ?? 0) == 1,
      isSaved: (map['is_saved'] ?? 0) == 1,
      createdAt: map['created_at'] as String,
      updatedAt: map['updated_at'] as String,
      syncStatus: (map['sync_status'] ?? 'pending') as String,
      isDeleted: (map['is_deleted'] ?? 0) == 1,
      meals: meals,
    );
  }

  Map<String, dynamic> toDbMap() => {
        'id': id,
        'user_id': userId,
        'title': title,
        'target_calories': targetCalories,
        'target_protein': targetProtein,
        'target_carbs': targetCarbs,
        'target_fat': targetFat,
        'target_fibre': targetFibre,
        'dietary_preference': dietaryPreference,
        'fitness_objective': fitnessObjective,
        'generated_by': generatedBy,
        'model_name': modelName,
        'ai_notes': aiNotes,
        'is_accepted': isAccepted ? 1 : 0,
        'is_saved': isSaved ? 1 : 0,
        'created_at': createdAt,
        'updated_at': updatedAt,
        'sync_status': syncStatus,
        'is_deleted': isDeleted ? 1 : 0,
      };

  factory DietPlan.fromApiJson(Map<String, dynamic> json, String userId) {
    final planId = (json['id'] ?? json['planId']) as String;
    final rawMeals = (json['meals'] as List<dynamic>?) ?? const [];
    return DietPlan(
      id: planId,
      userId: userId,
      title: (json['title'] ?? 'Personalized Diet Plan') as String,
      targetCalories: (json['targetCalories'] as num).toDouble(),
      targetProtein: (json['targetProtein'] as num).toDouble(),
      targetCarbs: (json['targetCarbs'] as num).toDouble(),
      targetFat: (json['targetFat'] as num).toDouble(),
      targetFibre: (json['targetFibre'] as num).toDouble(),
      dietaryPreference:
          (json['dietaryPreference'] ?? 'vegetarian') as String,
      fitnessObjective:
          (json['fitnessObjective'] ?? 'maintain_weight') as String,
      generatedBy: (json['generatedBy'] ?? 'gemini') as String,
      modelName: (json['modelName'] ?? '') as String,
      aiNotes: (json['aiNotes'] ?? '') as String,
      isAccepted: json['isAccepted'] == true,
      isSaved: json['isSaved'] == true,
      createdAt:
          (json['createdAt'] ?? DateTime.now().toIso8601String()) as String,
      updatedAt:
          (json['updatedAt'] ?? DateTime.now().toIso8601String()) as String,
      syncStatus: 'synced',
      isDeleted: json['isDeleted'] == true,
      meals: [
        for (var i = 0; i < rawMeals.length; i++)
          DietPlanMeal.fromApiJson(
              rawMeals[i] as Map<String, dynamic>, planId, i),
      ],
    );
  }

  Map<String, dynamic> toApiJson() => {
        'id': id,
        'title': title,
        'targetCalories': targetCalories,
        'targetProtein': targetProtein,
        'targetCarbs': targetCarbs,
        'targetFat': targetFat,
        'targetFibre': targetFibre,
        'dietaryPreference': dietaryPreference,
        'fitnessObjective': fitnessObjective,
        'generatedBy': generatedBy,
        'modelName': modelName,
        'aiNotes': aiNotes,
        'isAccepted': isAccepted,
        'isSaved': isSaved,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
        'isDeleted': isDeleted,
        'meals': meals.map((m) => m.toApiJson()).toList(),
      };

  DietPlan copyWith({
    String? title,
    String? generatedBy,
    bool? isAccepted,
    bool? isSaved,
    String? updatedAt,
    String? syncStatus,
    bool? isDeleted,
    List<DietPlanMeal>? meals,
  }) {
    return DietPlan(
      id: id,
      userId: userId,
      title: title ?? this.title,
      targetCalories: targetCalories,
      targetProtein: targetProtein,
      targetCarbs: targetCarbs,
      targetFat: targetFat,
      targetFibre: targetFibre,
      dietaryPreference: dietaryPreference,
      fitnessObjective: fitnessObjective,
      generatedBy: generatedBy ?? this.generatedBy,
      modelName: modelName,
      aiNotes: aiNotes,
      isAccepted: isAccepted ?? this.isAccepted,
      isSaved: isSaved ?? this.isSaved,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      syncStatus: syncStatus ?? this.syncStatus,
      isDeleted: isDeleted ?? this.isDeleted,
      meals: meals ?? this.meals,
    );
  }
}

