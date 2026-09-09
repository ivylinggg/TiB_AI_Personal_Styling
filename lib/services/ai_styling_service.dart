import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../config/google_drive_config.dart';
import '../models/colour_analysis_result.dart';
import '../models/wardrobe_item.dart';
import 'tib_model_service.dart';

class AiStylingResult {
  final String explanation;
  final String? topId;
  final String? bottomId;
  final String? shoesId;
  final String? accessoryId;

  const AiStylingResult({
    required this.explanation,
    required this.topId,
    required this.bottomId,
    required this.shoesId,
    required this.accessoryId,
  });

  bool get hasAnyItems =>
      topId != null || bottomId != null || shoesId != null || accessoryId != null;

  List<String> get itemIds => [
        topId,
        bottomId,
        shoesId,
        accessoryId,
      ].whereType<String>().toSet().toList();
}

/// Sends the authenticated user's personal styling context to the AI backend.
///
/// The backend is treated as untrusted output: every returned wardrobe ID must
/// belong to the exact wardrobe snapshot supplied for this request.
class AiStylingService {
  AiStylingService._();

  static const Duration _requestTimeout = Duration(seconds: 20);

  static Future<AiStylingResult?> getRecommendation({
    required ColourAnalysisResult profile,
    required List<WardrobeItem> wardrobe,
    required List<String> styles,
    required List<String> preferences,
    required String occasion,
    WardrobeItem? selectedItem,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || wardrobe.isEmpty) return null;

    final requestUid = user.uid;
    final cleanOccasion = occasion.trim();
    if (cleanOccasion.isEmpty) return null;

    try {
      final idToken = await user.getIdToken();
      if (idToken == null || idToken.isEmpty) return null;

      final personalBrand = await _loadPersonalBrand(requestUid);
      final tibModel = await TibModelService.load();

      // Never trust a selected item from a different account/navigation state.
      final safeSelectedItem = selectedItem != null &&
              wardrobe.any((item) => item.id == selectedItem.id && item.userId == requestUid)
          ? selectedItem
          : null;

      final payload = <String, dynamic>{
        'action': 'aiStyling',
        'uid': requestUid,
        'idToken': idToken,
        'profile': _profilePayload(profile),
        'tibModel': _tibModelPayload(tibModel, profile),
        'wardrobe': wardrobe
            .where((item) => item.userId.isEmpty || item.userId == requestUid)
            .map(_wardrobePayload)
            .toList(growable: false),
        'styles': _cleanStrings(styles, limit: 8),
        'preferences': _cleanStrings(preferences, limit: 8),
        'occasion': cleanOccasion,
        'personalBrand': personalBrand,
        if (safeSelectedItem != null) 'selectedItem': _wardrobePayload(safeSelectedItem),
      };

      if ((payload['wardrobe'] as List).isEmpty) return null;

      final response = await http
          .post(
            Uri.parse(GoogleDriveConfig.uploadUrl),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(_requestTimeout);

      if (response.statusCode < 200 || response.statusCode >= 300) return null;

      final decoded = jsonDecode(response.body);
      final data = _extractResponseMap(decoded);
      if (data == null || data['success'] != true) return null;

      // Re-read authentication state before accepting a delayed response.
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null || currentUser.uid != requestUid) return null;

      final allowedIds = wardrobe
          .where((item) => item.userId.isEmpty || item.userId == requestUid)
          .map((item) => item.id)
          .where((id) => id.trim().isNotEmpty)
          .toSet();

      final result = AiStylingResult(
        explanation: _readText(data['explanation']),
        topId: _validWardrobeId(data['topId'], allowedIds),
        bottomId: _validWardrobeId(data['bottomId'], allowedIds),
        shoesId: _validWardrobeId(data['shoesId'], allowedIds),
        accessoryId: _validWardrobeId(data['accessoryId'], allowedIds),
      );

      if (!result.hasAnyItems && result.explanation.isEmpty) return null;
      return result;
    } catch (_) {
      return null;
    }
  }

  static Future<Map<String, dynamic>> _loadPersonalBrand(String uid) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      final raw = snapshot.data()?['personalBrand'];
      return raw is Map<String, dynamic> ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  static Map<String, dynamic> _profilePayload(ColourAnalysisResult profile) => {
        'season': profile.season,
        'undertone': profile.undertone,
        'brightness': profile.brightness,
        'contrast': profile.contrast,
        'colours': profile.colours,
        'colourReasons': profile.colourReasons,
        'faceShape': profile.faceShape,
        'faceShapeDescription': profile.faceShapeDescription,
        'faceStylingGuidance': profile.faceStylingGuidance,
        'personalColour': {
          'undertone': profile.undertone,
          'value': profile.brightness,
          'contrast': profile.contrast,
          'recommendedColours': profile.colours,
          'analysisReasons': profile.colourReasons,
        },
      };

  static Map<String, dynamic> _tibModelPayload(
    TibModel model,
    ColourAnalysisResult profile,
  ) {
    final payload = <String, dynamic>{
      'scannedFaceShape': profile.faceShape,
    };
    if (!model.isComplete) return payload;

    payload.addAll({
      'faceShape': model.faceShape,
      'bodyShape': model.bodyShape,
      'weightKg': model.weight,
      'heightCm': model.height,
      'bustCm': model.bust,
      'waistCm': model.waist,
      'hipsCm': model.hips,
    });
    return payload;
  }

  static Map<String, dynamic> _wardrobePayload(WardrobeItem item) => {
        'id': item.id,
        'name': item.name,
        'category': item.category,
        'colour': item.colour,
        'style': item.style,
        'season': item.season,
        'isFavourite': item.isFavourite,
      };

  static List<String> _cleanStrings(List<String> values, {required int limit}) =>
      values
          .map((value) => value.trim())
          .where((value) => value.isNotEmpty)
          .toSet()
          .take(limit)
          .toList(growable: false);

  static Map<String, dynamic>? _extractResponseMap(dynamic decoded) {
    if (decoded is! Map) return null;
    final nested = decoded['data'];
    if (nested is Map) return Map<String, dynamic>.from(nested);
    return Map<String, dynamic>.from(decoded);
  }

  static String _readText(dynamic value) =>
      value is String ? value.trim() : '';

  static String? _validWardrobeId(dynamic value, Set<String> allowedIds) {
    if (value is! String) return null;
    final id = value.trim();
    return id.isEmpty || !allowedIds.contains(id) ? null : id;
  }
}
