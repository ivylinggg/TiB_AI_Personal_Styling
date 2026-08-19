import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/theme/dark_theme.dart';
import 'core/theme/light_theme.dart';
import 'providers/analysis_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/splash/splash_screen.dart';

class TibApp extends StatelessWidget {
  /// Loaded once in `main()` (before `runApp`) so the correct persisted
  /// theme applies on the very first frame -- no flash of the wrong
  /// theme while SharedPreferences loads.
  final ThemeProvider themeProvider;

  const TibApp({super.key, required this.themeProvider});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>(create: (_) => AuthProvider()),
        ChangeNotifierProvider<AnalysisProvider>(
          create: (_) => AnalysisProvider(),
        ),
        ChangeNotifierProvider<ThemeProvider>.value(value: themeProvider),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, theme, _) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'TiB AI',
            theme: LightTheme.theme,
            darkTheme: DarkTheme.theme,
            themeMode: theme.themeMode,
            home: const SplashScreen(),
          );
        },
      ),
    );
  }
}
