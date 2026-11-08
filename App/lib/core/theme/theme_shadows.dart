import 'package:flutter/material.dart';

class ThemeShadows {
  ThemeShadows._();

  /// Generates soft neomorphic shadows for raised components
  static List<BoxShadow> raised({
    required Color surface,
    required bool isDark,
    double elevation = 1.0,
    double blur = 12.0,
    double distance = 5.0,
  }) {
    final d = distance * elevation;
    final b = blur * elevation;

    if (isDark) {
      return [
        // Top-left highlight
        BoxShadow(
          color: const Color(0xFF2C3246).withValues(alpha: 0.6),
          offset: Offset(-d, -d),
          blurRadius: b,
          spreadRadius: 0,
        ),
        // Bottom-right depth shadow
        BoxShadow(
          color: const Color(0xFF10121A).withValues(alpha: 0.85),
          offset: Offset(d, d),
          blurRadius: b,
          spreadRadius: 0,
        ),
      ];
    } else {
      return [
        // Top-left light highlight
        BoxShadow(
          color: Colors.white.withValues(alpha: 0.85),
          offset: Offset(-d, -d),
          blurRadius: b,
          spreadRadius: 0,
        ),
        // Bottom-right soft depth shadow
        BoxShadow(
          color: const Color(0xFFA3B1C6).withValues(alpha: 0.45),
          offset: Offset(d, d),
          blurRadius: b,
          spreadRadius: 0,
        ),
      ];
    }
  }

  /// Generates pressed / sunken shadows
  static List<BoxShadow> pressed({
    required Color surface,
    required bool isDark,
    double distance = 3.0,
  }) {
    if (isDark) {
      return [
        BoxShadow(
          color: const Color(0xFF10121A).withValues(alpha: 0.9),
          offset: Offset(distance, distance),
          blurRadius: distance * 2,
          spreadRadius: 0,
        ),
      ];
    } else {
      return [
        BoxShadow(
          color: const Color(0xFFA3B1C6).withValues(alpha: 0.5),
          offset: Offset(distance, distance),
          blurRadius: distance * 2,
          spreadRadius: 0,
        ),
      ];
    }
  }

  /// Accent glow shadow for prominent buttons (+1 button)
  static List<BoxShadow> accentGlow({
    required Color accent,
    double intensity = 0.4,
  }) {
    return [
      BoxShadow(
        color: accent.withValues(alpha: intensity),
        offset: const Offset(0, 6),
        blurRadius: 18,
        spreadRadius: 1,
      ),
    ];
  }
}
