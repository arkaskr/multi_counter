import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class NutritionAccentPalette {
  NutritionAccentPalette._();

  static const Color warmOrange = Color(0xFFFF6D00);
  static const Color softGreen = Color(0xFF16A34A);
  static const Color proteinBlue = Color(0xFF2563EB);
  static const Color carbsAmber = Color(0xFFD97706);
  static const Color fatCoral = Color(0xFFE11D48);
  static const Color fibreTeal = Color(0xFF0D9488);
  static const Color waterCyan = Color(0xFF0284C7);
}

class CalorieProgressRing extends StatelessWidget {
  final double consumed;
  final double target;
  final double size;

  const CalorieProgressRing({
    super.key,
    required this.consumed,
    required this.target,
    this.size = 156,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.appTheme;
    final safeTarget = target <= 0 ? 1.0 : target;
    final ratio = consumed / safeTarget;
    final clamped = ratio.clamp(0.0, 1.0);
    final remaining = target - consumed;
    final isOver = remaining < 0;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size.square(size),
            painter: _CalorieRingPainter(
              progress: clamped,
              isOver: isOver,
              trackColor: theme.secondaryText.withValues(alpha: 0.14),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isOver
                    ? '+${remaining.abs().round()}'
                    : '${remaining.round()}',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: isOver ? NutritionAccentPalette.fatCoral : theme.text,
                  letterSpacing: -0.5,
                ),
              ),
              Text(
                isOver ? 'kcal over' : 'kcal left',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: theme.secondaryText,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: NutritionAccentPalette.warmOrange.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${consumed.round()} / ${target.round()}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: NutritionAccentPalette.warmOrange,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CalorieRingPainter extends CustomPainter {
  final double progress;
  final bool isOver;
  final Color trackColor;

  const _CalorieRingPainter({
    required this.progress,
    required this.isOver,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final strokeWidth = size.width * 0.1;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);

    if (progress <= 0) return;

    final sweep = 2 * math.pi * progress;
    final activePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        startAngle: -math.pi / 2,
        endAngle: 1.5 * math.pi,
        colors: isOver
            ? [
                NutritionAccentPalette.warmOrange,
                NutritionAccentPalette.fatCoral,
              ]
            : [
                NutritionAccentPalette.warmOrange,
                NutritionAccentPalette.softGreen,
              ],
      ).createShader(rect);

    canvas.drawArc(rect, -math.pi / 2, sweep, false, activePaint);
  }

  @override
  bool shouldRepaint(covariant _CalorieRingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.isOver != isOver ||
        oldDelegate.trackColor != trackColor;
  }
}

class MacroProgressBar extends StatelessWidget {
  final String label;
  final double current;
  final double target;
  final String unit;
  final Color color;

  const MacroProgressBar({
    super.key,
    required this.label,
    required this.current,
    required this.target,
    this.unit = 'g',
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.appTheme;
    final ratio = target > 0 ? (current / target).clamp(0.0, 1.0) : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: theme.text,
              ),
            ),
            Text(
              '${current.toStringAsFixed(current >= 10 ? 0 : 1)}/${target.round()}$unit',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: theme.secondaryText,
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 7,
            backgroundColor: color.withValues(alpha: 0.14),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}

