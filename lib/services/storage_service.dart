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

  static Future<String> uploadProfileImage({
    required String uid,
    required File image,
  }) async {
    final fileName =
        'profile_${uid}_${DateTime.now().millisecondsSinceEpoch}.jpg';

    final result = await _driveService.uploadProfileImage(
      imageFile: image,
      fileName: fileName,
    );

    if (result == null) {
      throw Exception('Failed to upload profile image to Google Drive.');
    }

    return result.imageUrl;
  }

  /// Best-effort removal of a previously uploaded profile image from
  /// Google Drive. This never throws: the Firestore `photoUrl` field is
  /// the source of truth for whether a user has a profile photo, so a
  /// failure here (network issue, file already removed, etc.) should not
  /// block or fail the remove-photo action the user already confirmed.
  static Future<void> removeProfileImage({required String? photoUrl}) async {
    final fileId = _driveFileIdFromUrl(photoUrl);

    if (fileId == null) {
      return;
    }

    await _driveService.deleteFile(fileId: fileId);
  }

  static String? _driveFileIdFromUrl(String? url) {
    if (url == null || url.isEmpty) {
      return null;
    }

    try {
      final id = Uri.parse(url).queryParameters['id'];

      if (id == null || id.isEmpty) {
        return null;
      }

      return id;
    } catch (_) {
      return null;
    }
  }
}
