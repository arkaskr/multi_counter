class AppConstants {
  AppConstants._();

  static const String appName = 'Daily Counter';
  static const String appVersion = '1.3.0';

  // Default Settings
  static const double defaultUnitAmount = 55.0;
  static const int defaultDailyLimit = 2;
  static const String defaultWeekStart = 'monday'; // 'monday' or 'sunday'
  static const String defaultCurrencySymbol = '₹';
  static const String defaultTheme = 'midnight_dark';

  // Platform Channel
  static const String widgetMethodChannel = 'com.dailycounter.app/widget';
  static const String updaterMethodChannel = 'com.dailycounter.app/updater';

  // App Update URLs
  static const String updateManifestUrl =
      'https://raw.githubusercontent.com/arkaskr/multi_counter/main/latest.json';
  static const String updateReleasesUrl =
      'https://github.com/arkaskr/multi_counter';
}
