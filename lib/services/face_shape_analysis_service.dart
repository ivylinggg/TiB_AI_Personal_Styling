import 'dart:io';
import 'dart:math' as math;

import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

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

    final points = contour.points
        .where((point) => point != null)
        .map((point) => point!)
        .toList();

    if (points.length < 24) {
      throw const FormatException(
        'Face outline could not be measured reliably. Please use a front-facing photo with your full face visible.',
      );
    }

    var minX = double.infinity;
    var maxX = double.negativeInfinity;
    var minY = double.infinity;
    var maxY = double.negativeInfinity;

    for (final point in points) {
      final x = point.x.toDouble();
      final y = point.y.toDouble();
      minX = math.min(minX, x);
      maxX = math.max(maxX, x);
      minY = math.min(minY, y);
      maxY = math.max(maxY, y);
    }

    final width = math.max(1.0, maxX - minX);
    final height = math.max(1.0, maxY - minY);

    double widthAt(double relativeY) {
      final targetY = minY + height * relativeY;
      final tolerance = height * .055;

      var hasNearPoint = false;
      var nearMinX = double.infinity;
      var nearMaxX = double.negativeInfinity;

      for (final point in points) {
        final x = point.x.toDouble();
        final y = point.y.toDouble();
        if ((y - targetY).abs() <= tolerance) {
          hasNearPoint = true;
          nearMinX = math.min(nearMinX, x);
          nearMaxX = math.max(nearMaxX, x);
        }
      }

      if (!hasNearPoint) return width * .5;
      return math.max(1.0, nearMaxX - nearMinX);
    }

    final foreheadWidth = widthAt(.28);
    final cheekboneWidth = widthAt(.50);
    final jawWidth = widthAt(.72);
    final chinWidth = widthAt(.86);

    final faceRatio = height / math.max(1.0, cheekboneWidth);
    final foreheadToCheek =
        foreheadWidth / math.max(1.0, cheekboneWidth);
    final jawToCheek = jawWidth / math.max(1.0, cheekboneWidth);
    final chinToJaw = chinWidth / math.max(1.0, jawWidth);

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
        'faceLengthToCheekbone': _round(faceRatio),
        'foreheadToCheekbone': _round(foreheadToCheek),
        'jawToCheekbone': _round(jawToCheek),
        'chinToJaw': _round(chinToJaw),
        'measurementConfidence': _round(confidence),
      },
      stylingGuidance: _guidance[shape]!,
    );
  }

  static String _classify({
    required double faceRatio,
    required double foreheadToCheek,
    required double jawToCheek,
    required double chinToJaw,
  }) {
    const profiles = <String, List<double>>{
      'Oval': [1.38, .92, .82],
      'Round': [1.06, .90, .88],
      'Square': [1.10, .96, .97],
      'Heart': [1.22, 1.00, .72],
      'Diamond': [1.27, .78, .74],
      'Oblong': [1.58, .90, .84],
      'Triangle': [1.16, .78, 1.02],
    };

    final input = <double>[faceRatio, foreheadToCheek, jawToCheek];
    var bestName = 'Oval';
    var bestDistance = double.infinity;

    for (final entry in profiles.entries) {
      final target = entry.value;
      var sum = 0.0;

      for (var i = 0; i < input.length; i++) {
        final normalized = (input[i] - target[i]) / _scale[i];
        sum += normalized * normalized;
      }

      if (entry.key == 'Heart') {
        sum += math.pow((chinToJaw - .55) / .25, 2).toDouble() * .10;
      } else if (entry.key == 'Diamond') {
        sum += math.pow((chinToJaw - .58) / .25, 2).toDouble() * .08;
      } else if (entry.key == 'Triangle') {
        sum += math.pow((chinToJaw - .82) / .25, 2).toDouble() * .08;
      }

      if (sum < bestDistance) {
        bestDistance = sum;
        bestName = entry.key;
      }
    }

    return bestName;
  }

  static const _scale = <double>[.20, .14, .16];

  static double _confidence({
    required String shape,
    required double faceRatio,
    required double foreheadToCheek,
    required double jawToCheek,
  }) {
    const profiles = <String, List<double>>{
      'Oval': [1.38, .92, .82],
      'Round': [1.06, .90, .88],
      'Square': [1.10, .96, .97],
      'Heart': [1.22, 1.00, .72],
      'Diamond': [1.27, .78, .74],
      'Oblong': [1.58, .90, .84],
      'Triangle': [1.16, .78, 1.02],
    };

    final target = profiles[shape]!;
    final errors = <double>[
      (faceRatio - target[0]).abs() / _scale[0],
      (foreheadToCheek - target[1]).abs() / _scale[1],
      (jawToCheek - target[2]).abs() / _scale[2],
    ];

    final meanError = errors.reduce((a, b) => a + b) / errors.length;
    return (100 * (1 - (meanError / 2).clamp(0.0, 1.0)))
        .clamp(0.0, 100.0)
        .toDouble();
  }

  static double _round(double value) =>
      double.parse(value.toStringAsFixed(3));

  static const _description = <String, String>{
    'Oval':
        'Balanced facial proportions with cheekbones slightly wider than the forehead and jaw, creating a gentle taper.',
    'Round':
        'Face length and width are relatively close, with a soft jaw and rounded overall contour.',
    'Square':
        'Forehead, cheekbones and jaw are broadly similar in width, with a stronger lower-face structure.',
    'Heart':
        'The upper face is broader and the face tapers noticeably toward a narrower chin.',
    'Diamond':
        'Cheekbones are the dominant width while both forehead and jaw are relatively narrower.',
    'Oblong':
        'The face is noticeably longer, with relatively consistent width through the forehead, cheeks and jaw.',
    'Triangle':
        'The lower face and jaw are relatively broad compared with the forehead, creating a stronger lower silhouette.',
  };

  static const _guidance = <String, List<String>>{
    'Oval': [
      'Balanced necklines work well',
      'Try medium hoops and soft geometric earrings',
      'Most hairstyle proportions can work',
    ],
    'Round': [
      'V-necks and longer open lines add visual length',
      'Try elongated earrings',
      'Soft layers can create vertical movement',
    ],
    'Square': [
      'Open necklines can soften the stronger jaw visually',
      'Try rounded or drop earrings',
      'Soft waves can balance stronger angles',
    ],
    'Heart': [
      'Scoop and balanced V-necks work well',
      'Try medium drop or oval earrings',
      'Keep visual weight balanced around the jaw',
    ],
    'Diamond': [
      'Open necklines can complement prominent cheekbones',
      'Try curved or oval earrings',
      'Soft fullness around the jaw can balance the face',
    ],
    'Oblong': [
      'Crew, boat and wider necklines can add visual width',
      'Try shorter or wider earrings',
      'Soft horizontal volume can balance facial length',
    ],
    'Triangle': [
      'Wider or softly structured necklines can balance a stronger jaw',
      'Try earrings with some upper-face visual weight',
      'Keep hairstyle volume toward the temples and crown',
    ],
  };
}
