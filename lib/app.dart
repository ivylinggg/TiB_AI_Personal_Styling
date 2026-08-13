import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/theme/light_theme.dart';
import 'providers/analysis_provider.dart';
import 'providers/auth_provider.dart';
import 'screens/splash/splash_screen.dart';

class TibApp extends StatelessWidget {
  const TibApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>(
          create: (_) => AuthProvider(),
        ),
        ChangeNotifierProvider<AnalysisProvider>(
          create: (_) => AnalysisProvider(),
        ),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'TiB AI',
        theme: LightTheme.theme,
        home: const SplashScreen(),
      ),
    );
  }
}
