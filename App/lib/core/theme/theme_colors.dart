import 'package:flutter/material.dart';

class ThemeColorPalette {
  final String id;
  final String name;
  final Color background;
  final Color surface;
  final Color cardBorder;
  final Color accent;
  final Color text;
  final Color secondaryText;
  final bool isDark;

  const ThemeColorPalette({
    required this.id,
    required this.name,
    required this.background,
    required this.surface,
    required this.cardBorder,
    required this.accent,
    required this.text,
    required this.secondaryText,
    this.isDark = false,
  });
}
