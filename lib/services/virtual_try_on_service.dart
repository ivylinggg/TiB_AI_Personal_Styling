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

  static const Duration _requestTimeout = Duration(seconds: 90);
  static const int _maxWardrobeItems = 5;
  static const int _maxModelImageBytes = 12 * 1024 * 1024;

  static Future<VirtualTryOnResult?> generate({
    required File modelPhoto,
    required List<WardrobeItem> items,
    String? occasion,
  }) async {
    if (!await modelPhoto.exists()) return null;
    if (items.isEmpty) return null;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    final idToken = await user.getIdToken();
    if (idToken == null || idToken.isEmpty) return null;

    final fileLength = await modelPhoto.length();
    if (fileLength <= 0 || fileLength > _maxModelImageBytes) return null;

    final modelBytes = await modelPhoto.readAsBytes();
    if (modelBytes.isEmpty || modelBytes.length > _maxModelImageBytes) return null;
    final modelMimeType = _mimeType(modelPhoto.path);

    final wardrobeItems = items
        .where((item) => item.imageUrl.trim().isNotEmpty)
        .where((item) => item.id.trim().isNotEmpty)
        .take(_maxWardrobeItems)
        .map(
          (item) => {
            'id': item.id.trim(),
            'imageUrl': item.imageUrl.trim(),
            'name': item.name.trim(),
            'category': item.category.trim(),
            'colour': item.colour.trim(),
            'style': item.style.trim(),
          },
        )
        .toList(growable: false);

    if (wardrobeItems.isEmpty) return null;

    final payload = {
      'action': 'virtualTryOn',
      'uid': user.uid,
      'idToken': idToken,
      'occasion': (occasion ?? 'Everyday').trim().isEmpty
          ? 'Everyday'
          : occasion!.trim(),
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
          .timeout(_requestTimeout);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map) return null;

      final root = Map<String, dynamic>.from(decoded);
      final rawPayload = root['result'];
      final data = rawPayload is Map
          ? Map<String, dynamic>.from(rawPayload)
          : root;

      final success = data['success'];
      if (success != true) return null;

      final imageUrl = data['imageUrl']?.toString().trim();
      if (imageUrl == null || imageUrl.isEmpty) return null;

      final parsedUri = Uri.tryParse(imageUrl);
      if (parsedUri == null || !parsedUri.hasScheme) return null;

      final provider = data['provider']?.toString().trim();
      return VirtualTryOnResult(
        imageUrl: imageUrl,
        provider: provider == null || provider.isEmpty
            ? 'gemini-3.1-flash-image'
            : provider,
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
