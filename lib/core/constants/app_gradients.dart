import 'package:flutter/material.dart';
import 'app_colors.dart';

/// VYEA gradients — restrained, editorial and low-contrast.
///
/// The core product stays neutral. Colourful accents are reserved for
/// colour-analysis content where they carry meaning.
class AppGradients {
  AppGradients._();

  static const LinearGradient primary = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.primary, AppColors.primaryDark],
  );

  static const LinearGradient ai = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFF2ECE5), Color(0xFFE5D8CA)],
  );

  static const LinearGradient premium = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFF6F0E8), Color(0xFFE4D5C2)],
  );

  static const LinearGradient soft = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.white, AppColors.ivory],
  );

  static const LinearGradient blush = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFF8EFEB), Color(0xFFF0E7E1)],
  );

  static const LinearGradient sage = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFF0F0E9), Color(0xFFE9E6DF)],
  );

  static const LinearGradient peach = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFF8EEE8), Color(0xFFF1E6DE)],
  );

  static LinearGradient season(String? seasonName) {
    final accent = AppColors.seasonAccent(seasonName);
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        accent.withValues(alpha: 0.82),
        accent.withValues(alpha: 0.42),
      ],
    );
  }
}
