import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'firebase_options.dart';
import 'providers/theme_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Load the persisted theme choice before the first frame, so the app
  // never flashes the wrong theme on startup.
  final themeProvider = await ThemeProvider.load();

  runApp(TibApp(themeProvider: themeProvider));
}
