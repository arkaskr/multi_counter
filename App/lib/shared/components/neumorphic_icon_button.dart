import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_shadows.dart';

class NeumorphicIconButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final double size;
  final double iconSize;
  final Color? iconColor;
  final Color? backgroundColor;
  final bool isCircle;
  final double borderRadius;
  final bool isActive;
  final bool isEnabled;
  final String? tooltip;

  const NeumorphicIconButton({
    super.key,
    required this.icon,
    this.onTap,
    this.size = 48.0,
    this.iconSize = 22.0,
    this.iconColor,
    this.backgroundColor,
    this.isCircle = true,
    this.borderRadius = 16.0,
    this.isActive = false,
    this.isEnabled = true,
    this.tooltip,
  });

  @override
  State<NeumorphicIconButton> createState() => _NeumorphicIconButtonState();
}

class _NeumorphicIconButtonState extends State<NeumorphicIconButton> {
  bool _isPressed = false;

  void _handleTapDown(TapDownDetails details) {
    if (!widget.isEnabled || widget.onTap == null) return;
    HapticFeedback.lightImpact();
    setState(() => _isPressed = true);
  }

  void _handleTapUp(TapUpDetails details) {
    if (!widget.isEnabled || widget.onTap == null) return;
    setState(() => _isPressed = false);
    widget.onTap?.call();
  }

  void _handleTapCancel() {
    if (!widget.isEnabled) return;
    setState(() => _isPressed = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.appTheme;
    final baseColor = widget.backgroundColor ?? theme.surface;

    List<BoxShadow> shadows;
    if (!widget.isEnabled || _isPressed) {
      shadows = const [];
    } else {
      shadows = ThemeShadows.raised(
        surface: baseColor,
        isDark: theme.isDark,
        elevation: 0.6,
      );
    }

    final effectiveBorder = Border.all(
      color: widget.isActive ? theme.accent : theme.cardBorder,
      width: 1.0,
    );

    final buttonWidget = GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: _isPressed ? 0.94 : 1.0,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOutCubic,
        child: AnimatedOpacity(
          opacity: widget.isEnabled ? 1.0 : 0.4,
          duration: const Duration(milliseconds: 120),
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              color: widget.isActive ? theme.accent.withValues(alpha: 0.15) : baseColor,
              shape: widget.isCircle ? BoxShape.circle : BoxShape.rectangle,
              borderRadius: widget.isCircle ? null : BorderRadius.circular(widget.borderRadius),
              boxShadow: shadows,
              border: effectiveBorder,
            ),
            child: Icon(
              widget.icon,
              size: widget.iconSize,
              color: widget.isActive
                  ? theme.accent
                  : (widget.iconColor ?? theme.text),
            ),
          ),
        ),
      ),
    );

    if (widget.tooltip != null) {
      return Tooltip(
        message: widget.tooltip!,
        child: buttonWidget,
      );
    }

    return buttonWidget;
  }
}
