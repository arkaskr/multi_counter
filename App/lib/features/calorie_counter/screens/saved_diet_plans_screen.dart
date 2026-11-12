import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/components/neumorphic_button.dart';
import '../../../shared/components/neumorphic_container.dart';
import '../models/diet_plan_models.dart';
import '../providers/calorie_providers.dart';
import '../services/nutrition_analytics_service.dart';
import '../widgets/calorie_progress_ring.dart';

/// Screen 12: Offline-Accessible Saved Diet Plans with Explicit Meal Confirmation Logging.
class SavedDietPlansScreen extends ConsumerWidget {
  const SavedDietPlansScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = context.appTheme;
    final plansAsync = ref.watch(savedDietPlansProvider);

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
          'Saved Diet Plans',
          style: TextStyle(color: theme.text, fontWeight: FontWeight.w700),
        ),
      ),
      body: plansAsync.when(
        data: (plans) {
          if (plans.isEmpty) {
            return Center(
              child: NeumorphicContainer(
                margin: const EdgeInsets.all(24),
                padding: const EdgeInsets.all(20),
                child: Text(
                  'No saved diet plans yet. Generate and save a plan in AI Diet Planner to access it offline anytime.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: theme.secondaryText),
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: plans.length,
            itemBuilder: (context, index) {
              final plan = plans[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: NeumorphicContainer(
                  padding: const EdgeInsets.all(16),
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
                                  plan.title,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: theme.text,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${plan.totalCalories.round()} kcal • P ${plan.totalProtein.round()}g • C ${plan.totalCarbs.round()}g • F ${plan.totalFat.round()}g',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: NutritionAccentPalette.warmOrange,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (plan.isAccepted)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: NutritionAccentPalette.softGreen
                                    .withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'ACCEPTED',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: NutritionAccentPalette.softGreen,
                                ),
                              ),
                            ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded,
                                size: 20, color: NutritionAccentPalette.fatCoral),
                            onPressed: () async {
                              final userId = ref.read(nutritionUserIdProvider);
                              await ref
                                  .read(dietPlannerServiceProvider)
                                  .deleteSavedPlan(userId, plan.id);
                              ref.invalidate(savedDietPlansProvider);
                            },
                          ),
                        ],
                      ),
                      const Divider(),
                      ...plan.meals.map((meal) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${meal.mealCategory.label} (${meal.totalCalories.round()} kcal)',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: theme.text,
                                        ),
                                      ),
                                      Text(
                                        meal.items
                                            .map((i) =>
                                                '${i.servingCount}× ${i.foodNameSnapshot}')
                                            .join(', '),
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: theme.secondaryText,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                NeumorphicButton(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 6),
                                  color: NutritionAccentPalette.softGreen,
                                  onTap: () => _confirmLogMeal(context, ref, meal),
                                  child: const Text(
                                    'Log',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )),
                    ],
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error loading saved plans: $err')),
      ),
    );
  }

  Future<void> _confirmLogMeal(
    BuildContext context,
    WidgetRef ref,
    DietPlanMeal meal,
  ) async {
    final date = ref.read(selectedCalorieDateProvider);
    final dateStr = NutritionAnalyticsService.formatDate(date);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Log ${meal.mealCategory.label}?'),
        content: Text(
          'Confirm you consumed ${meal.items.length} food item(s) (${meal.totalCalories.round()} kcal) on $dateStr.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
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
    if (confirmed != true) return;

    final userId = ref.read(nutritionUserIdProvider);
    await ref.read(dietPlannerServiceProvider).confirmAndLogPlanMeal(
          userId: userId,
          date: dateStr,
          meal: meal,
        );
    await ref.read(dailyDashboardProvider.notifier).refresh();
    ref.invalidate(nutritionAnalyticsProvider);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Logged ${meal.mealCategory.label} to $dateStr.'),
          backgroundColor: NutritionAccentPalette.softGreen,
        ),
      );
    }
  }
}

