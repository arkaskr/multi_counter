import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class NeumorphicProgress extends StatelessWidget {
  final double progress; // 0.0 to 1.0
  final double height;
  final double borderRadius;
  final Color? color;
  final bool showGlow;

  const NeumorphicProgress({
    super.key,
    required this.progress,
    this.height = 10.0,
    this.borderRadius = 8.0,
    this.color,
    this.showGlow = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.appTheme;
    final clampedProgress = progress.clamp(0.0, 1.0);
    final fillColor = color ?? theme.accent;

    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;

        return Container(
          height: height,
          decoration: BoxDecoration(
            color: theme.isDark ? const Color(0xFF1B1E29) : const Color(0xFFE9EDF4),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: theme.cardBorder,
              width: 0.8,
            ),
          ),
          child: Stack(
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0.0, end: clampedProgress),
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                builder: (context, value, child) {
                  final fillWidth = totalWidth * value;
                  if (fillWidth <= 0) return const SizedBox.shrink();

                  return Container(
                    width: fillWidth,
                    height: height,
                    decoration: BoxDecoration(
                      color: fillColor,
                      borderRadius: BorderRadius.circular(borderRadius),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
