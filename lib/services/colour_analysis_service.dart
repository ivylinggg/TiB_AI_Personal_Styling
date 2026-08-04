import '../models/colour_analysis_result.dart';

class ColourAnalysisService {
  static Future<ColourAnalysisResult> analyse() async {
    await Future.delayed(const Duration(seconds: 2));

    return const ColourAnalysisResult(
      season: "Warm Spring",
      undertone: "Warm",
      brightness: "Light",
      contrast: "Medium",
      colours: ["Peach", "Camel", "Olive", "Coral", "Cream"],
    );
  }
}
