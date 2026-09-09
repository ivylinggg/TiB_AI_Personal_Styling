import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart' as img;

import '../data/season_colour_guide.dart';
import '../models/colour_analysis_result.dart';

/// Local personal-colour analysis based on the observed face/skin image.
/// This is a heuristic photo analysis, not a clinical or laboratory colour test.
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
    if (!sample.isUsable) {
      throw const FormatException(
        'Unable to reliably analyse this photo. Please use one clear, front-facing portrait in even natural light.',
      );
    }

    final undertone = _undertone(sample);
    final brightness = _brightness(sample.skinToneValue);
    final contrast = _contrast(sample);
    final chroma = _chroma(sample);
    final clarity = _clarity(sample);
    final season = _season(
      undertone: undertone,
      brightness: brightness,
      contrast: contrast,
      chroma: chroma,
      clarity: clarity,
      skinValue: sample.skinToneValue,
      warmRatio: sample.warmRatio,
      coolRatio: sample.coolRatio,
      neutralRatio: sample.neutralRatio,
      averageChroma: sample.averageChroma,
    );
    final guide = SeasonColourGuide.forSeason(season);

    final reasons = <String>[
      '${_titleCase(undertone)} undertone signal from ${sample.skinCount} sampled skin pixels',
      '${_titleCase(brightness)} skin value detected',
      '${_titleCase(contrast)} natural facial contrast detected',
      '${_titleCase(chroma)} colour intensity detected',
      '${_titleCase(clarity)} colour clarity detected',
      'Primary season selected from the combined observed colour characteristics',
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
    final width = image.width;
    final height = image.height;
    if (width < 32 || height < 32) return _PortraitSample.empty();

    // Sample the central portrait region instead of the whole image so
    // background, clothing and large white/black areas do not dominate.
    final left = (width * .16).round().clamp(0, width - 1).toInt();
    final right = (width * .84).round().clamp(left + 1, width).toInt();
    final top = (height * .10).round().clamp(0, height - 1).toInt();
    final bottom = (height * .78).round().clamp(top + 1, height).toInt();

    final skinPixels = <_ColourPixel>[];
    var warmPixels = 0;
    var coolPixels = 0;
    var neutralPixels = 0;

    for (var y = top; y < bottom; y += 2) {
      for (var x = left; x < right; x += 2) {
        final p = image.getPixel(x, y);
        final rgb = _ColourPixel(
          r: p.r.toDouble(),
          g: p.g.toDouble(),
          b: p.b.toDouble(),
        );
        if (!_looksLikeSkin(rgb.r, rgb.g, rgb.b)) continue;
        skinPixels.add(rgb);

        final temperature = _pixelTemperature(rgb.r, rgb.g, rgb.b);
        if (temperature > 0.045) {
          warmPixels++;
        } else if (temperature < -0.018) {
          coolPixels++;
        } else {
          neutralPixels++;
        }
      }
    }

    if (skinPixels.length < 40) return _PortraitSample.empty();

    final count = skinPixels.length.toDouble();
    final average = skinPixels.reduce(
      (a, b) => _ColourPixel(r: a.r + b.r, g: a.g + b.g, b: a.b + b.b),
    );
    final avg = _ColourPixel(
      r: average.r / count,
      g: average.g / count,
      b: average.b / count,
    );

    final luminances = skinPixels
        .map((p) => _luminance(p.r, p.g, p.b))
        .toList()
      ..sort();
    final p15 = luminances[(luminances.length * .15).floor()];
    final p50 = luminances[(luminances.length * .50).floor()];
    final p85 = luminances[(luminances.length * .85).floor()];

    var imageDarkest = 255.0;
    var imageLightest = 0.0;
    var facialDark = 0.0;
    var facialLight = 0.0;
    var facialDarkCount = 0;
    var facialLightCount = 0;

    for (var y = 0; y < height; y += 8) {
      for (var x = 0; x < width; x += 8) {
        final p = image.getPixel(x, y);
        final r = p.r.toDouble();
        final g = p.g.toDouble();
        final b = p.b.toDouble();
        final value = _luminance(r, g, b);
        imageDarkest = math.min(imageDarkest, value);
        imageLightest = math.max(imageLightest, value);

        if (x >= left && x <= right && y >= top && y <= bottom) {
          if (value < p15 * .86) {
            facialDark += value;
            facialDarkCount++;
          }
          if (value > p85 * 1.05) {
            facialLight += value;
            facialLightCount++;
          }
        }
      }
    }

    final darkReference = facialDarkCount > 0 ? facialDark / facialDarkCount : p15;
    final lightReference = facialLightCount > 0 ? facialLight / facialLightCount : p85;
    final skinSpread = math.max(0.0, p85 - p15);
    final skinContrast = math.max(
      0.0,
      math.max(p85 - darkReference, lightReference - p15),
    );

    final averageChroma = skinPixels
            .map((p) => math.max(p.r, math.max(p.g, p.b)) - math.min(p.r, math.min(p.g, p.b)))
            .reduce((a, b) => a + b) /
        count;
    final claritySignal = (averageChroma / math.max(p50, 1)) * 100.0;

    return _PortraitSample(
      skinToneValue: p50,
      skinMeanLuminance: _luminance(avg.r, avg.g, avg.b),
      skinSpread: skinSpread,
      skinContrast: skinContrast,
      warmRatio: warmPixels / count,
      coolRatio: coolPixels / count,
      neutralRatio: neutralPixels / count,
      averageChroma: averageChroma,
      claritySignal: claritySignal,
      globalRange: imageLightest - imageDarkest,
      skinCount: skinPixels.length,
    );
  }

  static double _pixelTemperature(double r, double g, double b) {
    final sum = math.max(r + g + b, 1.0);
    // Warm skin tends to show stronger red/yellow relative to blue; cool skin
    // has a comparatively smaller warm-channel advantage. Normalising keeps the
    // signal less sensitive to exposure.
    return ((r - b) * .62 + (g - b) * .38) / sum;
  }

  static double _luminance(double r, double g, double b) {
    final maxChannel = math.max(r, math.max(g, b));
    if (maxChannel <= 1.0) {
      return (0.2126 * r + 0.7152 * g + 0.0722 * b) * 255.0;
    }
    return 0.2126 * r + 0.7152 * g + 0.0722 * b;
  }

  static bool _looksLikeSkin(double r, double g, double b) {
    final maxValue = math.max(r, math.max(g, b));
    final minValue = math.min(r, math.min(g, b));
    if (maxValue < 35 || maxValue - minValue < 10) return false;
    final sum = r + g + b;
    if (sum <= 0) return false;

    final nr = r / sum;
    final ng = g / sum;
    final nb = b / sum;
    final hueLike = nr > .27 && nr < .62 && ng > .19 && ng < .45 && nb < .38;
    final channelOrder = r >= g * .88 && g >= b * .88;
    return hueLike && channelOrder;
  }

  static String _undertone(_PortraitSample sample) {
    final warm = sample.warmRatio;
    final cool = sample.coolRatio;
    final neutral = sample.neutralRatio;
    if (warm > cool + .09 && warm >= neutral * .9) return 'Warm';
    if (cool > warm + .09 && cool >= neutral * .9) return 'Cool';
    return 'Neutral';
  }

  static String _brightness(double value) {
    if (value >= 205) return 'Light';
    if (value >= 148) return 'Medium';
    if (value >= 92) return 'Medium-Deep';
    return 'Deep';
  }

  static String _contrast(_PortraitSample sample) {
    final score = math.max(sample.skinContrast, sample.globalRange * .30);
    if (score >= 108) return 'High';
    if (score >= 58) return 'Medium';
    return 'Low';
  }

  static String _chroma(_PortraitSample sample) {
    if (sample.averageChroma >= 50) return 'High';
    if (sample.averageChroma >= 34) return 'Medium';
    return 'Low';
  }

  static String _clarity(_PortraitSample sample) {
    if (sample.claritySignal >= 12 && sample.skinSpread >= 24) return 'Clear';
    if (sample.claritySignal <= 8.0 || sample.skinSpread < 14) return 'Soft';
    return 'Balanced';
  }

  static String _season({
    required String undertone,
    required String brightness,
    required String contrast,
    required String chroma,
    required String clarity,
    required double skinValue,
    required double warmRatio,
    required double coolRatio,
    required double neutralRatio,
    required double averageChroma,
  }) {
    final warm = warmRatio;
    final cool = coolRatio;
    final neutral = neutralRatio;
    final warmthLead = warm - cool;
    final coolnessLead = cool - warm;
    final highChroma = chroma == 'High';
    final mediumChroma = chroma == 'Medium';
    final soft = clarity == 'Soft';
    final clear = clarity == 'Clear';
    final highContrast = contrast == 'High';
    final mediumContrast = contrast == 'Medium';
    final light = brightness == 'Light';
    final deep = brightness == 'Deep' || brightness == 'Medium-Deep';

    final scores = <String, double>{
      'Spring':
          (warmthLead > .02 ? 3.0 : 0) +
          (light ? 2.4 : 0) +
          (highChroma ? 2.0 : 0) +
          (clear ? 1.7 : 0) +
          (mediumContrast ? .6 : 0) +
          (skinValue >= 155 ? .8 : 0),
      'Summer':
          (coolnessLead > .02 ? 3.0 : 0) +
          (light ? 2.2 : 0) +
          (soft ? 2.1 : 0) +
          (!highContrast ? 1.0 : 0) +
          (!highChroma ? 1.0 : 0) +
          (skinValue >= 140 ? .7 : 0),
      'Autumn':
          (warmthLead > .02 ? 2.6 : 0) +
          (deep ? 2.4 : 0) +
          (soft ? 2.0 : 0) +
          (!highChroma ? 1.0 : 0) +
          (averageChroma < 42 ? .8 : 0) +
          (skinValue < 165 ? .6 : 0),
      'Winter':
          (coolnessLead > .02 ? 2.8 : 0) +
          (deep ? 2.2 : 0) +
          (highContrast ? 2.3 : 0) +
          (highChroma ? 1.9 : 0) +
          (clear ? 1.7 : 0) +
          (skinValue < 165 ? .6 : 0),
    };

    // Neutral undertones require secondary dimensions to separate Spring/Autumn
    // from Summer/Winter. Do not silently treat neutral as cool.
    if (undertone == 'Neutral') {
      scores['Spring'] = scores['Spring']! + (light && !soft ? 1.2 : 0) + (highChroma ? .6 : 0);
      scores['Summer'] = scores['Summer']! + (light && soft ? 1.4 : 0) + (!mediumChroma && !highChroma ? .5 : 0);
      scores['Autumn'] = scores['Autumn']! + (deep && soft ? 1.3 : 0);
      scores['Winter'] = scores['Winter']! + (deep && highContrast && highChroma ? 1.2 : 0);
    }

    // A weak temperature lead should not be allowed to manufacture a cool/warm
    // result from tiny measurement noise. In that case value/contrast/clarity
    // decide between adjacent seasons.
    if (math.max(warm, cool) - neutral < .03) {
      if (light && soft) return 'Summer';
      if (light && clear && highChroma) return 'Spring';
      if (deep && soft) return 'Autumn';
      if (deep && clear && highContrast && highChroma) return 'Winter';
    }

    return scores.entries.reduce(
      (best, entry) => entry.value > best.value ? entry : best,
    ).key;
  }

  static String _titleCase(String value) =>
      value.isEmpty ? value : value[0].toUpperCase() + value.substring(1);
}

class _ColourPixel {
  final double r, g, b;
  const _ColourPixel({required this.r, required this.g, required this.b});
}

class _PortraitSample {
  final double skinToneValue;
  final double skinMeanLuminance;
  final double skinSpread;
  final double skinContrast;
  final double warmRatio;
  final double coolRatio;
  final double neutralRatio;
  final double averageChroma;
  final double claritySignal;
  final double globalRange;
  final int skinCount;

  const _PortraitSample({
    required this.skinToneValue,
    required this.skinMeanLuminance,
    required this.skinSpread,
    required this.skinContrast,
    required this.warmRatio,
    required this.coolRatio,
    required this.neutralRatio,
    required this.averageChroma,
    required this.claritySignal,
    required this.globalRange,
    required this.skinCount,
  });

  factory _PortraitSample.empty() => const _PortraitSample(
        skinToneValue: 0,
        skinMeanLuminance: 0,
        skinSpread: 0,
        skinContrast: 0,
        warmRatio: 0,
        coolRatio: 0,
        neutralRatio: 0,
        averageChroma: 0,
        claritySignal: 0,
        globalRange: 0,
        skinCount: 0,
      );

  bool get isUsable => skinCount >= 40 && skinMeanLuminance > 0;
}
