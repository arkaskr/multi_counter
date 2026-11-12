class DatabaseConstants {
  DatabaseConstants._();

  static const String databaseName = 'daily_counter.db';
  static const int databaseVersion = 2;

  // Table: daily_records
  static const String tableDailyRecords = 'daily_records';
  static const String columnId = 'id';
  static const String columnDate = 'date';
  static const String columnCount = 'count';
  static const String columnAmountOverride = 'amount_override';
  static const String columnUpdatedAt = 'updated_at';

  // Table: app_settings
  static const String tableAppSettings = 'app_settings';
  static const String columnKey = 'key';
  static const String columnValue = 'value';

  // Setting keys
  static const String keyUnitAmount = 'unit_amount';
  static const String keyDailyLimit = 'daily_limit';
  static const String keyWeekStart = 'week_start';
  static const String keyCurrencySymbol = 'currency_symbol';
  static const String keySelectedTheme = 'selected_theme';
  static const String keyCustomThemeConfig = 'custom_theme_config';
  static const String keyCheckpointDate = 'checkpoint_date';
}
