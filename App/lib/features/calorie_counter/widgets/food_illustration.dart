import 'package:flutter/material.dart';

/// Lightweight, reusable 2D vector food illustration widget built purely with
/// Flutter [CustomPaint] so the app stays small even as the catalogue scales
/// to thousands of items.
class FoodIllustration extends StatelessWidget {
  final String illustrationId;
  final String? categoryId;
  final double size;

  const FoodIllustration({
    super.key,
    required this.illustrationId,
    this.categoryId,
    this.size = 48,
  });

  static Color accentColorFor(String illustrationId, String? categoryId) {
    final key = _resolveVisualKey(illustrationId, categoryId);
    switch (key) {
      case 'roti':
      case 'paratha':
      case 'dosa':
      case 'idli':
      case 'poha':
      case 'oats':
      case 'bread':
        return const Color(0xFFD97706); // warm golden wheat
      case 'dal':
      case 'curry':
      case 'biryani':
      case 'rice':
        return const Color(0xFFEA580C); // spice orange
      case 'apple':
      case 'watermelon':
      case 'pomegranate':
      case 'tomato':
        return const Color(0xFFEF4444); // vibrant fruit red
      case 'banana':
      case 'mango':
      case 'pineapple':
      case 'orange':
      case 'papaya':
      case 'corn':
        return const Color(0xFFF59E0B); // sunny citrus
      case 'grapes':
      case 'beetroot':
        return const Color(0xFF8B5CF6); // berry purple
      case 'guava':
      case 'spinach':
      case 'broccoli':
      case 'cucumber':
      case 'peas':
        return const Color(0xFF16A34A); // fresh garden green
      case 'milk':
      case 'curd':
      case 'paneer':
      case 'tofu':
      case 'cheese':
      case 'butter':
        return const Color(0xFF0284C7); // clean dairy blue
      case 'almond':
      case 'walnut':
      case 'peanut':
      case 'seeds':
      case 'beans':
        return const Color(0xFFA16207); // earthy nut brown
      case 'egg':
      case 'chicken':
      case 'fish':
        return const Color(0xFFDC2626); // protein coral-red
      case 'tea':
      case 'coffee':
      case 'juice':
      case 'coconut_water':
        return const Color(0xFF0D9488); // refreshing teal
      case 'pizza':
      case 'burger':
      case 'pasta':
      case 'sandwich':
        return const Color(0xFFE11D48); // international bistro
      default:
        return const Color(0xFFFF6D00);
    }
  }

  static String _resolveVisualKey(String id, String? categoryId) {
    if (id.isNotEmpty && _knownKeys.contains(id)) return id;
    switch (categoryId) {
      case 'indian_meals':
        return 'dal';
      case 'fruits':
        return 'apple';
      case 'vegetables':
        return 'broccoli';
      case 'dairy':
        return 'milk';
      case 'nuts_seeds':
        return 'almond';
      case 'protein':
        return 'egg';
      case 'beverages':
        return 'tea';
      case 'international':
        return 'pasta';
      default:
        return 'generic';
    }
  }

  static const Set<String> _knownKeys = {
    'roti',
    'paratha',
    'dal',
    'rice',
    'khichdi',
    'beans',
    'paneer',
    'biryani',
    'dosa',
    'idli',
    'poha',
    'curry',
    'banana',
    'apple',
    'orange',
    'mango',
    'papaya',
    'guava',
    'watermelon',
    'grapes',
    'pineapple',
    'pomegranate',
    'potato',
    'tomato',
    'spinach',
    'broccoli',
    'carrot',
    'cucumber',
    'cauliflower',
    'beetroot',
    'onion',
    'milk',
    'curd',
    'cheese',
    'butter',
    'almond',
    'walnut',
    'peanut',
    'seeds',
    'chicken',
    'fish',
    'egg',
    'tofu',
    'tea',
    'coffee',
    'juice',
    'coconut_water',
    'pizza',
    'burger',
    'sandwich',
    'pasta',
    'oats',
    'pancake',
    'bread',
    'peanut_butter',
    'generic',
  };

  @override
  Widget build(BuildContext context) {
    final visualKey = _resolveVisualKey(illustrationId, categoryId);
    final accent = accentColorFor(illustrationId, categoryId);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(size * 0.28),
        border: Border.all(
          color: accent.withValues(alpha: 0.25),
          width: 1,
        ),
      ),
      child: CustomPaint(
        size: Size.square(size),
        painter: _FoodVectorPainter(visualKey: visualKey, accent: accent),
      ),
    );
  }
}

class _FoodVectorPainter extends CustomPainter {
  final String visualKey;
  final Color accent;

  const _FoodVectorPainter({
    required this.visualKey,
    required this.accent,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    final cy = h / 2;

    final fillPaint = Paint()..style = PaintingStyle.fill;
    final strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = (w * 0.055).clamp(1.2, 3.0);

    switch (visualKey) {
      case 'roti':
      case 'paratha':
        // Golden flatbread with sear marks
        fillPaint.color = const Color(0xFFF6C478);
        canvas.drawCircle(Offset(cx, cy), w * 0.34, fillPaint);
        strokePaint.color = const Color(0xFFB45309);
        canvas.drawCircle(Offset(cx, cy), w * 0.34, strokePaint);
        fillPaint.color = const Color(0xFFB45309);
        canvas.drawCircle(Offset(cx - w * 0.11, cy - h * 0.09), w * 0.035, fillPaint);
        canvas.drawCircle(Offset(cx + w * 0.12, cy - h * 0.04), w * 0.04, fillPaint);
        canvas.drawCircle(Offset(cx - w * 0.04, cy + h * 0.12), w * 0.035, fillPaint);
        if (visualKey == 'paratha') {
          // Triangular/layered fold accent
          strokePaint.color = const Color(0xFF92400E);
          canvas.drawLine(
            Offset(cx - w * 0.16, cy),
            Offset(cx + w * 0.16, cy),
            strokePaint,
          );
        }
        break;

      case 'dosa':
        // Crispy golden triangle cone
        final path = Path()
          ..moveTo(w * 0.2, h * 0.72)
          ..lineTo(w * 0.52, h * 0.2)
          ..lineTo(w * 0.8, h * 0.72)
          ..close();
        fillPaint.color = const Color(0xFFF5B041);
        canvas.drawPath(path, fillPaint);
        strokePaint.color = const Color(0xFFB45309);
        canvas.drawPath(path, strokePaint);
        break;

      case 'idli':
        // Two soft steamed white cakes
        fillPaint.color = const Color(0xFFF8FAFC);
        strokePaint.color = const Color(0xFFCBD5E1);
        canvas.drawOval(
          Rect.fromCenter(center: Offset(cx - w * 0.12, cy + h * 0.04), width: w * 0.38, height: h * 0.26),
          fillPaint,
        );
        canvas.drawOval(
          Rect.fromCenter(center: Offset(cx - w * 0.12, cy + h * 0.04), width: w * 0.38, height: h * 0.26),
          strokePaint,
        );
        canvas.drawOval(
          Rect.fromCenter(center: Offset(cx + w * 0.12, cy - h * 0.08), width: w * 0.38, height: h * 0.26),
          fillPaint,
        );
        canvas.drawOval(
          Rect.fromCenter(center: Offset(cx + w * 0.12, cy - h * 0.08), width: w * 0.38, height: h * 0.26),
          strokePaint,
        );
        break;

      case 'dal':
      case 'curry':
      case 'khichdi':
      case 'poha':
      case 'rice':
      case 'biryani':
      case 'beans':
      case 'oats':
        // Bowl with food & garnish
        final bowlRect = Rect.fromCenter(
          center: Offset(cx, cy + h * 0.08),
          width: w * 0.64,
          height: h * 0.44,
        );
        fillPaint.color = visualKey == 'rice'
            ? const Color(0xFFF8FAFC)
            : (visualKey == 'dal' || visualKey == 'khichdi' || visualKey == 'poha'
                ? const Color(0xFFFBBF24)
                : accent.withValues(alpha: 0.85));
        canvas.drawOval(
          Rect.fromCenter(center: Offset(cx, cy - h * 0.04), width: w * 0.56, height: h * 0.22),
          fillPaint,
        );
        fillPaint.color = const Color(0xFF475569);
        canvas.drawArc(bowlRect, 0, 3.14159, true, fillPaint);
        strokePaint.color = const Color(0xFF334155);
        canvas.drawLine(
          Offset(cx - w * 0.3, cy + h * 0.08),
          Offset(cx + w * 0.3, cy + h * 0.08),
          strokePaint,
        );
        // Green herb leaf on top
        fillPaint.color = const Color(0xFF16A34A);
        canvas.drawCircle(Offset(cx + w * 0.04, cy - h * 0.09), w * 0.045, fillPaint);
        break;

      case 'apple':
      case 'tomato':
      case 'pomegranate':
      case 'guava':
      case 'peach':
        fillPaint.color = visualKey == 'guava'
            ? const Color(0xFF4ADE80)
            : const Color(0xFFEF4444);
        canvas.drawCircle(Offset(cx, cy + h * 0.04), w * 0.27, fillPaint);
        // Leaf
        fillPaint.color = const Color(0xFF16A34A);
        canvas.drawOval(
          Rect.fromCenter(center: Offset(cx + w * 0.09, cy - h * 0.25), width: w * 0.16, height: h * 0.09),
          fillPaint,
        );
        strokePaint.color = const Color(0xFF78350F);
        canvas.drawLine(
          Offset(cx, cy - h * 0.16),
          Offset(cx - w * 0.02, cy - h * 0.29),
          strokePaint,
        );
        break;

      case 'banana':
        strokePaint.color = const Color(0xFFFACC15);
        strokePaint.strokeWidth = w * 0.14;
        final bPath = Path()
          ..moveTo(w * 0.28, h * 0.65)
          ..quadraticBezierTo(w * 0.55, h * 0.7, w * 0.72, h * 0.28);
        canvas.drawPath(bPath, strokePaint);
        strokePaint.color = const Color(0xFFCA8A04);
        strokePaint.strokeWidth = w * 0.04;
        canvas.drawLine(Offset(w * 0.72, h * 0.28), Offset(w * 0.75, h * 0.23), strokePaint);
        break;

      case 'watermelon':
        final slice = Path()
          ..moveTo(w * 0.2, h * 0.55)
          ..arcToPoint(Offset(w * 0.8, h * 0.55), radius: Radius.circular(w * 0.32), clockwise: false)
          ..close();
        fillPaint.color = const Color(0xFFEF4444);
        canvas.drawPath(slice, fillPaint);
        strokePaint.color = const Color(0xFF16A34A);
        strokePaint.strokeWidth = w * 0.07;
        canvas.drawArc(
          Rect.fromCenter(center: Offset(cx, h * 0.55), width: w * 0.6, height: h * 0.34),
          0,
          3.14159,
          false,
          strokePaint,
        );
        fillPaint.color = const Color(0xFF1E293B);
        canvas.drawCircle(Offset(cx - w * 0.08, h * 0.52), w * 0.025, fillPaint);
        canvas.drawCircle(Offset(cx + w * 0.07, h * 0.5), w * 0.025, fillPaint);
        break;

      case 'orange':
      case 'mango':
      case 'papaya':
      case 'pineapple':
        fillPaint.color = const Color(0xFFF59E0B);
        canvas.drawOval(
          Rect.fromCenter(center: Offset(cx, cy + h * 0.03), width: w * 0.5, height: h * 0.54),
          fillPaint,
        );
        fillPaint.color = const Color(0xFF16A34A);
        canvas.drawOval(
          Rect.fromCenter(center: Offset(cx + w * 0.06, cy - h * 0.26), width: w * 0.16, height: h * 0.1),
          fillPaint,
        );
        break;

      case 'grapes':
        fillPaint.color = const Color(0xFF7C3AED);
        for (final pt in [
          Offset(cx - w * 0.1, cy - h * 0.06),
          Offset(cx + w * 0.1, cy - h * 0.06),
          Offset(cx, cy + h * 0.02),
          Offset(cx - w * 0.08, cy + h * 0.12),
          Offset(cx + w * 0.08, cy + h * 0.12),
          Offset(cx, cy + h * 0.22),
        ]) {
          canvas.drawCircle(pt, w * 0.09, fillPaint);
        }
        fillPaint.color = const Color(0xFF16A34A);
        canvas.drawCircle(Offset(cx, cy - h * 0.2), w * 0.06, fillPaint);
        break;

      case 'broccoli':
      case 'spinach':
      case 'cauliflower':
      case 'cucumber':
      case 'carrot':
        if (visualKey == 'carrot') {
          final cPath = Path()
            ..moveTo(cx - w * 0.14, cy - h * 0.14)
            ..lineTo(cx + w * 0.14, cy - h * 0.14)
            ..lineTo(cx, cy + h * 0.3)
            ..close();
          fillPaint.color = const Color(0xFFF97316);
          canvas.drawPath(cPath, fillPaint);
          fillPaint.color = const Color(0xFF16A34A);
          canvas.drawCircle(Offset(cx, cy - h * 0.21), w * 0.08, fillPaint);
        } else {
          fillPaint.color = const Color(0xFF86EFAC);
          canvas.drawRect(
            Rect.fromCenter(center: Offset(cx, cy + h * 0.14), width: w * 0.14, height: h * 0.24),
            fillPaint,
          );
          fillPaint.color = visualKey == 'cauliflower'
              ? const Color(0xFFF1F5F9)
              : const Color(0xFF16A34A);
          canvas.drawCircle(Offset(cx - w * 0.12, cy - h * 0.04), w * 0.14, fillPaint);
          canvas.drawCircle(Offset(cx + w * 0.12, cy - h * 0.04), w * 0.14, fillPaint);
          canvas.drawCircle(Offset(cx, cy - h * 0.14), w * 0.16, fillPaint);
        }
        break;

      case 'milk':
      case 'curd':
      case 'paneer':
      case 'tofu':
      case 'cheese':
      case 'butter':
        if (visualKey == 'cheese' || visualKey == 'butter') {
          fillPaint.color = const Color(0xFFFACC15);
          final rect = RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset(cx, cy), width: w * 0.56, height: h * 0.38),
            Radius.circular(w * 0.06),
          );
          canvas.drawRRect(rect, fillPaint);
          fillPaint.color = const Color(0xFFEAB308);
          canvas.drawCircle(Offset(cx - w * 0.1, cy - h * 0.04), w * 0.045, fillPaint);
          canvas.drawCircle(Offset(cx + w * 0.12, cy + h * 0.06), w * 0.035, fillPaint);
        } else {
          // Glass of milk / paneer cube
          fillPaint.color = const Color(0xFFE0F2FE);
          final cup = RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset(cx, cy + h * 0.03), width: w * 0.44, height: h * 0.56),
            Radius.circular(w * 0.08),
          );
          canvas.drawRRect(cup, fillPaint);
          fillPaint.color = Colors.white;
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromCenter(center: Offset(cx, cy + h * 0.08), width: w * 0.36, height: h * 0.38),
              Radius.circular(w * 0.05),
            ),
            fillPaint,
          );
          strokePaint.color = const Color(0xFF0284C7);
          canvas.drawRRect(cup, strokePaint);
        }
        break;

      case 'egg':
        fillPaint.color = const Color(0xFFFFFBEB);
        strokePaint.color = const Color(0xFFD97706);
        canvas.drawOval(
          Rect.fromCenter(center: Offset(cx, cy), width: w * 0.44, height: h * 0.56),
          fillPaint,
        );
        canvas.drawOval(
          Rect.fromCenter(center: Offset(cx, cy), width: w * 0.44, height: h * 0.56),
          strokePaint,
        );
        fillPaint.color = const Color(0xFFF59E0B);
        canvas.drawCircle(Offset(cx, cy + h * 0.06), w * 0.12, fillPaint);
        break;

      case 'chicken':
      case 'fish':
        fillPaint.color = visualKey == 'fish'
            ? const Color(0xFF38BDF8)
            : const Color(0xFFEA580C);
        canvas.drawOval(
          Rect.fromCenter(center: Offset(cx - w * 0.04, cy), width: w * 0.5, height: h * 0.3),
          fillPaint,
        );
        final tail = Path()
          ..moveTo(cx + w * 0.16, cy)
          ..lineTo(cx + w * 0.32, cy - h * 0.14)
          ..lineTo(cx + w * 0.32, cy + h * 0.14)
          ..close();
        canvas.drawPath(tail, fillPaint);
        break;

      case 'tea':
      case 'coffee':
      case 'juice':
      case 'coconut_water':
        // Cup with handle + steam
        fillPaint.color = accent;
        final mug = RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(cx - w * 0.04, cy + h * 0.08), width: w * 0.44, height: h * 0.42),
          Radius.circular(w * 0.08),
        );
        canvas.drawRRect(mug, fillPaint);
        strokePaint.color = accent;
        canvas.drawCircle(Offset(cx + w * 0.22, cy + h * 0.08), w * 0.09, strokePaint);
        strokePaint.color = const Color(0xFF94A3B8);
        canvas.drawLine(Offset(cx - w * 0.1, cy - h * 0.18), Offset(cx - w * 0.1, cy - h * 0.28), strokePaint);
        canvas.drawLine(Offset(cx + w * 0.04, cy - h * 0.18), Offset(cx + w * 0.04, cy - h * 0.3), strokePaint);
        break;

      case 'almond':
      case 'walnut':
      case 'peanut':
      case 'seeds':
      case 'peanut_butter':
        fillPaint.color = const Color(0xFFB45309);
        canvas.drawOval(
          Rect.fromCenter(center: Offset(cx - w * 0.08, cy + h * 0.02), width: w * 0.28, height: h * 0.44),
          fillPaint,
        );
        fillPaint.color = const Color(0xFFD97706);
        canvas.drawOval(
          Rect.fromCenter(center: Offset(cx + w * 0.12, cy - h * 0.04), width: w * 0.24, height: h * 0.36),
          fillPaint,
        );
        break;

      case 'pizza':
        final slice = Path()
          ..moveTo(w * 0.24, h * 0.24)
          ..lineTo(w * 0.78, h * 0.42)
          ..lineTo(w * 0.38, h * 0.78)
          ..close();
        fillPaint.color = const Color(0xFFFACC15);
        canvas.drawPath(slice, fillPaint);
        strokePaint.color = const Color(0xFFB45309);
        canvas.drawLine(Offset(w * 0.24, h * 0.24), Offset(w * 0.78, h * 0.42), strokePaint);
        fillPaint.color = const Color(0xFFEF4444);
        canvas.drawCircle(Offset(w * 0.45, h * 0.45), w * 0.055, fillPaint);
        canvas.drawCircle(Offset(w * 0.56, h * 0.52), w * 0.045, fillPaint);
        break;

      case 'burger':
      case 'sandwich':
      case 'bread':
      case 'pancake':
        fillPaint.color = const Color(0xFFF59E0B);
        canvas.drawArc(
          Rect.fromCenter(center: Offset(cx, cy - h * 0.02), width: w * 0.56, height: h * 0.36),
          3.14159,
          3.14159,
          true,
          fillPaint,
        );
        fillPaint.color = const Color(0xFF16A34A);
        canvas.drawRect(Rect.fromCenter(center: Offset(cx, cy + h * 0.03), width: w * 0.58, height: h * 0.07), fillPaint);
        fillPaint.color = const Color(0xFF78350F);
        canvas.drawRect(Rect.fromCenter(center: Offset(cx, cy + h * 0.1), width: w * 0.54, height: h * 0.09), fillPaint);
        fillPaint.color = const Color(0xFFF59E0B);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset(cx, cy + h * 0.2), width: w * 0.56, height: h * 0.1),
            Radius.circular(w * 0.04),
          ),
          fillPaint,
        );
        break;

      default:
        // Balanced plate fallback icon
        strokePaint.color = accent;
        canvas.drawCircle(Offset(cx, cy), w * 0.32, strokePaint);
        fillPaint.color = accent.withValues(alpha: 0.25);
        canvas.drawCircle(Offset(cx, cy), w * 0.22, fillPaint);
        fillPaint.color = accent;
        canvas.drawCircle(Offset(cx, cy), w * 0.08, fillPaint);
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _FoodVectorPainter oldDelegate) {
    return oldDelegate.visualKey != visualKey || oldDelegate.accent != accent;
  }
}

