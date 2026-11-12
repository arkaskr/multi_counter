import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/components/neumorphic_navigation_bar.dart';
import '../providers/calorie_providers.dart';
import '../widgets/calorie_progress_ring.dart';
import 'ai_diet_planner_screen.dart';
import 'calorie_dashboard_screen.dart';
import 'daily_goal_setup_screen.dart';
import 'food_catalogue_screen.dart';
import 'food_request_screen.dart';
import 'monthly_analytics_screen.dart';
import 'monthly_goal_setup_screen.dart';
import 'nutrition_preferences_screen.dart';
import 'saved_diet_plans_screen.dart';

/// Module Shell for the independent Calorie Counter module.
class CalorieCounterScreen extends ConsumerStatefulWidget {
  final int initialIndex;

  const CalorieCounterScreen({
    super.key,
    this.initialIndex = 0,
  });

  @override
  ConsumerState<CalorieCounterScreen> createState() =>
      _CalorieCounterScreenState();
}

class _CalorieCounterScreenState extends ConsumerState<CalorieCounterScreen> {
  late int _currentIndex;
  final Set<int> _visitedIndices = {};
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _visitedIndices.add(_currentIndex);
  }

  Future<void> _triggerManualSync() async {
    setState(() => _syncing = true);
    try {
      final res = await ref.read(dailyDashboardProvider.notifier).manualSync();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res.message),
          backgroundColor: res.success
              ? NutritionAccentPalette.softGreen
              : NutritionAccentPalette.carbsAmber,
        ),
      );
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.appTheme;

    const titles = [
      'Calorie Counter',
      'Food Catalogue',
      'AI Diet Planner',
      'Nutrition Analytics',
    ];

    final pages = [
      _visitedIndices.contains(0)
          ? const CalorieDashboardScreen()
          : const SizedBox.shrink(),
      _visitedIndices.contains(1)
          ? const FoodCatalogueScreen()
          : const SizedBox.shrink(),
      _visitedIndices.contains(2)
          ? const AiDietPlannerScreen()
          : const SizedBox.shrink(),
      _visitedIndices.contains(3)
          ? const MonthlyAnalyticsScreen()
          : const SizedBox.shrink(),
    ];

    return Scaffold(
      backgroundColor: theme.background,
      appBar: AppBar(
        backgroundColor: theme.background,
        elevation: 0,
        leading: IconButton(
          tooltip: 'Back to Hub',
          icon: Icon(Icons.arrow_back_rounded, color: theme.text),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(
          titles[_currentIndex],
          style: TextStyle(
            color: theme.text,
            fontWeight: FontWeight.w800,
            fontSize: 19,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Sync nutrition data',
            onPressed: _syncing ? null : _triggerManualSync,
            icon: _syncing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(
                    Icons.cloud_sync_rounded,
                    color: NutritionAccentPalette.softGreen,
                  ),
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert_rounded, color: theme.text),
            color: theme.surface,
            onSelected: (value) {
              Widget? target;
              switch (value) {
                case 'daily_goals':
                  target = const DailyGoalSetupScreen();
                  break;
                case 'monthly_goals':
                  target = const MonthlyGoalSetupScreen();
                  break;
                case 'preferences':
                  target = const NutritionPreferencesScreen();
                  break;
                case 'saved_plans':
                  target = const SavedDietPlansScreen();
                  break;
                case 'request_food':
                  target = const FoodRequestScreen();
                  break;
              }
              if (target != null) {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => target!),
                );
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'daily_goals',
                child: Text('Daily Goals Setup',
                    style: TextStyle(color: theme.text)),
              ),
              PopupMenuItem(
                value: 'monthly_goals',
                child: Text('Monthly Goals Setup',
                    style: TextStyle(color: theme.text)),
              ),
              PopupMenuItem(
                value: 'preferences',
                child: Text('Nutrition Preferences',
                    style: TextStyle(color: theme.text)),
              ),
              PopupMenuItem(
                value: 'saved_plans',
                child: Text('Saved Diet Plans',
                    style: TextStyle(color: theme.text)),
              ),
              PopupMenuItem(
                value: 'request_food',
                child:
                    Text('Request a Food', style: TextStyle(color: theme.text)),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: IndexedStack(
          index: _currentIndex,
          children: pages,
        ),
      ),
      bottomNavigationBar: NeumorphicNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() {
          _currentIndex = index;
          _visitedIndices.add(index);
        }),
        items: const [
          NeumorphicNavItem(
            icon: Icons.local_fire_department_rounded,
            label: 'Dashboard',
          ),
          NeumorphicNavItem(
            icon: Icons.restaurant_menu_rounded,
            label: 'Foods',
          ),
          NeumorphicNavItem(
            icon: Icons.auto_awesome_rounded,
            label: 'AI Plan',
          ),
          NeumorphicNavItem(
            icon: Icons.bar_chart_rounded,
            label: 'Analytics',
          ),
        ],
      ),
    );
  }
}
