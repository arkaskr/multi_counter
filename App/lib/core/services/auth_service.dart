import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';
import '../../shared/models/user_model.dart';

class AuthResult {
  final bool success;
  final String? message;
  final UserModel? user;
  final String? token;
  final String? devOtp;
  final String? userName;
  final bool isNotRegistered;
  final bool isAlreadyRegistered;

  const AuthResult({
    required this.success,
    this.message,
    this.user,
    this.token,
    this.devOtp,
    this.userName,
    this.isNotRegistered = false,
    this.isAlreadyRegistered = false,
  });
}

class AuthService {
  static final AuthService instance = AuthService._internal();

  @visibleForTesting
  AuthService.internal();

  AuthService._internal();

  static const String _keyToken = 'auth_token';
  static const String _keyUser = 'auth_user_json';
  static const String _keyGuest = 'auth_guest_mode';

  String? _token;
  UserModel? _currentUser;
  bool _isGuestMode = false;
  bool _initialized = false;

  String? get token => _token;
  UserModel? get currentUser => _currentUser;
  bool get isLoggedIn => _token != null && _currentUser != null;
  bool get isGuestMode => _isGuestMode;
  bool get isInitialized => _initialized;

  Future<void> init() async {
    if (_initialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      _token = prefs.getString(_keyToken);
      _isGuestMode = prefs.getBool(_keyGuest) ?? false;
      final userJson = prefs.getString(_keyUser);
      if (userJson != null) {
        _currentUser = UserModel.fromMap(jsonDecode(userJson) as Map<String, dynamic>);
      }
    } catch (e) {
      debugPrint('[AuthService] Init error: $e');
    } finally {
      _initialized = true;
    }
  }

  /// Sends 6-digit OTP to user email via backend Nodemailer
  /// mode: 'login' | 'register'
  Future<AuthResult> sendOtp({
    required String email,
    String? name,
    String mode = 'login',
  }) async {
    try {
      final url = Uri.parse('${AppConfig.apiBaseUrl}/auth/send-otp');
      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'email': email.trim(),
              'name': (name ?? '').trim(),
              'mode': mode,
            }),
          )
          .timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode >= 200 && response.statusCode < 300 && data['success'] == true) {
        return AuthResult(
          success: true,
          message: data['message'] as String? ?? 'OTP sent successfully',
          devOtp: data['devOtp'] as String?,
          userName: data['userName'] as String?,
        );
      } else {
        return AuthResult(
          success: false,
          message: data['message'] as String? ?? 'Failed to send OTP code.',
          isNotRegistered: data['isNotRegistered'] == true,
          isAlreadyRegistered: data['isAlreadyRegistered'] == true,
        );
      }
    } on SocketException {
      return const AuthResult(
        success: false,
        message: 'Could not connect to server. Check your network or server URL.',
      );
    } catch (e) {
      return AuthResult(
        success: false,
        message: 'Connection error: $e',
      );
    }
  }

  /// Verifies OTP code and registers/logs in the user
  Future<AuthResult> verifyOtp({
    required String email,
    required String otp,
    required String name,
  }) async {
    try {
      final url = Uri.parse('${AppConfig.apiBaseUrl}/auth/verify-otp');
      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'email': email.trim(),
              'otp': otp.trim(),
              'name': name.trim(),
            }),
          )
          .timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode >= 200 && response.statusCode < 300 && data['success'] == true) {
        final token = data['token'] as String;
        final user = UserModel.fromMap(data['user'] as Map<String, dynamic>);

        _token = token;
        _currentUser = user;
        _isGuestMode = false;

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_keyToken, token);
        await prefs.setString(_keyUser, jsonEncode(user.toMap()));
        await prefs.setBool(_keyGuest, false);

        return AuthResult(
          success: true,
          token: token,
          user: user,
          message: 'Login successful!',
        );
      } else {
        return AuthResult(
          success: false,
          message: data['message'] as String? ?? 'Invalid verification code.',
        );
      }
    } on SocketException {
      return const AuthResult(
        success: false,
        message: 'Could not connect to server. Check your network or server URL.',
      );
    } catch (e) {
      return AuthResult(
        success: false,
        message: 'Verification error: $e',
      );
    }
  }

  /// Continues in offline / guest mode without login
  Future<void> continueOffline() async {
    _isGuestMode = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyGuest, true);
    } catch (_) {}
  }

  /// Logs out the user and clears stored credentials
  Future<void> logout() async {
    _token = null;
    _currentUser = null;
    _isGuestMode = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyToken);
      await prefs.remove(_keyUser);
      await prefs.remove(_keyGuest);
    } catch (_) {}
  }
}

