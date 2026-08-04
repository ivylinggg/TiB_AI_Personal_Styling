class ColourAnalysisResult {
  final String season;
  final String undertone;
  final String brightness;
  final String contrast;
  final List<String> colours;

  const ColourAnalysisResult({
    required this.season,
    required this.undertone,
    required this.brightness,
    required this.contrast,
    required this.colours,
  });
}
