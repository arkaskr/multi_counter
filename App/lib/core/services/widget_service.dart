import 'dart:developer' as developer;
import 'package:flutter/services.dart';
import '../constants/app_constants.dart';

class WidgetService {
  static final WidgetService instance = WidgetService._internal();

  final MethodChannel _channel;
  void Function()? onWidgetUpdatedCallback;

  WidgetService._internal()
      : _channel = const MethodChannel(AppConstants.widgetMethodChannel) {
    _trySetupHandler();
  }

  /// Custom constructor for testing
  WidgetService.withChannel(MethodChannel channel) : _channel = channel {
    _trySetupHandler();
  }

  void _trySetupHandler() {
    try {
      _channel.setMethodCallHandler(_handleNativeMethodCall);
    } catch (_) {}
  }

  Future<dynamic> _handleNativeMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onWidgetIncremented':
      case 'onWidgetRefresh':
        developer.log('Native widget triggered update notification', name: 'WidgetService');
        onWidgetUpdatedCallback?.call();
        return true;
      default:
        return null;
    }
  }

  /// Notify the native Android Glance widget that data or settings changed,
  /// triggering a re-render of all active widgets.
  Future<void> notifyWidgetUpdate() async {
    try {
      await _channel.invokeMethod('updateWidget');
    } on MissingPluginException {
      // Expected in non-Android environments or unit tests
      developer.log('Widget method channel not available in current environment', name: 'WidgetService');
    } catch (e) {
      developer.log('Error notifying native widget: $e', name: 'WidgetService');
    }
  }
}
