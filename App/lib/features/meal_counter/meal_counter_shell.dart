import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:daily_counter/core/services/widget_service.dart';
import 'package:daily_counter/features/auth/providers/auth_providers.dart';
import 'package:daily_counter/shared/components/neumorphic_navigation_bar.dart';
import 'providers/home_providers.dart';
import 'screens/analytics_screen.dart';
import 'screens/history_screen.dart';
import 'screens/home_screen.dart';
import 'screens/settings_screen.dart';

class MealCounterShell extends ConsumerStatefulWidget {
  final int initialIndex;

  const MealCounterShell({
    super.key,
    this.initialIndex = 0,
  });

  @override
  ConsumerState<MealCounterShell> createState() => _MealCounterShellState();
}

class _MealCounterShellState extends ConsumerState<MealCounterShell> with WidgetsBindingObserver {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    WidgetsBinding.instance.addObserver(this);

    // Listen to native Glance widget updates in real-time
    WidgetService.instance.onWidgetUpdatedCallback = () {
      if (mounted) {
        ref.invalidate(todayRecordProvider);
        ref.invalidate(homeWeeklySummaryProvider);
        ref.invalidate(cycleMealsCountProvider);
        ref.invalidate(cycleTotalAmountProvider);
        ref.read(syncServiceProvider).autoSync();
      }
    };
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    WidgetService.instance.onWidgetUpdatedCallback = null;
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(todayRecordProvider);
      ref.invalidate(homeWeeklySummaryProvider);
      ref.invalidate(cycleMealsCountProvider);
      ref.invalidate(cycleTotalAmountProvider);
      ref.read(syncServiceProvider).autoSync();
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomeScreen(
        onOpenSettings: () {
          setState(() => _currentIndex = 3);
        },
        onBackToHub: () {
          Navigator.of(context).maybePop();
        },
      ),
      const AnalyticsScreen(),
      const HistoryScreen(),
      const SettingsScreen(),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: pages,
      ),
      bottomNavigationBar: NeumorphicNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() => _currentIndex = index);
        },
        items: const [
          NeumorphicNavItem(
            icon: Icons.dashboard_rounded,
            label: 'Home',
          ),
          NeumorphicNavItem(
            icon: Icons.insights_rounded,
            label: 'Analytics',
          ),
          NeumorphicNavItem(
            icon: Icons.calendar_month_rounded,
            label: 'History',
          ),
          NeumorphicNavItem(
            icon: Icons.tune_rounded,
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}

// Backward compatibility alias
typedef MainShell = MealCounterShell;

