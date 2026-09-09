import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart' as img;

/// Conservative client-side guard for Wardrobe uploads.
/// The validator is not a substitute for a dedicated vision model.
class WardrobeImageValidationService {
  WardrobeImageValidationService._();

  static const int _sampleWidth = 96;
  static const double _minForegroundRatio = 0.035;
  static const double _maxFlatSceneRatio = 0.82;

  static const List<String> allowedCategories = [
    'Tops',
    'Bottoms',
    'Dresses',
    'Suits',
    'Jackets',
    'Skirts',
    'Shoes',
    'Accessories',
  ];

  static Future<String?> validate(File file, {String? category}) async {
    if (!file.existsSync()) {
      return 'We could not read that photo. Please choose another image.';
    }

    if (category != null && !allowedCategories.contains(category)) {
      return 'Only clothing and fashion accessories can be added to Wardrobe.';
    }

    try {
      final decoded = img.decodeImage(await file.readAsBytes());
      if (decoded == null) {
        return 'This image format is not supported. Please choose another photo.';
      }

      final oriented = img.bakeOrientation(decoded);
      final sampleHeight = math.max(
        1,
        (oriented.height * _sampleWidth / oriented.width).round(),
      );
      final sample = img.copyResize(
        oriented,
        width: _sampleWidth,
        height: sampleHeight,
      );

      final result = _analyse(sample);

      if (result.foregroundRatio < _minForegroundRatio) {
        return 'This does not look like a clear clothing or fashion-accessory photo. Please upload one wearable item.';
      }

      if (result.foregroundRatio > _maxFlatSceneRatio && result.edgeContrast < 0.07) {
        return 'Please use a clearer photo with the clothing or accessory separated from the background.';
      }

      if (result.skinRatio > 0.24 && result.skinRatio > result.colouredObjectRatio * 1.35) {
        return 'Please upload the clothing or accessory itself, not a portrait or unrelated photo.';
      }

      return null;
    } catch (_) {
      return 'We could not analyse that photo. Please choose a clear clothing or accessory image.';
    }
  }

  static _ImageAnalysis _analyse(img.Image image) {
    var foreground = 0;
    var skinLike = 0;
    var colouredObject = 0;
    var edgeSum = 0.0;
    var edgeCount = 0;
    final total = image.width * image.height;

    int luminance(img.Pixel p) =>
        (0.2126 * p.r + 0.7152 * p.g + 0.0722 * p.b).round();

    bool skinLike(img.Pixel p) {
      final r = p.r.toDouble();
      final g = p.g.toDouble();
      final b = p.b.toDouble();
      final maxC = math.max(r, math.max(g, b));
      final minC = math.min(r, math.min(g, b));
      return r > g && g > b &&
          r - b > 18 &&
          maxC - minC > 20 &&
          r > 70 &&
          g > 35;
    }

    for (var y = 0; y < image.height; y++) {
      for (var x = 0; x < image.width; x++) {
        final p = image.getPixel(x, y);
        final l = luminance(p);
        final maxC = math.max(p.r, math.max(p.g, p.b)).toDouble();
        final minC = math.min(p.r, math.min(p.g, p.b)).toDouble();
        final chroma = (maxC - minC) / 255;

        // Treat mid-tone / chromatic pixels as likely foreground. Extreme
        // black or white pixels can still be clothing, so keep them when
        // nearby edge contrast supports a real object boundary.
        if (chroma > 0.12 || (l > 38 && l < 224)) foreground++;
        if (chroma > 0.22 && l > 30 && l < 230) colouredObject++;
        if (skinLike(p)) skinLike++;

        if (x + 2 < image.width) {
          edgeSum += (l - luminance(image.getPixel(x + 2, y))).abs() / 255;
          edgeCount++;
        }
        if (y + 2 < image.height) {
          edgeSum += (l - luminance(image.getPixel(x, y + 2))).abs() / 255;
          edgeCount++;
        }
      }
    }

    return _ImageAnalysis(
      foregroundRatio: total == 0 ? 0 : foreground / total,
      skinRatio: total == 0 ? 0 : skinLike / total,
      colouredObjectRatio: total == 0 ? 0 : colouredObject / total,
      edgeContrast: edgeCount == 0 ? 0 : edgeSum / edgeCount,
    );
  }
}

class _ImageAnalysis {
  const _ImageAnalysis({
    required this.foregroundRatio,
    required this.skinRatio,
    required this.colouredObjectRatio,
    required this.edgeContrast,
  });

  final double foregroundRatio;
  final double skinRatio;
  final double colouredObjectRatio;
  final double edgeContrast;
}
