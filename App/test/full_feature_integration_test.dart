import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:daily_counter/core/database/database_helper.dart';
import 'package:daily_counter/core/database/database_schema.dart';
import 'package:daily_counter/core/services/counter_service.dart';
import 'package:daily_counter/core/services/settings_service.dart';
import 'package:daily_counter/core/theme/app_theme.dart';
import 'package:daily_counter/core/theme/theme_presets.dart';
import 'package:daily_counter/core/theme/theme_provider.dart';
import 'package:daily_counter/core/utils/date_utils.dart';
import 'package:daily_counter/features/daily_edit/screens/daily_edit_screen.dart';
import 'package:daily_counter/features/history/screens/history_screen.dart';
import 'package:daily_counter/features/home/providers/home_providers.dart';
import 'package:daily_counter/features/home/screens/home_screen.dart';
import 'package:daily_counter/features/hub/screens/global_settings_screen.dart';
import 'package:daily_counter/features/settings/screens/settings_screen.dart';
import 'package:daily_counter/shared/models/app_settings.dart';
import 'package:daily_counter/shared/models/daily_record.dart';
import 'package:daily_counter/shared/models/weekly_summary.dart';

class FakeCounterService extends CounterService {
  final Map<String, DailyRecord> _store = {};

  @override
  Future<DailyRecord> getRecord(String date) async {
    return _store[date] ?? DailyRecord.empty(date);
  }

  @override
  Future<DailyRecord> getTodayRecord() async {
    final today = AppDateUtils.getTodayDateString();
    return getRecord(today);
  }

  @override
  Future<CounterResult> incrementToday() async {
    final today = AppDateUtils.getTodayDateString();
    return incrementDate(today);
  }

  @override
  Future<CounterResult> incrementDate(String date) async {
    final current = await getRecord(date);
    if (current.count >= 2) {
      return CounterResult(success: false, record: current, message: 'Daily limit reached!');
    }
    final updated = current.copyWith(
      count: current.count + 1,
      updatedAt: DateTime.now().toIso8601String(),
    );
    _store[date] = updated;
    return CounterResult(success: true, record: updated);
  }

  @override
  Future<CounterResult> decrementToday() async {
    final today = AppDateUtils.getTodayDateString();
    return decrementDate(today);
  }

  @override
  Future<CounterResult> decrementDate(String date) async {
    final current = await getRecord(date);
    if (current.count <= 0) {
      return CounterResult(success: true, record: current);
    }
    final updated = current.copyWith(
      count: current.count - 1,
      updatedAt: DateTime.now().toIso8601String(),
    );
    _store[date] = updated;
    return CounterResult(success: true, record: updated);
  }

  @override
  Future<CounterResult> setCount(String date, int count, int dailyLimit) async {
    final updated = DailyRecord(
      date: date,
      count: count,
      updatedAt: DateTime.now().toIso8601String(),
    );
    _store[date] = updated;
    return CounterResult(success: true, record: updated);
  }

  @override
  Future<DailyRecord> setAmountOverride(String date, double? override) async {
    final current = await getRecord(date);
    final updated = current.copyWith(
      amountOverride: override,
      clearAmountOverride: override == null,
      updatedAt: DateTime.now().toIso8601String(),
    );
    _store[date] = updated;
    return updated;
  }

  @override
  Future<void> resetDay(String date) async {
    _store.remove(date);
  }

  @override
  Future<void> resetWeek(List<String> weekDates) async {
    for (final d in weekDates) {
      _store.remove(d);
    }
  }

  @override
  Future<void> resetAllData() async {
    _store.clear();
  }

  @override
  Future<int> getFoodDaysCount() async {
    return _store.values.where((r) => r.count > 0).map((r) => r.date).toSet().length;
  }

  String? _checkpointDate;

  @override
  Future<int> getCycleMealsCount(String? checkpointDate) async {
    final cp = checkpointDate ?? _checkpointDate;
    return _store.values
        .where((r) => cp == null || cp.isEmpty || r.date.compareTo(cp) > 0)
        .fold<int>(0, (sum, r) => sum + r.count);
  }

  @override
  Future<double> getCycleTotalAmount(String? checkpointDate, double unitAmount) async {
    final cp = checkpointDate ?? _checkpointDate;
    return _store.values
        .where((r) => cp == null || cp.isEmpty || r.date.compareTo(cp) > 0)
        .fold<double>(0.0, (sum, r) => sum + r.calculateAmount(unitAmount));
  }

  @override
  Future<void> setCheckpoint(String date) async {
    _checkpointDate = date;
  }

  @override
  Future<void> clearCheckpoint() async {
    _checkpointDate = null;
  }

  @override
  Future<WeeklySummary> getWeekSummary(List<String> weekDates, AppSettings settings) async {
    return WeeklySummary.calculate(
      weekDates: weekDates,
      records: _store,
      unitAmount: settings.unitAmount,
      dailyLimit: settings.dailyLimit,
    );
  }
}

class FakeSettingsService extends SettingsService {
  AppSettings _settings = const AppSettings(
    unitAmount: 55.0,
    dailyLimit: 2,
    weekStart: 'monday',
    currencySymbol: '₹',
    selectedTheme: 'midnight_dark',
  );

  @override
  Future<AppSettings> getSettings() async => _settings;

  @override
  Future<List<DailyRecord>> checkDailyLimitConflicts(int newLimit) async => [];

  @override
  Future<void> updateSettings(AppSettings settings) async {
    _settings = settings;
  }

  @override
  Future<void> updateUnitAmount(double unitAmount) async {
    _settings = _settings.copyWith(unitAmount: unitAmount);
  }

  @override
  Future<void> updateDailyLimit(int dailyLimit) async {
    _settings = _settings.copyWith(dailyLimit: dailyLimit);
  }

  @override
  Future<void> updateTheme(String themeId, {String? customConfig}) async {
    _settings = _settings.copyWith(selectedTheme: themeId);
  }

  @override
  Future<void> updateWeekStart(String weekStart) async {
    _settings = _settings.copyWith(weekStart: weekStart);
  }

  @override
  Future<void> updateCurrencySymbol(String symbol) async {
    _settings = _settings.copyWith(currencySymbol: symbol);
  }

  @override
  Future<void> resetSettingsToDefaults() async {
    _settings = const AppSettings(
      unitAmount: 55.0,
      dailyLimit: 2,
      weekStart: 'monday',
      currencySymbol: '₹',
      selectedTheme: 'midnight_dark',
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  AppThemeData.useGoogleFonts = false;

  late Database db;
  late DatabaseHelper dbHelper;
  late CounterService counterService;
  late SettingsService settingsService;

  setUp(() async {
    DatabaseHelper.resetForTesting();
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    dbHelper = DatabaseHelper.withDatabase(db);

    await db.execute(DatabaseSchema.createDailyRecordsTable);
    await db.execute(DatabaseSchema.createDailyRecordsDateIndex);
    await db.execute(DatabaseSchema.createAppSettingsTable);

    final batch = db.batch();
    for (final setting in DatabaseSchema.initialSettings) {
      batch.insert('app_settings', setting);
    }
    await batch.commit(noResult: true);

    counterService = CounterService(dbHelper: dbHelper);
    settingsService = SettingsService(dbHelper: dbHelper);
  });

  tearDown(() async {
    await db.close();
    DatabaseHelper.resetForTesting();
  });

  group('Advanced Logic & Edge Cases with Real SQLite', () {
    test('Daily rollover preserves yesterday and starts today with 0', () async {
      const yesterday = '2026-11-01';
      const today = '2026-11-02';

      await counterService.incrementDate(yesterday);
      await counterService.incrementDate(yesterday);

      final recYesterday = await counterService.getRecord(yesterday);
      expect(recYesterday.count, 2);

      final recToday = await counterService.getRecord(today);
      expect(recToday.count, 0);

      await counterService.incrementDate(today);
      expect((await counterService.getRecord(today)).count, 1);
      expect((await counterService.getRecord(yesterday)).count, 2);
    });

    test('Weekly reset resets only the specified week dates', () async {
      final week1 = ['2026-10-26', '2026-10-27', '2026-10-28', '2026-10-29', '2026-10-30', '2026-10-31', '2026-11-01'];
      final week2 = ['2026-11-02', '2026-11-03', '2026-11-04', '2026-11-05', '2026-11-06', '2026-11-07', '2026-11-08'];

      await counterService.incrementDate(week1[0]);
      await counterService.incrementDate(week2[0]);

      expect((await counterService.getRecord(week1[0])).count, 1);
      expect((await counterService.getRecord(week2[0])).count, 1);

      await counterService.resetWeek(week1);

      expect((await counterService.getRecord(week1[0])).count, 0);
      expect((await counterService.getRecord(week2[0])).count, 1);
    });

    test('Reset all data clears daily records but preserves user settings', () async {
      await settingsService.updateUnitAmount(55.0);
      await settingsService.updateDailyLimit(4);
      await settingsService.updateTheme('midnight_dark');

      await counterService.incrementDate('2026-11-02');
      await counterService.incrementDate('2026-11-03');

      await counterService.resetAllData();

      expect((await counterService.getRecord('2026-11-02')).count, 0);
      expect((await counterService.getRecord('2026-11-03')).count, 0);

      final settings = await settingsService.getSettings();
      expect(settings.unitAmount, 55.0);
      expect(settings.dailyLimit, 4);
      expect(settings.selectedTheme, 'midnight_dark');
    });

    test('Changing unit amount recalculates amounts except for custom overrides', () async {
      const dayNormal = '2026-11-02';
      const dayOverride = '2026-11-03';

      await counterService.incrementDate(dayNormal);
      await counterService.incrementDate(dayOverride);
      await counterService.setAmountOverride(dayOverride, 100.0);

      var recNormal = await counterService.getRecord(dayNormal);
      var recOverride = await counterService.getRecord(dayOverride);
      expect(recNormal.calculateAmount(55.0), 55.0);
      expect(recOverride.calculateAmount(55.0), 100.0);

      await settingsService.updateUnitAmount(60.0);
      final newSettings = await settingsService.getSettings();

      recNormal = await counterService.getRecord(dayNormal);
      recOverride = await counterService.getRecord(dayOverride);
      expect(recNormal.calculateAmount(newSettings.unitAmount), 60.0);
      expect(recOverride.calculateAmount(newSettings.unitAmount), 100.0);
    });

    test('All 6 themes load, persist and switch cleanly', () async {
      final themeIds = ['soft_light', 'pure_white', 'midnight_dark', 'lavender', 'mint', 'warm_sand'];

      for (final id in themeIds) {
        await settingsService.updateTheme(id);
        final settings = await settingsService.getSettings();
        expect(settings.selectedTheme, id);

        final palette = ThemePresets.getById(id);
        expect(palette.id, id);
        final appTheme = AppThemeData.fromPalette(palette);
        expect(appTheme.toThemeData(), isNotNull);
      }
    });
  });

  group('UI Screen Widget Tests', () {
    testWidgets('HomeScreen renders today state and displays counter and amount', (tester) async {
      final fakeCounter = FakeCounterService();
      final fakeSettings = FakeSettingsService();

      final container = ProviderContainer(
        overrides: [
          counterServiceProvider.overrideWithValue(fakeCounter),
          settingsServiceProvider.overrideWithValue(fakeSettings),
        ],
      );
      addTearDown(container.dispose);

      final theme = AppThemeData.fromPalette(ThemePresets.softLight).toThemeData();

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: theme,
            home: HomeScreen(onOpenSettings: () {}),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text("TODAY'S COUNTER"), findsOneWidget);
      expect(find.text("TODAY'S AMOUNT"), findsOneWidget);
      expect(find.text('REMAINING: 2'), findsOneWidget);
      expect(find.text('WEEKLY PREVIEW'), findsOneWidget);
      expect(find.byIcon(Icons.tune_rounded), findsNothing);

      // Tap +1 button
      await tester.tap(find.byIcon(Icons.add_rounded));
      await tester.pumpAndSettle();

      expect(find.text('REMAINING: 1'), findsOneWidget);
      expect(find.text('₹55'), findsWidgets);
    });

    testWidgets('HistoryScreen displays weekly breakdown and navigation', (tester) async {
      final fakeCounter = FakeCounterService();
      final fakeSettings = FakeSettingsService();

      final container = ProviderContainer(
        overrides: [
          counterServiceProvider.overrideWithValue(fakeCounter),
          settingsServiceProvider.overrideWithValue(fakeSettings),
        ],
      );
      addTearDown(container.dispose);

      final theme = AppThemeData.fromPalette(ThemePresets.softLight).toThemeData();

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: theme,
            home: const HistoryScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('History'), findsOneWidget);
      expect(find.text('WEEKLY BREAKDOWN'), findsOneWidget);
      expect(find.text('DAILY BREAKDOWN'), findsOneWidget);
      expect(find.text('Total Count'), findsOneWidget);
      expect(find.text('Total Amount'), findsOneWidget);
      expect(find.byIcon(Icons.chevron_left_rounded), findsOneWidget);
      expect(find.byIcon(Icons.calendar_month_rounded), findsOneWidget);

      // Tap previous week
      await tester.tap(find.byIcon(Icons.chevron_left_rounded));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.today_rounded), findsOneWidget);

      expect(find.byTooltip('Next Week'), findsOneWidget);
    });

    testWidgets('DailyEditScreen allows adjusting count, override and reset', (tester) async {
      const testDate = '2026-11-02';
      final fakeCounter = FakeCounterService();
      final fakeSettings = FakeSettingsService();

      final container = ProviderContainer(
        overrides: [
          counterServiceProvider.overrideWithValue(fakeCounter),
          settingsServiceProvider.overrideWithValue(fakeSettings),
        ],
      );
      addTearDown(container.dispose);

      final theme = AppThemeData.fromPalette(ThemePresets.softLight).toThemeData();

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: theme,
            home: const DailyEditScreen(date: testDate),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Daily Record'), findsOneWidget);
      expect(find.text('DAILY COUNTER'), findsOneWidget);
      expect(find.text('DAILY AMOUNT'), findsOneWidget);
      expect(find.byIcon(Icons.remove_rounded), findsOneWidget);
      expect(find.byIcon(Icons.add_rounded), findsOneWidget);
      expect(find.byIcon(Icons.refresh_rounded), findsOneWidget);

      // Increment count
      await tester.tap(find.byIcon(Icons.add_rounded));
      await tester.pumpAndSettle();

      final record = await fakeCounter.getRecord(testDate);
      expect(record.count, 1);
    });

    testWidgets('SettingsScreen displays settings controls and GlobalSettingsScreen displays theme options', (tester) async {
      final fakeCounter = FakeCounterService();
      final fakeSettings = FakeSettingsService();

      final container = ProviderContainer(
        overrides: [
          counterServiceProvider.overrideWithValue(fakeCounter),
          settingsServiceProvider.overrideWithValue(fakeSettings),
        ],
      );
      addTearDown(container.dispose);

      final theme = AppThemeData.fromPalette(ThemePresets.softLight).toThemeData();

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: theme,
            home: const SettingsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Meal Settings'), findsOneWidget);
      expect(find.text('COUNTER SETTINGS'), findsOneWidget);
      expect(find.text('Billing Checkpoint'), findsOneWidget);
      expect(find.text('DATA MANAGEMENT'), findsNothing);
      expect(find.text('Reset Today'), findsNothing);
      expect(find.text('Reset Current Week'), findsNothing);
      expect(find.text('Reset All Meal Data'), findsNothing);

      // Now test GlobalSettingsScreen
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: theme,
            home: const GlobalSettingsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('App Settings'), findsOneWidget);
      expect(find.textContaining('APPEARANCE & THEME'), findsOneWidget);
      expect(find.text('Soft Light'), findsOneWidget);
      expect(find.text('Pure White'), findsOneWidget);
      expect(find.text('Midnight Dark'), findsOneWidget);
      expect(find.text('Lavender'), findsOneWidget);
      expect(find.text('Mint'), findsOneWidget);
      expect(find.text('Warm Sand'), findsOneWidget);
    });
  });
}
