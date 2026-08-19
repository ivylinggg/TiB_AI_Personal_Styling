import 'package:flutter/material.dart';

/// TiB visual system — warm, soft, editorial and human.
/// Ivory backgrounds, soft lavender interaction colour, peach/blush warmth,
/// muted sage, warm taupe and charcoal text.
class AppColors {
  AppColors._();

  static const Color ivory = Color(0xFFFCFAF8);
  static const Color white = Color(0xFFFFFFFF);
  static const Color primary = Color(0xFF9B7BD1);
  static const Color primaryDark = Color(0xFF7557AD);
  static const Color primarySoft = Color(0xFFE9DFF7);
  static const Color secondary = primarySoft;
  static const Color lavenderMist = Color(0xFFF2ECF9);
  static const Color blush = Color(0xFFF5D2C2);
  static const Color peach = Color(0xFFF2B9A1);
  static const Color sage = Color(0xFFB8C0A4);
  static const Color taupe = Color(0xFF81766E);
  static const Color brown = Color(0xFF8C5D49);
  static const Color charcoal = Color(0xFF29252A);
  static const Color textPrimary = charcoal;
  static const Color textSecondary = Color(0xFF6F686D);
  static const Color textMuted = Color(0xFF9D969B);
  static const Color background = ivory;
  static const Color surface = white;
  static const Color surfaceMuted = Color(0xFFF6F1EE);
  static const Color border = Color(0xFFE8E1DE);

  static const Color aiAccent = primary;
  static const Color aiAccentDark = primaryDark;
  static const Color aiAccentLight = lavenderMist;

  static const Color premiumAccent = Color(0xFF8D72C5);
  static const Color premiumAccentLight = Color(0xFFF0E9F8);
  static const Color premiumAccentDark = primaryDark;

  static const Color success = Color(0xFF78936B);
  static const Color warning = Color(0xFFD19A5A);
  static const Color error = Color(0xFFC96E6E);

  static const Map<String, Color> seasonAccents = {
    'Warm Spring': Color(0xFFE49A69),
    'Warm Autumn': Color(0xFFB86E4B),
    'Cool Summer': Color(0xFF9AA6C6),
    'Cool Winter': Color(0xFF68739B),
    'Clear Winter': Color(0xFF7E6BAA),
    'Soft Summer': Color(0xFFB39AC2),
    'Soft Autumn': Color(0xFFA98D6E),
  };

  static Color seasonAccent(String? season) =>
      seasonAccents[season] ?? primary;
}

class AppColorsDark {
  AppColorsDark._();

  static const Color primary = Color(0xFFC4A9E7);
  static const Color primaryDark = Color(0xFFA98BD1);
  static const Color secondary = Color(0xFFE7DDF1);
  static const Color background = Color(0xFF211E23);
  static const Color surface = Color(0xFF2B272D);
  static const Color surfaceMuted = Color(0xFF37313A);
  static const Color border = Color(0xFF4A424D);
  static const Color textPrimary = Color(0xFFFFFBFF);
  static const Color textSecondary = Color(0xFFD5CED8);
  static const Color textMuted = Color(0xFFA59EA8);
}
