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

  ColourAnalysisResult copyWith({
    String? season,
    String? undertone,
    String? brightness,
    String? contrast,
    String? imageUrl,
    List<String>? colours,
    String? faceShape,
    String? faceShapeDescription,
    Map<String, double>? faceMeasurements,
    List<String>? faceStylingGuidance,
    List<String>? colourReasons,
    String? chroma,
    String? clarity,
    List<String>? bestNeutrals,
    List<String>? accentColours,
    List<String>? lessIdealColours,
  }) {
    return ColourAnalysisResult(
      season: season ?? this.season,
      undertone: undertone ?? this.undertone,
      brightness: brightness ?? this.brightness,
      contrast: contrast ?? this.contrast,
      imageUrl: imageUrl ?? this.imageUrl,
      colours: colours ?? this.colours,
      faceShape: faceShape ?? this.faceShape,
      faceShapeDescription: faceShapeDescription ?? this.faceShapeDescription,
      faceMeasurements: faceMeasurements ?? this.faceMeasurements,
      faceStylingGuidance: faceStylingGuidance ?? this.faceStylingGuidance,
      colourReasons: colourReasons ?? this.colourReasons,
      chroma: chroma ?? this.chroma,
      clarity: clarity ?? this.clarity,
      bestNeutrals: bestNeutrals ?? this.bestNeutrals,
      accentColours: accentColours ?? this.accentColours,
      lessIdealColours: lessIdealColours ?? this.lessIdealColours,
    );
  }

  static List<String> normalizeStringList(dynamic value) {
    if (value is! List) return const [];
    return value
        .whereType<String>()
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }

  static Map<String, double> normalizeMeasurements(dynamic value) {
    if (value is! Map) return const {};
    final result = <String, double>{};
    value.forEach((key, rawValue) {
      if (rawValue is num) {
        result[key.toString()] = rawValue.toDouble();
      }
    });
    return Map.unmodifiable(result);
  }
}
