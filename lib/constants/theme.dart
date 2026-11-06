import 'package:flutter/material.dart';

/// Social Googol Official Design Tokens
/// Directly mapped from https://www.socialgoogol.com/assets/css/main.css
class SGTheme {
  // Backgrounds & Surfaces (Warm Earth - Dark Mode)
  static const Color bgDark = Color(0xFF171310);
  static const Color bgSubtle = Color(0xFF1C1712);
  static const Color bgInset = Color(0xFF26201A);
  static const Color surface = Color(0xFF1F1913);
  static const Color surfaceHover = Color(0xFF2A221A);
  static const Color logoTileDark = Color(0xFF231A12);

  // Typography
  static const Color text = Color(0xFFF2ECE1);
  static const Color textSecondary = Color(0xFFC9BDA9);
  static const Color textMuted = Color(0xFF9A8D7A);

  // Accents (Terracotta Rust & Amber)
  static const Color accent = Color(0xFFDD8B53);
  static const Color accentDeep = Color(0xFFB04A24);
  static const Color accentHover = Color(0xFFEBA46B);
  static const Color accentSoft = Color(0x1ADD8B53);
  static const Color accentBorder = Color(0x40DD8B53);

  // Status & Success
  static const Color positive = Color(0xFF4F7A4A);
  static const Color positiveSoft = Color(0x1A4F7A4A);
  static const Color warning = Color(0xFFA26A12);

  // Borders & Dividers
  static const Color border = Color(0x17F0E8DC);
  static const Color borderStrong = Color(0x2EF0E8DC);

  static ThemeData get themeData {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: bgDark,
      primaryColor: accent,
      fontFamily: 'Roboto',
      appBarTheme: const AppBarTheme(
        backgroundColor: surface,
        elevation: 0,
        titleTextStyle: TextStyle(
          color: text,
          fontSize: 17,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.3,
        ),
        iconTheme: IconThemeData(color: text),
      ),
      colorScheme: const ColorScheme.dark(
        primary: accent,
        secondary: accentHover,
        surface: surface,
        background: bgDark,
        onSurface: text,
        onBackground: text,
      ),
      dividerColor: border,
    );
  }
}
