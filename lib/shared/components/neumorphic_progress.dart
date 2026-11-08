import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import 'neumorphic_container.dart';

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

        return NeumorphicContainer(
          isPressed: true,
          shape: NeumorphicShape.pressed,
          borderRadius: borderRadius,
          height: height,
          padding: const EdgeInsets.all(2),
          child: Stack(
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0.0, end: clampedProgress),
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeOutCubic,
                builder: (context, value, child) {
                  final fillWidth = totalWidth * value;
                  if (fillWidth <= 0) return const SizedBox.shrink();

                  return Container(
                    width: fillWidth,
                    height: height,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(borderRadius),
                      gradient: LinearGradient(
                        colors: [
                          fillColor.withValues(alpha: 0.85),
                          fillColor,
                        ],
                      ),
                      boxShadow: showGlow && value > 0.05
                          ? [
                              BoxShadow(
                                color: fillColor.withValues(alpha: 0.5),
                                blurRadius: 6,
                                offset: const Offset(0, 1),
                              ),
                            ]
                          : null,
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
