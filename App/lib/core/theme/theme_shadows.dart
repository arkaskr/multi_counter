import 'package:flutter/material.dart';

class ThemeShadows {
  ThemeShadows._();

  /// Clean, modern, subtle card shadow for solid elevated cards
  static List<BoxShadow> raised({
    required Color surface,
    required bool isDark,
    double elevation = 1.0,
    double blur = 8.0,
    double distance = 2.0,
  }) {
    if (elevation <= 0) return const [];

    if (isDark) {
      return [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.22 * elevation.clamp(0.5, 1.5)),
          offset: Offset(0, distance * elevation),
          blurRadius: blur * elevation,
          spreadRadius: 0,
        ),
      ];
    } else {
      return [
        BoxShadow(
          color: const Color(0xFF141E30).withValues(alpha: 0.05 * elevation.clamp(0.5, 1.5)),
          offset: Offset(0, distance * elevation),
          blurRadius: blur * elevation,
          spreadRadius: 0,
        ),
      ];
    }
  }

  /// Flat feedback for pressed state (no beveled / sunken shadow)
  static List<BoxShadow> pressed({
    required Color surface,
    required bool isDark,
    double distance = 0.0,
  }) {
    return const [];
  }

  /// Subtle elevation shadow for primary action buttons
  static List<BoxShadow> accentGlow({
    required Color accent,
    double intensity = 0.25,
  }) {
    return [
      BoxShadow(
        color: accent.withValues(alpha: intensity),
        offset: const Offset(0, 3),
        blurRadius: 8,
        spreadRadius: 0,
      ),
    ];
  }
}
