import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../config/google_drive_config.dart';
import '../models/wardrobe_item.dart';

class VirtualTryOnResult {
  const VirtualTryOnResult({
    required this.imageUrl,
    this.provider = 'gemini-3.1-flash-image',
  });

  final String imageUrl;
  final String provider;
}

class VirtualTryOnService {
  const VirtualTryOnService._();

  static Future<VirtualTryOnResult?> generate({
    required File modelPhoto,
    required List<WardrobeItem> items,
    String? occasion,
  }) async {
    if (!modelPhoto.existsSync() || items.isEmpty) return null;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    final idToken = await user.getIdToken();
    if (idToken == null || idToken.isEmpty) return null;

    final modelBytes = await modelPhoto.readAsBytes();
    final modelMimeType = _mimeType(modelPhoto.path);

    final wardrobeItems = items
        .where((item) => item.imageUrl.trim().isNotEmpty)
        .take(5)
        .map(
          (item) => {
            'id': item.id,
            'imageUrl': item.imageUrl,
            'name': item.name,
            'category': item.category,
            'colour': item.colour,
            'style': item.style,
          },
        )
        .toList();

    if (wardrobeItems.isEmpty) return null;

    final payload = {
      'action': 'virtualTryOn',
      'uid': user.uid,
      'idToken': idToken,
      'occasion': occasion ?? 'Everyday',
      'modelImage': {
        'mimeType': modelMimeType,
        'data': base64Encode(modelBytes),
      },
      'items': wardrobeItems,
    };

    try {
      final response = await http
          .post(
            Uri.parse(GoogleDriveConfig.uploadUrl),
            headers: const {
              'Content-Type': 'application/json',
            },
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 90));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) return null;
      if (decoded['success'] != true) return null;

      final imageUrl = decoded['imageUrl'] as String?;
      if (imageUrl == null || imageUrl.isEmpty) return null;

      return VirtualTryOnResult(
        imageUrl: imageUrl,
        provider: decoded['provider'] as String? ?? 'gemini-3.1-flash-image',
      );
    } catch (_) {
      return null;
    }
  }

  static String _mimeType(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.heic')) return 'image/heic';
    if (lower.endsWith('.heif')) return 'image/heif';
    return 'image/jpeg';
  }
}
