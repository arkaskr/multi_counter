import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:daily_counter/core/theme/theme_provider.dart';
import 'package:daily_counter/features/app_update/models/update_manifest.dart';
import 'package:daily_counter/features/app_update/services/app_update_service.dart';
import 'package:daily_counter/features/app_update/widgets/update_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('UpdateManifest Model Tests', () {
    test('Correctly parses valid manifest JSON', () {
      const String jsonStr = '''
      {
        "versionName": "1.1.0",
        "versionCode": 2,
        "forceUpdate": true,
        "releaseNotes": "Fixes and performance boosts",
        "apkUrl": "https://github.com/arkaskr/multi_counter/releases/download/v1.1.0/app-release.apk",
        "sha256": "A1B2C3D4E5F6"
      }
      ''';

      final UpdateManifest manifest = UpdateManifest.fromRawJson(jsonStr);

      expect(manifest.versionName, '1.1.0');
      expect(manifest.versionCode, 2);
      expect(manifest.forceUpdate, isTrue);
      expect(manifest.releaseNotes, 'Fixes and performance boosts');
      expect(manifest.apkUrl, 'https://github.com/arkaskr/multi_counter/releases/download/v1.1.0/app-release.apk');
      expect(manifest.sha256, 'a1b2c3d4e5f6'); // trimmed and lowercased
    });

    test('isNewerThan compares versionCode correctly', () {
      const manifest = UpdateManifest(
        versionName: '1.2.0',
        versionCode: 3,
        forceUpdate: false,
        releaseNotes: 'Update notes',
        apkUrl: 'https://example.com/app.apk',
        sha256: 'abc123',
      );

      expect(manifest.isNewerThan(1), isTrue);
      expect(manifest.isNewerThan(2), isTrue);
      expect(manifest.isNewerThan(3), isFalse);
      expect(manifest.isNewerThan(4), isFalse);
    });

    test('Handles missing or nullable fields with safe defaults', () {
      final manifest = UpdateManifest.fromJson(const {});

      expect(manifest.versionName, '');
      expect(manifest.versionCode, 0);
      expect(manifest.forceUpdate, isFalse);
      expect(manifest.releaseNotes, '');
      expect(manifest.apkUrl, '');
      expect(manifest.sha256, '');
    });

    test('Throws FormatException on invalid non-map JSON', () {
      expect(() => UpdateManifest.fromRawJson('"not an object"'), throwsFormatException);
    });
  });

  group('AppUpdateService Tests', () {
    test('checkForUpdate returns hasUpdate = true when remote versionCode is higher', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'versionName': '1.1.0',
            'versionCode': 5,
            'forceUpdate': false,
            'releaseNotes': 'New shiny features',
            'apkUrl': 'https://github.com/arkaskr/multi_counter/releases/download/v1.1.0/app-release.apk',
            'sha256': '1234567890abcdef',
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = AppUpdateService.custom();
      final result = await service.checkForUpdate(
        client: mockClient,
        manifestUrl: 'https://example.com/latest.json',
      );

      expect(result.isSuccess, isTrue);
      expect(result.hasUpdate, isTrue);
      expect(result.manifest?.versionName, '1.1.0');
      expect(result.manifest?.versionCode, 5);
      expect(result.manifest?.forceUpdate, isFalse);
    });

    test('checkForUpdate returns hasUpdate = false when remote versionCode is equal or lower', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'versionName': '1.0.0',
            'versionCode': 1,
            'forceUpdate': false,
            'releaseNotes': 'No updates',
            'apkUrl': 'https://example.com/app.apk',
            'sha256': '',
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = AppUpdateService.custom();
      final result = await service.checkForUpdate(
        client: mockClient,
        manifestUrl: 'https://example.com/latest.json',
      );

      expect(result.isSuccess, isTrue);
      expect(result.hasUpdate, isFalse);
    });

    test('checkForUpdate handles HTTP 404 / 500 error gracefully', () async {
      final mockClient = MockClient((request) async {
        return http.Response('Not Found', 404);
      });

      final service = AppUpdateService.custom();
      final result = await service.checkForUpdate(
        client: mockClient,
        manifestUrl: 'https://example.com/latest.json',
      );

      expect(result.isSuccess, isFalse);
      expect(result.hasUpdate, isFalse);
      expect(result.errorMessage, contains('HTTP 404'));
    });

    test('checkForUpdate handles malformed JSON response gracefully', () async {
      final mockClient = MockClient((request) async {
        return http.Response('<!DOCTYPE html><html><body>Error</body></html>', 200);
      });

      final service = AppUpdateService.custom();
      final result = await service.checkForUpdate(
        client: mockClient,
        manifestUrl: 'https://example.com/latest.json',
      );

      expect(result.isSuccess, isFalse);
      expect(result.hasUpdate, isFalse);
      expect(result.errorMessage, isNotNull);
    });

    test('verifySha256 verifies matching hash and rejects mismatched hash', () async {
      final service = AppUpdateService.custom();
      final tempDir = Directory.systemTemp.createTempSync('sha_test_');
      final tempFile = File('${tempDir.path}/test_file.bin');
      const content = 'Daily Counter APK Test Content 2026';
      tempFile.writeAsStringSync(content);

      final expectedHash = sha256.convert(utf8.encode(content)).toString();

      // Matching hash
      final bool matches = await service.verifySha256(tempFile, expectedHash);
      expect(matches, isTrue);

      // Upper-case matching hash
      final bool matchesUpper = await service.verifySha256(tempFile, expectedHash.toUpperCase());
      expect(matchesUpper, isTrue);

      // Corrupted / wrong hash
      final bool rejectsBadHash = await service.verifySha256(tempFile, 'deadbeef123456');
      expect(rejectsBadHash, isFalse);

      // Empty hash
      final bool rejectsEmptyHash = await service.verifySha256(tempFile, '');
      expect(rejectsEmptyHash, isFalse);

      // Cleanup
      tempFile.deleteSync();
      tempDir.deleteSync();
    });
  });

  group('UpdateDialog Widget Tests', () {
    Widget buildTestDialog({
      required UpdateManifest manifest,
      String currentVersion = '1.0.0',
    }) {
      return ProviderScope(
        overrides: [
          themeProvider.overrideWith(ThemeNotifier.new),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: UpdateDialog(
              manifest: manifest,
              currentVersionName: currentVersion,
              service: AppUpdateService.custom(),
            ),
          ),
        ),
      );
    }

    testWidgets('Renders compulsory update dialog with REQUIRED badge and NO Later button', (tester) async {
      const manifest = UpdateManifest(
        versionName: '1.2.0',
        versionCode: 3,
        forceUpdate: false,
        releaseNotes: '• Major UI revamp\n• Performance optimizations',
        apkUrl: 'https://github.com/arkaskr/multi_counter/releases/download/v1.2.0/app-release.apk',
        sha256: 'abcdef123456',
      );

      await tester.pumpWidget(buildTestDialog(manifest: manifest));
      await tester.pumpAndSettle();

      expect(find.text('Update Required'), findsOneWidget);
      expect(find.text('v1.0.0  →  v1.2.0'), findsOneWidget);
      expect(find.text('REQUIRED'), findsOneWidget);
      expect(find.text('• Major UI revamp\n• Performance optimizations'), findsOneWidget);
      expect(find.text('Update Now'), findsOneWidget);
      expect(find.text('Exit App'), findsOneWidget);
      expect(find.text('Later'), findsNothing); // Must never have Later option
    });

    testWidgets('Renders mandatory update dialog with release notes and Update Now', (tester) async {
      const manifest = UpdateManifest(
        versionName: '2.0.0',
        versionCode: 10,
        forceUpdate: true,
        releaseNotes: 'Critical security update. Update immediately.',
        apkUrl: 'https://github.com/arkaskr/multi_counter/releases/download/v2.0.0/app-release.apk',
        sha256: 'abcdef123456',
      );

      await tester.pumpWidget(buildTestDialog(manifest: manifest));
      await tester.pumpAndSettle();

      expect(find.text('Update Required'), findsOneWidget);
      expect(find.text('REQUIRED'), findsOneWidget);
      expect(find.text('Critical security update. Update immediately.'), findsOneWidget);
      expect(find.text('Update Now'), findsOneWidget);
      expect(find.text('Exit App'), findsOneWidget);
      expect(find.text('Later'), findsNothing);
    });
  });
}
