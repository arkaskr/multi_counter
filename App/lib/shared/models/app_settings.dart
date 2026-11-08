import '../../core/constants/app_constants.dart';
import '../../core/constants/database_constants.dart';

class AppSettings {
  final double unitAmount;
  final int dailyLimit;
  final String weekStart; // 'monday' or 'sunday'
  final String currencySymbol;
  final String selectedTheme;
  final String? customThemeConfig;
  final String? checkpointDate;

  const AppSettings({
    this.unitAmount = AppConstants.defaultUnitAmount,
    this.dailyLimit = AppConstants.defaultDailyLimit,
    this.weekStart = AppConstants.defaultWeekStart,
    this.currencySymbol = AppConstants.defaultCurrencySymbol,
    this.selectedTheme = AppConstants.defaultTheme,
    this.customThemeConfig,
    this.checkpointDate,
  });

  AppSettings copyWith({
    double? unitAmount,
    int? dailyLimit,
    String? weekStart,
    String? currencySymbol,
    String? selectedTheme,
    String? customThemeConfig,
    bool clearCustomTheme = false,
    String? checkpointDate,
    bool clearCheckpointDate = false,
  }) {
    return AppSettings(
      unitAmount: unitAmount ?? this.unitAmount,
      dailyLimit: dailyLimit ?? this.dailyLimit,
      weekStart: weekStart ?? this.weekStart,
      currencySymbol: currencySymbol ?? this.currencySymbol,
      selectedTheme: selectedTheme ?? this.selectedTheme,
      customThemeConfig: clearCustomTheme ? null : (customThemeConfig ?? this.customThemeConfig),
      checkpointDate: clearCheckpointDate ? null : (checkpointDate ?? this.checkpointDate),
    );
  }

  Map<String, String> toSettingsMap() {
    final map = <String, String>{
      DatabaseConstants.keyUnitAmount: unitAmount.toString(),
      DatabaseConstants.keyDailyLimit: dailyLimit.toString(),
      DatabaseConstants.keyWeekStart: weekStart,
      DatabaseConstants.keyCurrencySymbol: currencySymbol,
      DatabaseConstants.keySelectedTheme: selectedTheme,
      DatabaseConstants.keyCheckpointDate: checkpointDate ?? '',
    };
    if (customThemeConfig != null) {
      map[DatabaseConstants.keyCustomThemeConfig] = customThemeConfig!;
    }
    return map;
  }

  factory AppSettings.fromSettingsMap(Map<String, String> map) {
    final cpDate = map[DatabaseConstants.keyCheckpointDate]?.trim();
    return AppSettings(
      unitAmount: double.tryParse(map[DatabaseConstants.keyUnitAmount] ?? '') ??
          AppConstants.defaultUnitAmount,
      dailyLimit: int.tryParse(map[DatabaseConstants.keyDailyLimit] ?? '') ??
          AppConstants.defaultDailyLimit,
      weekStart: map[DatabaseConstants.keyWeekStart] ?? AppConstants.defaultWeekStart,
      currencySymbol: map[DatabaseConstants.keyCurrencySymbol] ?? AppConstants.defaultCurrencySymbol,
      selectedTheme: map[DatabaseConstants.keySelectedTheme] ?? AppConstants.defaultTheme,
      customThemeConfig: map[DatabaseConstants.keyCustomThemeConfig],
      checkpointDate: (cpDate != null && cpDate.isNotEmpty) ? cpDate : null,
    );
  }

  @override
  String toString() {
    return 'AppSettings(unitAmount: $unitAmount, dailyLimit: $dailyLimit, weekStart: $weekStart, currencySymbol: $currencySymbol, selectedTheme: $selectedTheme, customThemeConfig: $customThemeConfig, checkpointDate: $checkpointDate)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AppSettings &&
        other.unitAmount == unitAmount &&
        other.dailyLimit == dailyLimit &&
        other.weekStart == weekStart &&
        other.currencySymbol == currencySymbol &&
        other.selectedTheme == selectedTheme &&
        other.customThemeConfig == customThemeConfig &&
        other.checkpointDate == checkpointDate;
  }

  @override
  int get hashCode {
    return Object.hash(
      unitAmount,
      dailyLimit,
      weekStart,
      currencySymbol,
      selectedTheme,
      customThemeConfig,
      checkpointDate,
    );
  }
}
