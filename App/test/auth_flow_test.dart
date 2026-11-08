import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:daily_counter/features/auth/providers/auth_providers.dart';
import 'package:daily_counter/features/auth/screens/login_screen.dart';
import 'package:daily_counter/features/auth/screens/otp_screen.dart';
import 'package:daily_counter/core/services/auth_service.dart';
import 'package:daily_counter/shared/models/user_model.dart';

class FakeAuthService extends AuthService {
  FakeAuthService() : super.internal();

  bool shouldSucceedSendOtp = true;
  bool isNotRegistered = false;

  @override
  Future<void> init() async {}

  @override
  bool get isInitialized => true;

  @override
  bool get isLoggedIn => false;

  @override
  Future<AuthResult> sendOtp({
    required String email,
    String? name,
    String mode = 'login',
  }) async {
    if (!shouldSucceedSendOtp) {
      return AuthResult(
        success: false,
        message: 'No account found with this email. Please register first.',
        isNotRegistered: isNotRegistered,
      );
    }
    return const AuthResult(
      success: true,
      message: 'OTP sent successfully',
      devOtp: '123456',
      userName: 'Test User',
    );
  }

  @override
  Future<AuthResult> verifyOtp({
    required String email,
    required String otp,
    required String name,
  }) async {
    if (otp == '123456') {
      return const AuthResult(
        success: true,
        token: 'fake_jwt_token',
        user: UserModel(id: 'u1', name: 'Test User', email: 'test@example.com'),
      );
    }
    return const AuthResult(
      success: false,
      message: 'Invalid OTP code',
    );
  }
}

void main() {
  testWidgets('LoginScreen shows error message when email is not registered without unmounting', (tester) async {
    final fakeAuth = FakeAuthService();
    fakeAuth.shouldSucceedSendOtp = false;
    fakeAuth.isNotRegistered = true;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authServiceProvider.overrideWithValue(fakeAuth),
        ],
        child: const MaterialApp(
          home: LoginScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify initial screen is on Log In mode
    expect(find.text('Daily Counter'), findsOneWidget);
    expect(find.text('Send Login OTP'), findsOneWidget);

    // Enter email
    final emailField = find.byType(TextField).first;
    await tester.enterText(emailField, 'unknown@example.com');
    await tester.pumpAndSettle();

    // Tap Send Login OTP
    await tester.tap(find.text('Send Login OTP'));
    await tester.pumpAndSettle();

    // The screen must NOT have unmounted, and the error banner should appear!
    expect(find.text('No account found with this email. Please register first.'), findsOneWidget);
    expect(find.text('Click here to Register this email →'), findsOneWidget);

    // Tap switch button
    await tester.tap(find.text('Click here to Register this email →'));
    await tester.pumpAndSettle();

    // Now it should be on Register mode with name field present
    expect(find.text('YOUR NAME'), findsOneWidget);
    expect(find.text('Send Verification Code'), findsOneWidget);
  });

  testWidgets('LoginScreen navigates to OtpScreen on successful OTP request', (tester) async {
    final fakeAuth = FakeAuthService();
    fakeAuth.shouldSucceedSendOtp = true;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authServiceProvider.overrideWithValue(fakeAuth),
        ],
        child: const MaterialApp(
          home: LoginScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Enter email
    final emailField = find.byType(TextField).first;
    await tester.enterText(emailField, 'user@example.com');
    await tester.pumpAndSettle();

    // Tap Send Login OTP
    await tester.tap(find.text('Send Login OTP'));
    await tester.pumpAndSettle();

    // Verify OtpScreen is now in the view!
    expect(find.byType(OtpScreen), findsOneWidget);
    expect(find.text('Welcome Back!'), findsOneWidget);
    expect(find.text('6-DIGIT CODE'), findsOneWidget);
    expect(find.text('• • • • • •'), findsOneWidget);
  });
}
