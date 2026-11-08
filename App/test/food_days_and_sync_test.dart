import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:daily_counter/core/database/database_helper.dart';
import 'package:daily_counter/core/services/counter_service.dart';
import 'package:daily_counter/core/services/sync_service.dart';
import 'package:daily_counter/shared/models/daily_record.dart';
import 'package:daily_counter/shared/models/user_model.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Food Days Counting Logic Tests', () {
    late Database db;
    late DatabaseHelper dbHelper;
    late CounterService counterService;

    setUp(() async {
      DatabaseHelper.resetForTesting();
      db = await openDatabase(
        inMemoryDatabasePath,
        version: 1,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE daily_records (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              date TEXT UNIQUE NOT NULL,
              count INTEGER NOT NULL DEFAULT 0,
              amount_override REAL,
              updated_at TEXT NOT NULL
            );
          ''');
          await db.execute('''
            CREATE TABLE app_settings (
              key TEXT PRIMARY KEY NOT NULL,
              value TEXT NOT NULL
            );
          ''');
          await db.insert('app_settings', {'key': 'daily_limit', 'value': '2'});
          await db.insert('app_settings', {'key': 'unit_amount', 'value': '55.0'});
          await db.insert('app_settings', {'key': 'checkpoint_date', 'value': ''});
        },
      );
      dbHelper = DatabaseHelper.withDatabase(db);
      counterService = CounterService(dbHelper: dbHelper);
    });

    tearDown(() async {
      await db.close();
      DatabaseHelper.resetForTesting();
    });

    test('Initial food days count is 0 when no meals have been logged', () async {
      final days = await counterService.getFoodDaysCount();
      expect(days, 0);
    });

    test('Food days count increments ONLY on days where food was consumed (count > 0)', () async {
      // Day 1: Had food (count = 1) -> Food Days = 1
      await dbHelper.saveRecord(DailyRecord(
        date: '2026-11-01',
        count: 1,
        updatedAt: DateTime.now().toIso8601String(),
      ));
      expect(await counterService.getFoodDaysCount(), 1);

      // Day 2: Had food (count = 2) -> Food Days = 2
      await dbHelper.saveRecord(DailyRecord(
        date: '2026-11-02',
        count: 2,
        updatedAt: DateTime.now().toIso8601String(),
      ));
      expect(await counterService.getFoodDaysCount(), 2);

      // Day 3: Fasted / Did NOT have any meal (count = 0) -> Food Days MUST NOT INCREMENT!
      await dbHelper.saveRecord(DailyRecord(
        date: '2026-11-03',
        count: 0,
        updatedAt: DateTime.now().toIso8601String(),
      ));
      expect(await counterService.getFoodDaysCount(), 2,
          reason: 'A day with count=0 must not increment the food days count');

      // Day 4: Another day with 0 food -> still 2
      await dbHelper.saveRecord(DailyRecord(
        date: '2026-11-04',
        count: 0,
        updatedAt: DateTime.now().toIso8601String(),
      ));
      expect(await counterService.getFoodDaysCount(), 2);

      // Day 5: Had a meal (count = 1) -> Food Days increments to 3!
      await dbHelper.saveRecord(DailyRecord(
        date: '2026-11-05',
        count: 1,
        updatedAt: DateTime.now().toIso8601String(),
      ));
      expect(await counterService.getFoodDaysCount(), 3);
    });

    test('Multiple meals on the same date count as 1 food day (distinct days)', () async {
      await counterService.setCount('2026-11-01', 2, 2);
      expect(await counterService.getFoodDaysCount(), 1);
    });

    test('Resetting a day with food decreases the food days count', () async {
      await counterService.setCount('2026-11-01', 1, 2);
      await counterService.setCount('2026-11-02', 1, 2);
      expect(await counterService.getFoodDaysCount(), 2);

      await counterService.resetDay('2026-11-02');
      expect(await counterService.getFoodDaysCount(), 1);
    });

    test('Batch save records and getAllRecords for cloud syncing', () async {
      final records = [
        DailyRecord(date: '2026-11-01', count: 1, updatedAt: '2026-11-01T12:00:00Z'),
        DailyRecord(date: '2026-11-02', count: 2, amountOverride: 100.0, updatedAt: '2026-11-02T12:00:00Z'),
      ];

      await dbHelper.saveRecords(records);
      final all = await dbHelper.getAllRecords();

      expect(all.length, 2);
      expect(all.firstWhere((r) => r.date == '2026-11-02').amountOverride, 100.0);
    });

    test('Checkpoint starts counting meals and amount from next day while keeping history for analytics', () async {
      // Days 1 to 15: 15 meals logged (count = 1 each day)
      for (int i = 1; i <= 15; i++) {
        final d = '2026-11-${i.toString().padLeft(2, '0')}';
        await counterService.setCount(d, 1, 2);
      }

      // Before checkpoint: cycle meals = 15, cycle amount = 15 * 55 = 825
      expect(await counterService.getCycleMealsCount(null), 15);
      expect(await counterService.getCycleTotalAmount(null, 55.0), 825.0);

      // User sets Checkpoint on 2026-11-15 (settles the 15 meals)
      await counterService.setCheckpoint('2026-11-15');

      // Right after checkpoint on day 15, cycle meals starting from day 16 is 0
      expect(await counterService.getCycleMealsCount('2026-11-15'), 0);
      expect(await counterService.getCycleTotalAmount('2026-11-15', 55.0), 0.0);

      // On day 16 (next day): User logs 2 meals
      await counterService.setCount('2026-11-16', 2, 2);

      // Cycle now counts only from day 16! (2 meals = 110 rs)
      expect(await counterService.getCycleMealsCount('2026-11-15'), 2);
      expect(await counterService.getCycleTotalAmount('2026-11-15', 55.0), 110.0);

      // But in background all 16 days exist for Analytics!
      final allRange = await dbHelper.getRecordsBetween('2026-11-01', '2026-11-16');
      expect(allRange.length, 16);
      final totalMealsAllTime = allRange.map((r) => r.count).reduce((a, b) => a + b);
      expect(totalMealsAllTime, 17); // 15 + 2

      // Clear checkpoint restores all-time count to cycle
      await counterService.clearCheckpoint();
      expect(await counterService.getCycleMealsCount(null), 17);
    });
  });

  group('User Model & Offline Sync Tests', () {
    test('UserModel serializes and deserializes cleanly', () {
      final user = const UserModel(
        id: 'user_123',
        name: 'Arka Sarkar',
        email: 'arka@example.com',
        createdAt: '2026-11-08T00:00:00Z',
      );

      final map = user.toMap();
      final fromMap = UserModel.fromMap(map);

      expect(fromMap.id, 'user_123');
      expect(fromMap.name, 'Arka Sarkar');
      expect(fromMap.email, 'arka@example.com');
    });

    test('SyncService handles unauthenticated state gracefully without crashing', () async {
      final syncService = SyncService();
      final result = await syncService.syncWithCloud();

      expect(result.success, false);
      expect(result.message, contains('Sign in'));
    });
  });
}

