import '../constants/app_constants.dart';
import '../constants/database_constants.dart';

class DatabaseSchema {
  DatabaseSchema._();

  static const String createDailyRecordsTable = '''
    CREATE TABLE IF NOT EXISTS ${DatabaseConstants.tableDailyRecords} (
      ${DatabaseConstants.columnId} INTEGER PRIMARY KEY AUTOINCREMENT,
      ${DatabaseConstants.columnDate} TEXT UNIQUE NOT NULL,
      ${DatabaseConstants.columnCount} INTEGER NOT NULL DEFAULT 0,
      ${DatabaseConstants.columnAmountOverride} REAL,
      ${DatabaseConstants.columnUpdatedAt} TEXT NOT NULL
    );
  ''';

  static const String createDailyRecordsDateIndex = '''
    CREATE INDEX IF NOT EXISTS idx_daily_records_date 
    ON ${DatabaseConstants.tableDailyRecords} (${DatabaseConstants.columnDate});
  ''';

  static const String createAppSettingsTable = '''
    CREATE TABLE IF NOT EXISTS ${DatabaseConstants.tableAppSettings} (
      ${DatabaseConstants.columnKey} TEXT PRIMARY KEY NOT NULL,
      ${DatabaseConstants.columnValue} TEXT NOT NULL
    );
  ''';

  static final List<Map<String, String>> initialSettings = [
    {
      'key': DatabaseConstants.keyUnitAmount,
      'value': AppConstants.defaultUnitAmount.toString(),
    },
    {
      'key': DatabaseConstants.keyDailyLimit,
      'value': AppConstants.defaultDailyLimit.toString(),
    },
    {
      'key': DatabaseConstants.keyWeekStart,
      'value': AppConstants.defaultWeekStart,
    },
    {
      'key': DatabaseConstants.keyCurrencySymbol,
      'value': AppConstants.defaultCurrencySymbol,
    },
    {
      'key': DatabaseConstants.keySelectedTheme,
      'value': AppConstants.defaultTheme,
    },
    {
      'key': DatabaseConstants.keyCheckpointDate,
      'value': '',
    },
  ];
}
