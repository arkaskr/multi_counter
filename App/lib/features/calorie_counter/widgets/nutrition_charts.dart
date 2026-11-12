import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../services/nutrition_analytics_service.dart';
import 'calorie_progress_ring.dart';

class CalorieTrendBarChart extends StatelessWidget {
  final List<DailyTrendPoint> points;
  final double height;
  final bool compactLabels;

  const CalorieTrendBarChart({
    super.key,
    required this.points,
    this.height = 160,
    this.compactLabels = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.appTheme;
    if (points.isEmpty) {
      return SizedBox(
        height: height,
        child: Center(
          child: Text(
            'No data points available',
            style: TextStyle(color: theme.secondaryText),
          ),
        ),
      );
    }

    double maxVal = 500;
    for (final p in points) {
      maxVal = math.max(maxVal, math.max(p.calories, p.dailyTargetCalories));
    }
    maxVal *= 1.12;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: height,
          child: CustomPaint(
            painter: _TrendBarPainter(
              points: points,
              maxVal: maxVal,
              emptyBarColor: theme.secondaryText.withValues(alpha: 0.12),
              targetLineColor:
                  NutritionAccentPalette.softGreen.withValues(alpha: 0.6),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: _buildXLabels(context, theme),
        ),
      ],
    );
  }

  List<Widget> _buildXLabels(BuildContext context, AppThemeData theme) {
    if (compactLabels && points.length > 10) {
      // Show Day 1, Mid, Last day labels
      final first = points.first.date.split('-').last;
      final mid = points[points.length ~/ 2].date.split('-').last;
      final last = points.last.date.split('-').last;
      return [
        Text(first, style: TextStyle(fontSize: 10, color: theme.secondaryText)),
        Text(mid, style: TextStyle(fontSize: 10, color: theme.secondaryText)),
        Text(last, style: TextStyle(fontSize: 10, color: theme.secondaryText)),
      ];
    }

    return points.map((p) {
      final dayPart = p.date.split('-').last;
      return Expanded(
        child: Center(
          child: Text(
            dayPart,
            style: TextStyle(
              fontSize: 10,
              fontWeight: p.hasRecords ? FontWeight.w700 : FontWeight.w400,
              color: p.hasRecords ? theme.text : theme.secondaryText,
            ),
          ),
        ),
      );
    }).toList();
  }
}

class _TrendBarPainter extends CustomPainter {
  final List<DailyTrendPoint> points;
  final double maxVal;
  final Color emptyBarColor;
  final Color targetLineColor;

  const _TrendBarPainter({
    required this.points,
    required this.maxVal,
    required this.emptyBarColor,
    required this.targetLineColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    final slotWidth = size.width / points.length;
    final barWidth = math.max(3.0, slotWidth * 0.56);

    // Draw reference target line from last point's daily target
    final refTarget = points.last.dailyTargetCalories;
    final targetY = size.height - ((refTarget / maxVal) * size.height);
    final targetPaint = Paint()
      ..color = targetLineColor
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;

    const dashWidth = 5.0;
    const dashSpace = 4.0;
    double x = 0;
    while (x < size.width) {
      canvas.drawLine(
        Offset(x, targetY),
        Offset(math.min(x + dashWidth, size.width), targetY),
        targetPaint,
      );
      x += dashWidth + dashSpace;
    }

    final barPaint = Paint()..style = PaintingStyle.fill;
    for (var i = 0; i < points.length; i++) {
      final p = points[i];
      final cx = (i + 0.5) * slotWidth;
      final left = cx - barWidth / 2;

      if (!p.hasRecords) {
        // Tiny baseline dot for unlogged day so missing history is never fabricated
        barPaint.color = emptyBarColor;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(left, size.height - 4, barWidth, 4),
            const Radius.circular(2),
          ),
          barPaint,
        );
        continue;
      }

      final barHeight = p.calories <= 0
          ? 6.0
          : math.max(8.0, (p.calories / maxVal) * size.height);
      final top = size.height - barHeight;

      barPaint.color = p.withinTarget
          ? NutritionAccentPalette.softGreen
          : (p.calories > p.dailyTargetCalories * 1.1
              ? NutritionAccentPalette.fatCoral
              : NutritionAccentPalette.warmOrange);

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(left, top, barWidth, barHeight),
          const Radius.circular(4),
        ),
        barPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _TrendBarPainter oldDelegate) => true;
}

class MacroCalorieSplitBar extends StatelessWidget {
  final double proteinGrams;
  final double carbsGrams;
  final double fatGrams;

  const MacroCalorieSplitBar({
    super.key,
    required this.proteinGrams,
    required this.carbsGrams,
    required this.fatGrams,
  });

  @override
  Widget build(BuildContext context) {
    final pKcal = proteinGrams * 4;
    final cKcal = carbsGrams * 4;
    final fKcal = fatGrams * 9;
    final total = pKcal + cKcal + fKcal;
    if (total <= 0) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Container(
          height: 10,
          color: context.appTheme.secondaryText.withValues(alpha: 0.14),
        ),
      );
    }

    final pFlex = math.max(1, ((pKcal / total) * 100).round());
    final cFlex = math.max(1, ((cKcal / total) * 100).round());
    final fFlex = math.max(1, ((fKcal / total) * 100).round());

    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            height: 10,
            child: Row(
              children: [
                Expanded(
                  flex: pFlex,
                  child: Container(color: NutritionAccentPalette.proteinBlue),
                ),
                Expanded(
                  flex: cFlex,
                  child: Container(color: NutritionAccentPalette.carbsAmber),
                ),
                Expanded(
                  flex: fFlex,
                  child: Container(color: NutritionAccentPalette.fatCoral),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _legendChip(
              context,
              'Protein ${((pKcal / total) * 100).round()}%',
              NutritionAccentPalette.proteinBlue,
            ),
            _legendChip(
              context,
              'Carbs ${((cKcal / total) * 100).round()}%',
              NutritionAccentPalette.carbsAmber,
            ),
            _legendChip(
              context,
              'Fat ${((fKcal / total) * 100).round()}%',
              NutritionAccentPalette.fatCoral,
            ),
          ],
        ),
      ],
    );
  }

  Widget _legendChip(BuildContext context, String text, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          text,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: context.appTheme.secondaryText,
          ),
        ),
      ],
    );
  }
}

