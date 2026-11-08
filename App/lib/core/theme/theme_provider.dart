import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/providers/auth_providers.dart';
import '../services/settings_service.dart';
import 'app_theme.dart';
import 'theme_presets.dart';

final settingsServiceProvider = Provider<SettingsService>((ref) {
  return SettingsService(
    syncService: ref.watch(syncServiceProvider),
  );
});

class ThemeNotifier extends Notifier<AppThemeData> {
  @override
  AppThemeData build() {
    return AppThemeData.fromPalette(ThemePresets.midnightDark);
  }

  Future<void> loadTheme() async {
    final settingsService = ref.read(settingsServiceProvider);
    try {
      final settings = await settingsService.getSettings();
      final palette = ThemePresets.getById(settings.selectedTheme);
      state = AppThemeData.fromPalette(palette);
    } catch (_) {}
  }

  Future<void> setTheme(String themeId) async {
    final settingsService = ref.read(settingsServiceProvider);
    final palette = ThemePresets.getById(themeId);
    state = AppThemeData.fromPalette(palette);
    await settingsService.updateTheme(themeId);
  }
}

final themeProvider = NotifierProvider<ThemeNotifier, AppThemeData>(ThemeNotifier.new);
