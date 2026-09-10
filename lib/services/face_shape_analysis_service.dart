import 'dart:io';
import 'dart:math' as math;

import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

/// Face-shape classification based on four standard front-facing measurements:
/// face length, forehead width, cheekbone width and jaw width.
///
/// Online face-shape references consistently use these proportions and the
/// widest facial region to distinguish the common styling categories. Their
/// exact boundaries vary, so this service uses reference profiles rather than
/// brittle one-rule cut-offs.
class FaceShapeAnalysis {
  final String shape;
  final String description;
  final Map<String, double> measurements;
  final List<String> stylingGuidance;

  const FaceShapeAnalysis({
    required this.shape,
    required this.description,
    required this.measurements,
    required this.stylingGuidance,
  });

  Map<String, dynamic> toMap() => {
        'shape': shape,
        'description': description,
        'measurements': measurements,
        'stylingGuidance': stylingGuidance,
      };
}

class FaceShapeAnalysisService {
  FaceShapeAnalysisService._();

  static const _profiles = <String, List<double>>{
    // length / cheekbone, forehead / cheekbone, jaw / cheekbone
    'Oval': [1.38, .92, .82],
    'Round': [1.06, .90, .88],
    'Square': [1.10, .96, .97],
    'Heart': [1.22, 1.00, .72],
    'Diamond': [1.27, .78, .74],
    'Oblong': [1.58, .90, .84],
    'Triangle': [1.16, .78, 1.02],
  };

  static Future<FaceShapeAnalysis> analyse({
    required File image,
    required List<Face> faces,
  }) async {
    if (faces.length != 1) {
      throw const FormatException(
        'Please use a clear photo with one front-facing face.',
      );
    }

    final face = faces.single;
    final contour = face.contours[FaceContourType.face];
    if (contour == null || contour.points.length < 24) {
      throw const FormatException(
        'Face outline could not be measured reliably. Please use a front-facing photo with your full face visible.',
      );
    }

    final points = contour.points;
    final left = points.map((p) => p.x.toDouble()).reduce(math.min);
    final right = points.map((p) => p.x.toDouble()).reduce(math.max);
    final top = points.map((p) => p.y.toDouble()).reduce(math.min);
    final bottom = points.map((p) => p.y.toDouble()).reduce(math.max);
    final width = math.max(1.0, right - left);
    final height = math.max(1.0, bottom - top);

    // The contour can be sparse at arbitrary Y positions. We therefore take
    // a local width around each measurement level rather than relying on one
    // exact contour point.
    double widthAt(double relativeY) {
      final targetY = top + height * relativeY;
      final tolerance = height * .055;
      final near = points
          .where((p) => (p.y - targetY).abs() <= tolerance)
          .toList();
      if (near.length < 2) return width * .5;
      final minX = near.map((p) => p.x.toDouble()).reduce(math.min);
      final maxX = near.map((p) => p.x.toDouble()).reduce(math.max);
      return math.max(1.0, maxX - minX);
    }

    final foreheadWidth = widthAt(.28);
    final cheekboneWidth = _robustCheekWidth(points, top, height, width);
    final jawWidth = widthAt(.72);
    final chinWidth = widthAt(.86);

    final faceRatio = height / width;
    final foreheadToCheek = foreheadWidth / cheekboneWidth;
    final jawToCheek = jawWidth / cheekboneWidth;
    final chinToJaw = chinWidth / jawWidth;

    final shape = _classify(
      faceRatio: faceRatio,
      foreheadToCheek: foreheadToCheek,
      jawToCheek: jawToCheek,
      chinToJaw: chinToJaw,
    );

    final confidence = _confidence(
      shape: shape,
      faceRatio: faceRatio,
      foreheadToCheek: foreheadToCheek,
      jawToCheek: jawToCheek,
    );

    return FaceShapeAnalysis(
      shape: shape,
      description: _description[shape]!,
      measurements: {
        'faceRatio': _round(faceRatio),
        'foreheadToCheek': _round(foreheadToCheek),
        'cheekboneWidthRatio': _round(cheekboneWidth / width),
        'jawToCheek': _round(jawToCheek),
        'chinToJaw': _round(chinToJaw),
        'measurementConfidence': _round(confidence),
      },
      stylingGuidance: _guidance[shape]!,
    );
  }

  static double _robustCheekWidth(
    List<FaceContourPoint> points,
    int top,
    int height,
    double fallback,
  ) {
    final levels = <double>[.43, .47, .50, .53, .57];
    final widths = <double>[];

    for (final level in levels) {
      final targetY = top + height * level;
      final tolerance = height * .05;
      final near = points
          .where((p) => (p.y - targetY).abs() <= tolerance)
          .toList();
      if (near.length < 2) continue;
      final minX = near.map((p) => p.x.toDouble()).reduce(math.min);
      final maxX = near.map((p) => p.x.toDouble()).reduce(math.max);
      widths.add(math.max(1.0, maxX - minX));
    }

    if (widths.isEmpty) return fallback * .5;
    widths.sort();
    return widths[widths.length ~/ 2];
  }

  static String _classify({
    required double faceRatio,
    required double foreheadToCheek,
    required double jawToCheek,
    required double chinToJaw,
  }) {
    // The reference method compares the full three ratios together instead of
    // letting one measurement dominate the decision.
    var bestShape = 'Oval';
    var bestDistance = double.infinity;

    for (final entry in _profiles.entries) {
      final profile = entry.value;
      final distance =
          _relativeDistance(faceRatio, profile[0], .11) +
          _relativeDistance(foreheadToCheek, profile[1], .11) +
          _relativeDistance(jawToCheek, profile[2], .11) +
          _shapeSpecificPenalty(
            entry.key,
            faceRatio: faceRatio,
            foreheadToCheek: foreheadToCheek,
            jawToCheek: jawToCheek,
            chinToJaw: chinToJaw,
          );

      if (distance < bestDistance) {
        bestDistance = distance;
        bestShape = entry.key;
      }
    }

    return bestShape;
  }

  static double _relativeDistance(double value, double target, double scale) {
    return (value - target).abs() / scale;
  }

  static double _shapeSpecificPenalty(
    String shape, {
    required double faceRatio,
    required double foreheadToCheek,
    required double jawToCheek,
    required double chinToJaw,
  }) {
    switch (shape) {
      case 'Round':
        return faceRatio > 1.25 ? (faceRatio - 1.25) * 2 : 0;
      case 'Square':
        return faceRatio > 1.30 ? (faceRatio - 1.30) * 2 : 0;
      case 'Oval':
        return faceRatio < 1.20 || faceRatio > 1.50 ? .8 : 0;
      case 'Oblong':
        return faceRatio < 1.45 ? (1.45 - faceRatio) * 2 : 0;
      case 'Heart':
        return foreheadToCheek < .90 || jawToCheek > .82 || chinToJaw > .78
            ? .9
            : 0;
      case 'Diamond':
        return foreheadToCheek > .88 || jawToCheek > .84 || chinToJaw > .78
            ? .9
            : 0;
      case 'Triangle':
        return jawToCheek < .90 ? (.90 - jawToCheek) * 2 : 0;
      default:
        return 0;
    }
  }

  static double _confidence({
    required String shape,
    required double faceRatio,
    required double foreheadToCheek,
    required double jawToCheek,
  }) {
    final target = _profiles[shape]!;
    final distance =
        _relativeDistance(faceRatio, target[0], .18) +
        _relativeDistance(foreheadToCheek, target[1], .18) +
        _relativeDistance(jawToCheek, target[2], .18);
    return (100 - distance * 12).clamp(0, 100).toDouble();
  }

  static double _round(double value) =>
      double.parse(value.toStringAsFixed(3));

  static const _description = <String, String>{
    'Oval':
        'Balanced facial proportions with a gently narrower jaw and forehead than the cheekbone area.',
    'Round':
        'A softer silhouette where facial width is close to length, with a curved jaw and no strong corners.',
    'Square':
        'A compact, structured silhouette with forehead, cheekbones and jaw reading at similar widths and a stronger jaw.',
    'Heart':
        'A wider upper face that narrows noticeably toward a smaller, tapered chin.',
    'Diamond':
        'Cheekbones form the strongest width, while the forehead and jaw are visibly narrower.',
    'Oblong':
        'A clearly elongated face with length noticeably greater than width and relatively even side widths.',
    'Triangle':
        'The lower face and jaw form the strongest width, with a comparatively narrower forehead.',
  };

  static const _guidance = <String, List<String>>{
    'Oval': [
      'Balanced necklines usually complement the natural proportions.',
      'Medium hoops, ovals and soft geometric earrings work well.',
      'Most hairstyle proportions can work without needing strong correction.',
    ],
    'Round': [
      'V-necks and longer open lines can add visual length.',
      'Longer or gently angular earrings create vertical movement.',
      'Soft layers can add structure without making the face look wider.',
    ],
    'Square': [
      'Open necklines can visually soften a stronger jaw.',
      'Rounded or drop earrings contrast nicely with angular structure.',
      'Soft waves and curved shapes can balance stronger corners.',
    ],
    'Heart': [
      'Scoop, round and balanced V-necks can support the narrower lower face.',
      'Medium drop or oval earrings add balanced visual weight.',
      'Avoid concentrating all visual weight at the forehead.',
    ],
    'Diamond': [
      'Open or softly rounded necklines can complement prominent cheekbones.',
      'Curved, oval and medium-width earrings are usually harmonious.',
      'A little visual fullness around the jaw can balance cheekbone width.',
    ],
    'Oblong': [
      'Crew, boat and wider necklines can add visual width.',
      'Shorter, wider or rounded earrings can balance face length.',
      'Soft horizontal volume can counter an elongated silhouette.',
    ],
    'Triangle': [
      'Wider necklines can balance a stronger lower face.',
      'Earrings with some upper width can draw attention upward.',
      'Keep styling detail distributed toward the upper face to balance the jaw.',
    ],
  };
}
