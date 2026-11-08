import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:daily_counter/core/database/database_helper.dart';
import 'package:daily_counter/core/services/counter_service.dart';
import 'package:daily_counter/core/services/settings_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Database db;
  late DatabaseHelper dbHelper;
  late CounterService counterService;
  late SettingsService settingsService;

  setUp(() async {
    // Open an in-memory database for clean test isolation
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    dbHelper = DatabaseHelper.withDatabase(db);
    // Initialize schema and seeds
    await db.execute('''
      CREATE TABLE IF NOT EXISTS daily_records (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT UNIQUE NOT NULL,
        count INTEGER NOT NULL DEFAULT 0,
        amount_override REAL,
        updated_at TEXT NOT NULL
      );
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS app_settings (
        key TEXT PRIMARY KEY NOT NULL,
        value TEXT NOT NULL
      );
    ''');
    // Seed default settings
    await db.insert('app_settings', {'key': 'unit_amount', 'value': '55.0'});
    await db.insert('app_settings', {'key': 'daily_limit', 'value': '2'});
    await db.insert('app_settings', {'key': 'week_start', 'value': 'monday'});
    await db.insert('app_settings', {'key': 'currency_symbol', 'value': '₹'});
    await db.insert('app_settings', {'key': 'selected_theme', 'value': 'midnight_dark'});
    await db.insert('app_settings', {'key': 'checkpoint_date', 'value': ''});

    counterService = CounterService(dbHelper: dbHelper);
    settingsService = SettingsService(dbHelper: dbHelper);
  });

  tearDown(() async {
    await db.close();
  });

  group('Database & CounterService Integration Tests', () {
    test('Increment counter up to daily limit (default 2)', () async {
      const date = '2026-11-02';

      // First increment -> count = 1
      final res1 = await counterService.incrementDate(date);
      expect(res1.success, true);
      expect(res1.record.count, 1);

      // Second increment -> count = 2
      final res2 = await counterService.incrementDate(date);
      expect(res2.success, true);
      expect(res2.record.count, 2);

      // Third increment -> Should FAIL as limit is 2
      final res3 = await counterService.incrementDate(date);
      expect(res3.success, false);
      expect(res3.record.count, 2);
      expect(res3.message, contains('limit reached'));
    });

    test('Decrement counter cannot go below 0', () async {
      const date = '2026-11-02';

      await counterService.incrementDate(date); // count = 1
      final dec1 = await counterService.decrementDate(date); // count = 0
      expect(dec1.success, true);
      expect(dec1.record.count, 0);

      // Decrementing again stays 0
      final dec2 = await counterService.decrementDate(date);
      expect(dec2.record.count, 0);
    });

    test('Manual count setting validates bounds', () async {
      const date = '2026-11-02';

      // Setting count = 2 is valid
      final resValid = await counterService.setCount(date, 2, 2);
      expect(resValid.success, true);
      expect(resValid.record.count, 2);

      // Setting count = 3 exceeds limit 2 -> fails
      final resOver = await counterService.setCount(date, 3, 2);
      expect(resOver.success, false);
      expect(resOver.message, contains('cannot exceed daily limit'));

      // Setting count < 0 -> fails
      final resNeg = await counterService.setCount(date, -1, 2);
      expect(resNeg.success, false);
      expect(resNeg.message, contains('cannot be negative'));
    });

    test('Custom amount override persists and clears properly', () async {
      const date = '2026-11-02';

      await counterService.incrementDate(date); // count = 1
      final recordWithOverride = await counterService.setAmountOverride(date, 60.0);
      expect(recordWithOverride.amountOverride, 60.0);
      expect(recordWithOverride.calculateAmount(45.0), 60.0);

      // Clear override
      final recordCleared = await counterService.setAmountOverride(date, null);
      expect(recordCleared.amountOverride, isNull);
      expect(recordCleared.calculateAmount(45.0), 45.0);
    });

    test('Reset day removes count and override', () async {
      const date = '2026-11-02';
      await counterService.incrementDate(date);
      await counterService.setAmountOverride(date, 75.0);

      await counterService.resetDay(date);
      final record = await counterService.getRecord(date);
      expect(record.count, 0);
      expect(record.amountOverride, isNull);
    });

    test('Settings service updates and loads properly', () async {
      final settings = await settingsService.getSettings();
      expect(settings.unitAmount, 55.0);
      expect(settings.dailyLimit, 2);
      expect(settings.weekStart, 'monday');
      expect(settings.currencySymbol, '₹');
      expect(settings.selectedTheme, 'midnight_dark');

      await settingsService.updateUnitAmount(50.0);
      await settingsService.updateDailyLimit(5);
      await settingsService.updateTheme('soft_light');

      final updated = await settingsService.getSettings();
      expect(updated.unitAmount, 50.0);
      expect(updated.dailyLimit, 5);
      expect(updated.selectedTheme, 'soft_light');
    });

    test('Detects daily limit conflicts when decreasing limit', () async {
      const date = '2026-11-02';
      // Set limit to 5, set count to 4
      await db.update('app_settings', {'value': '5'}, where: 'key = ?', whereArgs: ['daily_limit']);
      await counterService.setCount(date, 4, 5);

      // Now check conflict if user wants to lower limit to 3
      final conflicts = await settingsService.checkDailyLimitConflicts(3);
      expect(conflicts.length, 1);
      expect(conflicts.first.date, date);
      expect(conflicts.first.count, 4);

      // But limit 4 has no conflicts
      final noConflicts = await settingsService.checkDailyLimitConflicts(4);
      expect(noConflicts.isEmpty, true);
    });
  });
}
