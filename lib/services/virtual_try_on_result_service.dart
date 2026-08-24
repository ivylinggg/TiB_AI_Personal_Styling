import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../config/google_drive_config.dart';
import '../models/wardrobe_item.dart';

class VirtualTryOnRequest {
  final String modelPhotoPath;
  final List<WardrobeItem> items;
  final String occasion;

  const VirtualTryOnRequest({
    required this.modelPhotoPath,
    required this.items,
    required this.occasion,
  });
}

class VirtualTryOnResult {
  final String? imageUrl;
  final String status;

  const VirtualTryOnResult({
    required this.imageUrl,
    required this.status,
  });

  bool get isGenerated => imageUrl != null && imageUrl!.isNotEmpty;
}

class VirtualTryOnResultService {
  VirtualTryOnResultService._();

  static Future<VirtualTryOnResult> generate(VirtualTryOnRequest request) async {
    if (request.modelPhotoPath.isEmpty || request.items.isEmpty) {
      return const VirtualTryOnResult(
        imageUrl: null,
        status: 'Add your TiB Model and at least one wardrobe piece first.',
      );
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const VirtualTryOnResult(
        imageUrl: null,
        status: 'Please sign in again before generating a try-on.',
      );
    }

    final modelFile = File(request.modelPhotoPath);
    if (!modelFile.existsSync()) {
      return const VirtualTryOnResult(
        imageUrl: null,
        status: 'Your TiB Model photo is missing. Please upload it again.',
      );
    }

    try {
      final idToken = await user.getIdToken();
      if (idToken == null || idToken.isEmpty) {
        return const VirtualTryOnResult(
          imageUrl: null,
          status: 'Could not verify your account. Please try again.',
        );
      }

      final modelBytes = await modelFile.readAsBytes();
      final extension = modelFile.path.toLowerCase();
      final mimeType = extension.endsWith('.png')
          ? 'image/png'
          : extension.endsWith('.webp')
              ? 'image/webp'
              : 'image/jpeg';

      final response = await http
          .post(
            Uri.parse(GoogleDriveConfig.uploadUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'action': 'virtualTryOn',
              'uid': user.uid,
              'idToken': idToken,
              'occasion': request.occasion,
              'modelImage': {
                'mimeType': mimeType,
                'data': base64Encode(modelBytes),
              },
              'items': request.items
                  .take(5)
                  .map(
                    (item) => {
                      'id': item.id,
                      'name': item.name,
                      'category': item.category,
                      'colour': item.colour,
                      'style': item.style,
                      'imageUrl': item.imageUrl,
                    },
                  )
                  .toList(),
            }),
          )
          .timeout(const Duration(seconds: 90));

      if (response.statusCode != 200) {
        return VirtualTryOnResult(
          imageUrl: null,
          status: 'Virtual try-on request failed (${response.statusCode}).',
        );
      }

      final data = jsonDecode(response.body);
      if (data is! Map<String, dynamic>) {
        return const VirtualTryOnResult(
          imageUrl: null,
          status: 'Virtual try-on returned an invalid response.',
        );
      }

      if (data['success'] != true) {
        final error = data['error'] is String ? data['error'] as String : '';
        if (error == 'not_premium') {
          return const VirtualTryOnResult(
            imageUrl: null,
            status: 'Virtual Try-On is available for Premium users.',
          );
        }
        return VirtualTryOnResult(
          imageUrl: null,
          status: error.isEmpty ? 'Could not generate the try-on right now.' : error,
        );
      }

      final imageUrl = data['imageUrl'] is String ? data['imageUrl'] as String : '';
      if (imageUrl.isEmpty) {
        return const VirtualTryOnResult(
          imageUrl: null,
          status: 'The AI completed without returning an image.',
        );
      }

      return VirtualTryOnResult(
        imageUrl: imageUrl,
        status: 'Your AI virtual try-on is ready.',
      );
    } catch (_) {
      return const VirtualTryOnResult(
        imageUrl: null,
        status: 'Could not reach the virtual try-on service. Please try again.',
      );
    }
  }
}
