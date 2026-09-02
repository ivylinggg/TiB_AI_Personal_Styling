import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart' as img;

import '../data/season_colour_guide.dart';
import '../models/colour_analysis_result.dart';

class ColourAnalysisService {
  ColourAnalysisService._();

  /// Deterministic on-device colour analysis based on the user's portrait.
  ///
  /// The four-season framework in the TiB colour guide is:
  /// Winter = Deep • Cool • Clear
  /// Summer = Soft • Cool • Light
  /// Spring = Light • Warm • Clear
  /// Autumn = Deep • Warm • Muted
  ///
  /// The result is deliberately scored from several visual signals instead
  /// of using a single hard-coded fallback. We estimate skin warmth from
  /// multiple skin-like pixels, skin depth from luminance, clarity from skin
  /// chroma/saturation, and contrast from the relationship between the skin
  /// region and darker/lighter surrounding portrait areas.
  ///
  /// Face shape is useful for styling recommendations, but it is not used as
  /// a seasonal-colour determinant: seasonal colour analysis is driven by
  /// colouring (undertone, depth/brightness and contrast/clarity), not facial
  /// geometry.
  static Future<ColourAnalysisResult> analyse({
    required File image,
    required String imageUrl,
  }) async {
    final bytes = await image.readAsBytes();
    final decoded = img.decodeImage(bytes);

    if (decoded == null) {
      throw const FormatException('Unable to read the selected image.');
    }

    final source = img.bakeOrientation(decoded);
    final sample = _samplePortrait(source);

    if (sample.skinCount < 8) {
      throw const FormatException(
        'Unable to analyse the selected image. Please use a clear front-facing portrait in natural light.',
      );
    }

    final brightness = _brightness(sample.skinLuminance);
    final undertone = _undertone(sample.warmthScore);
    final contrast = _contrast(sample);
    final season = _season(
      undertone: undertone,
      brightness: brightness,
      contrast: contrast,
      skinChroma: sample.skinChroma,
      colourClarity: sample.colourClarity,
    );

    final guide = SeasonColourGuide.forSeason(season);

    return ColourAnalysisResult(
      season: season,
      undertone: undertone,
      brightness: brightness,
      contrast: contrast,
      imageUrl: imageUrl,
      colours: guide.bestColours,
    );
  }

  static _PortraitSample _samplePortrait(img.Image image) {
    var skinRed = 0.0;
    var skinGreen = 0.0;
    var skinBlue = 0.0;
    var skinLuminance = 0.0;
    var skinChroma = 0.0;
    var skinWarmth = 0.0;
    var skinCount = 0;

    // The central portrait region intentionally avoids most background pixels.
    final left = (image.width * 0.20).round().clamp(0, image.width - 1);
    final right = (image.width * 0.80).round().clamp(left + 1, image.width);
    final top = (image.height * 0.12).round().clamp(0, image.height - 1);
    final bottom = (image.height * 0.78).round().clamp(top + 1, image.height);

    for (var y = top; y < bottom; y += 4) {
      for (var x = left; x < right; x += 4) {
        final pixel = image.getPixel(x, y);
        final r = pixel.r.toDouble();
        final g = pixel.g.toDouble();
        final b = pixel.b.toDouble();

        if (!_looksLikeSkin(r, g, b)) continue;

        final luminance = _luminance(r, g, b);
        final maxValue = math.max(r, math.max(g, b));
        final minValue = math.min(r, math.min(g, b));
        final chroma = maxValue - minValue;

        // Warmth is measured with red/green against blue. Keeping the score
        // per pixel and averaging it prevents one bright skin patch from
        // deciding the entire analysis.
        final warmth = ((r - b) * 0.65) + ((g - b) * 0.35);

        skinRed += r;
        skinGreen += g;
        skinBlue += b;
        skinLuminance += luminance;
        skinChroma += chroma;
        skinWarmth += warmth;
        skinCount++;
      }
    }

    if (skinCount == 0) return _PortraitSample.empty();

    final avgSkinR = skinRed / skinCount;
    final avgSkinG = skinGreen / skinCount;
    final avgSkinB = skinBlue / skinCount;
    final avgSkinLuminance = skinLuminance / skinCount;
    final avgSkinChroma = skinChroma / skinCount;
    final avgWarmth = skinWarmth / skinCount;

    // Estimate colour clarity from how saturated the skin region is relative
    // to its luminance. This is intentionally a soft signal rather than a
    // binary threshold because phone cameras and lighting vary considerably.
    final colourClarity = (avgSkinChroma / math.max(avgSkinLuminance, 1)) * 100;

    // Sample the whole portrait for tonal extremes. These are later compared
    // with the skin luminance to estimate visible contrast.
    var darkest = 255.0;
    var lightest = 0.0;
    for (var y = 0; y < image.height; y += 12) {
      for (var x = 0; x < image.width; x += 12) {
        final p = image.getPixel(x, y);
        final value = _luminance(
          p.r.toDouble(),
          p.g.toDouble(),
          p.b.toDouble(),
        );
        darkest = math.min(darkest, value);
        lightest = math.max(lightest, value);
      }
    }

    // A secondary dark-region sample approximates hair/eyes/clothing around
    // the face and is more meaningful for contrast than background-only range.
    var darkCount = 0;
    var darkTotal = 0.0;
    for (var y = top; y < bottom; y += 6) {
      for (var x = left; x < right; x += 6) {
        final p = image.getPixel(x, y);
        final value = _luminance(
          p.r.toDouble(),
          p.g.toDouble(),
          p.b.toDouble(),
        );
        if (value < avgSkinLuminance * 0.72) {
          darkTotal += value;
          darkCount++;
        }
      }
    }

    final darkReference = darkCount > 0 ? darkTotal / darkCount : darkest;
    final skinToDarkContrast = avgSkinLuminance - darkReference;
    final globalRange = lightest - darkest;

    return _PortraitSample(
      skinRed: avgSkinR,
      skinGreen: avgSkinG,
      skinBlue: avgSkinB,
      skinLuminance: avgSkinLuminance,
      skinChroma: avgSkinChroma,
      warmthScore: avgWarmth,
      colourClarity: colourClarity,
      skinToDarkContrast: skinToDarkContrast,
      globalRange: globalRange,
      skinCount: skinCount,
    );
  }

  static bool _looksLikeSkin(double r, double g, double b) {
    final maxValue = math.max(r, math.max(g, b));
    final minValue = math.min(r, math.min(g, b));

    if (maxValue < 45 || maxValue - minValue < 18) return false;

    // Normalised chromaticity is more robust to exposure than fixed RGB
    // comparisons and accepts a wider range of natural skin tones.
    final sum = r + g + b;
    if (sum <= 0) return false;

    final nr = r / sum;
    final ng = g / sum;
    final nb = b / sum;

    return nr > 0.31 && nr < 0.52 && ng > 0.24 && ng < 0.40 && nb < 0.30;
  }

  static double _luminance(double r, double g, double b) {
    return (0.2126 * r) + (0.7152 * g) + (0.0722 * b);
  }

  static String _undertone(double warmthScore) {
    // Neutral is intentionally available. It is resolved later using the
    // other colour dimensions instead of forcing every neutral face into
    // Autumn.
    if (warmthScore >= 36) return 'Warm';
    if (warmthScore <= 23) return 'Cool';
    return 'Neutral';
  }

  static String _brightness(double luminance) {
    if (luminance >= 184) return 'Light';
    if (luminance >= 118) return 'Medium';
    return 'Deep';
  }

  static String _contrast(_PortraitSample sample) {
    final score = math.max(
      sample.skinToDarkContrast,
      sample.globalRange * 0.55,
    );

    if (score >= 105) return 'High';
    if (score >= 62) return 'Medium';
    return 'Low';
  }

  static String _season({
    required String undertone,
    required String brightness,
    required String contrast,
    required double skinChroma,
    required double colourClarity,
  }) {
    // Score all four seasons. This avoids the previous behaviour where any
    // warm/medium/deep portrait fell straight through to Autumn.
    final scores = <String, double>{
      'Spring': 0,
      'Summer': 0,
      'Autumn': 0,
      'Winter': 0,
    };

    // Temperature dimension.
    if (undertone == 'Warm') {
      scores['Spring'] = scores['Spring']! + 34;
      scores['Autumn'] = scores['Autumn']! + 34;
      scores['Summer'] = scores['Summer']! - 18;
      scores['Winter'] = scores['Winter']! - 18;
    } else if (undertone == 'Cool') {
      scores['Summer'] = scores['Summer']! + 34;
      scores['Winter'] = scores['Winter']! + 34;
      scores['Spring'] = scores['Spring']! - 18;
      scores['Autumn'] = scores['Autumn']! - 18;
    } else {
      scores['Spring'] = scores['Spring']! + 8;
      scores['Summer'] = scores['Summer']! + 8;
      scores['Autumn'] = scores['Autumn']! + 8;
      scores['Winter'] = scores['Winter']! + 8;
    }

    // Depth / brightness dimension.
    switch (brightness) {
      case 'Light':
        scores['Spring'] = scores['Spring']! + 30;
        scores['Summer'] = scores['Summer']! + 30;
        scores['Autumn'] = scores['Autumn']! - 8;
        scores['Winter'] = scores['Winter']! - 8;
        break;
      case 'Deep':
        scores['Autumn'] = scores['Autumn']! + 30;
        scores['Winter'] = scores['Winter']! + 30;
        scores['Spring'] = scores['Spring']! - 8;
        scores['Summer'] = scores['Summer']! - 8;
        break;
      default:
        scores['Spring'] = scores['Spring']! + 12;
        scores['Summer'] = scores['Summer']! + 12;
        scores['Autumn'] = scores['Autumn']! + 12;
        scores['Winter'] = scores['Winter']! + 12;
    }

    // Contrast dimension maps directly to the guide's clear/muted axis.
    if (contrast == 'High') {
      scores['Spring'] = scores['Spring']! + 22;
      scores['Winter'] = scores['Winter']! + 22;
      scores['Summer'] = scores['Summer']! - 6;
      scores['Autumn'] = scores['Autumn']! - 6;
    } else if (contrast == 'Low') {
      scores['Summer'] = scores['Summer']! + 22;
      scores['Autumn'] = scores['Autumn']! + 22;
      scores['Spring'] = scores['Spring']! - 6;
      scores['Winter'] = scores['Winter']! - 6;
    } else {
      scores['Spring'] = scores['Spring']! + 8;
      scores['Summer'] = scores['Summer']! + 8;
      scores['Autumn'] = scores['Autumn']! + 8;
      scores['Winter'] = scores['Winter']! + 8;
    }

    // Clarity is the tie-breaker between clear and muted seasons.
    final clearBonus = math.min(18, math.max(0, colourClarity * 1.6));
    final mutedBonus = math.min(18, math.max(0, 12 - colourClarity * 1.2));
    scores['Spring'] = scores['Spring']! + clearBonus;
    scores['Winter'] = scores['Winter']! + clearBonus;
    scores['Summer'] = scores['Summer']! + mutedBonus;
    scores['Autumn'] = scores['Autumn']! + mutedBonus;

    // Skin chroma provides another gentle tie-breaker for photographs with
    // similar brightness/contrast. Higher chroma favours clear seasons.
    if (skinChroma >= 42) {
      scores['Spring'] = scores['Spring']! + 8;
      scores['Winter'] = scores['Winter']! + 8;
    } else if (skinChroma <= 28) {
      scores['Summer'] = scores['Summer']! + 8;
      scores['Autumn'] = scores['Autumn']! + 8;
    }

    // Neutral faces should not always fall into one season. Use the measured
    // dimensions as the final tie-breaker and choose the highest score.
    return scores.entries.reduce(
      (best, entry) => entry.value > best.value ? entry : best,
    ).key;
  }
}

class _PortraitSample {
  final double skinRed;
  final double skinGreen;
  final double skinBlue;
  final double skinLuminance;
  final double skinChroma;
  final double warmthScore;
  final double colourClarity;
  final double skinToDarkContrast;
  final double globalRange;
  final int skinCount;

  const _PortraitSample({
    required this.skinRed,
    required this.skinGreen,
    required this.skinBlue,
    required this.skinLuminance,
    required this.skinChroma,
    required this.warmthScore,
    required this.colourClarity,
    required this.skinToDarkContrast,
    required this.globalRange,
    required this.skinCount,
  });

  factory _PortraitSample.empty() {
    return const _PortraitSample(
      skinRed: 0,
      skinGreen: 0,
      skinBlue: 0,
      skinLuminance: 0,
      skinChroma: 0,
      warmthScore: 0,
      colourClarity: 0,
      skinToDarkContrast: 0,
      globalRange: 0,
      skinCount: 0,
    );
  }
}
