import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

/// TiB AI Personal Styling typography.
///
/// Built from a brightness-aware [_build], with [light] and [dark] as
/// the two concrete themes `LightTheme`/`DarkTheme` consume. The type
/// sizes, weights and letter-spacing (the actual "typography" -- an
/// editorial feel with subtle negative letter-spacing on headline-level
/// text, default spacing on body text for readability, deliberately
/// varied weights) are identical in both -- only the colours change.
///
/// [labelLarge] (button/label text drawn on top of the primary accent)
/// is brightness-aware -- in light theme the primary accent is Dark
/// Navy, so its label is White; in dark theme the primary accent is
/// White, so its label is the dark navy background colour.
class AppTextTheme {
  AppTextTheme._();

  static TextTheme _build({
    required Color primary,
    required Color secondary,
    required Color muted,
    required Color onPrimary,
  }) {
    return TextTheme(
      displaySmall: TextStyle(
        fontSize: 36,
        fontWeight: FontWeight.w700,
        color: primary,
        letterSpacing: -0.6,
        height: 1.15,
      ),

      headlineLarge: TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        color: primary,
        letterSpacing: -0.5,
      ),

      headlineMedium: TextStyle(
        fontSize: 26,
        fontWeight: FontWeight.w700,
        color: primary,
        letterSpacing: -0.4,
      ),

      titleLarge: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: primary,
        letterSpacing: -0.2,
      ),

      titleMedium: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: primary,
      ),

      titleSmall: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: primary,
      ),

      bodyLarge: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: primary,
        height: 1.5,
      ),

      bodyMedium: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: secondary,
        height: 1.5,
      ),

      bodySmall: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: muted,
        height: 1.4,
      ),

      labelLarge: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: onPrimary,
      ),

      labelMedium: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: secondary,
        letterSpacing: 0.2,
      ),
    );
  }

  static final TextTheme light = _build(
    primary: AppColors.textPrimary,
    secondary: AppColors.textSecondary,
    muted: AppColors.textMuted,
    onPrimary: AppColors.background,
  );

  static final TextTheme dark = _build(
    primary: AppColorsDark.textPrimary,
    secondary: AppColorsDark.textSecondary,
    muted: AppColorsDark.textMuted,
    onPrimary: AppColorsDark.background,
  );
}
