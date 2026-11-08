import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/theme_colors.dart';
import '../../core/theme/theme_shadows.dart';

class NeumorphicThemeCard extends StatelessWidget {
  final ThemeColorPalette palette;
  final bool isSelected;
  final VoidCallback onTap;

  const NeumorphicThemeCard({
    super.key,
    required this.palette,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: isSelected
              ? [
                  ...ThemeShadows.raised(
                    surface: palette.surface,
                    isDark: palette.isDark,
                    elevation: 1.2,
                  ),
                  BoxShadow(
                    color: palette.accent.withValues(alpha: 0.4),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ]
              : ThemeShadows.raised(
                  surface: palette.surface,
                  isDark: palette.isDark,
                  elevation: 0.8,
                ),
          border: Border.all(
            color: isSelected ? palette.accent : Colors.transparent,
            width: 2.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Theme Name + Checkmark / Selection indicator
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  palette.name,
                  style: TextStyle(
                    color: palette.text,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: isSelected ? palette.accent : palette.surface,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? palette.accent : palette.secondaryText.withValues(alpha: 0.4),
                      width: 1.5,
                    ),
                  ),
                  child: isSelected
                      ? const Icon(
                          Icons.check_rounded,
                          size: 16,
                          color: Colors.white,
                        )
                      : null,
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Mini Counter Preview Box
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: palette.background,
                borderRadius: BorderRadius.circular(14),
                boxShadow: ThemeShadows.pressed(
                  surface: palette.background,
                  isDark: palette.isDark,
                  distance: 2,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '1 / 2',
                        style: TextStyle(
                          color: palette.text,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '₹45',
                        style: TextStyle(
                          color: palette.accent,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  // Miniature +1 button
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: palette.accent,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: palette.accent.withValues(alpha: 0.35),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Text(
                      '+1',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Color Palette Dots
            Row(
              children: [
                _buildColorDot(palette.background, 'BG'),
                const SizedBox(width: 6),
                _buildColorDot(palette.accent, 'Accent'),
                const SizedBox(width: 6),
                _buildColorDot(palette.text, 'Text'),
                const SizedBox(width: 6),
                _buildColorDot(palette.secondaryText, 'Sec'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildColorDot(Color color, String tooltip) {
    return Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.black12, width: 0.8),
      ),
    );
  }
}
