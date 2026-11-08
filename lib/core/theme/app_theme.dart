import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'theme_colors.dart';
import 'theme_presets.dart';

@immutable
class AppThemeData extends ThemeExtension<AppThemeData> {
  final String id;
  final String name;
  final Color background;
  final Color surface;
  final Color accent;
  final Color text;
  final Color secondaryText;
  final bool isDark;

  const AppThemeData({
    required this.id,
    required this.name,
    required this.background,
    required this.surface,
    required this.accent,
    required this.text,
    required this.secondaryText,
    required this.isDark,
  });

  factory AppThemeData.fromPalette(ThemeColorPalette palette) {
    return AppThemeData(
      id: palette.id,
      name: palette.name,
      background: palette.background,
      surface: palette.surface,
      accent: palette.accent,
      text: palette.text,
      secondaryText: palette.secondaryText,
      isDark: palette.isDark,
    );
  }

  @override
  AppThemeData copyWith({
    String? id,
    String? name,
    Color? background,
    Color? surface,
    Color? accent,
    Color? text,
    Color? secondaryText,
    bool? isDark,
  }) {
    return AppThemeData(
      id: id ?? this.id,
      name: name ?? this.name,
      background: background ?? this.background,
      surface: surface ?? this.surface,
      accent: accent ?? this.accent,
      text: text ?? this.text,
      secondaryText: secondaryText ?? this.secondaryText,
      isDark: isDark ?? this.isDark,
    );
  }

  @override
  AppThemeData lerp(ThemeExtension<AppThemeData>? other, double t) {
    if (other is! AppThemeData) return this;
    return AppThemeData(
      id: t < 0.5 ? id : other.id,
      name: t < 0.5 ? name : other.name,
      background: Color.lerp(background, other.background, t) ?? background,
      surface: Color.lerp(surface, other.surface, t) ?? surface,
      accent: Color.lerp(accent, other.accent, t) ?? accent,
      text: Color.lerp(text, other.text, t) ?? text,
      secondaryText: Color.lerp(secondaryText, other.secondaryText, t) ?? secondaryText,
      isDark: t < 0.5 ? isDark : other.isDark,
    );
  }

  static bool useGoogleFonts = true;

  /// Create Flutter ThemeData from AppThemeData
  ThemeData toThemeData() {
    TextTheme textTheme;
    if (useGoogleFonts) {
      try {
        textTheme = GoogleFonts.outfitTextTheme().apply(
          bodyColor: text,
          displayColor: text,
        );
      } catch (_) {
        textTheme = ThemeData.fallback().textTheme.apply(
          bodyColor: text,
          displayColor: text,
        );
      }
    } else {
      textTheme = ThemeData.fallback().textTheme.apply(
        bodyColor: text,
        displayColor: text,
      );
    }

    return ThemeData(
      useMaterial3: true,
      brightness: isDark ? Brightness.dark : Brightness.light,
      scaffoldBackgroundColor: background,
      colorScheme: ColorScheme(
        brightness: isDark ? Brightness.dark : Brightness.light,
        primary: accent,
        onPrimary: Colors.white,
        secondary: accent,
        onSecondary: Colors.white,
        error: Colors.redAccent,
        onError: Colors.white,
        surface: surface,
        onSurface: text,
      ),
      textTheme: textTheme,
      extensions: [this],
    );
  }
}

extension AppThemeContext on BuildContext {
  AppThemeData get appTheme {
    final ext = Theme.of(this).extension<AppThemeData>();
    if (ext == null) {
      return AppThemeData.fromPalette(ThemePresets.softLight);
    }
    return ext;
  }
}
