import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/components/neumorphic_button.dart';
import '../../../shared/components/neumorphic_container.dart';
import '../providers/calorie_providers.dart';
import '../widgets/calorie_progress_ring.dart';
import '../widgets/nutrition_charts.dart';
import 'monthly_goal_setup_screen.dart';

/// Screen 7: Daily, Weekly & Monthly Nutrition Analytics.
class MonthlyAnalyticsScreen extends ConsumerWidget {
  const MonthlyAnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = context.appTheme;
    final analyticsAsync = ref.watch(nutritionAnalyticsProvider);
    final selectedMonth = ref.watch(selectedAnalyticsMonthProvider);

    return analyticsAsync.when(
      data: (bundle) {
        final weekly = bundle.weekly;
        final monthly = bundle.monthly;
        final monthlyGoal = bundle.monthlyGoal;

        final prevDelta = monthly.previousPeriodAvgCalories != null
            ? monthly.averageDailyCalories - monthly.previousPeriodAvgCalories!
            : null;

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Weekly Analytics Card
            NeumorphicContainer(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Last 7 Days Trend',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: theme.text,
                        ),
                      ),
                      Text(
                        'Avg ${weekly.averageDailyCalories.round()} kcal/day',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: NutritionAccentPalette.warmOrange,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  CalorieTrendBarChart(points: weekly.dailyPoints),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _miniMetric(
                          theme, 'Days Logged', '${weekly.daysLogged}/7'),
                      _miniMetric(theme, 'Within Target',
                          '${weekly.daysWithinTarget}d'),
                      _miniMetric(
                          theme,
                          'Avg Protein',
                          '${weekly.averageDailyProtein.round()}g'),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Month switcher & Monthly Analytics Card
            NeumorphicContainer(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.chevron_left_rounded,
                            color: theme.text),
                        onPressed: () => ref
                            .read(selectedAnalyticsMonthProvider.notifier)
                            .shiftMonth(-1),
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            Text(
                              'Monthly Report • ${bundle.yearMonth}',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: theme.text,
                              ),
                            ),
                            Text(
                              '${monthly.totalCalendarDays} calendar days',
                              style: TextStyle(
                                fontSize: 11,
                                color: theme.secondaryText,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.chevron_right_rounded,
                            color: theme.text),
                        onPressed: () => ref
                            .read(selectedAnalyticsMonthProvider.notifier)
                            .shiftMonth(1),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  CalorieTrendBarChart(
                    points: monthly.dailyPoints,
                    height: 140,
                    compactLabels: true,
                  ),
                  const SizedBox(height: 14),
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 2.2,
                    children: [
                      _statBox(theme, 'Days Logged',
                          '${monthly.daysLogged} / ${monthly.totalCalendarDays}'),
                      _statBox(theme, 'Days Within Target',
                          '${monthly.daysWithinTarget} days'),
                      _statBox(theme, 'Daily Avg Intake',
                          '${monthly.averageDailyCalories.round()} kcal'),
                      _statBox(
                          theme,
                          'Meal Consistency',
                          '${monthly.mealConsistencyPercent.round()}%'),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (prevDelta != null)
                    Text(
                      'Historical comparison vs previous month: ${prevDelta >= 0 ? '+' : ''}${prevDelta.round()} kcal/day avg.',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.secondaryText,
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Monthly Macro Summary
            NeumorphicContainer(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Monthly Macro Averages (Logged Days)',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: theme.text,
                    ),
                  ),
                  const SizedBox(height: 10),
                  MacroCalorieSplitBar(
                    proteinGrams: monthly.totalProtein,
                    carbsGrams: monthly.totalCarbs,
                    fatGrams: monthly.totalFat,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Avg P ${monthly.averageDailyProtein.toStringAsFixed(1)}g • C ${monthly.averageDailyCarbs.toStringAsFixed(1)}g • F ${monthly.averageDailyFat.toStringAsFixed(1)}g • Fibre ${monthly.averageDailyFibre.toStringAsFixed(1)}g',
                    style: TextStyle(fontSize: 12, color: theme.secondaryText),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Independent Monthly Goal Progress
            NeumorphicContainer(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Monthly Goal Completion',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: theme.text,
                          ),
                        ),
                      ),
                      NeumorphicButton(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 7),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => MonthlyGoalSetupScreen(
                              initialYear: selectedMonth.year,
                              initialMonth: selectedMonth.month,
                            ),
                          ),
                        ),
                        child: Text(
                          monthlyGoal == null ? 'Set Monthly Goal' : 'Edit',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: NutritionAccentPalette.warmOrange,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (monthlyGoal == null)
                    Text(
                      'No independent monthly target configured for ${bundle.yearMonth} yet. Logged total: ${monthly.totalCalories.round()} kcal.',
                      style: TextStyle(fontSize: 12, color: theme.secondaryText),
                    )
                  else ...[
                    MacroProgressBar(
                      label: 'Monthly Calories',
                      current: monthly.totalCalories,
                      target: monthlyGoal.totalCalories,
                      unit: ' kcal',
                      color: NutritionAccentPalette.warmOrange,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${(monthly.monthlyProgressPercent ?? 0).toStringAsFixed(1)}% of ${monthlyGoal.totalCalories.round()} kcal monthly target completed.',
                      style:
                          TextStyle(fontSize: 12, color: theme.secondaryText),
                    ),
                  ],
                ],
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Error loading analytics: $err')),
    );
  }

  Widget _miniMetric(AppThemeData theme, String label, String val) {
    return Column(
      children: [
        Text(
          val,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: theme.text,
          ),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: theme.secondaryText),
        ),
      ],
    );
  }

  Widget _statBox(AppThemeData theme, String title, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.background.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            style: TextStyle(fontSize: 11, color: theme.secondaryText),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: theme.text,
            ),
          ),
        ],
      ),
    );
  }
}

