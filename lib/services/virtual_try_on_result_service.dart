import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/google_drive_config.dart';
import '../models/wardrobe_item.dart';
import 'tib_model_service.dart';

class VirtualTryOnRequest {
  final TibModelProfile model;
  final List<WardrobeItem> items;
  final String occasion;
  final String? stylingBrief;

  const VirtualTryOnRequest({
    required this.model,
    required this.items,
    required this.occasion,
    this.stylingBrief,
  });
}

class VirtualTryOnResult {
  final String? imageUrl;
  final String status;
  final String? requestId;

  const VirtualTryOnResult({
    required this.imageUrl,
    required this.status,
    this.requestId,
  });

  bool get isGenerated => imageUrl != null && imageUrl!.isNotEmpty;
}

class VirtualTryOnResultService {
  VirtualTryOnResultService._();

  static Future<VirtualTryOnResult> generate(VirtualTryOnRequest request) async {
    if (!request.model.isComplete || request.model.facePath == null) {
      return const VirtualTryOnResult(
        imageUrl: null,
        status: 'Create your complete TiB Model first.',
      );
    }
    if (request.items.isEmpty) {
      return const VirtualTryOnResult(
        imageUrl: null,
        status: 'Choose at least one wardrobe piece first.',
      );
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const VirtualTryOnResult(
        imageUrl: null,
        status: 'Please sign in again before generating a try-on.',
      );
    }

    final modelFile = File(request.model.facePath!);
    if (!modelFile.existsSync()) {
      return const VirtualTryOnResult(
        imageUrl: null,
        status: 'Your TiB Model photo is missing. Please scan your face again.',
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
      final path = modelFile.path.toLowerCase();
      final mimeType = path.endsWith('.png')
          ? 'image/png'
          : path.endsWith('.webp')
              ? 'image/webp'
              : 'image/jpeg';

      final body = <String, dynamic>{
        'action': 'virtualTryOn',
        'uid': user.uid,
        'idToken': idToken,
        'occasion': request.occasion,
        'stylingBrief': request.stylingBrief,
        'tibModel': request.model.measurementData,
        'modelImage': {
          'mimeType': mimeType,
          'data': base64Encode(modelBytes),
        },
        'items': request.items.take(6).map((item) => {
          'id': item.id,
          'name': item.name,
          'category': item.category,
          'colour': item.colour,
          'style': item.style,
          'imageUrl': item.imageUrl,
        }).toList(),
      };

      final response = await http
          .post(
            Uri.parse(GoogleDriveConfig.uploadUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 120));

      if (kDebugMode) debugPrint('virtualTryOn status: ${response.statusCode}');

      if (response.statusCode != 200) {
        return VirtualTryOnResult(
          imageUrl: null,
          status: 'Virtual try-on request failed (${response.statusCode}).',
        );
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        return const VirtualTryOnResult(
          imageUrl: null,
          status: 'Virtual try-on returned an invalid response.',
        );
      }

      if (decoded['success'] != true) {
        final error = decoded['error'] is String ? decoded['error'] as String : '';
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

      final imageUrl = decoded['imageUrl'] is String ? decoded['imageUrl'] as String : '';
      if (imageUrl.isEmpty) {
        return const VirtualTryOnResult(
          imageUrl: null,
          status: 'The AI completed without returning an image.',
        );
      }

      return VirtualTryOnResult(
        imageUrl: imageUrl,
        requestId: decoded['requestId']?.toString(),
        status: 'Your personalised AI try-on is ready.',
      );
    } catch (error) {
      if (kDebugMode) debugPrint('virtualTryOn error: $error');
      return const VirtualTryOnResult(
        imageUrl: null,
        status: 'Could not reach the virtual try-on service. Please try again.',
      );
    }
  }
}
