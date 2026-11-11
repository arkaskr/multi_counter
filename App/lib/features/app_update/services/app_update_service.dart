import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../../../core/constants/app_constants.dart';
import '../models/update_manifest.dart';
import '../widgets/update_dialog.dart';

/// Information about the currently installed app version.
class AppVersionInfo {
  final String versionName;
  final int versionCode;
  final String packageName;

  const AppVersionInfo({
    required this.versionName,
    required this.versionCode,
    required this.packageName,
  });

  @override
  String toString() => '$versionName ($versionCode)';
}

/// Result of checking for updates against the remote manifest.
class UpdateCheckResult {
  final bool hasUpdate;
  final int currentVersionCode;
  final String currentVersionName;
  final UpdateManifest? manifest;
  final String? errorMessage;

  const UpdateCheckResult({
    required this.hasUpdate,
    required this.currentVersionCode,
    required this.currentVersionName,
    this.manifest,
    this.errorMessage,
  });

  bool get isSuccess => errorMessage == null;
}

/// Service handling APK updates, manifest checks, downloading,
/// SHA-256 verification, and platform installation.
class AppUpdateService {
  AppUpdateService._internal({
    MethodChannel? channel,
  }) : _channel = channel ?? const MethodChannel(AppConstants.updaterMethodChannel);

  static final AppUpdateService instance = AppUpdateService._internal();

  /// Visible for testing to inject custom channels or mock behavior.
  factory AppUpdateService.custom({MethodChannel? channel}) {
    return AppUpdateService._internal(channel: channel);
  }

  final MethodChannel _channel;

  bool _isDialogOpen = false;
  bool _isChecking = false;

  /// Returns true if an update dialog is currently active on screen.
  bool get isDialogOpen => _isDialogOpen;

  /// Retrieves the current app version details from the native Android PackageManager.
  Future<AppVersionInfo> getAppVersion() async {
    try {
      final dynamic result = await _channel.invokeMethod('getAppVersion');
      if (result is Map) {
        final int code = (result['versionCode'] as num?)?.toInt() ?? 1;
        final String name = (result['versionName'] as String?) ?? AppConstants.appVersion;
        final String pkg = (result['packageName'] as String?) ?? 'com.dailycounter.app.daily_counter';
        return AppVersionInfo(
          versionName: name,
          versionCode: code,
          packageName: pkg,
        );
      }
    } catch (_) {
      // Fallback for tests or unsupported platforms
    }
    return const AppVersionInfo(
      versionName: AppConstants.appVersion,
      versionCode: 1,
      packageName: 'com.dailycounter.app.daily_counter',
    );
  }

  /// Checks the remote `latest.json` manifest against the installed version.
  Future<UpdateCheckResult> checkForUpdate({
    http.Client? client,
    String? manifestUrl,
  }) async {
    final AppVersionInfo currentVersion = await getAppVersion();
    final String targetUrl = manifestUrl ?? AppConstants.updateManifestUrl;

    final http.Client httpClient = client ?? http.Client();
    final bool shouldCloseClient = client == null;

    try {
      // Add timestamp to query to prevent GitHub raw CDN caching
      final Uri uri = Uri.parse(targetUrl).replace(
        queryParameters: {
          't': DateTime.now().millisecondsSinceEpoch.toString(),
        },
      );

      final http.Response response = await httpClient.get(
        uri,
        headers: {
          'Cache-Control': 'no-cache',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 12));

      if (response.statusCode != 200) {
        return UpdateCheckResult(
          hasUpdate: false,
          currentVersionCode: currentVersion.versionCode,
          currentVersionName: currentVersion.versionName,
          errorMessage: 'Server returned HTTP ${response.statusCode}',
        );
      }

      final UpdateManifest manifest = UpdateManifest.fromRawJson(response.body);
      final bool hasUpdate = manifest.isNewerThan(currentVersion.versionCode);

      return UpdateCheckResult(
        hasUpdate: hasUpdate,
        currentVersionCode: currentVersion.versionCode,
        currentVersionName: currentVersion.versionName,
        manifest: manifest,
      );
    } on TimeoutException {
      return UpdateCheckResult(
        hasUpdate: false,
        currentVersionCode: currentVersion.versionCode,
        currentVersionName: currentVersion.versionName,
        errorMessage: 'Connection timed out while checking for updates',
      );
    } on FormatException catch (e) {
      return UpdateCheckResult(
        hasUpdate: false,
        currentVersionCode: currentVersion.versionCode,
        currentVersionName: currentVersion.versionName,
        errorMessage: 'Invalid manifest format: ${e.message}',
      );
    } on SocketException catch (e) {
      return UpdateCheckResult(
        hasUpdate: false,
        currentVersionCode: currentVersion.versionCode,
        currentVersionName: currentVersion.versionName,
        errorMessage: 'Network error: ${e.message}',
      );
    } catch (e) {
      return UpdateCheckResult(
        hasUpdate: false,
        currentVersionCode: currentVersion.versionCode,
        currentVersionName: currentVersion.versionName,
        errorMessage: e.toString(),
      );
    } finally {
      if (shouldCloseClient) {
        httpClient.close();
      }
    }
  }

  /// Downloads the APK file to local cache with progress reporting.
  /// Follows HTTP redirects (GitHub releases redirect to AWS S3 / fastly storage).
  Future<File> downloadApk(
    UpdateManifest manifest, {
    void Function(double progress, int receivedBytes, int totalBytes)? onProgress,
    http.Client? client,
    bool Function()? isCancelled,
  }) async {
    final Directory cacheDir = await getTemporaryDirectory();
    final Directory updateDir = Directory('${cacheDir.path}/updates');
    if (!await updateDir.exists()) {
      await updateDir.create(recursive: true);
    }

    final String safeVersion = manifest.versionName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final File destinationFile = File(
      '${updateDir.path}/dailycounter_v${safeVersion}_${manifest.versionCode}.apk',
    );

    // If file already exists and passes SHA-256 verification, reuse it immediately
    if (await destinationFile.exists()) {
      if (manifest.sha256.isNotEmpty) {
        final bool isValid = await verifySha256(destinationFile, manifest.sha256);
        if (isValid) {
          final int fileLength = await destinationFile.length();
          onProgress?.call(1.0, fileLength, fileLength);
          return destinationFile;
        }
      }
      await destinationFile.delete();
    }

    final http.Client httpClient = client ?? http.Client();
    final bool shouldCloseClient = client == null;

    try {
      final http.Request request = http.Request('GET', Uri.parse(manifest.apkUrl));
      request.headers['User-Agent'] = 'DailyCounter-AppUpdater';
      final http.StreamedResponse response = await httpClient.send(request);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException('Download failed with status code ${response.statusCode}');
      }

      final int totalBytes = response.contentLength ?? 0;
      int receivedBytes = 0;

      final IOSink sink = destinationFile.openWrite();

      try {
        await for (final List<int> chunk in response.stream) {
          if (isCancelled?.call() == true) {
            await sink.flush();
            await sink.close();
            if (await destinationFile.exists()) {
              await destinationFile.delete();
            }
            throw const CancellationException('Download was cancelled by the user');
          }

          sink.add(chunk);
          receivedBytes += chunk.length;
          final double progress = totalBytes > 0
              ? (receivedBytes / totalBytes).clamp(0.0, 1.0)
              : 0.0;
          onProgress?.call(progress, receivedBytes, totalBytes);
        }

        await sink.flush();
      } finally {
        await sink.close();
      }

      if (totalBytes > 0 && receivedBytes < totalBytes) {
        if (await destinationFile.exists()) {
          await destinationFile.delete();
        }
        throw const HttpException('Incomplete download: connection was closed prematurely');
      }

      return destinationFile;
    } finally {
      if (shouldCloseClient) {
        httpClient.close();
      }
    }
  }

  /// Verifies the SHA-256 checksum of [file] against [expectedHash].
  /// Uses chunked streaming to verify large APKs with minimal memory footprint.
  Future<bool> verifySha256(File file, String expectedHash) async {
    final String cleanExpected = expectedHash.trim().toLowerCase();
    if (cleanExpected.isEmpty) {
      return false;
    }

    try {
      final Digest digest = await sha256.bind(file.openRead()).first;
      final String calculated = digest.toString().toLowerCase();
      return calculated == cleanExpected;
    } catch (_) {
      return false;
    }
  }

  /// Checks if the app currently has permission to install unknown apps on Android 8.0+.
  Future<bool> canRequestPackageInstalls() async {
    try {
      final bool? result = await _channel.invokeMethod<bool>('canRequestPackageInstalls');
      return result ?? true;
    } catch (_) {
      return true;
    }
  }

  /// Opens Android system settings for granting "Install unknown apps" permission.
  Future<bool> openInstallPermissionSettings() async {
    try {
      final bool? result = await _channel.invokeMethod<bool>('openInstallPermissionSettings');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Triggers Android's package installer for the downloaded APK.
  Future<bool> installApk(File apkFile) async {
    if (!await apkFile.exists()) {
      throw FileNotFoundException('APK file not found at ${apkFile.path}');
    }

    final bool? result = await _channel.invokeMethod<bool>(
      'installApk',
      {'filePath': apkFile.path},
    );
    return result ?? false;
  }

  /// Performs an update check and opens the UpdateDialog if a newer version exists.
  /// Can be triggered automatically on app start or manually from Settings.
  Future<void> checkForUpdateAndPrompt(
    BuildContext context, {
    bool isManualCheck = false,
  }) async {
    if (_isChecking || _isDialogOpen) return;
    _isChecking = true;

    if (isManualCheck && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Checking for updates...'),
          duration: Duration(seconds: 2),
        ),
      );
    }

    try {
      final UpdateCheckResult result = await checkForUpdate();

      if (!context.mounted) return;

      if (result.hasUpdate && result.manifest != null) {
        _isDialogOpen = true;
        await showDialog<void>(
          context: context,
          barrierDismissible: !result.manifest!.forceUpdate,
          builder: (dialogCtx) => PopScope(
            canPop: !result.manifest!.forceUpdate,
            child: UpdateDialog(
              manifest: result.manifest!,
              currentVersionName: result.currentVersionName,
              service: this,
            ),
          ),
        );
        _isDialogOpen = false;
      } else if (isManualCheck) {
        if (!result.isSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Update check failed: ${result.errorMessage}'),
              backgroundColor: Colors.redAccent,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('You are on the latest version (v${result.currentVersionName})'),
            ),
          );
        }
      }
    } catch (e) {
      if (isManualCheck && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error checking for updates: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      _isChecking = false;
    }
  }
}

/// Thrown when download is cancelled by user.
class CancellationException implements Exception {
  final String message;
  const CancellationException(this.message);
  @override
  String toString() => message;
}

/// Thrown when file is not found.
class FileNotFoundException implements Exception {
  final String message;
  const FileNotFoundException(this.message);
  @override
  String toString() => message;
}
