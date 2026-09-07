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
  static const _redirectStatuses = <int>{301, 302, 303, 307, 308};
  static const _requestTimeout = Duration(seconds: 30);

  Future<GoogleDriveUploadResult?> uploadImage({
    required File imageFile,
    required String fileName,
    required String type,
  }) async {
    try {
      if (!await imageFile.exists()) return null;
      final bytes = await imageFile.readAsBytes();
      if (bytes.isEmpty) return null;

      final response = await http
          .post(
            Uri.parse(GoogleDriveConfig.uploadUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'type': type,
              'image': base64Encode(bytes),
              'fileName': fileName,
              'mimeType': 'image/jpeg',
            }),
          )
          .timeout(_requestTimeout);

      final responseBody = await _resolveResponseBody(response);
      if (responseBody == null) return null;

      final data = _decodeMap(responseBody);
      if (data == null || data['success'] != true) return null;

      final fileId = data['fileId'] as String?;
      final imageUrl = data['imageUrl'] as String?;
      if (fileId == null || fileId.isEmpty || imageUrl == null || imageUrl.isEmpty) {
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
    return uploadImage(imageFile: imageFile, fileName: fileName, type: 'analysis');
  }

  Future<GoogleDriveUploadResult?> uploadWardrobeImage({
    required File imageFile,
    required String fileName,
  }) {
    return uploadImage(imageFile: imageFile, fileName: fileName, type: 'wardrobe');
  }

  Future<GoogleDriveUploadResult?> uploadProfileImage({
    required File imageFile,
    required String fileName,
  }) {
    return uploadImage(imageFile: imageFile, fileName: fileName, type: 'profile');
  }

  Future<bool> deleteFile({required String fileId}) async {
    try {
      final response = await http
          .post(
            Uri.parse(GoogleDriveConfig.uploadUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'action': 'delete', 'fileId': fileId}),
          )
          .timeout(_requestTimeout);

      final responseBody = await _resolveResponseBody(response);
      if (responseBody == null) return false;

      final data = _decodeMap(responseBody);
      return data?['success'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<String?> _resolveResponseBody(http.Response response) async {
    if (!_redirectStatuses.contains(response.statusCode)) {
      return response.statusCode == 200 ? response.body : null;
    }

    final location = response.headers['location'];
    if (location == null || location.isEmpty) return null;

    try {
      final redirectedResponse = await http
          .get(Uri.parse(location))
          .timeout(_requestTimeout);
      return redirectedResponse.statusCode == 200 ? redirectedResponse.body : null;
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic>? _decodeMap(String body) {
    try {
      final decoded = jsonDecode(body);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }
}
