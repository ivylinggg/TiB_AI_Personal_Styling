import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

class TibModelProfile {
  const TibModelProfile({
    this.facePath,
    this.bodyPath,
    required this.height,
    required this.bodyShape,
    required this.isComplete,
  });

  final String? facePath;
  final String? bodyPath;
  final double height;
  final String bodyShape;
  final bool isComplete;

  File? get faceFile => facePath == null ? null : File(facePath!);
  File? get bodyFile => bodyPath == null ? null : File(bodyPath!);
}

class TibModelService {
  static const faceKey = 'tib_model_face_path';
  static const bodyKey = 'tib_model_body_path';
  static const heightKey = 'tib_model_height';
  static const shapeKey = 'tib_model_body_shape';
  static const versionKey = 'tib_model_profile_version';

  static Future<TibModelProfile> load() async {
    final prefs = await SharedPreferences.getInstance();
    final facePath = prefs.getString(faceKey);
    final bodyPath = prefs.getString(bodyKey);
    final faceExists = facePath != null && File(facePath).existsSync();
    final bodyExists = bodyPath != null && File(bodyPath).existsSync();

    return TibModelProfile(
      facePath: faceExists ? facePath : null,
      bodyPath: bodyExists ? bodyPath : null,
      height: prefs.getDouble(heightKey) ?? 165,
      bodyShape: prefs.getString(shapeKey) ?? 'Balanced',
      isComplete: faceExists,
    );
  }

  static Future<void> save({
    required String facePath,
    String? bodyPath,
    required double height,
    required String bodyShape,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(faceKey, facePath);
    if (bodyPath == null) {
      await prefs.remove(bodyKey);
    } else {
      await prefs.setString(bodyKey, bodyPath);
    }
    await prefs.setDouble(heightKey, height);
    await prefs.setString(shapeKey, bodyShape);
    await prefs.setInt(versionKey, 1);
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    for (final key in [faceKey, bodyKey, heightKey, shapeKey, versionKey]) {
      await prefs.remove(key);
    }
  }
}
