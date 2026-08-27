import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;

import '../config/google_drive_config.dart';
import '../models/wardrobe_item.dart';
import 'personal_virtual_you_service.dart';
import 'tib_model_service.dart';

class VirtualTryOnRequest {
  final TibModelProfile model;
  final List<WardrobeItem> items;
  final String occasion;
  final String? stylingBrief;

  const VirtualTryOnRequest({required this.model, required this.items, required this.occasion, this.stylingBrief});
}

class VirtualTryOnResult {
  final String? imageUrl;
  final String status;
  final String? requestId;

  const VirtualTryOnResult({required this.imageUrl, required this.status, this.requestId});
  bool get isGenerated => imageUrl != null && imageUrl!.isNotEmpty;
}

class VirtualTryOnResultService {
  VirtualTryOnResultService._();

  static const int _maxRedirects = 5;
  static const Duration _requestTimeout = Duration(seconds: 360);
  static const int _maxImageDimension = 1600;
  static const int _jpegQuality = 82;

  static Future<http.Response> _postJsonFollowingRedirects({required Uri uri, required String body}) async {
    var currentUri = uri;
    for (var redirectCount = 0; redirectCount <= _maxRedirects; redirectCount++) {
      final postRequest = http.Request('POST', currentUri)
        ..followRedirects = false
        ..maxRedirects = 0
        ..headers['Accept'] = 'application/json'
        ..headers['Content-Type'] = 'application/json; charset=utf-8'
        ..body = body;
      final streamed = await postRequest.send().timeout(_requestTimeout);
      final response = await http.Response.fromStream(streamed);
      if (kDebugMode) debugPrint('virtualTryOn HTTP ${response.statusCode} POST ${response.request?.url}');
      final status = response.statusCode;
      final isRedirect = status == 301 || status == 302 || status == 303 || status == 307 || status == 308;
      if (!isRedirect) return response;
      final location = response.headers['location'];
      if (location == null || location.trim().isEmpty) throw const HttpException('Virtual Try-On service returned a redirect without a location.');
      if (redirectCount == _maxRedirects) throw const HttpException('Virtual Try-On service redirected too many times.');
      currentUri = currentUri.resolve(location.trim());
      if (status == 301 || status == 302 || status == 303) {
        final getRequest = http.Request('GET', currentUri)
          ..followRedirects = false
          ..maxRedirects = 0
          ..headers['Accept'] = 'application/json';
        final getStreamed = await getRequest.send().timeout(_requestTimeout);
        final getResponse = await http.Response.fromStream(getStreamed);
        if (kDebugMode) debugPrint('virtualTryOn redirect GET ${getResponse.statusCode} ${getResponse.request?.url}');
        final getStatus = getResponse.statusCode;
        final getIsRedirect = getStatus == 301 || getStatus == 302 || getStatus == 303 || getStatus == 307 || getStatus == 308;
        if (!getIsRedirect) return getResponse;
        final getLocation = getResponse.headers['location'];
        if (getLocation == null || getLocation.trim().isEmpty) throw const HttpException('Virtual Try-On redirect did not provide a final location.');
        currentUri = currentUri.resolve(getLocation.trim());
        if (getStatus == 301 || getStatus == 302 || getStatus == 303) {
          final finalRequest = http.Request('GET', currentUri)
            ..followRedirects = false
            ..maxRedirects = 0
            ..headers['Accept'] = 'application/json';
          final finalStreamed = await finalRequest.send().timeout(_requestTimeout);
          return await http.Response.fromStream(finalStreamed);
        }
      }
    }
    throw const HttpException('Virtual Try-On redirect handling failed.');
  }

  static Future<Map<String, String>> _encodeImage(File file) async {
    final originalBytes = await file.readAsBytes();
    final decoded = img.decodeImage(originalBytes);
    if (decoded == null) throw const FormatException('Could not read one of the model images.');
    final oriented = img.bakeOrientation(decoded);
    final longestSide = oriented.width > oriented.height ? oriented.width : oriented.height;
    final prepared = longestSide > _maxImageDimension
        ? img.copyResize(oriented, width: oriented.width >= oriented.height ? _maxImageDimension : null, height: oriented.height > oriented.width ? _maxImageDimension : null, interpolation: img.Interpolation.linear)
        : oriented;
    return {'mimeType': 'image/jpeg', 'data': base64Encode(img.encodeJpg(prepared, quality: _jpegQuality))};
  }

  static Future<VirtualTryOnResult> generate(VirtualTryOnRequest request) async {
    final model = request.model;
    if (!model.isComplete || model.facePath == null || model.bodyPath == null) return const VirtualTryOnResult(imageUrl: null, status: 'Complete your Personal TiB Model first: face, full-body reference and real measurements are required.');
    if (request.items.isEmpty) return const VirtualTryOnResult(imageUrl: null, status: 'Choose at least one wardrobe piece first.');
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const VirtualTryOnResult(imageUrl: null, status: 'Please sign in again before generating a try-on.');
    final faceFile = File(model.facePath!);
    final bodyFile = File(model.bodyPath!);
    if (!faceFile.existsSync()) return const VirtualTryOnResult(imageUrl: null, status: 'Your face reference is missing. Please update your Personal TiB Model.');
    if (!bodyFile.existsSync()) return const VirtualTryOnResult(imageUrl: null, status: 'Your full-body reference is missing. Please update your Personal TiB Model.');

    try {
      final idToken = await user.getIdToken();
      if (idToken == null || idToken.isEmpty) return const VirtualTryOnResult(imageUrl: null, status: 'Could not verify your account. Please try again.');
      final faceImage = await _encodeImage(faceFile);
      final bodyImage = await _encodeImage(bodyFile);
      final body = <String, dynamic>{
        'action': 'virtualTryOn',
        'uid': user.uid,
        'idToken': idToken,
        'occasion': request.occasion,
        'stylingBrief': request.stylingBrief ?? 'Dress my Personal TiB Model using the selected wardrobe only. Preserve the real person identity and real body proportions.',
        'tibModel': model.measurementData,
        'personalModel': model.personalIdentityData,
        'personalVirtualYou': PersonalVirtualYouService.buildContract(model),
        'modelImage': faceImage,
        'bodyImage': bodyImage,
        'modelReferencePriority': 'full_body_then_face_then_measurements',
        'outputRequirement': 'head_to_toe_full_body',
        'items': request.items.take(6).map((item) => {'id': item.id, 'name': item.name, 'category': item.category, 'colour': item.colour, 'style': item.style, 'imageUrl': item.imageUrl}).toList(),
      };
      final response = await _postJsonFollowingRedirects(uri: Uri.parse(GoogleDriveConfig.uploadUrl), body: jsonEncode(body));
      if (kDebugMode) { debugPrint('virtualTryOn final status: ${response.statusCode}'); debugPrint('virtualTryOn response: ${response.body}'); }
      final responseText = response.body.trim();
      Map<String, dynamic>? decoded;
      try { final candidate = jsonDecode(responseText); if (candidate is Map<String, dynamic>) decoded = candidate; } catch (_) {}
      if (decoded != null) {
        if (decoded['success'] != true) {
          final errorCode = decoded['errorCode']?.toString().trim() ?? '';
          final error = decoded['error'] is String ? (decoded['error'] as String).trim() : '';
          if (errorCode == 'not_premium') return const VirtualTryOnResult(imageUrl: null, status: 'Virtual Try-On requires the Premium plan.');
          final detail = error.isEmpty ? errorCode : error;
          return VirtualTryOnResult(imageUrl: null, requestId: decoded['requestId']?.toString(), status: detail.isEmpty ? 'Could not generate your Personal Virtual You right now.' : 'Virtual Try-On failed: $detail');
        }
        final imageUrl = decoded['imageUrl'] is String ? (decoded['imageUrl'] as String).trim() : '';
        if (imageUrl.isEmpty) return const VirtualTryOnResult(imageUrl: null, status: 'The AI completed without returning an image.');
        return VirtualTryOnResult(imageUrl: imageUrl, requestId: decoded['requestId']?.toString(), status: 'Your Personal TiB Model is now wearing your selected look.');
      }
      final contentType = response.headers['content-type'] ?? '';
      final preview = responseText.length > 180 ? responseText.substring(0, 180) : responseText;
      if (response.statusCode != 200) return VirtualTryOnResult(imageUrl: null, status: 'Virtual Try-On backend returned HTTP ${response.statusCode}. $preview');
      if (contentType.contains('text/html') || responseText.toLowerCase().contains('<html')) return const VirtualTryOnResult(imageUrl: null, status: 'The Apps Script Web App returned an HTML page instead of JSON. Check the deployment and /exec URL.');
      return VirtualTryOnResult(imageUrl: null, status: 'Virtual Try-On returned an unreadable response. Content-Type: $contentType. Response: $preview');
    } on SocketException catch (error) {
      if (kDebugMode) debugPrint('virtualTryOn socket error: $error');
      return const VirtualTryOnResult(imageUrl: null, status: 'Could not connect to the Virtual Try-On backend. Check the internet connection and Apps Script deployment.');
    } on TimeoutException catch (error) {
      if (kDebugMode) debugPrint('virtualTryOn timeout: $error');
      return const VirtualTryOnResult(imageUrl: null, status: 'Virtual Try-On is taking longer than expected. Please try again.');
    } on FormatException catch (error) {
      if (kDebugMode) debugPrint('virtualTryOn format error: $error');
      return VirtualTryOnResult(imageUrl: null, status: 'The Virtual Try-On request could not read an image: ${error.message}');
    } on HttpException catch (error) {
      if (kDebugMode) debugPrint('virtualTryOn HTTP error: $error');
      return VirtualTryOnResult(imageUrl: null, status: 'Virtual Try-On backend error: ${error.message}');
    } catch (error) {
      if (kDebugMode) debugPrint('virtualTryOn error: $error');
      return VirtualTryOnResult(imageUrl: null, status: 'Virtual Try-On failed: $error');
    }
  }
}