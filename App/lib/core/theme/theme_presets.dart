import 'package:flutter/material.dart';
import 'theme_colors.dart';

class ThemePresets {
  ThemePresets._();

  static const ThemeColorPalette softLight = ThemeColorPalette(
    id: 'soft_light',
    name: 'Soft Light',
    background: Color(0xFFF0F3F9),
    surface: Color(0xFFFFFFFF),
    cardBorder: Color(0xFFDFE4ED),
    accent: Color(0xFF5375F6),
    text: Color(0xFF1C2434),
    secondaryText: Color(0xFF6E7C94),
    isDark: false,
  );

  static const ThemeColorPalette pureWhite = ThemeColorPalette(
    id: 'pure_white',
    name: 'Pure White',
    background: Color(0xFFF6F8FC),
    surface: Color(0xFFFFFFFF),
    cardBorder: Color(0xFFE2E7F0),
    accent: Color(0xFF4A6CF7),
    text: Color(0xFF1A202C),
    secondaryText: Color(0xFF718096),
    isDark: false,
  );

  static const ThemeColorPalette midnightDark = ThemeColorPalette(
    id: 'midnight_dark',
    name: 'Midnight Dark',
    background: Color(0xFF161822),
    surface: Color(0xFF222634),
    cardBorder: Color(0xFF2C3246),
    accent: Color(0xFF7E97FF),
    text: Color(0xFFFFFFFF),
    secondaryText: Color(0xFF949EB2),
    isDark: true,
  );

  static const ThemeColorPalette lavender = ThemeColorPalette(
    id: 'lavender',
    name: 'Lavender',
    background: Color(0xFFF5F3FA),
    surface: Color(0xFFFFFFFF),
    cardBorder: Color(0xFFE5DFEE),
    accent: Color(0xFF7B57DE),
    text: Color(0xFF2A223B),
    secondaryText: Color(0xFF7B7293),
    isDark: false,
  );

  static const ThemeColorPalette mint = ThemeColorPalette(
    id: 'mint',
    name: 'Mint',
    background: Color(0xFFF0F7F4),
    surface: Color(0xFFFFFFFF),
    cardBorder: Color(0xFFD6EAE1),
    accent: Color(0xFF229A72),
    text: Color(0xFF1A332B),
    secondaryText: Color(0xFF69897E),
    isDark: false,
  );

  static const ThemeColorPalette warmSand = ThemeColorPalette(
    id: 'warm_sand',
    name: 'Warm Sand',
    background: Color(0xFFF9F6F1),
    surface: Color(0xFFFFFFFF),
    cardBorder: Color(0xFFE8DFD3),
    accent: Color(0xFFBF6F36),
    text: Color(0xFF382A20),
    secondaryText: Color(0xFF88796C),
    isDark: false,
  );

  static const List<ThemeColorPalette> allThemes = [
    softLight,
    pureWhite,
    midnightDark,
    lavender,
    mint,
    warmSand,
  ];

  static ThemeColorPalette getById(String id) {
    return allThemes.firstWhere(
      (theme) => theme.id == id,
      orElse: () => midnightDark,
    );
  }
}
