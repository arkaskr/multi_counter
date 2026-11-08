import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../shared/models/app_settings.dart';

class SettingsNotifier extends AsyncNotifier<AppSettings> {
  @override
  Future<AppSettings> build() async {
    final service = ref.watch(settingsServiceProvider);
    return await service.getSettings();
  }

  Future<void> updateUnitAmount(double amount) async {
    final service = ref.read(settingsServiceProvider);
    await service.updateUnitAmount(amount);
    ref.invalidateSelf();
  }

  Future<void> updateDailyLimit(int limit) async {
    final service = ref.read(settingsServiceProvider);
    await service.updateDailyLimit(limit);
    ref.invalidateSelf();
  }

  Future<void> updateWeekStart(String weekStart) async {
    final service = ref.read(settingsServiceProvider);
    await service.updateWeekStart(weekStart);
    ref.invalidateSelf();
  }

  Future<void> updateCurrencySymbol(String symbol) async {
    final service = ref.read(settingsServiceProvider);
    await service.updateCurrencySymbol(symbol);
    ref.invalidateSelf();
  }

  Future<void> updateCheckpointDate(String? date) async {
    final service = ref.read(settingsServiceProvider);
    await service.updateCheckpointDate(date);
    ref.invalidateSelf();
  }

  Future<void> resetSettingsToDefaults() async {
    final service = ref.read(settingsServiceProvider);
    await service.resetSettingsToDefaults();
    ref.invalidateSelf();
  }
}

final settingsNotifierProvider =
    AsyncNotifierProvider<SettingsNotifier, AppSettings>(SettingsNotifier.new);
