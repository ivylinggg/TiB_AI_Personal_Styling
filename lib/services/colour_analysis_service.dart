import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart' as img;

import '../models/colour_analysis_result.dart';

class ColourAnalysisService {
  ColourAnalysisService._();

  /// Performs a deterministic image-based colour analysis.
  ///
  /// This is intentionally kept inside the service layer so the UI/provider
  /// does not contain analysis logic. It is not a trained AI model; it uses
  /// sampled facial-area colours to estimate undertone, brightness and
  /// contrast and then maps those measurements to a seasonal palette.
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

    final sample = _sampleSkinRegion(source);

    if (sample.count == 0) {
      throw const FormatException(
        'Unable to analyse the selected image. Please use a clear portrait photo.',
      );
    }

    final brightness = _brightness(sample.luminance);
    final undertone = _undertone(sample.red, sample.green, sample.blue);
    final contrast = _contrast(source);
    final season = _season(
      undertone: undertone,
      brightness: brightness,
      contrast: contrast,
    );

    return ColourAnalysisResult(
      season: season,
      undertone: undertone,
      brightness: brightness,
      contrast: contrast,
      imageUrl: imageUrl,
      colours: _paletteForSeason(season),
    );
  }

  static _ColourSample _sampleSkinRegion(img.Image image) {
    final left = (image.width * 0.25).round();
    final right = (image.width * 0.75).round();
    final top = (image.height * 0.22).round();
    final bottom = (image.height * 0.62).round();

    var red = 0.0;
    var green = 0.0;
    var blue = 0.0;
    var luminance = 0.0;
    var count = 0;

    // Sample every few pixels to keep analysis fast on mobile.
    for (var y = top; y < bottom; y += 8) {
      for (var x = left; x < right; x += 8) {
        final pixel = image.getPixel(x, y);
        final r = pixel.r.toDouble();
        final g = pixel.g.toDouble();
        final b = pixel.b.toDouble();

        if (!_looksLikeSkin(r, g, b)) continue;

        red += r;
        green += g;
        blue += b;
        luminance += (0.2126 * r) + (0.7152 * g) + (0.0722 * b);
        count++;
      }
    }

    if (count == 0) {
      return _ColourSample.empty();
    }

    return _ColourSample(
      red: red / count,
      green: green / count,
      blue: blue / count,
      luminance: luminance / count,
      count: count,
    );
  }

  static bool _looksLikeSkin(double r, double g, double b) {
    final maxValue = math.max(r, math.max(g, b));
    final minValue = math.min(r, math.min(g, b));

    if (maxValue - minValue < 12) return false;
    if (r < 60 || g < 35 || b < 25) return false;

    return r > g * 0.92 && g > b * 0.95;
  }

  static String _undertone(
    double red,
    double green,
    double blue,
  ) {
    final warmScore = ((red - blue) + (green - blue)) / 2;
    final coolScore = blue - ((red + green) / 2);

    if ((warmScore - coolScore).abs() < 12) {
      return 'Neutral';
    }

    return warmScore > coolScore ? 'Warm' : 'Cool';
  }

  static String _brightness(double luminance) {
    if (luminance >= 190) return 'Light';
    if (luminance >= 135) return 'Medium';
    return 'Deep';
  }

  static String _contrast(img.Image image) {
    final values = <double>[];

    for (var y = 0; y < image.height; y += 16) {
      for (var x = 0; x < image.width; x += 16) {
        final p = image.getPixel(x, y);
        values.add(
          (0.2126 * p.r) +
              (0.7152 * p.g) +
              (0.0722 * p.b),
        );
      }
    }

    if (values.length < 2) return 'Medium';

    var minValue = values.first;
    var maxValue = values.first;

    for (final value in values) {
      minValue = math.min(minValue, value);
      maxValue = math.max(maxValue, value);
    }

    final range = maxValue - minValue;

    if (range >= 150) return 'High';
    if (range >= 90) return 'Medium';
    return 'Low';
  }

  static String _season({
    required String undertone,
    required String brightness,
    required String contrast,
  }) {
    if (undertone == 'Warm') {
      if (brightness == 'Light') return 'Warm Spring';
      if (contrast == 'High') return 'Warm Autumn';
      return 'Warm Autumn';
    }

    if (undertone == 'Cool') {
      if (brightness == 'Light') return 'Cool Summer';
      return 'Cool Winter';
    }

    if (brightness == 'Light') return 'Soft Summer';
    if (contrast == 'High') return 'Clear Winter';
    return 'Soft Autumn';
  }

  static List<String> _paletteForSeason(String season) {
    switch (season) {
      case 'Warm Spring':
        return const ['Peach', 'Coral', 'Cream', 'Camel', 'Olive'];
      case 'Warm Autumn':
        return const ['Terracotta', 'Rust', 'Camel', 'Mustard', 'Olive'];
      case 'Cool Summer':
        return const ['Rose', 'Mauve', 'Dusty Blue', 'Lavender', 'Soft Grey'];
      case 'Cool Winter':
        return const ['Berry', 'Navy', 'Emerald', 'Charcoal', 'Crisp White'];
      case 'Clear Winter':
        return const ['Ruby', 'Cobalt', 'Emerald', 'Black', 'Pure White'];
      case 'Soft Summer':
        return const ['Dusty Rose', 'Sage', 'Mauve', 'Powder Blue', 'Taupe'];
      default:
        return const ['Terracotta', 'Olive', 'Cream', 'Camel', 'Warm Rose'];
    }
  }
}

class _ColourSample {
  final double red;
  final double green;
  final double blue;
  final double luminance;
  final int count;

  const _ColourSample({
    required this.red,
    required this.green,
    required this.blue,
    required this.luminance,
    required this.count,
  });

  factory _ColourSample.empty() {
    return const _ColourSample(
      red: 0,
      green: 0,
      blue: 0,
      luminance: 0,
      count: 0,
    );
  }
}
