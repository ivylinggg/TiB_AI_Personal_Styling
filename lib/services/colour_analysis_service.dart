import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart' as img;

import '../data/season_colour_guide.dart';
import '../models/colour_analysis_result.dart';

class ColourAnalysisService {
  ColourAnalysisService._();

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
    var skinLuminance = 0.0;
    var skinChroma = 0.0;
    var skinWarmth = 0.0;
    var skinCount = 0;

    final width = image.width;
    final height = image.height;
    final left = (width * 0.14).round().clamp(0, math.max(0, width - 1)).toInt();
    final right = (width * 0.86).round().clamp(left + 1, width).toInt();
    final top = (height * 0.08).round().clamp(0, math.max(0, height - 1)).toInt();
    final bottom = (height * 0.82).round().clamp(top + 1, height).toInt();

    for (var y = top; y < bottom; y += 3) {
      for (var x = left; x < right; x += 3) {
        final pixel = image.getPixel(x, y);
        final r = pixel.r.toDouble();
        final g = pixel.g.toDouble();
        final b = pixel.b.toDouble();
        if (!_looksLikeSkin(r, g, b)) continue;

        final luminance = _luminance(r, g, b);
        final maxValue = math.max(r, math.max(g, b));
        final minValue = math.min(r, math.min(g, b));
        final chroma = maxValue - minValue;
        final warmth = ((r - b) * 0.65) + ((g - b) * 0.35);

        skinLuminance += luminance;
        skinChroma += chroma;
        skinWarmth += warmth;
        skinCount++;
      }
    }

    if (skinCount == 0) return _PortraitSample.empty();

    final avgSkinLuminance = skinLuminance / skinCount;
    final avgSkinChroma = skinChroma / skinCount;
    final avgWarmth = skinWarmth / skinCount;
    final colourClarity = (avgSkinChroma / math.max(avgSkinLuminance, 1)) * 100;

    var darkest = 255.0;
    var lightest = 0.0;
    for (var y = 0; y < height; y += 12) {
      for (var x = 0; x < width; x += 12) {
        final pixel = image.getPixel(x, y);
        final value = _luminance(
          pixel.r.toDouble(),
          pixel.g.toDouble(),
          pixel.b.toDouble(),
        );
        darkest = math.min(darkest, value);
        lightest = math.max(lightest, value);
      }
    }

    var darkCount = 0;
    var darkTotal = 0.0;
    for (var y = top; y < bottom; y += 5) {
      for (var x = left; x < right; x += 5) {
        final pixel = image.getPixel(x, y);
        final value = _luminance(
          pixel.r.toDouble(),
          pixel.g.toDouble(),
          pixel.b.toDouble(),
        );
        if (value < avgSkinLuminance * 0.72) {
          darkTotal += value;
          darkCount++;
        }
      }
    }

    final darkReference = darkCount > 0 ? darkTotal / darkCount : darkest;
    return _PortraitSample(
      skinLuminance: avgSkinLuminance,
      skinChroma: avgSkinChroma,
      warmthScore: avgWarmth,
      colourClarity: colourClarity,
      skinToDarkContrast: avgSkinLuminance - darkReference,
      globalRange: lightest - darkest,
      skinCount: skinCount,
    );
  }

  static bool _looksLikeSkin(double r, double g, double b) {
    final maxValue = math.max(r, math.max(g, b));
    final minValue = math.min(r, math.min(g, b));
    if (maxValue < 35 || maxValue - minValue < 12) return false;

    final sum = r + g + b;
    if (sum <= 0) return false;
    final nr = r / sum;
    final ng = g / sum;
    final nb = b / sum;

    return nr > 0.28 && nr < 0.56 && ng > 0.20 && ng < 0.43 && nb < 0.34;
  }

  static double _luminance(double r, double g, double b) =>
      (0.2126 * r) + (0.7152 * g) + (0.0722 * b);

  static String _undertone(double warmthScore) {
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
    final scores = <String, double>{
      'Spring': 0,
      'Summer': 0,
      'Autumn': 0,
      'Winter': 0,
    };

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
      for (final season in scores.keys) {
        scores[season] = scores[season]! + 8;
      }
    }

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
        for (final season in scores.keys) {
          scores[season] = scores[season]! + 12;
        }
    }

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
      for (final season in scores.keys) {
        scores[season] = scores[season]! + 8;
      }
    }

    final clearBonus = math.min(18, math.max(0, colourClarity * 1.6));
    final mutedBonus = math.min(18, math.max(0, 12 - colourClarity * 1.2));
    scores['Spring'] = scores['Spring']! + clearBonus;
    scores['Winter'] = scores['Winter']! + clearBonus;
    scores['Summer'] = scores['Summer']! + mutedBonus;
    scores['Autumn'] = scores['Autumn']! + mutedBonus;

    if (skinChroma >= 42) {
      scores['Spring'] = scores['Spring']! + 8;
      scores['Winter'] = scores['Winter']! + 8;
    } else if (skinChroma <= 28) {
      scores['Summer'] = scores['Summer']! + 8;
      scores['Autumn'] = scores['Autumn']! + 8;
    }

    return scores.entries.reduce(
      (best, entry) => entry.value > best.value ? entry : best,
    ).key;
  }
}

class _PortraitSample {
  final double skinLuminance;
  final double skinChroma;
  final double warmthScore;
  final double colourClarity;
  final double skinToDarkContrast;
  final double globalRange;
  final int skinCount;

  const _PortraitSample({
    required this.skinLuminance,
    required this.skinChroma,
    required this.warmthScore,
    required this.colourClarity,
    required this.skinToDarkContrast,
    required this.globalRange,
    required this.skinCount,
  });

  factory _PortraitSample.empty() => const _PortraitSample(
        skinLuminance: 0,
        skinChroma: 0,
        warmthScore: 0,
        colourClarity: 0,
        skinToDarkContrast: 0,
        globalRange: 0,
        skinCount: 0,
      );
}
