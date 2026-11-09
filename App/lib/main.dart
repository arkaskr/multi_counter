import 'dart:io' show Platform;
import 'dart:ui' show PlatformDispatcher;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'core/config/app_config.dart';
import 'core/constants/app_constants.dart';
import 'core/database/database_helper.dart';
import 'core/theme/theme_provider.dart';
import 'features/auth/providers/auth_providers.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/hub/screens/hub_screen.dart';
import 'features/meal_counter/meal_counter_shell.dart';

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

class DailyCounterApp extends ConsumerWidget {
  const DailyCounterApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: themeData.toThemeData(),
      home: homeWidget,
    );
  }
}
