import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/app_radius.dart';
import 'app_text_theme.dart';

/// The app's dark theme (PHASE A -- previously this file existed but was
/// empty, so the app had no real dark mode at all).
///
/// This mirrors [LightTheme] component-for-component so every default-
/// themed Material widget (AppBar, Card, Chip, buttons, inputs, dialogs,
/// bottom sheets, navigation bar, dividers, snackbars) gets a correctly
/// coloured dark counterpart automatically. It is a genuine dark navy
/// theme built from [AppColorsDark] (near-black navy surfaces, white
/// text) -- not a naive inversion to plain black/white.
///
/// Known scope limit (see the Phase A report): this only re-skins
/// default-themed Material components and any widget that reads
/// `Theme.of(context)`. Screens that read the plain `AppColors.x`
/// statics directly for bespoke, non-Theme-driven UI will not change
/// between light/dark until they're migrated in a later phase -- that
/// migration is intentionally out of scope here to avoid an
/// uncontrolled, all-at-once rewrite.
class DarkTheme {
  DarkTheme._();

  static ThemeData get theme {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColorsDark.primary,
      brightness: Brightness.dark,
    ).copyWith(
      primary: AppColorsDark.primary,
      secondary: AppColorsDark.secondary,
      surface: AppColorsDark.surface,
      error: AppColors.error,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,

      scaffoldBackgroundColor: AppColorsDark.background,
      colorScheme: colorScheme,
      textTheme: AppTextTheme.dark,

      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: AppColorsDark.textPrimary,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: AppColorsDark.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),

      cardTheme: CardThemeData(
        elevation: 0,
        color: AppColorsDark.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: const BorderSide(color: AppColorsDark.border),
        ),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: AppColorsDark.surfaceMuted,
        selectedColor: AppColorsDark.primary,
        disabledColor: AppColorsDark.surfaceMuted,
        labelStyle: const TextStyle(
          color: AppColorsDark.textPrimary,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
        secondaryLabelStyle: const TextStyle(
          color: AppColorsDark.background,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.full),
        ),
      ),

      // Button/link text sits on top of the lightened dark-mode primary
      // accent, so it uses the dark background colour rather than white
      // -- against AppColorsDark.primary, that keeps contrast well above
      // the light theme's white-on-primary contrast (see the Phase A
      // report for the exact figures).
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColorsDark.primary,
          foregroundColor: AppColorsDark.background,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColorsDark.primary,
          side: const BorderSide(color: AppColorsDark.border, width: 1.4),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColorsDark.primary,
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColorsDark.surfaceMuted,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: const BorderSide(
            color: AppColorsDark.primary,
            width: 1.6,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: const BorderSide(color: AppColors.error, width: 1.4),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: const BorderSide(color: AppColors.error, width: 1.6),
        ),
        labelStyle: const TextStyle(color: AppColorsDark.textSecondary),
        hintStyle: const TextStyle(color: AppColorsDark.textMuted),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: AppColorsDark.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        titleTextStyle: AppTextTheme.dark.titleLarge,
        contentTextStyle: AppTextTheme.dark.bodyMedium,
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: AppColorsDark.surface,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: AppColorsDark.surface,
        showDragHandle: true,
        dragHandleColor: AppColorsDark.border,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.xl),
          ),
        ),
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColorsDark.surface,
        // Mid navy border tone, not the light blue-grey secondary --
        // against the white selected icon/label below, this gives real
        // contrast (the light blue-grey would wash the white icon out
        // almost to the point of invisibility).
        indicatorColor: AppColorsDark.border,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        height: 66,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 11,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected
                ? AppColorsDark.primary
                : AppColorsDark.textMuted,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected
                ? AppColorsDark.primary
                : AppColorsDark.textMuted,
          );
        }),
      ),

      dividerTheme: const DividerThemeData(
        color: AppColorsDark.border,
        thickness: 1,
        space: 1,
      ),

      // Mirrors the light theme's inverted-contrast toast: there it's a
      // dark bar on a light screen, so here it's a white bar on the
      // dark screen, keeping it equally prominent either way.
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColorsDark.textPrimary,
        contentTextStyle: const TextStyle(color: AppColorsDark.background),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
      ),
    );
  }
}
