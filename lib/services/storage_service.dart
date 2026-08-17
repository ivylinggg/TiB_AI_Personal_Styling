import 'dart:io';

import 'google_drive_service.dart';

class StorageService {
  StorageService._();

  static final GoogleDriveService _driveService = GoogleDriveService();

  static Future<String> uploadAnalysisImage({
    required String uid,
    required File image,
  }) async {
    final fileName =
        'analysis_${uid}_${DateTime.now().millisecondsSinceEpoch}.jpg';

    final result = await _driveService.uploadAnalysisImage(
      imageFile: image,
      fileName: fileName,
    );

    if (result == null) {
      throw Exception('Failed to upload analysis image to Google Drive.');
    }

    return result.imageUrl;
  }

  static Future<String> uploadWardrobeImage({
    required String uid,
    required File image,
  }) async {
    final fileName =
        'wardrobe_${uid}_${DateTime.now().millisecondsSinceEpoch}.jpg';

    final result = await _driveService.uploadWardrobeImage(
      imageFile: image,
      fileName: fileName,
    );

    if (result == null) {
      throw Exception('Failed to upload wardrobe image to Google Drive.');
    }

    return result.imageUrl;
  }
}
