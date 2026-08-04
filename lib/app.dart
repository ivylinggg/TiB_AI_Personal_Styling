import 'package:flutter/material.dart';

import 'core/theme/light_theme.dart';
import 'screens/splash/splash_screen.dart';

class TibApp extends StatelessWidget {
  const TibApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,

      title: 'TiB AI',

      theme: LightTheme.theme,

      home: const SplashScreen(),
    );
  }
}
