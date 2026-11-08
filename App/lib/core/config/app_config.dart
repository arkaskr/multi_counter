import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppConfig {
  AppConfig._();

  static const String keyCustomApiBaseUrl = 'custom_api_base_url';

  static const String defaultMongoDbUri =
      'mongodb+srv://arkaskr24_db_user:wVvVLeD9fGrnMnBO@counter.v7ndlkx.mongodb.net/daily_counter?retryWrites=true&w=majority';

  /// Determines default API URL based on platform:
  /// - Android Emulator: http://10.0.2.2:5000/api
  /// - Desktop / Linux / macOS / Web / iOS Simulator: http://localhost:5000/api
  static String get defaultApiBaseUrl {
    if (!kIsWeb && Platform.isAndroid) {
      return 'http://10.0.2.2:5000/api';
    }
    return 'http://localhost:5000/api';
  }

  static String _currentApiBaseUrl = defaultApiBaseUrl;

  static String get apiBaseUrl => _currentApiBaseUrl;

  static Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedUrl = prefs.getString(keyCustomApiBaseUrl);
      if (savedUrl != null && savedUrl.trim().isNotEmpty) {
        _currentApiBaseUrl = savedUrl.trim();
      } else {
        _currentApiBaseUrl = defaultApiBaseUrl;
      }
    } catch (_) {
      _currentApiBaseUrl = defaultApiBaseUrl;
    }
  }

  static Future<void> setApiBaseUrl(String url) async {
    final cleanUrl = url.trim().replaceAll(RegExp(r'/+$'), '');
    _currentApiBaseUrl = cleanUrl;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(keyCustomApiBaseUrl, cleanUrl);
    } catch (_) {}
  }

  static Future<void> resetApiBaseUrl() async {
    _currentApiBaseUrl = defaultApiBaseUrl;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(keyCustomApiBaseUrl);
    } catch (_) {}
  }
}

