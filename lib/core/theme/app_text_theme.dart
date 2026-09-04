import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

/// VYEA typography — clean, editorial and quietly premium.
///
/// The hierarchy uses strong charcoal headlines, softer supporting copy and
/// restrained tracking for labels so the interface feels like a fashion
/// product rather than a generic AI dashboard.
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
        letterSpacing: -0.8,
        height: 1.12,
      ),
      headlineLarge: TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        color: primary,
        letterSpacing: -0.65,
        height: 1.15,
      ),
      headlineMedium: TextStyle(
        fontSize: 26,
        fontWeight: FontWeight.w700,
        color: primary,
        letterSpacing: -0.45,
        height: 1.18,
      ),
      titleLarge: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w650,
        color: primary,
        letterSpacing: -0.25,
        height: 1.2,
      ),
      titleMedium: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: primary,
        letterSpacing: -0.1,
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
        height: 1.45,
      ),
      labelLarge: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: onPrimary,
        letterSpacing: 0.05,
      ),
      labelMedium: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: secondary,
        letterSpacing: 0.55,
      ),
      labelSmall: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        color: muted,
        letterSpacing: 0.7,
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
