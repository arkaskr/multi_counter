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
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _handleSendOtp() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();

    if (name.isEmpty) {
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
    });

    try {
      final res = await ref.read(authStateProvider.notifier).sendOtp(email, name);

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (res.success) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => OtpScreen(
              name: name,
              email: email,
              devOtp: res.devOtp,
              isModal: widget.isModal,
            ),
          ),
        );
      } else {
        setState(() => _errorMessage = res.message ?? 'Failed to send OTP');
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
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: theme.accent.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                        border: Border.all(color: theme.accent, width: 2),
                      ),
                      child: Icon(
                        Icons.lunch_dining_rounded,
                        size: 42,
                        color: theme.accent,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

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
                    'Sign in or create account to sync meals with MongoDB cloud',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: theme.secondaryText,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Main Card
                  NeumorphicContainer(
                    borderRadius: 24,
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
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
                        const SizedBox(height: 12),

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

                        // Send OTP Button
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
                                : const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.send_rounded, size: 18, color: Colors.white),
                                      SizedBox(width: 8),
                                      Text(
                                        'Send Verification Code',
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Offline / Guest Mode option
                  if (!widget.isModal)
                    Center(
                      child: TextButton.icon(
                        icon: Icon(Icons.cloud_off_rounded, size: 18, color: theme.secondaryText),
                        label: Text(
                          'Continue in Offline Mode',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: theme.secondaryText,
                          ),
                        ),
                        onPressed: () async {
                          await ref.read(authStateProvider.notifier).continueOffline();
                        },
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
