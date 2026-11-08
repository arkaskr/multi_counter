import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';
import '../database/database_helper.dart';
import '../../shared/models/app_settings.dart';
import '../../shared/models/daily_record.dart';
import 'auth_service.dart';

class SyncResult {
  final bool success;
  final bool isOffline;
  final int syncedRecordsCount;
  final String message;
  final String? syncedAt;

  const SyncResult({
    required this.success,
    this.isOffline = false,
    this.syncedRecordsCount = 0,
    required this.message,
    this.syncedAt,
  });
}

class SyncService {
  final DatabaseHelper _dbHelper;
  final AuthService _authService;

  SyncService({
    DatabaseHelper? dbHelper,
    AuthService? authService,
  })  : _dbHelper = dbHelper ?? DatabaseHelper.instance,
        _authService = authService ?? AuthService.instance;

  static const String _keyLastSyncedAt = 'last_synced_at_timestamp';

  /// Get formatted last sync time
  Future<String?> getLastSyncedAt() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_keyLastSyncedAt);
    } catch (_) {
      return null;
    }
  }

  /// Sets last sync time
  Future<void> _setLastSyncedAt(String isoString) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyLastSyncedAt, isoString);
    } catch (_) {}
  }

  /// Checks if server / MongoDB is reachable
  Future<bool> checkServerReachability() async {
    try {
      final url = Uri.parse('${AppConfig.apiBaseUrl}/health');
      final response = await http.get(url).timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data['status'] == 'ok';
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Performs full two-way synchronization between local SQLite and remote MongoDB.
  /// If offline or server unreachable, returns graceful offline status without errors.
  Future<SyncResult> syncWithCloud() async {
    if (!_authService.isLoggedIn) {
      return const SyncResult(
        success: false,
        message: 'Sign in to sync your data with MongoDB cloud database.',
      );
    }

    final token = _authService.token;
    if (token == null) {
      return const SyncResult(
        success: false,
        message: 'Authentication required for syncing.',
      );
    }

    try {
      // 1. Gather all local records and settings
      final localRecords = await _dbHelper.getAllRecords();
      final localSettings = await _dbHelper.getSettings();
      final lastSyncedAt = await getLastSyncedAt();

      final recordsPayload = localRecords
          .map((r) => {
                'date': r.date,
                'count': r.count,
                'amountOverride': r.amountOverride,
                'updatedAt': r.updatedAt,
              })
          .toList();

      final settingsPayload = {
        'unitAmount': localSettings.unitAmount,
        'dailyLimit': localSettings.dailyLimit,
        'weekStart': localSettings.weekStart,
        'currencySymbol': localSettings.currencySymbol,
        'selectedTheme': localSettings.selectedTheme,
        'customThemeConfig': localSettings.customThemeConfig,
        'updatedAt': DateTime.now().toIso8601String(),
      };

      // 2. Call server sync API
      final url = Uri.parse('${AppConfig.apiBaseUrl}/sync');
      final response = await http
          .post(
            url,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              'records': recordsPayload,
              'settings': settingsPayload,
              'lastSyncedAt': lastSyncedAt,
            }),
          )
          .timeout(const Duration(seconds: 12));

      if (response.statusCode == 401) {
        return const SyncResult(
          success: false,
          message: 'Session expired. Please sign in again.',
        );
      }

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final syncedAt = data['syncedAt'] as String? ?? DateTime.now().toIso8601String();
        final serverRecordsRaw = data['records'] as List<dynamic>? ?? [];

        // 3. Merge server records into local SQLite
        if (serverRecordsRaw.isNotEmpty) {
          final cloudRecords = serverRecordsRaw.map((item) {
            final m = item as Map<String, dynamic>;
            return DailyRecord(
              date: m['date'] as String,
              count: (m['count'] as num?)?.toInt() ?? 0,
              amountOverride: (m['amount_override'] as num?)?.toDouble(),
              updatedAt: m['updated_at'] as String? ?? syncedAt,
            );
          }).toList();

          await _dbHelper.saveRecords(cloudRecords);
        }

        // 4. Update settings if provided by server
        if (data['settings'] != null) {
          final s = data['settings'] as Map<String, dynamic>;
          final settingsMap = <String, String>{};
          s.forEach((k, v) {
            if (v != null) settingsMap[k] = v.toString();
          });
          final cloudSettings = AppSettings.fromSettingsMap(settingsMap);
          await _dbHelper.saveSettings(cloudSettings);
        }

        await _setLastSyncedAt(syncedAt);

        return SyncResult(
          success: true,
          isOffline: false,
          syncedRecordsCount: serverRecordsRaw.length,
          syncedAt: syncedAt,
          message: 'Synced ${serverRecordsRaw.length} record(s) with MongoDB.',
        );
      } else {
        return SyncResult(
          success: false,
          message: 'Sync response error (${response.statusCode})',
        );
      }
    } on SocketException {
      return const SyncResult(
        success: false,
        isOffline: true,
        message: 'Offline mode: changes saved locally. Will sync to MongoDB when connected.',
      );
    } catch (e) {
      debugPrint('[SyncService] Sync error: $e');
      return SyncResult(
        success: false,
        isOffline: true,
        message: 'Sync unavailable ($e). Local data preserved.',
      );
    }
  }

  /// Triggers background sync without interrupting the user
  Future<void> autoSync() async {
    if (!_authService.isLoggedIn) return;
    try {
      await syncWithCloud();
    } catch (_) {}
  }
}

