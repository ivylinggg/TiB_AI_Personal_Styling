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
      throw const FormatException('Please use a clear photo with one front-facing face.');
    }

    final face = faces.single;
    final contour = face.contours[FaceContourType.face];
    final boundingBox = face.boundingBox;

    if (contour == null || contour.points.length < 12) {
      return _analyseFromBoundingBox(boundingBox);
    }

    final points = contour.points;
    final left = points.map((p) => p.x.toDouble()).reduce(math.min);
    final right = points.map((p) => p.x.toDouble()).reduce(math.max);
    final top = points.map((p) => p.y.toDouble()).reduce(math.min);
    final bottom = points.map((p) => p.y.toDouble()).reduce(math.max);
    final width = math.max(1, right - left);
    final height = math.max(1, bottom - top);

    double widthAt(double relativeY) {
      final targetY = top + (height * relativeY);
      final near = points.where((p) => (p.y - targetY).abs() <= height * 0.055).toList();
      if (near.length < 2) return width * 0.5;
      final minX = near.map((p) => p.x.toDouble()).reduce(math.min);
      final maxX = near.map((p) => p.x.toDouble()).reduce(math.max);
      return maxX - minX;
    }

    final upperWidth = widthAt(.30);
    final cheekboneWidth = widthAt(.50);
    final jawWidth = widthAt(.72);
    final chinWidth = widthAt(.86);
    final widthHeightRatio = width / height;
    final jawToCheek = jawWidth / math.max(1, cheekboneWidth);
    final foreheadToCheek = upperWidth / math.max(1, cheekboneWidth);
    final chinToJaw = chinWidth / math.max(1, jawWidth);

    final shape = _classify(
      widthHeightRatio: widthHeightRatio,
      foreheadToCheek: foreheadToCheek,
      jawToCheek: jawToCheek,
      chinToJaw: chinToJaw,
    );

    return FaceShapeAnalysis(
      shape: shape,
      description: _description[shape]!,
      measurements: {
        'faceRatio': _round(widthHeightRatio),
        'foreheadToCheek': _round(foreheadToCheek),
        'jawToCheek': _round(jawToCheek),
        'chinToJaw': _round(chinToJaw),
      },
      stylingGuidance: _guidance[shape]!,
    );
  }

  static FaceShapeAnalysis _analyseFromBoundingBox(Rect box) {
    final width = math.max(1, box.width);
    final height = math.max(1, box.height);
    final ratio = width / height;
    final shape = ratio < .72
        ? 'Oblong'
        : ratio > .93
            ? 'Round'
            : 'Oval';
    return FaceShapeAnalysis(
      shape: shape,
      description: _description[shape]!,
      measurements: {'faceRatio': _round(ratio)},
      stylingGuidance: _guidance[shape]!,
    );
  }

  static String _classify({
    required double widthHeightRatio,
    required double foreheadToCheek,
    required double jawToCheek,
    required double chinToJaw,
  }) {
    if (widthHeightRatio <= .70) return 'Oblong';
    if (foreheadToCheek >= .92 && jawToCheek <= .68 && chinToJaw <= .62) return 'Heart';
    if (jawToCheek >= .86 && widthHeightRatio >= .78 && widthHeightRatio <= .98) return 'Square';
    if (widthHeightRatio >= .91 && jawToCheek >= .82) return 'Round';
    if (foreheadToCheek <= .78 && jawToCheek <= .82 && chinToJaw <= .72) return 'Diamond';
    return 'Oval';
  }

  static double _round(double value) => double.parse(value.toStringAsFixed(3));

  static const _description = <String, String>{
    'Oval': 'Balanced facial proportions with a gently narrower jaw and forehead than the cheekbone area.',
    'Round': 'A softer silhouette with similar width and height and a gently curved jaw area.',
    'Square': 'A structured silhouette with a broad lower face and a stronger jaw presence.',
    'Heart': 'A wider upper face that tapers toward a narrower chin.',
    'Diamond': 'Cheekbones create the strongest width, with a narrower forehead and jaw.',
    'Oblong': 'The face reads noticeably longer than it is wide, with a more elongated silhouette.',
  };

  static const _guidance = <String, List<String>>{
    'Oval': ['Balanced necklines work well', 'Try medium hoops and soft geometric earrings', 'Most hairstyle proportions can work'],
    'Round': ['V-necks and longer open lines add length', 'Try elongated earrings', 'Soft layers can create vertical movement'],
    'Square': ['Open necklines soften the jaw visually', 'Try rounded or drop earrings', 'Soft waves can balance stronger angles'],
    'Heart': ['Scoop and balanced V-necks work well', 'Try medium drop or oval earrings', 'Keep visual weight balanced around the jaw'],
    'Diamond': ['Open necklines can complement prominent cheekbones', 'Try curved or oval earrings', 'Soft fullness around the jaw can balance the face'],
    'Oblong': ['Crew, boat and wider necklines can add visual width', 'Try shorter or wider earrings', 'Soft horizontal volume can balance length'],
  };
}
