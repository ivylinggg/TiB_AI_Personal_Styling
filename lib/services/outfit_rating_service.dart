import 'dart:math' as math;

/// Result produced by the TiB Outfit Check feature.
///
/// The service is intentionally deterministic: the same detected signals
/// always produce the same score and recommendations. Image understanding
/// can be connected later without changing the presentation layer.
class OutfitRatingResult {
  final int overallScore;
  final int colourHarmonyScore;
  final int outfitCoordinationScore;
  final int personalColourScore;
  final int stylingScore;
  final int accessoryScore;
  final List<String> strengths;
  final List<String> improvements;
  final List<AccessoryRecommendation> accessories;

  const OutfitRatingResult({
    required this.overallScore,
    required this.colourHarmonyScore,
    required this.outfitCoordinationScore,
    required this.personalColourScore,
    required this.stylingScore,
    required this.accessoryScore,
    required this.strengths,
    required this.improvements,
    required this.accessories,
  });
}

class AccessoryRecommendation {
  final String category;
  final String name;
  final String reason;

  const AccessoryRecommendation({
    required this.category,
    required this.name,
    required this.reason,
  });
}

/// TiB's first-stage outfit scoring engine.
///
/// It accepts signals already available in the app (season, face shape,
/// body shape and outfit colour temperature) rather than pretending that a
/// photo has been fully understood when it has not. This keeps the feature
/// explainable and gives the future vision/AI service a stable contract.
class OutfitRatingService {
  const OutfitRatingService();

  OutfitRatingResult rate({
    String? season,
    String? faceShape,
    String? bodyShape,
    bool? outfitIsWarm,
    bool? outfitIsMuted,
    bool? outfitIsLight,
    bool? outfitIsHighContrast,
    bool hasAccessories = false,
  }) {
    final normalizedSeason = (season ?? '').trim().toLowerCase();
    final normalizedFace = (faceShape ?? '').trim().toLowerCase();
    final normalizedBody = (bodyShape ?? '').trim().toLowerCase();

    var colour = 78;
    var personalColour = 76;
    var coordination = 80;
    var styling = 78;
    var accessory = hasAccessories ? 84 : 72;

    final warmSeason = normalizedSeason.contains('spring') || normalizedSeason.contains('autumn');
    final coolSeason = normalizedSeason.contains('summer') || normalizedSeason.contains('winter');
    final lightSeason = normalizedSeason.contains('spring') || normalizedSeason.contains('summer');
    final mutedSeason = normalizedSeason.contains('summer') || normalizedSeason.contains('autumn');

    if (outfitIsWarm != null) {
      final match = (warmSeason && outfitIsWarm) || (coolSeason && !outfitIsWarm);
      personalColour += match ? 10 : -9;
      colour += match ? 7 : -6;
    }
    if (outfitIsMuted != null) {
      final match = mutedSeason == outfitIsMuted;
      personalColour += match ? 6 : -5;
      colour += match ? 5 : -4;
    }
    if (outfitIsLight != null) {
      final match = lightSeason == outfitIsLight;
      personalColour += match ? 5 : -4;
    }
    if (outfitIsHighContrast != null && normalizedSeason.contains('winter')) {
      personalColour += outfitIsHighContrast ? 5 : -4;
    }

    if (normalizedBody.contains('hourglass')) styling += 6;
    if (normalizedBody.contains('rectangle')) styling += 3;
    if (normalizedBody.contains('pear')) styling += 4;
    if (normalizedBody.contains('apple')) styling += 3;
    if (normalizedBody.contains('inverted')) styling += 3;

    if (normalizedFace.contains('round')) accessory += 4;
    if (normalizedFace.contains('square')) accessory += 4;
    if (normalizedFace.contains('oval')) accessory += 6;
    if (normalizedFace.contains('heart')) accessory += 4;

    colour = _clamp(colour);
    personalColour = _clamp(personalColour);
    coordination = _clamp(coordination);
    styling = _clamp(styling);
    accessory = _clamp(accessory);

    final overall = _clamp(
      (colour * .25 + coordination * .20 + personalColour * .25 + styling * .18 + accessory * .12).round(),
    );

    final strengths = <String>[];
    final improvements = <String>[];

    if (personalColour >= 85) {
      strengths.add('The outfit works well with your personal colour direction.');
    } else {
      improvements.add('Try colours closer to your personal seasonal palette.');
    }
    if (colour >= 85) {
      strengths.add('The colours create a balanced overall impression.');
    } else {
      improvements.add('Reduce competing colours and keep a clearer colour hierarchy.');
    }
    if (styling >= 84) {
      strengths.add('The silhouette supports your styling profile.');
    } else {
      improvements.add('Adjust the silhouette to create a more intentional proportion.');
    }
    if (accessory < 82) {
      improvements.add('Add one or two intentional accessories to complete the look.');
    } else {
      strengths.add('The accessory direction complements the overall look.');
    }

    final accessories = _recommendAccessories(
      season: normalizedSeason,
      faceShape: normalizedFace,
      hasAccessories: hasAccessories,
    );

    return OutfitRatingResult(
      overallScore: overall,
      colourHarmonyScore: colour,
      outfitCoordinationScore: coordination,
      personalColourScore: personalColour,
      stylingScore: styling,
      accessoryScore: accessory,
      strengths: strengths,
      improvements: improvements,
      accessories: accessories,
    );
  }

  List<AccessoryRecommendation> _recommendAccessories({
    required String season,
    required String faceShape,
    required bool hasAccessories,
  }) {
    final warm = season.contains('spring') || season.contains('autumn');
    final metal = warm ? 'Gold' : 'Silver';
    final earring = faceShape.contains('round')
        ? 'elongated $metal earrings'
        : faceShape.contains('square')
            ? 'soft $metal hoops'
            : 'medium $metal earrings';

    final necklace = faceShape.contains('round')
        ? '$metal pendant necklace'
        : 'delicate $metal layered necklace';

    return [
      AccessoryRecommendation(
        category: 'Necklace',
        name: necklace,
        reason: 'Balances the neckline while staying consistent with your colour direction.',
      ),
      AccessoryRecommendation(
        category: 'Earrings',
        name: earring,
        reason: 'Adds a flattering vertical or softened shape around the face.',
      ),
      AccessoryRecommendation(
        category: 'Bracelet',
        name: 'minimal $metal chain bracelet',
        reason: 'Adds polish without competing with the main outfit.',
      ),
      if (!hasAccessories)
        const AccessoryRecommendation(
          category: 'Bag',
          name: 'structured neutral handbag',
          reason: 'Adds a practical finishing piece while keeping the outfit balanced.',
        ),
    ];
  }

  int _clamp(int value) => math.max(0, math.min(100, value));
}
