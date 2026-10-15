import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_background_remover/image_background_remover.dart';

import 'google_drive_service.dart';

/// Storage facade for user images.
///
/// Uploads use bounded network requests and keep existing local-image
/// fallback behaviour so a transient storage failure does not leave callers
/// waiting indefinitely.
class StorageService {
  StorageService._();

  static final GoogleDriveService _driveService = GoogleDriveService();
  static Future<void>? _backgroundModel;
  static const _uploadTimeout = Duration(seconds: 45);

  static Future<void> _ensureBackgroundModel() {
    return _backgroundModel ??= BackgroundRemover.instance.initializeOrt();
  }

  static Future<String> uploadAnalysisImage({
    required String uid,
    required File image,
  }) async {
    final fileName = 'analysis_${uid}_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final result = await _driveService
        .uploadAnalysisImage(imageFile: image, fileName: fileName)
        .timeout(_uploadTimeout, onTimeout: () => null);
    if (result == null) {
      throw Exception('Failed to upload analysis image to Google Drive.');
    }
    return result.imageUrl;
  }

  static Future<String> uploadWardrobeImage({
    required String uid,
    required File image,
  }) async {
    final processed = await _prepareWardrobeImage(image);
    final fileName = 'wardrobe_${uid}_${DateTime.now().millisecondsSinceEpoch}.png';

    try {
      final result = await _driveService
          .uploadWardrobeImage(imageFile: processed, fileName: fileName)
          .timeout(_uploadTimeout, onTimeout: () => null);
      if (result == null) {
        throw Exception('Failed to upload wardrobe image to Google Drive.');
      }
      return result.imageUrl;
    } finally {
      if (processed.path != image.path) {
        try {
          await processed.delete();
        } catch (_) {}
      }
    }
  }

  static Future<File> _prepareWardrobeImage(File original) async {
    try {
      await _ensureBackgroundModel().timeout(
        const Duration(seconds: 20),
        onTimeout: () {},
      );
      final bytes = await original.readAsBytes().timeout(const Duration(seconds: 10));
      final cutout = await BackgroundRemover.instance
          .removeBgBytes(
            bytes,
            threshold: 0.50,
            smoothMask: true,
            enhanceEdges: true,
          )
          .timeout(const Duration(seconds: 30));
      final white = await BackgroundRemover.instance
          .addBackground(image: cutout, bgColor: Colors.white)
          .timeout(const Duration(seconds: 15));

      final tempDir = await Directory.systemTemp.createTemp('tib_wardrobe_');
      final output = File('${tempDir.path}/wardrobe_clean.png');
      await output.writeAsBytes(white, flush: true).timeout(const Duration(seconds: 10));
      return output;
    } catch (_) {
      return original;
    }
  }

  static Future<String> uploadProfileImage({
    required String uid,
    required File image,
  }) async {
    final fileName = 'profile_${uid}_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final result = await _driveService
        .uploadProfileImage(imageFile: image, fileName: fileName)
        .timeout(_uploadTimeout, onTimeout: () => null);
    if (result == null) {
      throw Exception('Failed to upload profile image to Google Drive.');
    }
    return result.imageUrl;
  }

  static Future<void> removeProfileImage({required String? photoUrl}) async {
    await deleteImageByUrl(photoUrl);
  }

  static Future<void> deleteImageByUrl(String? imageUrl) async {
    final fileId = _driveFileIdFromUrl(imageUrl);
    if (fileId == null) return;
    final deleted = await _driveService.deleteFile(fileId: fileId).timeout(
      _uploadTimeout,
      onTimeout: () => false,
    );
    if (!deleted) {
      throw Exception('Failed to delete image from Google Drive.');
    }
  }

  static String? _driveFileIdFromUrl(String? url) {
    if (url == null || url.isEmpty) return null;
    try {
      final id = Uri.parse(url).queryParameters['id'];
      return id == null || id.isEmpty ? null : id;
    } catch (_) {
      return null;
    }
  }
}
