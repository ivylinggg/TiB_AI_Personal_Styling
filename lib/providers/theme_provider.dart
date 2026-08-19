import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists and exposes the user's chosen app theme (Light / Dark /
/// System), backed by SharedPreferences so the choice survives an app
/// restart. Defaults to [ThemeMode.system] when nothing has been saved
/// yet (first launch, or a user who has never opened the theme setting)
/// -- the safe, honest baseline the Phase A brief asked for, with no
/// time-of-day scheduler layered on top.
///
/// The Settings screen that lets a user actually pick a mode is Phase C
/// work; this provider is the persistence + wiring foundation it will
/// call into.
class ThemeProvider extends ChangeNotifier {
  static const _prefsKey = 'app_theme_mode';

  ThemeMode _themeMode;

  ThemeProvider._(this._themeMode);

  ThemeMode get themeMode => _themeMode;

  /// Loads the persisted theme choice (if any) and returns a ready
  /// [ThemeProvider]. Call this once, before `runApp`, so the correct
  /// theme applies from the very first frame with no flash of the wrong
  /// theme.
  static Future<ThemeProvider> load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefsKey);
    return ThemeProvider._(_decode(saved));
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) {
      return;
    }

    _themeMode = mode;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, _encode(mode));
  }

  static String _encode(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'system';
    }
  }

  static ThemeMode _decode(String? value) {
    switch (value) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }
}
