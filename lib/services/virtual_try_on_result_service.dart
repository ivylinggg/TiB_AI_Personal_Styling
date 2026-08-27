import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;

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
  static const Duration _requestTimeout = Duration(seconds: 360);
  static const int _maxImageDimension = 1600;
  static const int _jpegQuality = 82;

  /// Apps Script Web Apps normally redirect the initial /exec POST to a
  /// googleusercontent URL. Never let the HTTP client automatically turn a
  /// 302/303 POST into a GET; manually repeat the POST with the same JSON body.
  static Future<http.Response> _postJsonFollowingRedirects({
    required Uri uri,
    required String body,
  }) async {
    var currentUri = uri;

    for (var redirectCount = 0; redirectCount <= _maxRedirects; redirectCount++) {
      final request = http.Request('POST', currentUri)
        ..followRedirects = false
        ..maxRedirects = 0
        ..headers['Accept'] = 'application/json'
        ..headers['Content-Type'] = 'application/json; charset=utf-8'
        ..body = body;

      final streamed = await request.send().timeout(_requestTimeout);
      final response = await http.Response.fromStream(streamed);

      if (kDebugMode) {
        debugPrint(
          'virtualTryOn HTTP ${response.statusCode} POST ${response.request?.url}',
        );
        debugPrint('virtualTryOn content-type: ${response.headers['content-type']}');
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
    }

    throw const HttpException('Virtual Try-On redirect handling failed.');
  }

  static Future<Map<String, String>> _encodeImage(File file) async {
    final originalBytes = await file.readAsBytes();
    final decoded = img.decodeImage(originalBytes);

    if (decoded == null) {
      throw const FormatException('Could not read one of the model images.');
    }

    final oriented = img.bakeOrientation(decoded);
    final longestSide = oriented.width > oriented.height
        ? oriented.width
        : oriented.height;

    final prepared = longestSide > _maxImageDimension
        ? img.copyResize(
            oriented,
            width: oriented.width >= oriented.height ? _maxImageDimension : null,
            height: oriented.height > oriented.width ? _maxImageDimension : null,
            interpolation: img.Interpolation.linear,
          )
        : oriented;

    final jpegBytes = img.encodeJpg(prepared, quality: _jpegQuality);

    return {
      'mimeType': 'image/jpeg',
      'data': base64Encode(jpegBytes),
    };
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

    final facePath = request.model.facePath;
    if (facePath == null || facePath.isEmpty) {
      return const VirtualTryOnResult(
        imageUrl: null,
        status: 'Your TiB face reference is missing. Please recreate your TiB Model.',
      );
    }

    final faceFile = File(facePath);
    if (!faceFile.existsSync()) {
      return const VirtualTryOnResult(
        imageUrl: null,
        status: 'Your TiB face reference is missing. Please recreate your TiB Model.',
      );
    }

    final bodyPath = request.model.bodyPath;
    final bodyFile = bodyPath == null ? null : File(bodyPath);
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

      final faceImage = await _encodeImage(faceFile);
      final bodyImage = await _encodeImage(bodyFile);
      final tibModel = request.model.measurementData;

      final body = <String, dynamic>{
        'action': 'virtualTryOn',
        'uid': user.uid,
        'idToken': idToken,
        'occasion': request.occasion,
        'stylingBrief': request.stylingBrief,
        'tibModel': tibModel,
        'modelImage': faceImage,
        'bodyImage': bodyImage,
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
        debugPrint('virtualTryOn response: ${response.body}');
      }

      final responseText = response.body.trim();

      Map<String, dynamic>? decoded;
      try {
        final candidate = jsonDecode(responseText);
        if (candidate is Map<String, dynamic>) {
          decoded = candidate;
        }
      } catch (_) {
        decoded = null;
      }

      if (decoded != null) {
        if (decoded['success'] != true) {
          final error = decoded['error'] is String
              ? (decoded['error'] as String).trim()
              : '';

          if (error == 'not_premium') {
            return const VirtualTryOnResult(
              imageUrl: null,
              status: 'Virtual Try-On is temporarily unavailable because the connected backend is still using the old Premium access rule. Redeploy the latest Code.gs.',
            );
          }

          return VirtualTryOnResult(
            imageUrl: null,
            status: error.isEmpty
                ? 'Could not generate your Virtual You right now.'
                : 'Virtual Try-On failed: $error',
          );
        }

        final imageUrl = decoded['imageUrl'] is String
            ? (decoded['imageUrl'] as String).trim()
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
      }

      final contentType = response.headers['content-type'] ?? '';
      final preview = responseText.length > 180
          ? responseText.substring(0, 180)
          : responseText;

      if (response.statusCode != 200) {
        return VirtualTryOnResult(
          imageUrl: null,
          status: 'Virtual Try-On backend returned HTTP ${response.statusCode}. $preview',
        );
      }

      if (contentType.contains('text/html') ||
          responseText.toLowerCase().contains('<html')) {
        return const VirtualTryOnResult(
          imageUrl: null,
          status: 'The Apps Script Web App returned an HTML page instead of JSON. Set the deployment access to Anyone, deploy a new version, and keep the /exec URL in the app.',
        );
      }

      return VirtualTryOnResult(
        imageUrl: null,
        status: 'Virtual Try-On returned an unreadable response. Content-Type: $contentType. Response: $preview',
      );
    } on SocketException catch (error) {
      if (kDebugMode) debugPrint('virtualTryOn socket error: $error');
      return const VirtualTryOnResult(
        imageUrl: null,
        status: 'Could not connect to the Virtual Try-On backend. Check the Apps Script deployment and internet connection.',
      );
    } on TimeoutException catch (error) {
      if (kDebugMode) debugPrint('virtualTryOn timeout: $error');
      return const VirtualTryOnResult(
        imageUrl: null,
        status: 'Virtual Try-On is taking longer than expected. The AI generation may still be processing. Please try again after the backend deployment is confirmed.',
      );
    } on FormatException catch (error) {
      if (kDebugMode) debugPrint('virtualTryOn format error: $error');
      return VirtualTryOnResult(
        imageUrl: null,
        status: 'The Virtual Try-On request could not read an image: ${error.message}',
      );
    } on HttpException catch (error) {
      if (kDebugMode) debugPrint('virtualTryOn HTTP error: $error');
      return VirtualTryOnResult(
        imageUrl: null,
        status: 'Virtual Try-On backend error: ${error.message}',
      );
    } catch (error) {
      if (kDebugMode) debugPrint('virtualTryOn error: $error');
      return VirtualTryOnResult(
        imageUrl: null,
        status: 'Virtual Try-On failed: $error',
      );
    }
  }
}
