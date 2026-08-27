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

  static const int _maxRedirects = 5;

  /// Pre-launch access policy:
  /// the Flutter client never checks Premium entitlement before generating.
  /// Premium can be reintroduced later at the backend/product-access layer.
  static const bool preLaunchAllUsers = true;

  static Future<http.Response> _postJsonFollowingRedirects({
    required Uri uri,
    required String body,
  }) async {
    var currentUri = uri;
    var method = 'POST';

    for (var redirectCount = 0;
        redirectCount <= _maxRedirects;
        redirectCount++) {
      final request = http.Request(method, currentUri)
        ..followRedirects = false
        ..maxRedirects = 0
        ..headers['Accept'] = 'application/json';

      if (method == 'POST') {
        request.headers['Content-Type'] = 'application/json';
        request.body = body;
      }

      final streamed = await request.send().timeout(
        const Duration(seconds: 180),
      );
      final response = await http.Response.fromStream(streamed);

      if (kDebugMode) {
        debugPrint(
          'virtualTryOn HTTP ${response.statusCode} $method ${response.request?.url}',
        );
      }

      final status = response.statusCode;
      final isRedirect = status == 301 ||
          status == 302 ||
          status == 303 ||
          status == 307 ||
          status == 308;

      if (!isRedirect) return response;

      final location = response.headers['location'];
      if (location == null || location.trim().isEmpty) {
        throw const HttpException(
          'Virtual Try-On service returned a redirect without a location.',
        );
      }

      if (redirectCount == _maxRedirects) {
        throw const HttpException(
          'Virtual Try-On service redirected too many times.',
        );
      }

      currentUri = currentUri.resolve(location.trim());
      method = status == 301 || status == 302 || status == 303 ? 'GET' : 'POST';

      if (kDebugMode) {
        debugPrint('virtualTryOn redirect → $method $currentUri');
      }
    }

    throw const HttpException('Virtual Try-On redirect handling failed.');
  }

  static Future<VirtualTryOnResult> generate(
    VirtualTryOnRequest request,
  ) async {
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

    final faceFile = File(request.model.facePath!);
    final bodyPath = request.model.bodyPath;
    final bodyFile = bodyPath == null ? null : File(bodyPath);

    if (!faceFile.existsSync()) {
      return const VirtualTryOnResult(
        imageUrl: null,
        status: 'Your face scan is missing. Please scan your face again.',
      );
    }

    if (bodyFile == null || !bodyFile.existsSync()) {
      return const VirtualTryOnResult(
        imageUrl: null,
        status: 'Add your full-body photo to your TiB Model so Virtual You can match your real body shape and proportions.',
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

      Future<Map<String, String>> encodeImage(File file) async {
        final bytes = await file.readAsBytes();
        final path = file.path.toLowerCase();
        final mimeType = path.endsWith('.png')
            ? 'image/png'
            : path.endsWith('.webp')
                ? 'image/webp'
                : 'image/jpeg';
        return {
          'mimeType': mimeType,
          'data': base64Encode(bytes),
        };
      }

      final faceImage = await encodeImage(faceFile);
      final bodyImage = await encodeImage(bodyFile);

      final body = <String, dynamic>{
        'action': 'virtualTryOn',
        'uid': user.uid,
        'idToken': idToken,
        'occasion': request.occasion,
        'stylingBrief': request.stylingBrief,
        'tibModel': request.model.measurementData,
        // Reference 1: user's face / identity.
        'modelImage': faceImage,
        // Reference 2: user's real full-body silhouette / proportions.
        'bodyImage': bodyImage,
        // Only the user's selected wardrobe is sent as clothing references.
        'items': request.items.take(6).map((item) => {
          'id': item.id,
          'name': item.name,
          'category': item.category,
          'colour': item.colour,
          'style': item.style,
          'imageUrl': item.imageUrl,
        }).toList(),
      };

      final response = await _postJsonFollowingRedirects(
        uri: Uri.parse(GoogleDriveConfig.uploadUrl),
        body: jsonEncode(body),
      );

      if (kDebugMode) {
        debugPrint('virtualTryOn final status: ${response.statusCode}');
        if (response.body.isNotEmpty) {
          debugPrint('virtualTryOn response: ${response.body}');
        }
      }

      if (response.statusCode != 200) {
        try {
          final serverBody = jsonDecode(response.body);
          if (serverBody is Map<String, dynamic>) {
            final error = serverBody['error'];
            if (error is String && error.trim().isNotEmpty) {
              return VirtualTryOnResult(
                imageUrl: null,
                status: 'Virtual try-on failed: ${error.trim()}',
              );
            }
          }
        } catch (_) {}

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
        final error = decoded['error'] is String
            ? decoded['error'] as String
            : '';

        // Never present Premium as a Flutter-side requirement during pre-launch.
        if (preLaunchAllUsers && error == 'not_premium') {
          return const VirtualTryOnResult(
            imageUrl: null,
            status: 'The connected AI service is still using an older deployment. Update the Virtual Try-On backend deployment and try again.',
          );
        }

        return VirtualTryOnResult(
          imageUrl: null,
          status: error.isEmpty
              ? 'Could not generate the try-on right now.'
              : error,
        );
      }

      final imageUrl = decoded['imageUrl'] is String
          ? decoded['imageUrl'] as String
          : '';
      if (imageUrl.isEmpty) {
        return const VirtualTryOnResult(
          imageUrl: null,
          status: 'The AI completed without returning an image.',
        );
      }

      return VirtualTryOnResult(
        imageUrl: imageUrl,
        requestId: decoded['requestId']?.toString(),
        status: 'Your personalised AI Virtual You is ready.',
      );
    } catch (error) {
      if (kDebugMode) debugPrint('virtualTryOn error: $error');

      if (error is SocketException || error is HttpException) {
        return VirtualTryOnResult(
          imageUrl: null,
          status:
              'Could not reach the virtual try-on service. ${error.toString().replaceFirst('Exception: ', '')}',
        );
      }

      return const VirtualTryOnResult(
        imageUrl: null,
        status: 'Could not reach the virtual try-on service. Please try again.',
      );
    }
  }
}
