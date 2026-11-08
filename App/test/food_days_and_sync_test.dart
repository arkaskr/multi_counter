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
          await db.insert('app_settings', {'key': 'unit_amount', 'value': '45.0'});
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

