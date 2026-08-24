import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/google_drive_config.dart';
import 'tib_avatar_service.dart';
import 'tib_model_service.dart';

class TibPersonalAvatarResult {
  const TibPersonalAvatarResult({
    required this.success,
    required this.status,
    this.modelUrl,
  });

  final bool success;
  final String status;
  final String? modelUrl;
}

class TibPersonalAvatarService {
  TibPersonalAvatarService._();

  static Future<TibPersonalAvatarResult> generate(TibModelProfile profile) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const TibPersonalAvatarResult(
        success: false,
        status: 'Please sign in again before creating your TiB Avatar.',
      );
    }

    if (!await TibAvatarService.canBuildPersonalAvatar(profile)) {
      return const TibPersonalAvatarResult(
        success: false,
        status: 'Complete your TiB Model first.',
      );
    }

    final face = profile.faceFile!;
    final body = profile.bodyFile;

    try {
      final idToken = await user.getIdToken();
      if (idToken == null || idToken.isEmpty) {
        return const TibPersonalAvatarResult(
          success: false,
          status: 'Could not verify your account. Please try again.',
        );
      }

      final faceBytes = await face.readAsBytes();
      final bodyBytes = body != null && body.existsSync()
          ? await body.readAsBytes()
          : null;
      final context = await TibAvatarService.buildGenerationContext(profile);

      final payload = <String, dynamic>{
        'action': 'generateTiBAvatar',
        'uid': user.uid,
        'idToken': idToken,
        'tibModel': context['measurements'],
        'avatarContext': context,
        'faceImage': {
          'mimeType': _mimeType(face.path),
          'data': base64Encode(faceBytes),
        },
        if (bodyBytes != null)
          'bodyImage': {
            'mimeType': _mimeType(body!.path),
            'data': base64Encode(bodyBytes),
          },
      };

      await TibAvatarService.markGenerating(profile: profile);

      final response = await http
          .post(
            Uri.parse(GoogleDriveConfig.uploadUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 120));

      if (kDebugMode) {
        debugPrint('generateTiBAvatar status: ${response.statusCode}');
      }

      if (response.statusCode != 200) {
        await TibAvatarService.markGenerationFailed(
          status: 'Avatar generation request failed (${response.statusCode}).',
        );
        return TibPersonalAvatarResult(
          success: false,
          status: 'Avatar generation request failed (${response.statusCode}).',
        );
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        await TibAvatarService.markGenerationFailed(
          status: 'Avatar generation returned an invalid response.',
        );
        return const TibPersonalAvatarResult(
          success: false,
          status: 'Avatar generation returned an invalid response.',
        );
      }

      if (decoded['success'] != true) {
        final error = decoded['error']?.toString() ?? '';
        final status = error.isEmpty
            ? 'Could not create your TiB Avatar right now.'
            : error;
        await TibAvatarService.markGenerationFailed(status: status);
        return TibPersonalAvatarResult(success: false, status: status);
      }

      final modelUrl = decoded['modelUrl']?.toString();
      if (modelUrl == null || modelUrl.isEmpty) {
        const status = 'Avatar generation completed without returning a GLB model.';
        await TibAvatarService.markGenerationFailed(status: status);
        return const TibPersonalAvatarResult(success: false, status: status);
      }

      await TibAvatarService.saveGeneratedAvatar(
        modelUrl: modelUrl,
        profile: profile,
      );

      return TibPersonalAvatarResult(
        success: true,
        status: 'Your personalised TiB 3D Avatar is ready.',
        modelUrl: modelUrl,
      );
    } catch (error) {
      if (kDebugMode) {
        debugPrint('generateTiBAvatar error: $error');
      }
      const status = 'Could not connect to the TiB Avatar service. Please try again.';
      await TibAvatarService.markGenerationFailed(status: status);
      return const TibPersonalAvatarResult(success: false, status: status);
    }
  }

  static String _mimeType(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }
}
