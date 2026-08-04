import 'package:flutter/material.dart';

import '../../../models/colour_analysis_result.dart';

class AnalysisResultScreen extends StatelessWidget {
  final ColourAnalysisResult result;

  const AnalysisResultScreen({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Analysis Result")),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Icon(Icons.auto_awesome, size: 80, color: Color(0xFFC58F73)),

          const SizedBox(height: 24),

          _buildTile("Season", result.season),

          _buildTile("Undertone", result.undertone),

          _buildTile("Brightness", result.brightness),

          _buildTile("Contrast", result.contrast),

          const SizedBox(height: 20),

          const Text(
            "Recommended Colours",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 12),

          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: result.colours
                .map((colour) => Chip(label: Text(colour)))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildTile(String title, String value) {
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: ListTile(title: Text(title), subtitle: Text(value)),
    );
  }
}
