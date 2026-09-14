import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_background_remover/image_background_remover.dart';

import 'google_drive_service.dart';

/// Storage facade for user images.
///
/// Wardrobe uploads are normalised before they reach Google Drive. Processing
/// is best-effort, while upload failures are surfaced with a useful error.
class StorageService {
  StorageService._();

  static const _uploadTimeout = Duration(seconds: 60);
  static final GoogleDriveService _driveService = GoogleDriveService();
  static Future<void>? _backgroundModel;

  static Future<void> _ensureBackgroundModel() {
    return _backgroundModel ??= BackgroundRemover.instance.initializeOrt()
        .timeout(const Duration(seconds: 30));
  }

  static Future<String> uploadAnalysisImage({
    required String uid,
    required File image,
  }) async {
    _validateSource(image);
    final fileName = 'analysis_${uid}_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final result = await _driveService
        .uploadAnalysisImage(imageFile: image, fileName: fileName)
        .timeout(_uploadTimeout, onTimeout: () => null);
    if (result == null) {
      throw TimeoutException('The analysis image upload timed out. Please try again.');
    }
    return result.imageUrl;
  }

  static Future<String> uploadWardrobeImage({
    required String uid,
    required File image,
  }) async {
    _validateSource(image);
    final processed = await _prepareWardrobeImage(image);
    final fileName = 'wardrobe_${uid}_${DateTime.now().millisecondsSinceEpoch}.png';

    try {
      final result = await _driveService
          .uploadWardrobeImage(imageFile: processed, fileName: fileName)
          .timeout(_uploadTimeout, onTimeout: () => null);
      if (result == null) {
        throw TimeoutException('The wardrobe image upload timed out. Please try again.');
      }
      return result.imageUrl;
    } on TimeoutException {
      rethrow;
    } catch (error) {
      throw Exception('Could not upload this wardrobe image. Please try again.');
    } finally {
      if (processed.path != image.path) {
        try {
          await processed.delete();
          final parent = Directory(processed.parent.path);
          if (await parent.exists()) {
            await parent.delete();
          }
        } catch (_) {}
      }
    }
  }

  static void _validateSource(File image) {
    if (!image.existsSync()) {
      throw ArgumentError('The selected image is no longer available. Please choose it again.');
    }
    final length = image.lengthSync();
    if (length <= 0) {
      throw ArgumentError('The selected image is empty. Please choose another image.');
    }
    if (length > 20 * 1024 * 1024) {
      throw ArgumentError('Please choose an image smaller than 20 MB.');
    }
  }

  static Future<File> _prepareWardrobeImage(File original) async {
    try {
      await _ensureBackgroundModel();
      final bytes = await original.readAsBytes();
      final cutout = await BackgroundRemover.instance
          .removeBgBytes(bytes, threshold: 0.50, smoothMask: true, enhanceEdges: true)
          .timeout(const Duration(seconds: 45));
      final white = await BackgroundRemover.instance
          .addBackground(image: cutout, bgColor: Colors.white)
          .timeout(const Duration(seconds: 20));

      final tempDir = await Directory.systemTemp.createTemp('tib_wardrobe_');
      final output = File('${tempDir.path}/wardrobe_clean.png');
      await output.writeAsBytes(white, flush: true);
      return output;
    } catch (_) {
      return original;
    }
  }

  static Future<String> uploadProfileImage({
    required String uid,
    required File image,
  }) async {
    _validateSource(image);
    final fileName = 'profile_${uid}_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final result = await _driveService
        .uploadProfileImage(imageFile: image, fileName: fileName)
        .timeout(_uploadTimeout, onTimeout: () => null);
    if (result == null) {
      throw TimeoutException('The profile image upload timed out. Please try again.');
    }
    return result.imageUrl;
  }

  static Future<void> removeProfileImage({required String? photoUrl}) async {
    await deleteImageByUrl(photoUrl);
  }

  static Future<void> deleteImageByUrl(String? imageUrl) async {
    final fileId = _driveFileIdFromUrl(imageUrl);
    if (fileId == null) return;
    try {
      await _driveService
          .deleteFile(fileId: fileId)
          .timeout(_uploadTimeout);
    } on TimeoutException {
      throw TimeoutException('The image deletion timed out. Please try again.');
    }
  }

  static String? _driveFileIdFromUrl(String? url) {
    if (url == null || url.trim().isEmpty) return null;
    try {
      final id = Uri.parse(url.trim()).queryParameters['id'];
      return id == null || id.isEmpty ? null : id;
    } catch (_) {
      return null;
    }
  }
}
