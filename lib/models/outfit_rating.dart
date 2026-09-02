class OutfitRating {
  final int overallScore;
  final int colourHarmonyScore;
  final int coordinationScore;
  final int personalColourScore;
  final int stylingScore;
  final int accessoriesScore;
  final List<String> strengths;
  final List<String> improvements;
  final List<AccessoryRecommendation> accessories;
  final int upgradedScore;
  final String summary;

  const OutfitRating({
    required this.overallScore,
    required this.colourHarmonyScore,
    required this.coordinationScore,
    required this.personalColourScore,
    required this.stylingScore,
    required this.accessoriesScore,
    required this.strengths,
    required this.improvements,
    required this.accessories,
    required this.upgradedScore,
    required this.summary,
  });
}

class AccessoryRecommendation {
  final String type;
  final String name;
  final String reason;

  const AccessoryRecommendation({
    required this.type,
    required this.name,
    required this.reason,
  });
}
