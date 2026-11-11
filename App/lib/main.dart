import 'dart:io' show Platform;
import 'dart:ui' show PlatformDispatcher;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'core/config/app_config.dart';
import 'core/constants/app_constants.dart';
import 'core/database/database_helper.dart';
import 'core/theme/theme_provider.dart';
import 'features/app_update/services/app_update_service.dart';
import 'features/auth/providers/auth_providers.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/hub/screens/hub_screen.dart';

export 'features/meal_counter/meal_counter_shell.dart';

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

  // Initialize AppConfig (loads API URL / server endpoints)
  await AppConfig.init();

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

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

class DailyCounterApp extends ConsumerStatefulWidget {
  const DailyCounterApp({super.key});

  @override
  ConsumerState<DailyCounterApp> createState() => _DailyCounterAppState();
}

class _DailyCounterAppState extends ConsumerState<DailyCounterApp> {
  bool _hasCheckedUpdate = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkUpdateOnLaunch();
    });
  }

  void _checkUpdateOnLaunch() {
    if (_hasCheckedUpdate) return;
    _hasCheckedUpdate = true;

    // Asynchronously check for GitHub updates without delaying app startup
    Future.delayed(const Duration(milliseconds: 1500), () {
      final context = appNavigatorKey.currentContext;
      if (context != null && context.mounted) {
        AppUpdateService.instance.checkForUpdateAndPrompt(
          context,
          isManualCheck: false,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeData = ref.watch(themeProvider);
    final authState = ref.watch(authStateProvider);

    Widget homeWidget;
    if (!authState.isInitialized) {
      homeWidget = Scaffold(
        backgroundColor: themeData.background,
        body: const Center(child: CircularProgressIndicator()),
      );
    } else if (!authState.isLoggedIn && !authState.isGuestMode) {
      homeWidget = const LoginScreen();
    } else {
      homeWidget = const HubScreen();
    }

    return MaterialApp(
      navigatorKey: appNavigatorKey,
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: themeData.toThemeData(),
      home: homeWidget,
    );
  }
}
