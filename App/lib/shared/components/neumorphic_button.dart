import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_shadows.dart';

class NeumorphicButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry? padding;
  final double borderRadius;
  final bool isProminent;
  final bool isEnabled;
  final Color? color;

  const NeumorphicButton({
    super.key,
    required this.child,
    this.onTap,
    this.width,
    this.height,
    this.padding = const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
    this.borderRadius = 20.0,
    this.isProminent = false,
    this.isEnabled = true,
    this.color,
  });

  @override
  State<NeumorphicButton> createState() => _NeumorphicButtonState();
}

class _NeumorphicButtonState extends State<NeumorphicButton> {
  bool _isPressed = false;

  void _handleTapDown(TapDownDetails details) {
    if (!widget.isEnabled || widget.onTap == null) return;
    HapticFeedback.lightImpact();
    setState(() => _isPressed = true);
  }

  void _handleTapUp(TapUpDetails details) {
    if (!widget.isEnabled || widget.onTap == null) return;
    setState(() => _isPressed = false);
    widget.onTap?.call();
  }

  void _handleTapCancel() {
    if (!widget.isEnabled) return;
    setState(() => _isPressed = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.appTheme;

    final baseColor = widget.isProminent
        ? theme.accent
        : (widget.color ?? theme.surface);

    List<BoxShadow> shadows;
    if (!widget.isEnabled || _isPressed) {
      shadows = const [];
    } else if (widget.isProminent) {
      shadows = ThemeShadows.accentGlow(
        accent: theme.accent,
        intensity: theme.isDark ? 0.3 : 0.25,
      );
    } else {
      shadows = ThemeShadows.raised(
        surface: baseColor,
        isDark: theme.isDark,
        elevation: 0.8,
      );
    }

    final effectiveBorder = widget.isProminent
        ? null
        : Border.all(
            color: theme.cardBorder,
            width: 1.0,
          );

    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: _isPressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOutCubic,
        child: AnimatedOpacity(
          opacity: widget.isEnabled ? 1.0 : 0.45,
          duration: const Duration(milliseconds: 120),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            curve: Curves.easeOutCubic,
            width: widget.width,
            height: widget.height,
            padding: widget.padding,
            decoration: BoxDecoration(
              color: baseColor,
              borderRadius: BorderRadius.circular(widget.borderRadius),
              boxShadow: shadows,
              border: effectiveBorder,
            ),
            child: Center(
              child: DefaultTextStyle(
                style: TextStyle(
                  color: widget.isProminent ? Colors.white : theme.text,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
                child: widget.child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
