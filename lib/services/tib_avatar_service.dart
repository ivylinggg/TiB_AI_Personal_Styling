import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'tib_model_service.dart';

/// Persistent state for the user's TiB 3D avatar.
///
/// A generated GLB is optional. Until one exists, the UI safely falls back to
/// the interactive base model while keeping the user's TiB profile available.
class TibAvatarService {
  TibAvatarService._();

  static const avatarUrlKey = 'tib_avatar_model_url';
  static const avatarStatusKey = 'tib_avatar_status';
  static const avatarVersionKey = 'tib_avatar_version';
  static const avatarProfileHashKey = 'tib_avatar_profile_hash';

  static const statusBase = 'base';
  static const statusReady = 'ready';
  static const statusNeedsUpdate = 'needs_update';
  static const statusGenerating = 'generating';

  static const String fallbackAvatarUrl =
      'https://raw.githubusercontent.com/KhronosGroup/glTF-Sample-Assets/main/Models/Corset/glTF-Binary/Corset.glb';

  static Future<String?> getAvatarUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(avatarUrlKey);
  }

  static Future<String> getStatus() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(avatarStatusKey) ?? statusBase;
  }

  static Future<int> getVersion() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(avatarVersionKey) ?? 0;
  }

  static Future<String?> getProfileHash() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(avatarProfileHashKey);
  }

  static Future<void> markGenerating(TibModelProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(avatarStatusKey, statusGenerating);
    await prefs.setString(avatarProfileHashKey, profileFingerprint(profile));
  }

  static Future<void> saveGeneratedAvatar({
    required String modelUrl,
    required TibModelProfile profile,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(avatarUrlKey, modelUrl);
    await prefs.setString(avatarStatusKey, statusReady);
    await prefs.setInt(avatarVersionKey, (prefs.getInt(avatarVersionKey) ?? 0) + 1);
    await prefs.setString(avatarProfileHashKey, profileFingerprint(profile));
  }

  static Future<void> resetToBaseAvatar() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(avatarUrlKey);
    await prefs.setString(avatarStatusKey, statusBase);
    await prefs.remove(avatarVersionKey);
    await prefs.remove(avatarProfileHashKey);
  }

  static Future<bool> canBuildPersonalAvatar(TibModelProfile profile) async {
    if (!profile.isComplete) return false;
    final face = profile.faceFile;
    return face != null && face.existsSync();
  }

  static Future<bool> needsRegeneration(TibModelProfile profile) async {
    if (!await canBuildPersonalAvatar(profile)) return false;
    final current = profileFingerprint(profile);
    final saved = await getProfileHash();
    final url = await getAvatarUrl();
    return url == null || url.isEmpty || saved != current;
  }

  static String profileFingerprint(TibModelProfile profile) {
    return [
      profile.faceShape,
      profile.bodyShape,
      profile.weight,
      profile.height,
      profile.bust,
      profile.waist,
      profile.hips,
      profile.bodyPath ?? '',
    ].join('|');
  }

  static Future<Map<String, dynamic>> buildGenerationContext(
    TibModelProfile profile,
  ) async {
    final context = {
      'version': 2,
      'faceShape': profile.faceShape,
      'bodyShape': profile.bodyShape,
      'measurements': profile.measurementData,
      'faceImagePath': profile.facePath,
      'bodyImagePath': profile.bodyPath,
    };
    if (kDebugMode) debugPrint('TiB avatar context prepared: ${context['bodyShape']} / ${context['faceShape']}');
    return context;
  }
}
