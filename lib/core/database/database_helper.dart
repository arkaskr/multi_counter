import 'dart:async';
import 'dart:io';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../constants/database_constants.dart';
import '../../shared/models/app_settings.dart';
import '../../shared/models/daily_record.dart';
import 'database_schema.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  /// For testing or custom database injection
  DatabaseHelper.withDatabase(Database db) {
    _database = db;
  }

  /// Cleanly reset database handle for testing
  static void resetForTesting() {
    _database = null;
  }

  Future<Database> get database async {
    if (_database != null && _database!.isOpen) return _database!;
    _database = await _initDB(DatabaseConstants.databaseName);
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    // Ensure parent directory exists
    try {
      final dir = Directory(dirname(path));
      if (!dir.existsSync()) {
        dir.createSync(recursive: true);
      }
    } catch (_) {}

    return await openDatabase(
      path,
      version: DatabaseConstants.databaseVersion,
      onCreate: _createDB,
      onConfigure: _onConfigure,
    );
  }

  Future<void> _onConfigure(Database db) async {
    // Enable WAL mode and foreign keys for performance and concurrency
    await db.execute('PRAGMA foreign_keys = ON');
    try {
      await db.execute('PRAGMA journal_mode = WAL');
    } catch (_) {}
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute(DatabaseSchema.createDailyRecordsTable);
    await db.execute(DatabaseSchema.createDailyRecordsDateIndex);
    await db.execute(DatabaseSchema.createAppSettingsTable);

    // Seed default settings
    final batch = db.batch();
    for (final setting in DatabaseSchema.initialSettings) {
      batch.insert(
        DatabaseConstants.tableAppSettings,
        setting,
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
    await batch.commit(noResult: true);
  }

  // ==================== DAILY RECORDS CRUD ====================

  /// Get daily record for a specific date (YYYY-MM-DD). Returns empty record if not found.
  Future<DailyRecord> getRecord(String date) async {
    final db = await database;
    final results = await db.query(
      DatabaseConstants.tableDailyRecords,
      where: '${DatabaseConstants.columnDate} = ?',
      whereArgs: [date],
      limit: 1,
    );

    if (results.isNotEmpty) {
      return DailyRecord.fromMap(results.first);
    }
    return DailyRecord.empty(date);
  }

  /// Get multiple daily records for a list of dates
  Future<Map<String, DailyRecord>> getRecordsForDates(List<String> dates) async {
    if (dates.isEmpty) return {};
    final db = await database;
    final placeholders = List.filled(dates.length, '?').join(',');
    final results = await db.query(
      DatabaseConstants.tableDailyRecords,
      where: '${DatabaseConstants.columnDate} IN ($placeholders)',
      whereArgs: dates,
    );

    final map = <String, DailyRecord>{};
    for (final date in dates) {
      map[date] = DailyRecord.empty(date);
    }
    for (final row in results) {
      final record = DailyRecord.fromMap(row);
      map[record.date] = record;
    }
    return map;
  }

  /// Insert or update a daily record
  Future<void> saveRecord(DailyRecord record) async {
    final db = await database;
    await db.insert(
      DatabaseConstants.tableDailyRecords,
      record.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Transactionally increment counter for a date if below dailyLimit.
  /// Returns updated record on success, or null if dailyLimit reached.
  Future<DailyRecord?> incrementDailyCount(String date) async {
    final db = await database;
    return await db.transaction<DailyRecord?>((txn) async {
      // 1. Read daily limit
      final settingsRow = await txn.query(
        DatabaseConstants.tableAppSettings,
        where: '${DatabaseConstants.columnKey} = ?',
        whereArgs: [DatabaseConstants.keyDailyLimit],
        limit: 1,
      );
      final limit = settingsRow.isNotEmpty
          ? (int.tryParse(settingsRow.first[DatabaseConstants.columnValue] as String? ?? '2') ?? 2)
          : 2;

      // 2. Read current record
      final recordRows = await txn.query(
        DatabaseConstants.tableDailyRecords,
        where: '${DatabaseConstants.columnDate} = ?',
        whereArgs: [date],
        limit: 1,
      );

      final currentRecord = recordRows.isNotEmpty
          ? DailyRecord.fromMap(recordRows.first)
          : DailyRecord.empty(date);

      if (currentRecord.count >= limit) {
        return null; // Limit reached
      }

      final updatedRecord = currentRecord.copyWith(
        count: currentRecord.count + 1,
        updatedAt: DateTime.now().toIso8601String(),
      );

      await txn.insert(
        DatabaseConstants.tableDailyRecords,
        updatedRecord.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      return updatedRecord;
    });
  }

  /// Transactionally decrement counter for a date. Cannot go below 0.
  Future<DailyRecord> decrementDailyCount(String date) async {
    final db = await database;
    return await db.transaction<DailyRecord>((txn) async {
      final recordRows = await txn.query(
        DatabaseConstants.tableDailyRecords,
        where: '${DatabaseConstants.columnDate} = ?',
        whereArgs: [date],
        limit: 1,
      );

      final currentRecord = recordRows.isNotEmpty
          ? DailyRecord.fromMap(recordRows.first)
          : DailyRecord.empty(date);

      if (currentRecord.count <= 0) {
        return currentRecord;
      }

      final updatedRecord = currentRecord.copyWith(
        count: currentRecord.count - 1,
        updatedAt: DateTime.now().toIso8601String(),
      );

      await txn.insert(
        DatabaseConstants.tableDailyRecords,
        updatedRecord.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      return updatedRecord;
    });
  }

  /// Reset a single day's record (count=0, amount_override=null)
  Future<void> resetDay(String date) async {
    final db = await database;
    await db.delete(
      DatabaseConstants.tableDailyRecords,
      where: '${DatabaseConstants.columnDate} = ?',
      whereArgs: [date],
    );
  }

  /// Reset multiple days (e.g. current week)
  Future<void> resetDays(List<String> dates) async {
    if (dates.isEmpty) return;
    final db = await database;
    final placeholders = List.filled(dates.length, '?').join(',');
    await db.delete(
      DatabaseConstants.tableDailyRecords,
      where: '${DatabaseConstants.columnDate} IN ($placeholders)',
      whereArgs: dates,
    );
  }

  /// Reset all daily records
  Future<void> resetAllDailyRecords() async {
    final db = await database;
    await db.delete(DatabaseConstants.tableDailyRecords);
  }

  /// Returns total number of distinct days where the user had food (count > 0).
  /// If the user did not have any food on a day, it does not increment.
  Future<int> getFoodDaysCount() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(DISTINCT ${DatabaseConstants.columnDate}) as food_days '
      'FROM ${DatabaseConstants.tableDailyRecords} '
      'WHERE ${DatabaseConstants.columnCount} > 0',
    );
    if (result.isNotEmpty) {
      return (result.first['food_days'] as int?) ?? 0;
    }
    return 0;
  }

  /// Get all records from SQLite for cloud syncing
  Future<List<DailyRecord>> getAllRecords() async {
    final db = await database;
    final results = await db.query(
      DatabaseConstants.tableDailyRecords,
      orderBy: '${DatabaseConstants.columnDate} DESC',
    );
    return results.map((e) => DailyRecord.fromMap(e)).toList();
  }

  /// Batch save or merge records from cloud sync
  Future<void> saveRecords(List<DailyRecord> records) async {
    if (records.isEmpty) return;
    final db = await database;
    final batch = db.batch();
    for (final record in records) {
      batch.insert(
        DatabaseConstants.tableDailyRecords,
        record.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  /// Find records where count is strictly greater than newLimit
  Future<List<DailyRecord>> getRecordsExceedingLimit(int newLimit) async {
    final db = await database;
    final results = await db.query(
      DatabaseConstants.tableDailyRecords,
      where: '${DatabaseConstants.columnCount} > ?',
      whereArgs: [newLimit],
      orderBy: '${DatabaseConstants.columnDate} DESC',
    );
    return results.map((e) => DailyRecord.fromMap(e)).toList();
  }

  // ==================== APP SETTINGS CRUD ====================

  /// Load all settings from database
  Future<AppSettings> getSettings() async {
    final db = await database;
    final results = await db.query(DatabaseConstants.tableAppSettings);
    final map = <String, String>{};
    for (final row in results) {
      final key = row[DatabaseConstants.columnKey] as String?;
      final value = row[DatabaseConstants.columnValue] as String?;
      if (key != null && value != null) {
        map[key] = value;
      }
    }
    return AppSettings.fromSettingsMap(map);
  }

  /// Save or update a single setting
  Future<void> saveSetting(String key, String value) async {
    final db = await database;
    await db.insert(
      DatabaseConstants.tableAppSettings,
      {
        DatabaseConstants.columnKey: key,
        DatabaseConstants.columnValue: value,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Save all settings
  Future<void> saveSettings(AppSettings settings) async {
    final db = await database;
    final batch = db.batch();
    final map = settings.toSettingsMap();
    for (final entry in map.entries) {
      batch.insert(
        DatabaseConstants.tableAppSettings,
        {
          DatabaseConstants.columnKey: entry.key,
          DatabaseConstants.columnValue: entry.value,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  /// Reset settings to defaults
  Future<void> resetSettingsToDefaults() async {
    final db = await database;
    await db.delete(DatabaseConstants.tableAppSettings);
    final batch = db.batch();
    for (final setting in DatabaseSchema.initialSettings) {
      batch.insert(
        DatabaseConstants.tableAppSettings,
        setting,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  /// Close database
  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }
}
