import 'package:flutter/material.dart';

class TibApp extends StatelessWidget {
  const TibApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TiB AI Personal Styling',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFFC58F73),
      ),
      home: const Scaffold(
        body: Center(
          child: Text(
            'TiB AI Personal Styling',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}
