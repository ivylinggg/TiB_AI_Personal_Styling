import '../models/colour_analysis_result.dart';

class ColourAnalysisService {
  ColourAnalysisService._();

  static Future<ColourAnalysisResult> analyse() async {
    // 模拟 AI 分析耗时
    await Future.delayed(const Duration(seconds: 2));

    return const ColourAnalysisResult(
      season: "Warm Spring",
      undertone: "Warm",
      brightness: "Light",
      contrast: "Medium",
      imageUrl: "",
      colours: ["Peach", "Coral", "Cream", "Camel", "Olive"],
    );
  }
}
