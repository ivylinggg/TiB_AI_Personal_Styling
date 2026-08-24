import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';

class TibModelProfile {
  const TibModelProfile({this.facePath, this.bodyPath, required this.weight, required this.height, required this.bust, required this.waist, required this.hips, required this.bodyShape, required this.faceShape, required this.isComplete});
  final String? facePath;
  final String? bodyPath;
  final double weight;
  final double height;
  final double bust;
  final double waist;
  final double hips;
  final String bodyShape;
  final String faceShape;
  final bool isComplete;
  File? get faceFile => facePath == null ? null : File(facePath!);
  File? get bodyFile => bodyPath == null ? null : File(bodyPath!);
  Map<String, dynamic> get measurementData => {'weightKg': weight, 'heightCm': height, 'bustCm': bust, 'waistCm': waist, 'hipsCm': hips, 'bodyShape': bodyShape, 'faceShape': faceShape};
}

class TibModelService {
  static const faceKey = 'tib_model_face_path';
  static const bodyKey = 'tib_model_body_path';
  static const weightKey = 'tib_model_weight';
  static const heightKey = 'tib_model_height';
  static const bustKey = 'tib_model_bust';
  static const waistKey = 'tib_model_waist';
  static const hipsKey = 'tib_model_hips';
  static const shapeKey = 'tib_model_body_shape';
  static const faceShapeKey = 'tib_model_face_shape';
  static const versionKey = 'tib_model_profile_version';

  static String calculateBodyShape({required double bust, required double waist, required double hips}) {
    if (waist >= bust * .90 || waist >= hips * .90) return 'Apple';
    if (hips >= bust * 1.05 && hips - waist >= 7.5) return 'Pear';
    final d = (bust - hips).abs() / ((bust + hips) / 2);
    if (d <= .05 && waist <= bust * .75 && waist <= hips * .75) return 'Hourglass';
    if (d <= .05 && waist > bust * .75 && waist > hips * .75) return 'Rectangle';
    if (bust >= hips * 1.05 && bust - waist >= 7.5) return 'Inverted Triangle';
    return 'Rectangle';
  }

  /// Automatic face-shape classification from the scanned face geometry.
  /// Users never enter face-shape measurements manually.
  static String calculateFaceShape({required double faceWidth, required double faceHeight, double? foreheadWidth, double? cheekboneWidth, double? jawWidth, double? chinRatio}) {
    if (faceWidth <= 0 || faceHeight <= 0) return 'Oval';
    final ratio = faceHeight / faceWidth;
    final forehead = foreheadWidth ?? faceWidth;
    final cheekbones = cheekboneWidth ?? faceWidth;
    final jaw = jawWidth ?? faceWidth * .82;
    final jawToCheek = jaw / cheekbones;
    final foreheadToJaw = forehead / jaw;
    final chin = chinRatio ?? .5;
    if (ratio >= 1.45 && jawToCheek < .90) return 'Oblong';
    if (ratio <= 1.18 && jawToCheek >= .92) return 'Round';
    if (cheekbones >= forehead * 1.06 && cheekbones >= jaw * 1.10 && chin < .48) return 'Diamond';
    if (foreheadToJaw >= 1.10 && jawToCheek < .90) return 'Heart';
    if (ratio <= 1.25 && foreheadToJaw <= 1.08 && jawToCheek >= .92) return 'Square';
    return 'Oval';
  }

  static Future<TibModelProfile> load() async {
    final prefs = await SharedPreferences.getInstance();
    final facePath = prefs.getString(faceKey);
    final bodyPath = prefs.getString(bodyKey);
    final faceExists = facePath != null && File(facePath).existsSync();
    final bodyExists = bodyPath != null && File(bodyPath).existsSync();
    final weight = prefs.getDouble(weightKey);
    final height = prefs.getDouble(heightKey);
    final bust = prefs.getDouble(bustKey);
    final waist = prefs.getDouble(waistKey);
    final hips = prefs.getDouble(hipsKey);
    final savedShape = prefs.getString(shapeKey);
    final savedFaceShape = prefs.getString(faceShapeKey);
    final complete = weight != null && height != null && bust != null && waist != null && hips != null && weight > 0 && height > 0 && bust > 0 && waist > 0 && hips > 0;
    final bodyShape = complete ? calculateBodyShape(bust: bust, waist: waist, hips: hips) : (savedShape ?? 'Not measured');
    return TibModelProfile(facePath: faceExists ? facePath : null, bodyPath: bodyExists ? bodyPath : null, weight: weight ?? 0, height: height ?? 0, bust: bust ?? 0, waist: waist ?? 0, hips: hips ?? 0, bodyShape: bodyShape, faceShape: savedFaceShape ?? 'Not scanned', isComplete: faceExists && complete);
  }

  static Future<void> save({required String facePath, String? bodyPath, required double weight, required double height, required double bust, required double waist, required double hips, required String faceShape}) async {
    final prefs = await SharedPreferences.getInstance();
    final bodyShape = calculateBodyShape(bust: bust, waist: waist, hips: hips);
    await prefs.setString(faceKey, facePath);
    if (bodyPath == null) { await prefs.remove(bodyKey); } else { await prefs.setString(bodyKey, bodyPath); }
    await prefs.setDouble(weightKey, weight);
    await prefs.setDouble(heightKey, height);
    await prefs.setDouble(bustKey, bust);
    await prefs.setDouble(waistKey, waist);
    await prefs.setDouble(hipsKey, hips);
    await prefs.setString(shapeKey, bodyShape);
    await prefs.setString(faceShapeKey, faceShape);
    await prefs.setInt(versionKey, 3);
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    for (final key in [faceKey, bodyKey, weightKey, heightKey, bustKey, waistKey, hipsKey, shapeKey, faceShapeKey, versionKey]) { await prefs.remove(key); }
  }
}
