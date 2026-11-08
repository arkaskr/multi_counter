import '../database/database_helper.dart';
import '../../shared/models/app_settings.dart';
import '../../shared/models/daily_record.dart';
import 'sync_service.dart';
import 'widget_service.dart';

class SettingsService {
  final DatabaseHelper _dbHelper;
  final WidgetService _widgetService;
  final SyncService? _syncService;

  SettingsService({
    DatabaseHelper? dbHelper,
    WidgetService? widgetService,
    SyncService? syncService,
  })  : _dbHelper = dbHelper ?? DatabaseHelper.instance,
        _widgetService = widgetService ?? WidgetService.instance,
        _syncService = syncService;

  /// Loads current application settings
  Future<AppSettings> getSettings() async {
    return await _dbHelper.getSettings();
  }

  /// Checks if setting a new daily limit would conflict with existing records.
  /// Returns list of records with count > newLimit.
  Future<List<DailyRecord>> checkDailyLimitConflicts(int newLimit) async {
    return await _dbHelper.getRecordsExceedingLimit(newLimit);
  }

  /// Updates settings and notifies the home-screen widget.
  Future<void> updateSettings(AppSettings settings) async {
    await _dbHelper.saveSettings(settings);
    await _widgetService.notifyWidgetUpdate();
    _syncService?.autoSync();
  }

  /// Updates unit amount specifically
  Future<void> updateUnitAmount(double unitAmount) async {
    final current = await getSettings();
    final updated = current.copyWith(unitAmount: unitAmount);
    await updateSettings(updated);
  }

  /// Updates daily limit specifically (assuming conflict resolution was handled)
  Future<void> updateDailyLimit(int dailyLimit) async {
    final current = await getSettings();
    final updated = current.copyWith(dailyLimit: dailyLimit);
    await updateSettings(updated);
  }

  /// Updates selected theme preset
  Future<void> updateTheme(String themeId, {String? customConfig}) async {
    final current = await getSettings();
    final updated = current.copyWith(
      selectedTheme: themeId,
      customThemeConfig: customConfig,
      clearCustomTheme: customConfig == null && current.customThemeConfig != null,
    );
    await updateSettings(updated);
  }

  /// Updates week start preference ('monday' or 'sunday')
  Future<void> updateWeekStart(String weekStart) async {
    final current = await getSettings();
    final updated = current.copyWith(weekStart: weekStart);
    await updateSettings(updated);
  }

  /// Updates currency symbol
  Future<void> updateCurrencySymbol(String symbol) async {
    final current = await getSettings();
    final updated = current.copyWith(currencySymbol: symbol);
    await updateSettings(updated);
  }

  /// Updates or clears checkpoint date
  Future<void> updateCheckpointDate(String? date) async {
    final current = await getSettings();
    final updated = current.copyWith(
      checkpointDate: date,
      clearCheckpointDate: date == null || date.trim().isEmpty,
    );
    await updateSettings(updated);
  }

  /// Reset settings back to factory defaults
  Future<void> resetSettingsToDefaults() async {
    await _dbHelper.resetSettingsToDefaults();
    await _widgetService.notifyWidgetUpdate();
    _syncService?.autoSync();
  }
}
