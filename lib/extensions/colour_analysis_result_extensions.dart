import '../models/colour_analysis_result.dart';

extension ColourAnalysisResultSeasonExtension on ColourAnalysisResult {
  ColourAnalysisResult copyWithSeason(String season) {
    return ColourAnalysisResult(
      season: season,
      undertone: undertone,
      brightness: brightness,
      contrast: contrast,
      imageUrl: imageUrl,
      colours: colours,
      faceShape: faceShape,
      faceShapeDescription: faceShapeDescription,
      faceMeasurements: faceMeasurements,
      faceStylingGuidance: faceStylingGuidance,
      colourReasons: colourReasons,
      chroma: chroma,
      clarity: clarity,
      bestNeutrals: bestNeutrals,
      accentColours: accentColours,
      lessIdealColours: lessIdealColours,
    );
  }
}
