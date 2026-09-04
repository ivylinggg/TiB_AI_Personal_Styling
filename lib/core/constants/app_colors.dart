import 'package:flutter/material.dart';

/// VYEA visual system — modern, editorial, refined and human.
///
/// The product UI stays intentionally neutral and restrained so the user's
/// personal colours, outfits and analysis results remain the visual focus.
/// Four-season colours are reserved for analysis-specific surfaces.
class AppColors {
  AppColors._();

  // Core VYEA neutrals
  static const Color ivory = Color(0xFFF8F6F2);
  static const Color white = Color(0xFFFFFFFF);
  static const Color primary = Color(0xFF252321);
  static const Color primaryDark = Color(0xFF171614);
  static const Color primarySoft = Color(0xFFE8E3DB);
  static const Color secondary = Color(0xFFE8E3DB);
  static const Color lavenderMist = Color(0xFFF1EEE9);
  static const Color blush = Color(0xFFE9D7CE);
  static const Color peach = Color(0xFFD9B8A6);
  static const Color sage = Color(0xFFB9B9A9);
  static const Color taupe = Color(0xFF817A72);
  static const Color brown = Color(0xFF806247);
  static const Color charcoal = Color(0xFF252321);
  static const Color textPrimary = charcoal;
  static const Color textSecondary = Color(0xFF6E6963);
  static const Color textMuted = Color(0xFF9A948D);
  static const Color background = ivory;
  static const Color surface = white;
  static const Color surfaceMuted = Color(0xFFF2EFEA);
  static const Color border = Color(0xFFE1DCD4);

  // AI styling uses the same restrained editorial language rather than
  // introducing a separate bright "AI" colour.
  static const Color aiAccent = Color(0xFF806247);
  static const Color aiAccentDark = Color(0xFF604832);
  static const Color aiAccentLight = Color(0xFFF1EAE3);

  // Premium remains understated and luxury-inspired.
  static const Color premiumAccent = Color(0xFF8B6A43);
  static const Color premiumAccentLight = Color(0xFFF2EBE1);
  static const Color premiumAccentDark = Color(0xFF654A2D);

  static const Color success = Color(0xFF71866A);
  static const Color warning = Color(0xFFB48650);
  static const Color error = Color(0xFFB96767);

  /// Legacy compatibility token. Older screens used `eggYolk` for the
  /// warm action colour. Keep the name temporarily while the UI migrates.
  static const Color eggYolk = peach;

  /// Four-season colours are intentionally kept more expressive because
  /// they communicate the user's personal colour analysis.
  static const Map<String, Color> seasonAccents = {
    'Winter': Color(0xFF4D63A0),
    'Summer': Color(0xFF8D68B4),
    'Spring': Color(0xFFD58A4D),
    'Autumn': Color(0xFF9B5A38),

    // Legacy aliases kept for older saved analyses.
    'Warm Spring': Color(0xFFE49A69),
    'Warm Autumn': Color(0xFFB86E4B),
    'Cool Summer': Color(0xFF9AA6C6),
    'Cool Winter': Color(0xFF68739B),
    'Clear Winter': Color(0xFF7E6BAA),
    'Soft Summer': Color(0xFFB39AC2),
    'Soft Autumn': Color(0xFFA98D6E),
  };

  static Color seasonAccent(String? season) => seasonAccents[season] ?? primary;
}

class AppColorsDark {
  AppColorsDark._();

  static const Color primary = Color(0xFFF0ECE5);
  static const Color primaryDark = Color(0xFFFFFFFF);
  static const Color secondary = Color(0xFF3A3530);
  static const Color background = Color(0xFF1C1A18);
  static const Color surface = Color(0xFF272421);
  static const Color surfaceMuted = Color(0xFF332F2A);
  static const Color border = Color(0xFF48423B);
  static const Color textPrimary = Color(0xFFF8F5EF);
  static const Color textSecondary = Color(0xFFD0C9C0);
  static const Color textMuted = Color(0xFF9E978E);
}
