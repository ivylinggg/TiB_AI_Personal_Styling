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
    final temperature = _temperature(undertone, sample);
    final season = _season(
      undertone: undertone,
      brightness: brightness,
      contrast: contrast,
      chroma: chroma,
      clarity: clarity,
    );
    final guide = SeasonColourGuide.forSeason(season);

    final reasons = <String>[
      '${_titleCase(temperature)} facial colouring detected from ${sample.skinCount} sampled skin pixels',
      '${_titleCase(brightness)} overall skin value detected',
      '${_titleCase(contrast)} natural facial contrast detected',
      '${_titleCase(chroma)} colour intensity detected',
      '${_titleCase(clarity)} colour clarity detected',
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

    final left = (width * 0.16).round().clamp(0, width - 1).toInt();
    final right = (width * 0.84).round().clamp(left + 1, width).toInt();
    final top = (height * 0.10).round().clamp(0, height - 1).toInt();
    final bottom = (height * 0.78).round().clamp(top + 1, height).toInt();

    final skinPixels = <_ColourPixel>[];
    var redHigh = 0.0;
    var redGreen = 0.0;
    var blueLow = 0.0;

    for (var y = top; y < bottom; y += 3) {
      for (var x = left; x < right; x += 3) {
        final p = image.getPixel(x, y);
        final rgb = _ColourPixel(
          r: p.r.toDouble(),
          g: p.g.toDouble(),
          b: p.b.toDouble(),
        );
        if (!_looksLikeSkin(rgb.r, rgb.g, rgb.b)) continue;
        skinPixels.add(rgb);
        redHigh += rgb.r;
        redGreen += rgb.r - rgb.g;
        blueLow += rgb.g - rgb.b;
      }
    }

    if (skinPixels.length < 20) return _PortraitSample.empty();

    final average = skinPixels.reduce((a, b) => _ColourPixel(
          r: a.r + b.r,
          g: a.g + b.g,
          b: a.b + b.b,
        ));
    final count = skinPixels.length.toDouble();
    final avg = _ColourPixel(
      r: average.r / count,
      g: average.g / count,
      b: average.b / count,
    );

    final luminances = skinPixels.map((p) => _luminance(p.r, p.g, p.b)).toList();
    luminances.sort();
    final p20 = luminances[(luminances.length * .20).floor()];
    final p50 = luminances[(luminances.length * .50).floor()];
    final p80 = luminances[(luminances.length * .80).floor()];

    var imageDarkest = 255.0;
    var imageLightest = 0.0;
    var facialDark = 0.0;
    var facialLight = 0.0;
    var facialDarkCount = 0;
    var facialLightCount = 0;

    for (var y = 0; y < height; y += 10) {
      for (var x = 0; x < width; x += 10) {
        final p = image.getPixel(x, y);
        final value = _luminance(p.r.toDouble(), p.g.toDouble(), p.b.toDouble());
        imageDarkest = math.min(imageDarkest, value);
        imageLightest = math.max(imageLightest, value);

        if (x >= left && x <= right && y >= top && y <= bottom) {
          if (value < p20 * .82) {
            facialDark += value;
            facialDarkCount++;
          }
          if (value > p80 * 1.08) {
            facialLight += value;
            facialLightCount++;
          }
        }
      }
    }

    final darkReference = facialDarkCount > 0 ? facialDark / facialDarkCount : p20;
    final lightReference = facialLightCount > 0 ? facialLight / facialLightCount : p80;
    final skinSpread = math.max(0.0, p80 - p20);
    final skinContrast = math.max(
      0.0,
      math.max(p80 - darkReference, lightReference - p20),
    );

    final avgWarmth = ((redHigh / count) - avg.b) * .58 +
        (redGreen / count) * .27 +
        (blueLow / count) * .15;

    final avgChroma = skinPixels
            .map((p) => math.max(p.r, math.max(p.g, p.b)) - math.min(p.r, math.min(p.g, p.b)))
            .reduce((a, b) => a + b) /
        count;

    final claritySignal = (avgChroma / math.max(p50, 1)) * 100.0;
    final neutralitySignal = ((avg.r - avg.b).abs() / math.max(avg.r + avg.g + avg.b, 1)) * 1000.0;

    return _PortraitSample(
      skinToneValue: p50,
      skinMeanLuminance: _luminance(avg.r, avg.g, avg.b),
      skinSpread: skinSpread,
      skinContrast: skinContrast,
      averageWarmth: avgWarmth,
      averageChroma: avgChroma,
      claritySignal: claritySignal,
      neutralitySignal: neutralitySignal,
      globalRange: imageLightest - imageDarkest,
      skinCount: skinPixels.length,
    );
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

    final hueLike = nr > .27 && nr < .58 && ng > .20 && ng < .44 && nb < .36;
    final redDominant = r >= g * .92 && g >= b * .92;
    return hueLike && redDominant;
  }

  static String _undertone(_PortraitSample sample) {
    if (sample.averageWarmth >= 34) return 'Warm';
    if (sample.averageWarmth <= 22) return 'Cool';
    return 'Neutral';
  }

  static String _brightness(double value) {
    if (value >= 188) return 'Light';
    if (value >= 125) return 'Medium';
    if (value >= 78) return 'Medium-Deep';
    return 'Deep';
  }

  static String _contrast(_PortraitSample sample) {
    final score = math.max(sample.skinContrast, sample.globalRange * .42);
    if (score >= 112) return 'High';
    if (score >= 62) return 'Medium';
    return 'Low';
  }

  static String _chroma(_PortraitSample sample) {
    if (sample.averageChroma >= 44) return 'High';
    if (sample.averageChroma >= 31) return 'Medium';
    return 'Low';
  }

  static String _clarity(_PortraitSample sample) {
    if (sample.claritySignal >= 11.0 && sample.skinSpread >= 20) return 'Clear';
    if (sample.claritySignal <= 7.8 || sample.skinSpread < 12) return 'Soft';
    return 'Balanced';
  }

  static String _temperature(String undertone, _PortraitSample sample) {
    if (undertone == 'Warm' && sample.averageChroma >= 31) return 'Warm and vibrant';
    if (undertone == 'Cool' && sample.averageChroma >= 31) return 'Cool and defined';
    if (undertone == 'Neutral') return 'Balanced neutral';
    return undertone;
  }

  static String _season({
    required String undertone,
    required String brightness,
    required String contrast,
    required String chroma,
    required String clarity,
  }) {
    final highChroma = chroma == 'High';
    final soft = clarity == 'Soft';
    final clear = clarity == 'Clear';

    if (undertone == 'Warm') {
      if ((brightness == 'Light' || brightness == 'Medium') && highChroma && clear) {
        return 'Spring';
      }
      if (brightness == 'Deep' || brightness == 'Medium-Deep' || soft) {
        return 'Autumn';
      }
      return contrast == 'High' && highChroma ? 'Spring' : 'Autumn';
    }

    if (undertone == 'Cool') {
      if (brightness == 'Light' && soft) return 'Summer';
      if (brightness == 'Deep' || brightness == 'Medium-Deep' || (clear && highChroma)) {
        return 'Winter';
      }
      return contrast == 'Low' ? 'Summer' : 'Winter';
    }

    // Neutral undertones are refined by value + clarity rather than forced
    // into a warm/cool family using skin depth alone.
    if (brightness == 'Light') return soft ? 'Summer' : 'Spring';
    if (brightness == 'Deep' || brightness == 'Medium-Deep') {
      return clear && contrast == 'High' ? 'Winter' : 'Autumn';
    }
    if (soft) return 'Summer';
    return contrast == 'High' && highChroma ? 'Winter' : 'Autumn';
  }

  static String _titleCase(String value) {
    if (value.isEmpty) return value;
    return value[0].toUpperCase() + value.substring(1);
  }
}

class _ColourPixel {
  final double r;
  final double g;
  final double b;

  const _ColourPixel({required this.r, required this.g, required this.b});
}

class _PortraitSample {
  final double skinToneValue;
  final double skinMeanLuminance;
  final double skinSpread;
  final double skinContrast;
  final double averageWarmth;
  final double averageChroma;
  final double claritySignal;
  final double neutralitySignal;
  final double globalRange;
  final int skinCount;

  const _PortraitSample({
    required this.skinToneValue,
    required this.skinMeanLuminance,
    required this.skinSpread,
    required this.skinContrast,
    required this.averageWarmth,
    required this.averageChroma,
    required this.claritySignal,
    required this.neutralitySignal,
    required this.globalRange,
    required this.skinCount,
  });

  factory _PortraitSample.empty() => const _PortraitSample(
        skinToneValue: 0,
        skinMeanLuminance: 0,
        skinSpread: 0,
        skinContrast: 0,
        averageWarmth: 0,
        averageChroma: 0,
        claritySignal: 0,
        neutralitySignal: 0,
        globalRange: 0,
        skinCount: 0,
      );

  bool get isUsable => skinCount >= 20 && skinMeanLuminance > 0;
}
