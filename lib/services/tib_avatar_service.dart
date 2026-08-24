import 'package:shared_preferences/shared_preferences.dart';

import 'tib_model_service.dart';

/// Stores the user's persistent TiB Avatar configuration.
///
/// The avatar asset is intentionally separated from the TiB Model profile so a
/// generated personalised 3D asset can be swapped in without changing the
/// styling and wardrobe flows.
class TibAvatarService {
  TibAvatarService._();

  static const avatarUrlKey = 'tib_avatar_model_url';
  static const avatarStatusKey = 'tib_avatar_status';
  static const avatarVersionKey = 'tib_avatar_version';

  static const statusBase = 'base';
  static const statusReady = 'ready';

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

  static Future<void> saveGeneratedAvatar({required String modelUrl}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(avatarUrlKey, modelUrl);
    await prefs.setString(avatarStatusKey, statusReady);
    await prefs.setInt(avatarVersionKey, 1);
  }

  static Future<void> resetToBaseAvatar() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(avatarUrlKey);
    await prefs.setString(avatarStatusKey, statusBase);
    await prefs.remove(avatarVersionKey);
  }

  static Future<bool> canBuildPersonalAvatar(TibModelProfile profile) async {
    if (!profile.isComplete) return false;
    final face = profile.faceFile;
    if (face == null || !face.existsSync()) return false;
    return true;
  }

  /// Returns deterministic profile data for the future avatar-generation API.
  static Future<Map<String, dynamic>> buildGenerationContext(
    TibModelProfile profile,
  ) async {
    return {
      'version': 1,
      'faceShape': profile.faceShape,
      'bodyShape': profile.bodyShape,
      'measurements': profile.measurementData,
      'faceImagePath': profile.facePath,
      'bodyImagePath': profile.bodyPath,
    };
  }
}
