import 'dart:io';

import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

class MlKitService {
  MlKitService._();

  static final FaceDetector detector = FaceDetector(
    options: FaceDetectorOptions(
      performanceMode: FaceDetectorMode.accurate,
      enableContours: true,
      enableLandmarks: true,
    ),
  );

  static Future<List<Face>> detectFace(File image) async {
    final inputImage = InputImage.fromFile(image);

    return await detector.processImage(inputImage);
  }

  static Future<void> dispose() async {
    await detector.close();
  }
}
