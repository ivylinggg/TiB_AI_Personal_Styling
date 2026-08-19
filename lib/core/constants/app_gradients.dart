import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Centralised, curated gradients. Only the gradients that are actually
/// used somewhere are kept.
///
/// PHASE A (v4): [primary] is pure Batik Air Blue tones; [ai] blends
/// blue into the egg-yolk accent so AI moments read as "Blue with a
/// small yellow highlight" per the brief, entirely through this one
/// gradient definition -- no AI screen needed to change; [premium]
/// stays a pure yellow gradient (darker to lighter) so Premium is
/// unmistakably marked.
class AppGradients {
  AppGradients._();

  /// The brand gradient, used by PrimaryButton and by the Dashboard/
  /// Profile/AI Stylist hero headers.
  static const LinearGradient primary = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.primary, AppColors.primaryDark],
  );

  /// Marks genuinely AI-generated content -- Batik Air Blue fading into
  /// the egg-yolk accent, giving AI moments a small yellow highlight
  /// without making AI its own separate colour family. Reserved for
  /// that purpose only, never a general decorative gradient.
  static const LinearGradient ai = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.primary, AppColors.premiumAccent],
  );

  /// Premium surface -- the special egg-yolk accent at full strength
  /// fading to a softer tint of itself, so Premium content is
  /// unmistakably marked. Deliberately NOT built from
  /// [AppColors.premiumAccentDark] -- that token is Deep Blue (the
  /// "text/icon on a yellow surface" colour per the brief), not a
  /// darker yellow, so it would turn this into a blue-to-yellow
  /// gradient rather than the pure-yellow surface Premium needs.
  static const LinearGradient premium = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.premiumAccent, Color(0xFFFAD968)],
  );

  /// A subtle tint gradient for the user's own analysed season family.
  /// Only ever built from a real saved season string (via
  /// AppColors.seasonAccent) -- never an invented colour. Deliberately
  /// exempt from the brand-colour rule (see AppColors' doc comment on
  /// seasonAccents): this represents the customer's real analysis
  /// result, not app chrome.
  static LinearGradient season(String? seasonName) {
    final accent = AppColors.seasonAccent(seasonName);
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        accent.withValues(alpha: 0.85),
        accent.withValues(alpha: 0.55),
      ],
    );
  }
}
