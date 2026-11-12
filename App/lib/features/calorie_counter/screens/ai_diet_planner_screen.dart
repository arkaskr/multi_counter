import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/components/neumorphic_button.dart';
import '../../../shared/components/neumorphic_container.dart';
import '../models/diet_plan_models.dart';
import '../models/food_models.dart';
import '../providers/calorie_providers.dart';
import '../services/nutrition_analytics_service.dart';
import '../widgets/calorie_progress_ring.dart';
import '../widgets/food_illustration.dart';
import 'food_search_screen.dart';
import 'nutrition_preferences_screen.dart';
import 'saved_diet_plans_screen.dart';

/// Screen 11: AI Diet Planner Screen.
///
/// Never trusts AI nutrition math (all numbers come from verified catalogue),
/// supports Replace Food, Adjust Quantity, Regenerate, Accept, Save,
/// View Saved Plans, and explicit per-meal Confirm & Log.
class AiDietPlannerScreen extends ConsumerStatefulWidget {
  const AiDietPlannerScreen({super.key});

  @override
  ConsumerState<AiDietPlannerScreen> createState() =>
      _AiDietPlannerScreenState();
}

class _AiDietPlannerScreenState extends ConsumerState<AiDietPlannerScreen> {
  final _notesCtrl = TextEditingController();
  DietPlan? _currentPlan;
  String? _notice;
  bool _usedFallback = false;
  bool _generating = false;

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    setState(() => _generating = true);
    try {
      final dashboard = await ref.read(dailyDashboardProvider.future);
      final userId = ref.read(nutritionUserIdProvider);
      final res = await ref.read(dietPlannerServiceProvider).generatePlan(
            userId: userId,
            goal: dashboard.goal,
            preferences: dashboard.preferences,
            customInstructions: _notesCtrl.text.trim(),
          );
      if (!mounted) return;
      setState(() {
        _currentPlan = res.plan;
        _usedFallback = res.usedFallback;
        _notice = res.notice;
      });
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  Future<void> _replaceFood(DietPlanMeal meal, DietPlanItem item) async {
    final picked = await Navigator.of(context).push<dynamic>(
      MaterialPageRoute(
        builder: (_) => FoodSearchScreen(
          initialMealCategory: meal.mealCategory,
          selectionOnly: true,
        ),
      ),
    );
    if (picked is Map && _currentPlan != null && mounted) {
      final updated =
          await ref.read(dietPlannerServiceProvider).replacePlanItem(
                plan: _currentPlan!,
                mealId: meal.id,
                itemId: item.id,
                replacementFood: picked['food'] as FoodItem,
                serving: picked['serving'] as FoodServing,
                servingCount: picked['servingCount'] as double,
              );
      setState(() => _currentPlan = updated);
    }
  }

  Future<void> _adjustQuantity(
      DietPlanMeal meal, DietPlanItem item, double newCount) async {
    if (_currentPlan == null || newCount < 0.5 || newCount > 10) return;
    final updated =
        await ref.read(dietPlannerServiceProvider).adjustPlanItemQuantity(
              plan: _currentPlan!,
              mealId: meal.id,
              itemId: item.id,
              newServingCount: newCount,
            );
    if (mounted) setState(() => _currentPlan = updated);
  }

  Future<void> _saveOrAccept({required bool accept}) async {
    if (_currentPlan == null) return;
    final saved = await ref.read(dietPlannerServiceProvider).savePlan(
          _currentPlan!,
          isAccepted: accept,
          isSaved: true,
        );
    ref.invalidate(savedDietPlansProvider);
    if (!mounted) return;
    setState(() => _currentPlan = saved);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(accept
            ? 'Plan accepted & saved offline. Confirm individual meals as you eat them.'
            : 'Plan saved for offline viewing.'),
        backgroundColor: NutritionAccentPalette.softGreen,
      ),
    );
  }

  Future<void> _confirmAndLogMeal(DietPlanMeal meal) async {
    final selectedDate = ref.read(selectedCalorieDateProvider);
    final dateStr = NutritionAnalyticsService.formatDate(selectedDate);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Confirm ${meal.mealCategory.label}?'),
        content: Text(
          'Add ${meal.items.length} item(s) (${meal.totalCalories.round()} kcal) to your actual food log for $dateStr?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Not Yet'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: NutritionAccentPalette.softGreen,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Confirm & Log',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok != true) return;

    final userId = ref.read(nutritionUserIdProvider);
    await ref.read(dietPlannerServiceProvider).confirmAndLogPlanMeal(
          userId: userId,
          date: dateStr,
          meal: meal,
        );
    await ref.read(dailyDashboardProvider.notifier).refresh();
    ref.invalidate(nutritionAnalyticsProvider);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Logged ${meal.mealCategory.label} to $dateStr.'),
          backgroundColor: NutritionAccentPalette.softGreen,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.appTheme;
    final dashboardState = ref.watch(dailyDashboardProvider).value;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        NeumorphicContainer(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.auto_awesome_rounded,
                      color: NutritionAccentPalette.warmOrange),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'AI Personalized Diet Planner',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: theme.text,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const SavedDietPlansScreen(),
                      ),
                    ),
                    child: const Text('Saved Plans'),
                  ),
                ],
              ),
              if (dashboardState != null) ...[
                const SizedBox(height: 6),
                Text(
                  'Target: ${dashboardState.goal.calories.round()} kcal • ${dashboardState.preferences.dietaryPreference.replaceAll('_', ' ')} • ${dashboardState.preferences.fitnessObjective.replaceAll('_', ' ')}',
                  style: TextStyle(fontSize: 12, color: theme.secondaryText),
                ),
              ],
              const SizedBox(height: 10),
              TextField(
                controller: _notesCtrl,
                style: TextStyle(color: theme.text, fontSize: 13),
                decoration: const InputDecoration(
                  isDense: true,
                  labelText: 'Optional preferences note (e.g. high protein vegetarian)',
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: NeumorphicButton(
                      isEnabled: !_generating,
                      color: NutritionAccentPalette.warmOrange,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      onTap: _generate,
                      child: Center(
                        child: Text(
                          _generating
                              ? 'Generating...'
                              : (_currentPlan == null
                                  ? 'Generate Diet Plan'
                                  : 'Regenerate Plan'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  NeumorphicButton(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const NutritionPreferencesScreen(),
                      ),
                    ),
                    padding: const EdgeInsets.all(13),
                    child: Icon(Icons.tune_rounded, color: theme.text, size: 20),
                  ),
                ],
              ),
            ],
          ),
        ),

        if (_notice != null) ...[
          const SizedBox(height: 12),
          NeumorphicContainer(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(
                  _usedFallback
                      ? Icons.rule_folder_rounded
                      : Icons.verified_rounded,
                  size: 18,
                  color: _usedFallback
                      ? NutritionAccentPalette.carbsAmber
                      : NutritionAccentPalette.softGreen,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _notice!,
                    style: TextStyle(fontSize: 12, color: theme.secondaryText),
                  ),
                ),
              ],
            ),
          ),
        ],

        if (_currentPlan != null) ...[
          const SizedBox(height: 14),
          NeumorphicContainer(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        _currentPlan!.title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: theme.text,
                        ),
                      ),
                    ),
                    Text(
                      '${_currentPlan!.totalCalories.round()} kcal',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: NutritionAccentPalette.warmOrange,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Protein ${_currentPlan!.totalProtein.round()}g • Carbs ${_currentPlan!.totalCarbs.round()}g • Fat ${_currentPlan!.totalFat.round()}g • Fibre ${_currentPlan!.totalFibre.round()}g',
                  style: TextStyle(fontSize: 12, color: theme.secondaryText),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: NeumorphicButton(
                        color: NutritionAccentPalette.softGreen,
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        onTap: () => _saveOrAccept(accept: true),
                        child: const Center(
                          child: Text(
                            'Accept Plan',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: NeumorphicButton(
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        onTap: () => _saveOrAccept(accept: false),
                        child: Center(
                          child: Text(
                            'Save Plan',
                            style: TextStyle(
                              color: theme.text,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          ..._currentPlan!.meals.map((meal) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: NeumorphicContainer(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${meal.mealCategory.label}${meal.mealTiming.isNotEmpty ? ' • ${meal.mealTiming}' : ''}',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: theme.text,
                                  ),
                                ),
                                if (meal.explanation.isNotEmpty)
                                  Text(
                                    meal.explanation,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: theme.secondaryText,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Text(
                            '${meal.totalCalories.round()} kcal',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: NutritionAccentPalette.warmOrange,
                            ),
                          ),
                        ],
                      ),
                      const Divider(),
                      ...meal.items.map((item) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(
                              children: [
                                FoodIllustration(
                                  illustrationId: item.illustrationSnapshot,
                                  size: 38,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.foodNameSnapshot,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: theme.text,
                                        ),
                                      ),
                                      Text(
                                        '${item.servingCount} × ${item.servingLabelSnapshot} (${item.calories.round()} kcal)',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: theme.secondaryText,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Decrease quantity',
                                  icon: Icon(Icons.remove_circle_outline,
                                      size: 18, color: theme.secondaryText),
                                  onPressed: () => _adjustQuantity(
                                      meal, item, item.servingCount - 0.5),
                                ),
                                IconButton(
                                  tooltip: 'Increase quantity',
                                  icon: Icon(Icons.add_circle_outline,
                                      size: 18, color: theme.secondaryText),
                                  onPressed: () => _adjustQuantity(
                                      meal, item, item.servingCount + 0.5),
                                ),
                                IconButton(
                                  tooltip: 'Replace Food',
                                  icon: const Icon(Icons.swap_horiz_rounded,
                                      size: 20,
                                      color: NutritionAccentPalette.warmOrange),
                                  onPressed: () => _replaceFood(meal, item),
                                ),
                              ],
                            ),
                          )),
                      const SizedBox(height: 6),
                      Align(
                        alignment: Alignment.centerRight,
                        child: NeumorphicButton(
                          color: NutritionAccentPalette.softGreen,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          onTap: () => _confirmAndLogMeal(meal),
                          child: const Text(
                            'Confirm & Log Meal',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )),
        ],
      ],
    );
  }
}

