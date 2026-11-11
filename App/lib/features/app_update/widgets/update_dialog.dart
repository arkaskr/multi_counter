import 'dart:io';

import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../models/update_manifest.dart';
import '../services/app_update_service.dart';

enum UpdateDialogState {
  ready,
  downloading,
  verifying,
  permissionRequired,
  installing,
  error,
}

class UpdateDialog extends StatefulWidget {
  final UpdateManifest manifest;
  final String currentVersionName;
  final AppUpdateService? service;

  const UpdateDialog({
    super.key,
    required this.manifest,
    required this.currentVersionName,
    this.service,
  });

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  late final AppUpdateService _service;

  UpdateDialogState _state = UpdateDialogState.ready;
  double _downloadProgress = 0.0;
  int _receivedBytes = 0;
  int _totalBytes = 0;
  String? _errorMessage;
  bool _isCancelled = false;
  File? _verifiedApkFile;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? AppUpdateService.instance;
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const List<String> suffixes = ['B', 'KB', 'MB', 'GB'];
    int i = 0;
    double d = bytes.toDouble();
    while (d >= 1024 && i < suffixes.length - 1) {
      d /= 1024;
      i++;
    }
    return '${d.toStringAsFixed(1)} ${suffixes[i]}';
  }

  Future<void> _startUpdate() async {
    setState(() {
      _state = UpdateDialogState.downloading;
      _downloadProgress = 0.0;
      _receivedBytes = 0;
      _totalBytes = 0;
      _errorMessage = null;
      _isCancelled = false;
    });

    try {
      // Step 1: Download APK
      final File apkFile = await _service.downloadApk(
        widget.manifest,
        client: null,
        isCancelled: () => _isCancelled,
        onProgress: (progress, received, total) {
          if (mounted && !_isCancelled) {
            setState(() {
              _downloadProgress = progress;
              _receivedBytes = received;
              _totalBytes = total;
            });
          }
        },
      );

      if (_isCancelled) return;

      // Step 2: SHA-256 Verification
      setState(() => _state = UpdateDialogState.verifying);

      if (widget.manifest.sha256.isNotEmpty) {
        final bool isValid = await _service.verifySha256(apkFile, widget.manifest.sha256);
        if (!isValid) {
          try {
            if (await apkFile.exists()) await apkFile.delete();
          } catch (_) {}
          throw Exception(
            'Security Check Failed: Downloaded package SHA-256 does not match release manifest. Update aborted for safety.',
          );
        }
      }

      _verifiedApkFile = apkFile;

      // Step 3: Check Android install permission
      await _checkPermissionAndInstall(apkFile);
    } on CancellationException {
      if (mounted) {
        setState(() {
          _state = UpdateDialogState.ready;
          _downloadProgress = 0.0;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _state = UpdateDialogState.error;
          _errorMessage = e.toString().replaceFirst('Exception: ', '').trim();
        });
      }
    }
  }

  Future<void> _checkPermissionAndInstall(File apkFile) async {
    final bool canInstall = await _service.canRequestPackageInstalls();
    if (!canInstall) {
      if (mounted) {
        setState(() => _state = UpdateDialogState.permissionRequired);
      }
      return;
    }

    if (mounted) {
      setState(() => _state = UpdateDialogState.installing);
    }

    try {
      await _service.installApk(apkFile);
    } catch (e) {
      if (mounted) {
        setState(() {
          _state = UpdateDialogState.error;
          _errorMessage = 'Failed to launch installer: $e';
        });
      }
    }
  }

  void _cancelDownload() {
    _isCancelled = true;
    setState(() {
      _state = UpdateDialogState.ready;
      _downloadProgress = 0.0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.appTheme;
    final bool isForce = widget.manifest.forceUpdate;

    return Dialog(
      backgroundColor: theme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: theme.cardBorder, width: 1.5),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        padding: const EdgeInsets.all(22),
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Header: Icon + Title + Version Tag
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: (isForce ? Colors.amber : theme.accent).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    isForce ? Icons.warning_amber_rounded : Icons.system_update_rounded,
                    color: isForce ? Colors.amber[700] ?? Colors.amber : theme.accent,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isForce ? 'Mandatory Update' : 'New Update Available',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: theme.text,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'v${widget.currentVersionName}  →  v${widget.manifest.versionName}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: theme.accent,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isForce)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                    ),
                    child: const Text(
                      'REQUIRED',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Colors.redAccent,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 18),

            // Dynamic Body Content based on State
            if (_state == UpdateDialogState.ready) ...[
              _buildReleaseNotes(theme),
              const SizedBox(height: 22),
              _buildActionButtons(theme, isForce),
            ] else if (_state == UpdateDialogState.downloading) ...[
              _buildDownloadingView(theme, isForce),
            ] else if (_state == UpdateDialogState.verifying) ...[
              _buildVerifyingView(theme),
            ] else if (_state == UpdateDialogState.permissionRequired) ...[
              _buildPermissionRequiredView(theme),
            ] else if (_state == UpdateDialogState.installing) ...[
              _buildInstallingView(theme),
            ] else if (_state == UpdateDialogState.error) ...[
              _buildErrorView(theme, isForce),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildReleaseNotes(dynamic theme) {
    final String notes = widget.manifest.releaseNotes.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "WHAT'S NEW",
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
            color: theme.secondaryText,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          constraints: const BoxConstraints(maxHeight: 180),
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: theme.background,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: theme.cardBorder),
          ),
          child: SingleChildScrollView(
            child: Text(
              notes.isNotEmpty ? notes : '• Bug fixes, UI enhancements, and general stability improvements.',
              style: TextStyle(
                fontSize: 13,
                height: 1.45,
                color: theme.text,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(dynamic theme, bool isForce) {
    return Row(
      children: [
        if (!isForce) ...[
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: OutlinedButton.styleFrom(
                foregroundColor: theme.secondaryText,
                side: BorderSide(color: theme.cardBorder, width: 1.5),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text(
                'Later',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(width: 12),
        ],
        Expanded(
          flex: isForce ? 1 : 2,
          child: ElevatedButton(
            onPressed: _startUpdate,
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.accent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.download_rounded, size: 18),
                SizedBox(width: 8),
                Text(
                  'Update Now',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDownloadingView(dynamic theme, bool isForce) {
    final int percent = (_downloadProgress * 100).toInt();

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Downloading update...',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: theme.text,
              ),
            ),
            Text(
              '$percent%',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: theme.accent,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: _totalBytes > 0 ? _downloadProgress : null,
            minHeight: 8,
            backgroundColor: theme.background,
            valueColor: AlwaysStoppedAnimation<Color>(theme.accent),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _totalBytes > 0
                  ? '${_formatBytes(_receivedBytes)} of ${_formatBytes(_totalBytes)}'
                  : _formatBytes(_receivedBytes),
              style: TextStyle(
                fontSize: 12,
                color: theme.secondaryText,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (!isForce)
              GestureDetector(
                onTap: _cancelDownload,
                child: Text(
                  'Cancel',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.redAccent.withValues(alpha: 0.9),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildVerifyingView(dynamic theme) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        children: [
          SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation<Color>(theme.accent),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Verifying package integrity (SHA-256)...',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: theme.text,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionRequiredView(dynamic theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.orange.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.security_rounded, color: Colors.orange, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Permission Required',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Colors.orange,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Android requires you to grant "Install unknown apps" permission to install updates from within the app.',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.4,
                        color: theme.text,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        ElevatedButton(
          onPressed: () async {
            await _service.openInstallPermissionSettings();
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.accent,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 13),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text(
            'Open Settings to Allow',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
          ),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () {
            if (_verifiedApkFile != null) {
              _checkPermissionAndInstall(_verifiedApkFile!);
            }
          },
          child: Text(
            'I have enabled permission -> Install Now',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: theme.accent,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInstallingView(dynamic theme) {
    final bool isForce = widget.manifest.forceUpdate;
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            children: [
              SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(theme.accent),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Opening system package installer...',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: theme.text,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Follow the prompt on your screen to complete the installation.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  color: theme.secondaryText,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            if (!isForce) ...[
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: theme.secondaryText,
                    side: BorderSide(color: theme.cardBorder, width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Later', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: ElevatedButton(
                onPressed: () {
                  if (_verifiedApkFile != null) {
                    _checkPermissionAndInstall(_verifiedApkFile!);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Install Again', style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildErrorView(dynamic theme, bool isForce) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.red.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Update Error',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Colors.redAccent,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _errorMessage ?? 'An unexpected error occurred during update.',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.4,
                        color: theme.text,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            if (!isForce) ...[
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: theme.secondaryText,
                    side: BorderSide(color: theme.cardBorder, width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Dismiss', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: ElevatedButton(
                onPressed: _startUpdate,
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Retry', style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
