import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/components/neumorphic_button.dart';
import '../../../shared/components/neumorphic_container.dart';
import '../../../shared/components/neumorphic_input.dart';
import '../providers/auth_providers.dart';
import 'otp_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  final bool isModal;

  const LoginScreen({super.key, this.isModal = false});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isRegister = false; // false = Login, true = Register
  bool _isLoading = false;
  String? _errorMessage;
  bool _isNotRegisteredError = false;
  bool _isAlreadyRegisteredError = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _switchMode(bool register) {
    setState(() {
      _isRegister = register;
      _errorMessage = null;
      _isNotRegisteredError = false;
      _isAlreadyRegisteredError = false;
    });
  }

  Future<void> _handleSendOtp() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();

    if (_isRegister && name.isEmpty) {
      setState(() => _errorMessage = 'Please enter your name');
      return;
    }

    if (email.isEmpty || !email.contains('@') || !email.contains('.')) {
      setState(() => _errorMessage = 'Please enter a valid email address');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _isNotRegisteredError = false;
      _isAlreadyRegisteredError = false;
    });

    try {
      final res = await ref.read(authStateProvider.notifier).sendOtp(
            email,
            name: _isRegister ? name : null,
            mode: _isRegister ? 'register' : 'login',
          );

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (res.success) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => OtpScreen(
              name: _isRegister ? name : (res.userName ?? ''),
              email: email,
              devOtp: res.devOtp,
              isLogin: !_isRegister,
              isModal: widget.isModal,
            ),
          ),
        );
      } else {
        setState(() {
          _errorMessage = res.message ?? 'Failed to send OTP';
          _isNotRegisteredError = res.isNotRegistered;
          _isAlreadyRegisteredError = res.isAlreadyRegistered;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.appTheme;

    return Scaffold(
      backgroundColor: theme.background,
      appBar: widget.isModal
          ? AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(
                icon: Icon(Icons.close_rounded, color: theme.text),
                onPressed: () => Navigator.of(context).pop(),
              ),
            )
          : null,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // App Icon / Logo
                  Center(
                    child: Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        color: theme.accent.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                        border: Border.all(color: theme.accent, width: 2),
                      ),
                      child: Icon(
                        Icons.lunch_dining_rounded,
                        size: 40,
                        color: theme.accent,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Title
                  Text(
                    'Daily Counter',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: theme.text,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _isRegister
                        ? 'Create an account to backup and sync meals across devices'
                        : 'Sign in to access your saved records and cloud sync',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: theme.secondaryText,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Mode Toggle Selector (Log In / Register)
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: theme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: theme.secondaryText.withValues(alpha: 0.15),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => _switchMode(false),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: !_isRegister ? theme.accent : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Center(
                                child: Text(
                                  'Log In',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: !_isRegister ? Colors.white : theme.secondaryText,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => _switchMode(true),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: _isRegister ? theme.accent : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Center(
                                child: Text(
                                  'Register',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: _isRegister ? Colors.white : theme.secondaryText,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Main Input Card
                  NeumorphicContainer(
                    borderRadius: 24,
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Name input only when Registering
                        if (_isRegister) ...[
                          Text(
                            'YOUR NAME',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.2,
                              color: theme.secondaryText,
                            ),
                          ),
                          const SizedBox(height: 8),
                          NeumorphicInput(
                            controller: _nameController,
                            hintText: 'e.g. Arka Sarkar',
                            prefixIcon: Icon(Icons.person_outline_rounded, size: 20, color: theme.secondaryText),
                          ),
                          const SizedBox(height: 18),
                        ],

                        Text(
                          'EMAIL ADDRESS',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                            color: theme.secondaryText,
                          ),
                        ),
                        const SizedBox(height: 8),
                        NeumorphicInput(
                          controller: _emailController,
                          hintText: 'e.g. user@example.com',
                          keyboardType: TextInputType.emailAddress,
                          prefixIcon: Icon(Icons.email_outlined, size: 20, color: theme.secondaryText),
                        ),
                        const SizedBox(height: 14),

                        // Error Banner with one-tap switch button if relevant
                        if (_errorMessage != null) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.error_outline_rounded, size: 16, color: Colors.red),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _errorMessage!,
                                        style: const TextStyle(fontSize: 12, color: Colors.red, fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                  ],
                                ),
                                if (_isNotRegisteredError) ...[
                                  const SizedBox(height: 8),
                                  GestureDetector(
                                    onTap: () => _switchMode(true),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: theme.accent,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Text(
                                        'Click here to Register this email →',
                                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white),
                                      ),
                                    ),
                                  ),
                                ],
                                if (_isAlreadyRegisteredError) ...[
                                  const SizedBox(height: 8),
                                  GestureDetector(
                                    onTap: () => _switchMode(false),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: theme.accent,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Text(
                                        'Click here to Log In instead →',
                                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                        ],

                        // Submit Button
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: NeumorphicButton(
                            isProminent: true,
                            isEnabled: !_isLoading,
                            onTap: _handleSendOtp,
                            child: _isLoading
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        _isRegister ? Icons.person_add_rounded : Icons.login_rounded,
                                        size: 18,
                                        color: Colors.white,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        _isRegister ? 'Send Verification Code' : 'Send Login OTP',
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Switch Mode Prompt
                        Center(
                          child: GestureDetector(
                            onTap: () => _switchMode(!_isRegister),
                            child: Text.rich(
                              TextSpan(
                                text: _isRegister ? 'Already have an account? ' : "Don't have an account? ",
                                style: TextStyle(fontSize: 13, color: theme.secondaryText),
                                children: [
                                  TextSpan(
                                    text: _isRegister ? 'Log In' : 'Register',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      color: theme.accent,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
