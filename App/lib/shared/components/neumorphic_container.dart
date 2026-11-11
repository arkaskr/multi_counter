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

    final shadows = (isPressed || shape == NeumorphicShape.pressed)
        ? const <BoxShadow>[]
        : ThemeShadows.raised(
            surface: baseColor,
            isDark: theme.isDark,
            elevation: elevation,
          );

    final effectiveBorder = border ??
        Border.all(
          color: theme.cardBorder,
          width: 1.0,
        );

    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOutCubic,
      width: width,
      height: height,
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: baseColor,
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: shadows,
        border: effectiveBorder,
      ),
      child: child,
    );
  }
}
