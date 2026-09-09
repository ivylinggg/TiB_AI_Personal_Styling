class ColourAnalysisResult {
  final String season;
  final String undertone;
  final String brightness;
  final String contrast;
  final String imageUrl;
  final List<String> colours;
  final String faceShape;
  final String faceShapeDescription;
  final Map<String, double> faceMeasurements;
  final List<String> faceStylingGuidance;
  final List<String> colourReasons;
  final String chroma;
  final String clarity;
  final List<String> bestNeutrals;
  final List<String> accentColours;
  final List<String> lessIdealColours;

  const ColourAnalysisResult({
    required this.season,
    required this.undertone,
    required this.brightness,
    required this.contrast,
    required this.imageUrl,
    required this.colours,
    this.faceShape = 'Unknown',
    this.faceShapeDescription = '',
    this.faceMeasurements = const {},
    this.faceStylingGuidance = const [],
    this.colourReasons = const [],
    this.chroma = 'Unknown',
    this.clarity = 'Unknown',
    this.bestNeutrals = const [],
    this.accentColours = const [],
    this.lessIdealColours = const [],
  });
}
