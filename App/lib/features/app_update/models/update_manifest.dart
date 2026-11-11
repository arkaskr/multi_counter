import 'dart:convert';

/// Represents the update manifest hosted on GitHub Releases.
/// Matches the schema:
/// ```json
/// {
///   "versionName": "1.1.0",
///   "versionCode": 2,
///   "forceUpdate": false,
///   "releaseNotes": "Bug fixes and improvements",
///   "apkUrl": "https://github.com/arkaskr/app-releases/releases/download/v1.1.0/app-release.apk",
///   "sha256": "APK_SHA256_HASH"
/// }
/// ```
class UpdateManifest {
  final String versionName;
  final int versionCode;
  final bool forceUpdate;
  final String releaseNotes;
  final String apkUrl;
  final String sha256;

  const UpdateManifest({
    required this.versionName,
    required this.versionCode,
    required this.forceUpdate,
    required this.releaseNotes,
    required this.apkUrl,
    required this.sha256,
  });

  factory UpdateManifest.fromJson(Map<String, dynamic> json) {
    return UpdateManifest(
      versionName: json['versionName'] as String? ?? '',
      versionCode: (json['versionCode'] as num?)?.toInt() ?? 0,
      forceUpdate: json['forceUpdate'] as bool? ?? false,
      releaseNotes: json['releaseNotes'] as String? ?? '',
      apkUrl: json['apkUrl'] as String? ?? '',
      sha256: (json['sha256'] as String? ?? '').trim().toLowerCase(),
    );
  }

  factory UpdateManifest.fromRawJson(String rawJson) {
    final dynamic decoded = jsonDecode(rawJson);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Invalid JSON manifest structure');
    }
    return UpdateManifest.fromJson(decoded);
  }

  Map<String, dynamic> toJson() {
    return {
      'versionName': versionName,
      'versionCode': versionCode,
      'forceUpdate': forceUpdate,
      'releaseNotes': releaseNotes,
      'apkUrl': apkUrl,
      'sha256': sha256,
    };
  }

  /// Checks if this remote manifest represents a newer version than [currentVersionCode].
  bool isNewerThan(int currentVersionCode) {
    return versionCode > currentVersionCode;
  }

  @override
  String toString() {
    return 'UpdateManifest(v$versionName ($versionCode), force: $forceUpdate, url: $apkUrl)';
  }
}
