import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_shadows.dart';

enum NeumorphicShape {
  flat,
  convex,
  concave,
  pressed,
}

class NeumorphicContainer extends StatelessWidget {
  final Widget? child;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final bool isPressed;
  final NeumorphicShape shape;
  final Color? color;
  final double elevation;
  final Border? border;

  const NeumorphicContainer({
    super.key,
    this.child,
    this.width,
    this.height,
    this.padding,
    this.margin,
    this.borderRadius = 16.0,
    this.isPressed = false,
    this.shape = NeumorphicShape.flat,
    this.color,
    this.elevation = 1.0,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.appTheme;
    final baseColor = color ?? theme.surface;

    List<BoxShadow> shadows;
    if (isPressed || shape == NeumorphicShape.pressed) {
      shadows = ThemeShadows.pressed(
        surface: baseColor,
        isDark: theme.isDark,
      );
    } else {
      shadows = ThemeShadows.raised(
        surface: baseColor,
        isDark: theme.isDark,
        elevation: elevation,
      );
    }

    Gradient? gradient;
    if (shape == NeumorphicShape.convex) {
      gradient = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          theme.isDark ? baseColor.withValues(alpha: 0.95) : Colors.white.withValues(alpha: 0.3),
          baseColor,
        ],
      );
    } else if (shape == NeumorphicShape.concave || isPressed || shape == NeumorphicShape.pressed) {
      gradient = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          theme.isDark
              ? const Color(0xFF141722).withValues(alpha: 0.6)
              : const Color(0xFFA3B1C6).withValues(alpha: 0.25),
          baseColor,
        ],
      );
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOutCubic,
      width: width,
      height: height,
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: baseColor,
        gradient: gradient,
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: shadows,
        border: border,
      ),
      child: child,
    );
  }
}
