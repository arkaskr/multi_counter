import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_theme.dart';
import 'neumorphic_container.dart';

class NeumorphicInput extends StatelessWidget {
  final TextEditingController? controller;
  final String? hintText;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final String? prefixText;
  final String? suffixText;
  final TextInputType keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged;
  final bool readOnly;
  final bool autofocus;
  final TextAlign textAlign;
  final TextStyle? style;
  final TextStyle? hintStyle;

  const NeumorphicInput({
    super.key,
    this.controller,
    this.hintText,
    this.hintStyle,
    this.prefixIcon,
    this.suffixIcon,
    this.prefixText,
    this.suffixText,
    this.keyboardType = TextInputType.text,
    this.inputFormatters,
    this.onChanged,
    this.readOnly = false,
    this.autofocus = false,
    this.textAlign = TextAlign.start,
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.appTheme;

    final inputBg = theme.isDark
        ? const Color(0xFF1A1D28)
        : const Color(0xFFF3F5FA);

    return Container(
      decoration: BoxDecoration(
        color: inputBg,
        borderRadius: BorderRadius.circular(14.0),
        border: Border.all(
          color: theme.cardBorder,
          width: 1.0,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: TextField(
        controller: controller,
        readOnly: readOnly,
        autofocus: autofocus,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        onChanged: onChanged,
        textAlign: textAlign,
        style: style ??
            TextStyle(
              color: theme.text,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
        cursorColor: theme.accent,
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: hintText,
          hintStyle: hintStyle ??
              TextStyle(
                color: theme.secondaryText.withValues(alpha: 0.7),
                fontSize: 14,
                fontWeight: FontWeight.normal,
              ),
          prefixIcon: prefixIcon,
          suffixIcon: suffixIcon,
          prefixText: prefixText,
          prefixStyle: TextStyle(
            color: theme.text,
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
          suffixText: suffixText,
          suffixStyle: TextStyle(
            color: theme.secondaryText,
            fontSize: 13,
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }
}
