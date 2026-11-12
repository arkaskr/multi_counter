import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/components/neumorphic_container.dart';
import '../models/meal_log_model.dart';
import '../providers/calorie_providers.dart';
import '../widgets/calorie_progress_ring.dart';
import '../widgets/nutrition_charts.dart';

/// Screen 6: Full Daily Nutrition Summary (Macros, Micronutrients & Meal Split).
class DailyNutritionSummaryScreen extends ConsumerWidget {
  const DailyNutritionSummaryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = context.appTheme;
    final dashboardAsync = ref.watch(dailyDashboardProvider);

    return Scaffold(
      backgroundColor: theme.background,
      appBar: AppBar(
        backgroundColor: theme.background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: theme.text),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Daily Nutrition Summary',
          style: TextStyle(color: theme.text, fontWeight: FontWeight.w700),
        ),
      ),
      body: dashboardAsync.when(
        data: (state) {
          final totals = state.totals;
          final goal = state.goal;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              NeumorphicContainer(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Date: ${state.dateString}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: theme.secondaryText,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          totals.hasRecords
                              ? '${totals.calories.round()} kcal logged'
                              : 'No foods logged on this date',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: theme.text,
                          ),
                        ),
                        Text(
                          'Goal: ${goal.calories.round()}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: NutritionAccentPalette.warmOrange,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    MacroCalorieSplitBar(
                      proteinGrams: totals.protein,
                      carbsGrams: totals.carbs,
                      fatGrams: totals.fat,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              NeumorphicContainer(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Macronutrients vs Goal',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: theme.text,
                      ),
                    ),
                    const SizedBox(height: 12),
                    MacroProgressBar(
                      label: 'Protein',
                      current: totals.protein,
                      target: goal.protein,
                      color: NutritionAccentPalette.proteinBlue,
                    ),
                    const SizedBox(height: 10),
                    MacroProgressBar(
                      label: 'Carbohydrates',
                      current: totals.carbs,
                      target: goal.carbs,
                      color: NutritionAccentPalette.carbsAmber,
                    ),
                    const SizedBox(height: 10),
                    MacroProgressBar(
                      label: 'Fat',
                      current: totals.fat,
                      target: goal.fat,
                      color: NutritionAccentPalette.fatCoral,
                    ),
                    const SizedBox(height: 10),
                    MacroProgressBar(
                      label: 'Dietary Fibre',
                      current: totals.fibre,
                      target: goal.fibre,
                      color: NutritionAccentPalette.fibreTeal,
                    ),
                    if (goal.hydrationMl != null && goal.hydrationMl! > 0) ...[
                      const SizedBox(height: 10),
                      MacroProgressBar(
                        label: 'Hydration',
                        current: totals.hydrationMl.toDouble(),
                        target: goal.hydrationMl!.toDouble(),
                        unit: ' ml',
                        color: NutritionAccentPalette.waterCyan,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),
              NeumorphicContainer(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Detailed Nutrients (From Snapshot Records)',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: theme.text,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _row(theme, 'Total Sugar', '${totals.sugar.toStringAsFixed(1)} g'),
                    _row(theme, 'Saturated Fat', '${totals.saturatedFat.toStringAsFixed(1)} g'),
                    _row(theme, 'Sodium', '${totals.sodiumMg.toStringAsFixed(1)} mg'),
                    _row(theme, 'Potassium', '${totals.potassiumMg.toStringAsFixed(1)} mg'),
                    _row(theme, 'Calcium', '${totals.calciumMg.toStringAsFixed(1)} mg'),
                    _row(theme, 'Iron', '${totals.ironMg.toStringAsFixed(1)} mg'),
                    _row(theme, 'Vitamin C', '${totals.vitaminCMg.toStringAsFixed(1)} mg'),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              NeumorphicContainer(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Breakdown by Meal',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: theme.text,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ...MealCategory.values.map((m) {
                      final list = totals.logsByMeal[m] ?? const [];
                      final cal = totals.mealCalories(m);
                      return _row(
                        theme,
                        '${m.label} (${list.length})',
                        '${cal.round()} kcal',
                      );
                    }),
                  ],
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
      ),
    );
  }

  Widget _row(AppThemeData theme, String label, String val) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: theme.secondaryText, fontSize: 13)),
          Text(val,
              style: TextStyle(
                  color: theme.text, fontWeight: FontWeight.w700, fontSize: 13)),
        ],
      ),
    );
  }
}

