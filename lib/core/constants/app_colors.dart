import 'package:flutter/material.dart';

/// TiB AI Personal Styling design system colours.
///
/// PHASE A (v4) -- BATIK AIR IDENTITY: Blue + White, with Egg-Yolk
/// Yellow reserved as a small special accent. This replaces the
/// previous Dark Navy + White + Yellow-as-Premium-only direction --
/// the brand is now explicitly framed as the Batik Air visual identity.
///
/// The repo was checked first for any existing official Batik Air
/// brand colours/logo assets (grepped for "batik"/hex values, checked
/// `assets/` and pubspec.yaml) -- none exist, so the two starting
/// values given in the brief are used directly:
///
///   batikBlue  #0054A6  -- primary / action / AI identity (dominant)
///   white      #FFFFFF  -- main light background (dominant)
///   eggYolk    #F5C400  -- SPECIAL accent only -- Favourites, Premium,
///                          AI highlight touches, selected states.
///                          Never a background, never body text.
///
/// Target hierarchy: ~60-70% white/very-light-blue, ~25-30% Batik Air
/// Blue, ~5-10% egg-yolk yellow. Status colours (success/warning/error)
/// are the one deliberate exception to "only these colours" -- semantic
/// feedback, not brand, so they stay conventional red/green/amber.
///
/// [AppColorsDark] is the dark-theme counterpart -- a genuine deep-navy
/// dark theme (not a brown/black inversion), with white text and the
/// same egg-yolk yellow accent.
class AppColors {
  AppColors._();

  // ===============================
  // THE CORE COLOURS
  // ===============================

  /// Batik Air Blue. The main brand/action colour.
  static const Color batikBlue = Color(0xFF0054A6);

  /// White. The main light background.
  static const Color white = Color(0xFFFFFFFF);

  /// Egg-Yolk Yellow. The SPECIAL accent -- Favourites, Premium, AI
  /// highlight touches, selected states. Never a page background,
  /// never body text (see [premiumAccentDark] for the "deep blue text
  /// on yellow" rule).
  static const Color eggYolk = Color(0xFFF5C400);

  // ===============================
  // Brand
  // ===============================

  static const Color primary = batikBlue;

  /// A darkened derivative of [batikBlue] -- pressed/emphasis state and
  /// the deeper stop of the brand gradient.
  static const Color primaryDark = Color(0xFF003F7D);

  /// Secondary brand surface -- a pale blue-grey derived from
  /// [batikBlue]. Used for unselected chip surfaces, icon-circle
  /// highlights, borders, and secondary backgrounds.
  static const Color secondary = Color(0xFFD6E4F2);

  // ===============================
  // Surfaces -- white, with a barely-blue-tinted lift for cards
  // ===============================

  static const Color background = white;

  /// Cards/sheets: a very soft blue-white so they read as "lifted" off
  /// [background] without needing a heavy shadow.
  static const Color surface = Color(0xFFF5F9FD);

  /// Chip/input fills -- one step further toward [secondary].
  static const Color surfaceMuted = Color(0xFFE8F0FA);

  /// Card/divider outline -- [secondary] directly.
  static const Color border = secondary;

  // ===============================
  // Text -- Batik Air Blue only, varied by opacity for hierarchy.
  // Never pure black.
  // ===============================

  static const Color textPrimary = batikBlue;

  /// [batikBlue] at ~70% opacity -- descriptions, secondary labels.
  static const Color textSecondary = Color(0xB30054A6);

  /// [batikBlue] at ~50% opacity -- hints, timestamps, disabled text.
  static const Color textMuted = Color(0x800054A6);

  // ===============================
  // AI accent -- AI-generated content stays on-brand blue (never a
  // separate purple hue -- "AI is part of the Batik Air identity"),
  // with the small egg-yolk highlight expressed via [AppGradients.ai]
  // rather than a whole new flat colour.
  // ===============================

  static const Color aiAccent = primary;
  static const Color aiAccentDark = primaryDark;

  /// Light tinted background for AI content cards/badges.
  static const Color aiAccentLight = surfaceMuted;

  // ===============================
  // Premium accent -- the special egg-yolk yellow.
  // ===============================

  static const Color premiumAccent = eggYolk;

  /// Light tint for Premium card/badge backgrounds.
  static const Color premiumAccentLight = Color(0xFFFCF0C2);

  /// Icon/text drawn on a Premium yellow fill uses Deep Blue, per the
  /// brief's explicit rule ("Use Deep Blue text on yellow") -- a
  /// darkened yellow would read muddy and isn't what was asked for.
  static const Color premiumAccentDark = primaryDark;

  // ===============================
  // Status -- semantic feedback only, deliberately conventional so
  // error/success/warning still read correctly. Never used as a brand/
  // decorative colour.
  // ===============================

  static const Color success = Color(0xFF43A047);
  static const Color warning = Color(0xFFFFB300);
  static const Color error = Color(0xFFE53935);

  // ===============================
  // Season-family accents -- keyed ONLY to the real season strings
  // ColourAnalysisService actually produces (see its _season() method):
  // Warm Spring, Warm Autumn, Cool Summer, Cool Winter, Clear Winter,
  // Soft Summer, Soft Autumn.
  //
  // Deliberately EXEMPT from the brand-colour rule: these represent the
  // customer's own real personal-colour-analysis result, not app
  // chrome. Recolouring a Warm Spring result to Batik Air blue would
  // misrepresent the user's actual analysis. Used subtly (tinted
  // backgrounds/containers on screens that already show the user's own
  // analysis), never as the primary brand colour and never for a
  // season that doesn't exist.
  // ===============================

  static const Map<String, Color> seasonAccents = {
    'Warm Spring': Color(0xFFE8A46B),
    'Warm Autumn': Color(0xFFC97B4A),
    'Cool Summer': Color(0xFF8FA6C9),
    'Cool Winter': Color(0xFF5E6FA3),
    'Clear Winter': Color(0xFF6B5B95),
    'Soft Summer': Color(0xFFB6A4C9),
    'Soft Autumn': Color(0xFFA98F6B),
  };

  /// The subtle accent for a real saved season string. Falls back to
  /// [primary] for null/unrecognised values -- this never invents a new
  /// season, it just keeps the UI safe if an unexpected value appears.
  static Color seasonAccent(String? season) {
    if (season == null) {
      return primary;
    }
    return seasonAccents[season] ?? primary;
  }
}

/// Dark-theme counterpart of [AppColors] -- a genuine deep-navy palette
/// (not a brown/grey inversion), with the exact background/surface
/// values from the brief:
///
///   background -- #071A2B (very dark navy)
///   surface    -- #0D2940 (dark navy, one step lighter)
///   primary    -- white (the accent that pops on a dark surface)
///   secondary  -- pale blue-grey
///   text       -- white
///
/// Egg-yolk yellow stays the exact same hue in both themes -- it's a
/// special accent, not a surface/text tone that needs to invert.
class AppColorsDark {
  AppColorsDark._();

  /// On a dark surface, white is the colour that pops -- used for
  /// primary buttons, active nav/icons, and text.
  static const Color primary = AppColors.white;

  /// Pressed/secondary-emphasis state for the dark-mode primary --
  /// [AppColors.secondary] directly, reused rather than invented.
  static const Color primaryDark = AppColors.secondary;

  static const Color secondary = AppColors.secondary;

  /// Very dark navy, per the brief.
  static const Color background = Color(0xFF071A2B);

  /// Dark navy, per the brief -- one step lighter than [background].
  static const Color surface = Color(0xFF0D2940);

  /// Chip/input fill -- one step lighter still.
  static const Color surfaceMuted = Color(0xFF14375A);

  /// A mid Batik Air blue -- visible against the darker surfaces above
  /// (the light [secondary] blue-grey would nearly disappear against
  /// them), and keeps dark mode unmistakably the same brand.
  static const Color border = Color(0xFF1F4A73);

  static const Color textPrimary = AppColors.white;

  /// White at ~70% opacity.
  static const Color textSecondary = Color(0xB3FFFFFF);

  /// White at ~50% opacity.
  static const Color textMuted = Color(0x80FFFFFF);
}
