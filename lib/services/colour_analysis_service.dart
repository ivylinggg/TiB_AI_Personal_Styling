import 'dart:io';

import '../models/colour_analysis_result.dart';

class ColourAnalysisService {
  ColourAnalysisService._();

  static Future<ColourAnalysisResult> analyse({
    required File image,
    required String imageUrl,
  }) async {
    /*
      ============================================================
      AI COLOUR ANALYSIS ENGINE
      ============================================================

      Current stage:
      This service is the central entry point for the AI analysis.

      The current implementation uses a controlled analysis result
      while the actual AI colour-analysis engine is being connected.

      DO NOT put the analysis result directly inside
      AnalysisScreen.

      Future AI integration will happen HERE.
    */

    await Future.delayed(const Duration(seconds: 2));

    return ColourAnalysisResult(
      season: 'Warm Spring',
      undertone: 'Warm',
      brightness: 'Light',
      contrast: 'Medium',
      imageUrl: imageUrl,
      colours: const ['Peach', 'Coral', 'Cream', 'Camel', 'Olive'],
    );
  }
}
