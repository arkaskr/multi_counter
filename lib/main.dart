import 'dart:io' show Platform;
import 'dart:ui' show PlatformDispatcher;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'core/constants/app_constants.dart';
import 'core/database/database_helper.dart';
import 'core/services/widget_service.dart';
import 'core/theme/theme_provider.dart';
import 'features/history/screens/history_screen.dart';
import 'features/home/providers/home_providers.dart';
import 'features/home/screens/home_screen.dart';
import 'features/settings/screens/settings_screen.dart';
import 'shared/components/neumorphic_navigation_bar.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Setup global error handling so unexpected errors do not terminate the process
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('Caught Flutter Error: ${details.exceptionAsString()}');
  };

  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    debugPrint('Uncaught Asynchronous Error: $error\n$stack');
    return true; // handled, don't crash
  };

  // Initialize SQLite FFI on desktop platforms (Linux, Windows, macOS)
  if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
    try {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    } catch (e) {
      debugPrint('Desktop SQLite FFI initialization note: $e');
    }
  }

  // Safe initialize SQLite database (app proceeds even if deferred)
  try {
    await DatabaseHelper.instance.database;
  } catch (e, stack) {
    debugPrint('Database initialization deferred: $e\n$stack');
  }

  runApp(
    const ProviderScope(
      child: DailyCounterApp(),
    ),
  );
}

class DailyCounterApp extends ConsumerWidget {
  const DailyCounterApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeData = ref.watch(themeProvider);

    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: themeData.toThemeData(),
      home: const MainShell(),
    );
  }
}

class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> with WidgetsBindingObserver {
  int _currentIndex = 0;

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
    // When user returns to app after tapping the home-screen widget
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(todayRecordProvider);
      ref.invalidate(homeWeeklySummaryProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomeScreen(
        onOpenSettings: () {
          setState(() => _currentIndex = 2);
        },
      ),
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
