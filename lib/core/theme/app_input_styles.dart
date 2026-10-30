import 'package:flutter/material.dart';

/// Centralized input decorations to avoid repeating OutlineInputBorder and colors.
class AppInputStyles {
  static InputDecoration outline({
    String? hintText,
    String? prefixText,
    Widget? suffixIcon,
    double borderRadius = 8,
    EdgeInsetsGeometry contentPadding = const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    TextStyle? hintStyle,
  }) {
    return InputDecoration(
      hintText: hintText,
      prefixText: prefixText,
      suffixIcon: suffixIcon,
      prefixStyle: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF64748B), fontSize: 13),
      hintStyle: hintStyle ?? const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
      filled: true,
      fillColor: Colors.white,
      contentPadding: contentPadding,
      isDense: true,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(borderRadius),
        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(borderRadius),
        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(borderRadius),
        borderSide: const BorderSide(color: Color(0xFF1565C0), width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(borderRadius),
        borderSide: const BorderSide(color: Color(0xFFEF4444)),
      ),
      errorStyle: const TextStyle(fontSize: 10.5, height: 1.1),
    );
  }

  static InputDecoration compact({
    String? hintText,
    Widget? suffixIcon,
    double borderRadius = 4,
  }) {
    return outline(
      hintText: hintText,
      suffixIcon: suffixIcon,
      borderRadius: borderRadius,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      hintStyle: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontWeight: FontWeight.normal),
    );
  }
}

