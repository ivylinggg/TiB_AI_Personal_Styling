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

    double widthAt(double relativeY) {
      final targetY = top + height * relativeY;
      final tolerance = height * .045;
      final near = points.where((p) => (p.y - targetY).abs() <= tolerance).toList();
      if (near.length < 2) return width * .5;
      final minX = near.map((p) => p.x.toDouble()).reduce(math.min);
      final maxX = near.map((p) => p.x.toDouble()).reduce(math.max);
      return math.max(1.0, maxX - minX);
    }

    final foreheadWidth = widthAt(.28);
    final upperCheekWidth = widthAt(.43);
    final cheekboneWidth = widthAt(.50);
    final lowerCheekWidth = widthAt(.60);
    final jawWidth = widthAt(.72);
    final chinWidth = widthAt(.86);

    final faceRatio = height / width;
    final foreheadToCheek = foreheadWidth / cheekboneWidth;
    final jawToCheek = jawWidth / cheekboneWidth;
    final lowerToUpperCheek = lowerCheekWidth / upperCheekWidth;
    final chinToJaw = chinWidth / jawWidth;

    final shape = _classify(
      faceRatio: faceRatio,
      foreheadToCheek: foreheadToCheek,
      jawToCheek: jawToCheek,
      lowerToUpperCheek: lowerToUpperCheek,
      chinToJaw: chinToJaw,
    );

    final balance = _balanceScore(
      faceRatio: faceRatio,
      foreheadToCheek: foreheadToCheek,
      jawToCheek: jawToCheek,
      lowerToUpperCheek: lowerToUpperCheek,
    );

    return FaceShapeAnalysis(
      shape: shape,
      description: _description[shape]!,
      measurements: {
        'faceRatio': _round(faceRatio),
        'foreheadToCheek': _round(foreheadToCheek),
        'cheekboneWidthRatio': _round(cheekboneWidth / width),
        'jawToCheek': _round(jawToCheek),
        'lowerToUpperCheek': _round(lowerToUpperCheek),
        'chinToJaw': _round(chinToJaw),
        'measurementConfidence': _round(balance),
      },
      stylingGuidance: _guidance[shape]!,
    );
  }

  static String _classify({
    required double faceRatio,
    required double foreheadToCheek,
    required double jawToCheek,
    required double lowerToUpperCheek,
    required double chinToJaw,
  }) {
    if (faceRatio >= 1.48 && jawToCheek < .90) return 'Oblong';
    if (faceRatio <= 1.18 && jawToCheek >= .90 && lowerToUpperCheek >= .90) return 'Round';
    if (foreheadToCheek >= .91 && jawToCheek <= .73 && chinToJaw <= .63) return 'Heart';
    if (jawToCheek >= .87 && foreheadToCheek >= .82 && faceRatio <= 1.32) return 'Square';
    if (foreheadToCheek <= .80 && jawToCheek <= .82 && chinToJaw <= .72) return 'Diamond';
    return 'Oval';
  }

  static double _balanceScore({
    required double faceRatio,
    required double foreheadToCheek,
    required double jawToCheek,
    required double lowerToUpperCheek,
  }) {
    final ratioFit = 1 - (faceRatio - 1.35).abs().clamp(0.0, .7) / .7;
    final foreheadFit = 1 - (foreheadToCheek - .88).abs().clamp(0.0, .45) / .45;
    final jawFit = 1 - (jawToCheek - .84).abs().clamp(0.0, .45) / .45;
    final cheekFit = 1 - (lowerToUpperCheek - .92).abs().clamp(0.0, .45) / .45;
    return ((ratioFit + foreheadFit + jawFit + cheekFit) / 4 * 100).clamp(0, 100).toDouble();
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
