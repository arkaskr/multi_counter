class AppConstants {
  AppConstants._();

  static const String appName = 'Daily Counter';
  static const String appVersion = '1.0.0';

  // Default Settings
  static const double defaultUnitAmount = 45.0;
  static const int defaultDailyLimit = 2;
  static const String defaultWeekStart = 'monday'; // 'monday' or 'sunday'
  static const String defaultCurrencySymbol = '₹';
  static const String defaultTheme = 'soft_light';

  // Platform Channel
  static const String widgetMethodChannel = 'com.dailycounter.app/widget';
}
