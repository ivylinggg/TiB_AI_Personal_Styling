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

    final reasons = <String>[
      '${sample.warmthLabel} undertone detected from the sampled skin tones',
      '${sample.brightnessLabel} overall skin depth detected',
      '${sample.contrastLabel} natural facial contrast detected',
      sample.clarityLabel,
    ];

    return ColourAnalysisResult(
      season: season,
      undertone: undertone,
      brightness: brightness,
      contrast: contrast,
      imageUrl: imageUrl,
      colours: guide.bestColours,
      colourReasons: reasons,
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
        final value = _luminance(pixel.r.toDouble(), pixel.g.toDouble(), pixel.b.toDouble());
        darkest = math.min(darkest, value);
        lightest = math.max(lightest, value);
      }
    }

    var darkCount = 0;
    var darkTotal = 0.0;
    for (var y = top; y < bottom; y += 5) {
      for (var x = left; x < right; x += 5) {
        final pixel = image.getPixel(x, y);
        final value = _luminance(pixel.r.toDouble(), pixel.g.toDouble(), pixel.b.toDouble());
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

  static double _luminance(double r, double g, double b) => (0.2126 * r) + (0.7152 * g) + (0.0722 * b);

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
    final score = math.max(sample.skinToDarkContrast, sample.globalRange * 0.55);
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
    final isWarm = undertone == 'Warm';
    final isCool = undertone == 'Cool';
    final isLight = brightness == 'Light';
    final isDeep = brightness == 'Deep';
    final isClear = colourClarity >= 10.5 || skinChroma >= 42;
    final isMuted = colourClarity <= 8.0 || skinChroma <= 28;

    if (isWarm && isLight && isClear) return 'Spring';
    if (isWarm && isDeep && (isMuted || contrast != 'High')) return 'Autumn';
    if (isCool && isLight && (isMuted || contrast == 'Low')) return 'Summer';
    if (isCool && isDeep && isClear) return 'Winter';

    if (isWarm) return isLight ? 'Spring' : 'Autumn';
    if (isCool) return isLight ? 'Summer' : 'Winter';

    if (isLight) return contrast == 'High' ? 'Spring' : 'Summer';
    if (isDeep) return contrast == 'High' ? 'Winter' : 'Autumn';
    return isMuted ? 'Summer' : (contrast == 'High' ? 'Winter' : 'Autumn');
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

  String get warmthLabel {
    if (warmthScore >= 36) return 'Warm';
    if (warmthScore <= 23) return 'Cool';
    return 'Neutral';
  }

  String get brightnessLabel {
    if (skinLuminance >= 184) return 'Light';
    if (skinLuminance >= 118) return 'Medium';
    return 'Deep';
  }

  String get contrastLabel {
    final value = math.max(skinToDarkContrast, globalRange * .55);
    if (value >= 105) return 'High';
    if (value >= 62) return 'Medium';
    return 'Low';
  }

  String get clarityLabel {
    if (colourClarity >= 10.5) return 'Clear, lively colouring detected';
    if (colourClarity <= 8) return 'Soft, muted colouring detected';
    return 'Balanced colour clarity detected';
  }
}
