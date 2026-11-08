import 'package:flutter/material.dart';
import 'theme_colors.dart';

class ThemePresets {
  ThemePresets._();

  static const ThemeColorPalette softLight = ThemeColorPalette(
    id: 'soft_light',
    name: 'Soft Light',
    background: Color(0xFFE8EDF4),
    surface: Color(0xFFE8EDF4),
    accent: Color(0xFF6C8EFF),
    text: Color(0xFF30394D),
    secondaryText: Color(0xFF8490A5),
    isDark: false,
  );

  static const ThemeColorPalette pureWhite = ThemeColorPalette(
    id: 'pure_white',
    name: 'Pure White',
    background: Color(0xFFF7F8FA),
    surface: Color(0xFFFFFFFF),
    accent: Color(0xFF5277E8),
    text: Color(0xFF252B38),
    secondaryText: Color(0xFF9299A7),
    isDark: false,
  );

  static const ThemeColorPalette midnightDark = ThemeColorPalette(
    id: 'midnight_dark',
    name: 'Midnight Dark',
    background: Color(0xFF202431),
    surface: Color(0xFF202431),
    accent: Color(0xFF829BFF),
    text: Color(0xFFF0F2FA),
    secondaryText: Color(0xFF929BB1),
    isDark: true,
  );

  static const ThemeColorPalette lavender = ThemeColorPalette(
    id: 'lavender',
    name: 'Lavender',
    background: Color(0xFFEFECF8),
    surface: Color(0xFFEFECF8),
    accent: Color(0xFF9679DC),
    text: Color(0xFF38334D),
    secondaryText: Color(0xFF9690AA),
    isDark: false,
  );

  static const ThemeColorPalette mint = ThemeColorPalette(
    id: 'mint',
    name: 'Mint',
    background: Color(0xFFE8F3EF),
    surface: Color(0xFFE8F3EF),
    accent: Color(0xFF45A98B),
    text: Color(0xFF29443D),
    secondaryText: Color(0xFF849E94),
    isDark: false,
  );

  static const ThemeColorPalette warmSand = ThemeColorPalette(
    id: 'warm_sand',
    name: 'Warm Sand',
    background: Color(0xFFF2EDE5),
    surface: Color(0xFFF2EDE5),
    accent: Color(0xFFD58D58),
    text: Color(0xFF483B32),
    secondaryText: Color(0xFFA29487),
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
