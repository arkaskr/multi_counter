import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:daily_counter/core/constants/app_constants.dart';
import 'package:daily_counter/core/services/widget_service.dart';
import 'package:daily_counter/core/theme/app_theme.dart';
import 'package:daily_counter/core/theme/theme_provider.dart';
import 'package:daily_counter/core/utils/date_utils.dart';
import 'package:daily_counter/features/auth/providers/auth_providers.dart';
import 'package:daily_counter/features/calorie_counter/screens/calorie_counter_screen.dart';
import 'package:daily_counter/features/expense_counter/screens/expense_counter_screen.dart';
import 'package:daily_counter/features/hub/screens/global_settings_screen.dart';
import 'package:daily_counter/features/hub/widgets/hub_card.dart';
import 'package:daily_counter/features/meal_counter/meal_counter_shell.dart';
import 'package:daily_counter/features/meal_counter/providers/home_providers.dart';
import 'package:daily_counter/features/surprise/screens/surprise_screen.dart';
import 'package:daily_counter/shared/components/neumorphic_container.dart';

class HubScreen extends ConsumerStatefulWidget {
  const HubScreen({super.key});

  @override
  ConsumerState<HubScreen> createState() => _HubScreenState();
}

class _HubScreenState extends ConsumerState<HubScreen> with WidgetsBindingObserver {
  DateTime? _lastOfflineToastTime;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ref.read(themeProvider.notifier).loadTheme();

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

    // Trigger background cloud sync with MongoDB if online
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndSync(showOfflineToast: true);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    WidgetService.instance.onWidgetUpdatedCallback = null;
    super.dispose();
  }

  Future<void> _checkAndSync({bool showOfflineToast = false}) async {
    final syncService = ref.read(syncServiceProvider);
    final isOnline = await syncService.checkServerReachability();
    if (isOnline) {
      await syncService.autoSync();
    } else if (showOfflineToast && mounted) {
      final now = DateTime.now();
      if (_lastOfflineToastTime == null || now.difference(_lastOfflineToastTime!).inSeconds > 30) {
        _lastOfflineToastTime = now;
        _showOfflineNotification(context);
      }
    }
  }

  void _showOfflineNotification(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: const Color(0xFF2C3142),
        duration: const Duration(seconds: 4),
        content: const Row(
          children: [
            Icon(Icons.wifi_off_rounded, color: Colors.amber, size: 22),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'You are offline. Changes will be auto-synced to cloud when internet is available.',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(todayRecordProvider);
      ref.invalidate(homeWeeklySummaryProvider);
      ref.invalidate(cycleMealsCountProvider);
      ref.invalidate(cycleTotalAmountProvider);
      _checkAndSync(showOfflineToast: true);
    }
  }

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.appTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Log Out',
          style: TextStyle(color: context.appTheme.text, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Are you sure you want to log out? Local data is safely backed up to MongoDB.',
          style: TextStyle(color: context.appTheme.secondaryText),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel', style: TextStyle(color: context.appTheme.secondaryText)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Log Out', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await ref.read(authStateProvider.notifier).logout();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.appTheme;
    final authState = ref.watch(authStateProvider);
    final userName = authState.user?.name.trim().isNotEmpty == true
        ? authState.user!.name.trim()
        : (authState.isGuestMode ? 'Guest' : 'Friend');

    final userInitial = userName.isNotEmpty ? userName[0].toUpperCase() : 'U';
    final todayStr = AppDateUtils.getTodayDateString();

    return Scaffold(
      backgroundColor: theme.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row: User Avatar, Greeting, and Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      // Avatar Circle
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: theme.accent.withValues(alpha: 0.15),
                          border: Border.all(color: theme.accent.withValues(alpha: 0.5), width: 1.5),
                        ),
                        child: Center(
                          child: Text(
                            userInitial,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: theme.accent,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Welcome back,',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: theme.secondaryText,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            userName,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: theme.text,
                              letterSpacing: -0.3,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  // Actions: Settings + Sync + Logout
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const GlobalSettingsScreen()),
                          );
                        },
                        child: NeumorphicContainer(
                          borderRadius: 14,
                          padding: const EdgeInsets.all(10),
                          child: Icon(
                            Icons.settings_outlined,
                            size: 20,
                            color: theme.accent,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      GestureDetector(
                        onTap: () async {
                          await _checkAndSync(showOfflineToast: true);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text('Data synced with MongoDB cloud.'),
                                backgroundColor: Colors.green[700],
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          }
                        },
                        child: NeumorphicContainer(
                          borderRadius: 14,
                          padding: const EdgeInsets.all(10),
                          child: Icon(
                            Icons.cloud_sync_rounded,
                            size: 20,
                            color: theme.accent,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      GestureDetector(
                        onTap: _handleLogout,
                        child: NeumorphicContainer(
                          borderRadius: 14,
                          padding: const EdgeInsets.all(10),
                          child: Icon(
                            Icons.logout_rounded,
                            size: 20,
                            color: Colors.red[400],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Date & Status Banner
              NeumorphicContainer(
                borderRadius: 20,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: theme.accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.calendar_today_rounded, size: 16, color: theme.accent),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppDateUtils.formatDisplayDate(todayStr),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: theme.text,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            authState.isLoggedIn ? 'MongoDB Cloud Sync Active' : 'Offline Storage Active',
                            style: TextStyle(
                              fontSize: 11,
                              color: authState.isLoggedIn ? Colors.green[400] : theme.secondaryText,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // 2 Row x 2 Col Setup
              Row(
                children: [
                  Expanded(
                    child: HubCard(
                      icon: Icons.lunch_dining_rounded,
                      title: 'Meal Counter',
                      iconColor: const Color(0xFF00E676),
                      iconBgColor: const Color(0xFF00E676).withValues(alpha: 0.15),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const MealCounterShell(),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: HubCard(
                      icon: Icons.local_fire_department_rounded,
                      title: 'Calorie Counter',
                      iconColor: const Color(0xFFFF6D00),
                      iconBgColor: const Color(0xFFFF6D00).withValues(alpha: 0.15),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const CalorieCounterScreen(),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: HubCard(
                      icon: Icons.account_balance_wallet_rounded,
                      title: 'Expense Counter',
                      iconColor: const Color(0xFF2979FF),
                      iconBgColor: const Color(0xFF2979FF).withValues(alpha: 0.15),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const ExpenseCounterScreen(),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: HubCard(
                      icon: Icons.auto_awesome_rounded,
                      title: 'Surprise',
                      iconColor: const Color(0xFFA855F7),
                      iconBgColor: const Color(0xFFA855F7).withValues(alpha: 0.15),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const SurpriseScreen(),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}

