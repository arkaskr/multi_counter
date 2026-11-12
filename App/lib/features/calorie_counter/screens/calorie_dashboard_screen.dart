import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/components/neumorphic_button.dart';
import '../../../shared/components/neumorphic_container.dart';
import '../models/meal_log_model.dart';
import '../providers/calorie_providers.dart';
import '../widgets/calorie_progress_ring.dart';
import '../widgets/food_illustration.dart';
import 'add_edit_meal_screen.dart';
import 'daily_goal_setup_screen.dart';
import 'daily_nutrition_summary_screen.dart';
import 'food_detail_screen.dart';
import 'food_search_screen.dart';

/// Screen 1: Daily Calorie Counter Dashboard.
class CalorieDashboardScreen extends ConsumerWidget {
  const CalorieDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = context.appTheme;
    final selectedDate = ref.watch(selectedCalorieDateProvider);
    final dashboardAsync = ref.watch(dailyDashboardProvider);

    final now = DateTime.now();
    final isToday = selectedDate.year == now.year &&
        selectedDate.month == now.month &&
        selectedDate.day == now.day;

    return dashboardAsync.when(
      data: (state) {
        final totals = state.totals;
        final goal = state.goal;

        return RefreshIndicator(
          onRefresh: () =>
              ref.read(dailyDashboardProvider.notifier).refresh(),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
            children: [
              // Date Navigator Bar
              NeumorphicContainer(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: 'Previous day',
                      icon: Icon(Icons.chevron_left_rounded, color: theme.text),
                      onPressed: () => ref
                          .read(selectedCalorieDateProvider.notifier)
                          .shiftDays(-1),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: selectedDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now().add(const Duration(days: 7)),
                          );
                          if (picked != null) {
                            ref
                                .read(selectedCalorieDateProvider.notifier)
                                .setDate(picked);
                          }
                        },
                        child: Column(
                          children: [
                            Text(
                              isToday
                                  ? 'Today'
                                  : DateFormat('EEE, d MMM yyyy')
                                      .format(selectedDate),
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: theme.text,
                              ),
                            ),
                            Text(
                              totals.hasRecords
                                  ? '${totals.entryCount} logged item(s)'
                                  : 'No records recorded for this date',
                              style: TextStyle(
                                fontSize: 11,
                                color: totals.hasRecords
                                    ? NutritionAccentPalette.softGreen
                                    : theme.secondaryText,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Next day',
                      icon:
                          Icon(Icons.chevron_right_rounded, color: theme.text),
                      onPressed: () => ref
                          .read(selectedCalorieDateProvider.notifier)
                          .shiftDays(1),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // Main Calorie & Macros Hero Card
              NeumorphicContainer(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        CalorieProgressRing(
                          consumed: totals.calories,
                          target: goal.calories,
                          size: 144,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            children: [
                              MacroProgressBar(
                                label: 'Protein',
                                current: totals.protein,
                                target: goal.protein,
                                color: NutritionAccentPalette.proteinBlue,
                              ),
                              const SizedBox(height: 8),
                              MacroProgressBar(
                                label: 'Carbs',
                                current: totals.carbs,
                                target: goal.carbs,
                                color: NutritionAccentPalette.carbsAmber,
                              ),
                              const SizedBox(height: 8),
                              MacroProgressBar(
                                label: 'Fat',
                                current: totals.fat,
                                target: goal.fat,
                                color: NutritionAccentPalette.fatCoral,
                              ),
                              const SizedBox(height: 8),
                              MacroProgressBar(
                                label: 'Fibre',
                                current: totals.fibre,
                                target: goal.fibre,
                                color: NutritionAccentPalette.fibreTeal,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (!totals.hasRecords)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: theme.secondaryText.withValues(alpha: 0.09),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'No food records exist for ${state.dateString} yet.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.secondaryText,
                          ),
                        ),
                      )
                    else if (totals.hasRecordedZeroCalories)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: NutritionAccentPalette.softGreen
                              .withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          'Zero-calorie intake explicitly recorded for this day.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: NutritionAccentPalette.softGreen,
                          ),
                        ),
                      ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: NeumorphicButton(
                            color: NutritionAccentPalette.warmOrange,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const FoodSearchScreen(),
                              ),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_rounded,
                                    color: Colors.white, size: 18),
                                SizedBox(width: 6),
                                Text(
                                  'Quick Add Food',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        NeumorphicButton(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 12),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  const DailyNutritionSummaryScreen(),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.pie_chart_outline_rounded,
                                  size: 18, color: theme.text),
                              const SizedBox(width: 4),
                              Text(
                                'Details',
                                style: TextStyle(
                                  color: theme.text,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        NeumorphicButton(
                          padding: const EdgeInsets.all(12),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const DailyGoalSetupScreen(),
                            ),
                          ),
                          child: const Icon(Icons.flag_rounded,
                              size: 18,
                              color: NutritionAccentPalette.softGreen),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // Hydration Quick Tracker
              if (goal.hydrationMl != null && goal.hydrationMl! > 0) ...[
                NeumorphicContainer(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Row(
                    children: [
                      const Icon(Icons.water_drop_rounded,
                          color: NutritionAccentPalette.waterCyan, size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: MacroProgressBar(
                          label: 'Hydration',
                          current: totals.hydrationMl.toDouble(),
                          target: goal.hydrationMl!.toDouble(),
                          unit: ' ml',
                          color: NutritionAccentPalette.waterCyan,
                        ),
                      ),
                      const SizedBox(width: 10),
                      NeumorphicButton(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        onTap: () => ref
                            .read(dailyDashboardProvider.notifier)
                            .setHydration(totals.hydrationMl + 250),
                        child: const Text(
                          '+250ml',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: NutritionAccentPalette.waterCyan,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // Recently Consumed Foods
              if (state.recentFoods.isNotEmpty) ...[
                Text(
                  'Recently Consumed',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: theme.text,
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 92,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: state.recentFoods.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 10),
                    itemBuilder: (context, index) {
                      final food = state.recentFoods[index];
                      return SizedBox(
                        width: 152,
                        child: NeumorphicButton(
                          padding: const EdgeInsets.all(10),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => FoodDetailScreen(
                                food: food,
                                initialMealCategory: _defaultMealCategoryForNow(),
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              FoodIllustration(
                                illustrationId: food.illustrationId,
                                categoryId: food.categoryId,
                                size: 36,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      food.name,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: theme.text,
                                      ),
                                    ),
                                    Text(
                                      '${food.caloriesPerDefaultServing.round()} kcal',
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color:
                                            NutritionAccentPalette.warmOrange,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Meals Sections
              Text(
                "Today's Meals",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: theme.text,
                ),
              ),
              const SizedBox(height: 10),
              ...MealCategory.values.map((mealCat) {
                final items = totals.logsByMeal[mealCat] ?? const [];
                final mealKcal = totals.mealCalories(mealCat);
                return Padding(
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
                                    mealCat.label,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      color: theme.text,
                                    ),
                                  ),
                                  Text(
                                    items.isEmpty
                                        ? 'No items logged'
                                        : '${items.length} item(s) • ${mealKcal.round()} kcal',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: theme.secondaryText,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            NeumorphicButton(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 7),
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => AddEditMealScreen(
                                    initialMealCategory: mealCat,
                                  ),
                                ),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.add_rounded,
                                      size: 16,
                                      color: NutritionAccentPalette.warmOrange),
                                  SizedBox(width: 3),
                                  Text(
                                    'Add',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: NutritionAccentPalette.warmOrange,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (items.isNotEmpty) ...[
                          const Divider(),
                          ...items.map((log) => InkWell(
                                onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => AddEditMealScreen(
                                      existingLog: log,
                                    ),
                                  ),
                                ),
                                child: Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 6),
                                  child: Row(
                                    children: [
                                      FoodIllustration(
                                        illustrationId:
                                            log.illustrationSnapshot,
                                        size: 36,
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              log.foodNameSnapshot,
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w700,
                                                color: theme.text,
                                              ),
                                            ),
                                            Text(
                                              '${log.servingCount} × ${log.servingLabelSnapshot} (${log.totalGrams.round()}g)',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: theme.secondaryText,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            '${log.calories.round()} kcal',
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w800,
                                              color: NutritionAccentPalette
                                                  .warmOrange,
                                            ),
                                          ),
                                          Text(
                                            'P ${log.protein.toStringAsFixed(1)}g',
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: theme.secondaryText,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(width: 4),
                                      IconButton(
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        icon: Icon(
                                          Icons.close_rounded,
                                          size: 16,
                                          color: theme.secondaryText,
                                        ),
                                        onPressed: () => ref
                                            .read(
                                                dailyDashboardProvider.notifier)
                                            .deleteLogEntry(log.id),
                                      ),
                                    ],
                                  ),
                                ),
                              )),
                        ],
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('Error loading dashboard: $err'),
        ),
      ),
    );
  }
}

MealCategory _defaultMealCategoryForNow() {
  final hour = DateTime.now().hour;
  if (hour < 11) return MealCategory.breakfast;
  if (hour < 13) return MealCategory.morningSnack;
  if (hour < 16) return MealCategory.lunch;
  if (hour < 19) return MealCategory.eveningSnack;
  return MealCategory.dinner;
}
