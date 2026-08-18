import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../config/google_drive_config.dart';

class GoogleDriveUploadResult {
  final String fileId;
  final String imageUrl;

  const GoogleDriveUploadResult({required this.fileId, required this.imageUrl});
}

class GoogleDriveService {
  Future<GoogleDriveUploadResult?> uploadImage({
    required File imageFile,
    required String fileName,
    required String type,
  }) async {
    try {
      final bytes = await imageFile.readAsBytes();

      final response = await http.post(
        Uri.parse(GoogleDriveConfig.uploadUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'type': type,
          'image': base64Encode(bytes),
          'fileName': fileName,
          'mimeType': 'image/jpeg',
        }),
      );

      String responseBody = response.body;

      if (response.statusCode == 301 ||
          response.statusCode == 302 ||
          response.statusCode == 303 ||
          response.statusCode == 307 ||
          response.statusCode == 308) {
        final location = response.headers['location'];

        if (location == null || location.isEmpty) {
          return null;
        }

        final redirectedResponse = await http.get(Uri.parse(location));

        if (redirectedResponse.statusCode != 200) {
          return null;
        }

        responseBody = redirectedResponse.body;
      }

      if (response.statusCode != 200 &&
          response.statusCode != 301 &&
          response.statusCode != 302 &&
          response.statusCode != 303 &&
          response.statusCode != 307 &&
          response.statusCode != 308) {
        return null;
      }

      final data = jsonDecode(responseBody);

      if (data is! Map<String, dynamic>) {
        return null;
      }

      if (data['success'] != true) {
        return null;
      }

      final fileId = data['fileId'] as String?;
      final imageUrl = data['imageUrl'] as String?;

      if (fileId == null || fileId.isEmpty) {
        return null;
      }

      if (imageUrl == null || imageUrl.isEmpty) {
        return null;
      }

      return GoogleDriveUploadResult(fileId: fileId, imageUrl: imageUrl);
    } catch (_) {
      return null;
    }
  }

  Future<GoogleDriveUploadResult?> uploadAnalysisImage({
    required File imageFile,
    required String fileName,
  }) {
    return uploadImage(
      imageFile: imageFile,
      fileName: fileName,
      type: 'analysis',
    );
  }

  Future<GoogleDriveUploadResult?> uploadWardrobeImage({
    required File imageFile,
    required String fileName,
  }) {
    return uploadImage(
      imageFile: imageFile,
      fileName: fileName,
      type: 'wardrobe',
    );
  }

  Future<GoogleDriveUploadResult?> uploadProfileImage({
    required File imageFile,
    required String fileName,
  }) {
    return uploadImage(
      imageFile: imageFile,
      fileName: fileName,
      type: 'profile',
    );
  }

  Future<bool> deleteFile({required String fileId}) async {
    try {
      final response = await http.post(
        Uri.parse(GoogleDriveConfig.uploadUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'action': 'delete', 'fileId': fileId}),
      );

      String responseBody = response.body;

      if (response.statusCode == 301 ||
          response.statusCode == 302 ||
          response.statusCode == 303 ||
          response.statusCode == 307 ||
          response.statusCode == 308) {
        final location = response.headers['location'];

        if (location == null || location.isEmpty) {
          return false;
        }

        final redirectedResponse = await http.get(Uri.parse(location));

        if (redirectedResponse.statusCode != 200) {
          return false;
        }

        responseBody = redirectedResponse.body;
      }

      if (response.statusCode != 200 &&
          response.statusCode != 301 &&
          response.statusCode != 302 &&
          response.statusCode != 303 &&
          response.statusCode != 307 &&
          response.statusCode != 308) {
        return false;
      }

      final data = jsonDecode(responseBody);

      if (data is! Map<String, dynamic>) {
        return false;
      }

      return data['success'] == true;
    } catch (_) {
      return false;
    }
  }
}
