import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/components/neumorphic_button.dart';
import '../../../shared/components/neumorphic_container.dart';
import '../../../shared/components/neumorphic_input.dart';
import '../providers/auth_providers.dart';

class OtpScreen extends ConsumerStatefulWidget {
  final String name;
  final String email;
  final String? devOtp;
  final bool isLogin;
  final bool isModal;

  const OtpScreen({
    super.key,
    required this.name,
    required this.email,
    this.devOtp,
    this.isLogin = false,
    this.isModal = false,
  });

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final TextEditingController _otpController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  String? _currentDevOtp;

  @override
  void initState() {
    super.initState();
    _currentDevOtp = widget.devOtp;
  }

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _handleVerify() async {
    final otp = _otpController.text.trim();
    if (otp.length < 4) {
      setState(() => _errorMessage = 'Please enter the 6-digit code');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await ref.read(authStateProvider.notifier).verifyOtp(
            widget.email,
            otp,
            widget.name,
          );

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (res.success) {
        // Trigger initial sync with MongoDB
        ref.read(syncStatusProvider.notifier).triggerSync();

        if (widget.isModal) {
          // Pop twice to dismiss modal flow
          Navigator.of(context).pop();
          Navigator.of(context).pop();
        } else {
          // Pop back to root so MainShell is displayed
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      } else {
        setState(() => _errorMessage = res.message ?? 'Verification failed');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error: $e';
      });
    }
  }

  Future<void> _handleResend() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await ref.read(authStateProvider.notifier).sendOtp(
            widget.email,
            name: widget.name,
            mode: widget.isLogin ? 'login' : 'register',
          );

      if (!mounted) return;
      setState(() {
        _isLoading = false;
        if (res.devOtp != null) {
          _currentDevOtp = res.devOtp;
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res.message ?? 'New OTP sent to ${widget.email}'),
          backgroundColor: Colors.green[700],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to resend: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.appTheme;

    return Scaffold(
      backgroundColor: theme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: theme.text),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: theme.accent.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.mark_email_read_rounded, size: 36, color: theme.accent),
                  ),
                ),
                const SizedBox(height: 20),

                Text(
                  widget.isLogin ? 'Welcome Back!' : 'Verify Your Email',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: theme.text,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.isLogin && widget.name.isNotEmpty
                      ? 'Hi ${widget.name}! Enter the login code sent to:\n${widget.email}'
                      : 'Enter the verification code sent to:\n${widget.email}',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: theme.secondaryText,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 28),

                NeumorphicContainer(
                  borderRadius: 24,
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '6-DIGIT CODE',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                          color: theme.secondaryText,
                        ),
                      ),
                      const SizedBox(height: 8),

                      NeumorphicInput(
                        controller: _otpController,
                        autofocus: true,
                        hintText: '• • • • • •',
                        hintStyle: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 8,
                          color: theme.secondaryText.withValues(alpha: 0.35),
                        ),
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 8,
                          color: theme.text,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(6),
                        ],
                      ),
                      const SizedBox(height: 12),

                      if (_currentDevOtp != null) ...[
                        InkWell(
                          onTap: () {
                            setState(() {
                              _otpController.text = _currentDevOtp!;
                            });
                          },
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.blue.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.info_outline, size: 16, color: Colors.blue),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Code: $_currentDevOtp • Tap to fill',
                                    style: const TextStyle(fontSize: 12, color: Colors.blue, fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],

                      if (_errorMessage != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline, size: 16, color: Colors.red),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _errorMessage!,
                                  style: const TextStyle(fontSize: 12, color: Colors.red, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],

                      const SizedBox(height: 12),

                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: NeumorphicButton(
                          isProminent: true,
                          isEnabled: !_isLoading,
                          onTap: _handleVerify,
                          child: _isLoading
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                                )
                              : Text(
                                  widget.isLogin ? 'Verify & Log In' : 'Verify & Create Account',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Didn't receive the code? ",
                      style: TextStyle(fontSize: 13, color: theme.secondaryText),
                    ),
                    GestureDetector(
                      onTap: _isLoading ? null : _handleResend,
                      child: Text(
                        'Resend OTP',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: theme.accent,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

