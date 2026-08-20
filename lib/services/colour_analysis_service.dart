import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart' as img;

import '../data/season_colour_guide.dart';
import '../models/colour_analysis_result.dart';

class ColourAnalysisService {
  ColourAnalysisService._();

  /// Analyses the selected portrait image using the detected facial-area
  /// colours plus overall brightness/contrast, then maps the result to the
  /// four-season framework from the user's colour guide:
  ///
  /// Winter  = Deep • Cool • Clear
  /// Summer  = Soft • Cool • Light
  /// Spring  = Light • Warm • Clear
  /// Autumn  = Deep • Warm • Muted
  ///
  /// This remains an on-device deterministic analysis rather than a trained
  /// vision model. The existing ML Kit face detection in AnalysisProvider is
  /// still used first to ensure there is exactly one face in the source image.
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

  static _ColourSample _sampleSkinRegion(img.Image image) {
    final left = (image.width * 0.25).round();
    final right = (image.width * 0.75).round();
    final top = (image.height * 0.18).round();
    final bottom = (image.height * 0.68).round();

    var red = 0.0;
    var green = 0.0;
    var blue = 0.0;
    var luminance = 0.0;
    var count = 0;

    for (var y = top; y < bottom; y += 6) {
      for (var x = left; x < right; x += 6) {
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

    if (count == 0) return _ColourSample.empty();

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
    if (r < 55 || g < 30 || b < 20) return false;

    return r > g * 0.90 && g > b * 0.92;
  }

  static String _undertone(double red, double green, double blue) {
    final warmScore = ((red - blue) + (green - blue)) / 2;
    final coolScore = blue - ((red + green) / 2);
    final difference = warmScore - coolScore;

    if (difference.abs() < 16) return 'Neutral';
    return difference > 0 ? 'Warm' : 'Cool';
  }

  static String _brightness(double luminance) {
    if (luminance >= 190) return 'Light';
    if (luminance >= 132) return 'Medium';
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
    if (range >= 95) return 'Medium';
    return 'Low';
  }

  static String _season({
    required String undertone,
    required String brightness,
    required String contrast,
  }) {
    if (undertone == 'Warm') {
      // PDF standard: Spring = Light/Warm/Clear; Autumn = Deep/Warm/Muted.
      return brightness == 'Light' && contrast != 'Low' ? 'Spring' : 'Autumn';
    }

    if (undertone == 'Cool') {
      // PDF standard: Summer = Soft/Cool/Light; Winter = Deep/Cool/Clear.
      return brightness == 'Light' && contrast != 'High' ? 'Summer' : 'Winter';
    }

    // Neutral undertones need a visual tie-breaker. Light/soft colouring is
    // placed into Summer, while deeper/high-contrast colouring is placed into
    // Winter; medium/deep lower-contrast colouring leans Autumn.
    if (brightness == 'Light' && contrast != 'High') return 'Summer';
    if (contrast == 'High') return brightness == 'Light' ? 'Spring' : 'Winter';
    if (brightness == 'Deep') return 'Autumn';
    return 'Autumn';
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
