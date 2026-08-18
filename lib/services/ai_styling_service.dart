import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../config/google_drive_config.dart';
import '../models/colour_analysis_result.dart';
import '../models/wardrobe_item.dart';

/// Result of a real Claude AI styling request. [topId]/[bottomId]/[shoesId]/
/// [accessoryId] are ids of items from the caller's own wardrobe (validated
/// server-side against the wardrobe list that was sent) -- never a
/// fabricated item. [accessoryId] is only ever set when Claude judged the
/// occasion actually calls for one and a real match existed.
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
}

/// Calls the existing Apps Script Web App's `aiStyling` action, which
/// verifies the caller is a Premium user (via their Firebase ID token,
/// checked against Firestore) and, only then, asks Claude for a real
/// personalised pick from the user's own wardrobe.
///
/// This never throws and never surfaces a network/AI error to the caller --
/// any failure (not Premium, offline, timeout, AI unavailable) simply
/// returns null so the screen can fall back to the local heuristic engine.
class AiStylingService {
  AiStylingService._();

  static Future<AiStylingResult?> getRecommendation({
    required ColourAnalysisResult profile,
    required List<WardrobeItem> wardrobe,
    required List<String> styles,
    required List<String> preferences,
    required String occasion,
  }) async {
    if (wardrobe.isEmpty) {
      return null;
    }

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        return null;
      }

      final idToken = await user.getIdToken();
      if (idToken == null || idToken.isEmpty) {
        return null;
      }

      final response = await http
          .post(
            Uri.parse(GoogleDriveConfig.uploadUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'action': 'aiStyling',
              'uid': user.uid,
              'idToken': idToken,
              'profile': {
                'season': profile.season,
                'undertone': profile.undertone,
                'brightness': profile.brightness,
                'contrast': profile.contrast,
                'colours': profile.colours,
              },
              'wardrobe': wardrobe
                  .map(
                    (item) => {
                      'id': item.id,
                      'name': item.name,
                      'category': item.category,
                      'colour': item.colour,
                      'style': item.style,
                      'isFavourite': item.isFavourite,
                    },
                  )
                  .toList(),
              'styles': styles,
              'preferences': preferences,
              'occasion': occasion,
            }),
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode != 200) {
        return null;
      }

      final data = jsonDecode(response.body);

      if (data is! Map<String, dynamic> || data['success'] != true) {
        return null;
      }

      final explanation = data['explanation'] is String
          ? (data['explanation'] as String).trim()
          : '';

      String? asId(dynamic value) =>
          value is String && value.isNotEmpty ? value : null;

      final topId = asId(data['topId']);
      final bottomId = asId(data['bottomId']);
      final shoesId = asId(data['shoesId']);
      final accessoryId = asId(data['accessoryId']);

      if (explanation.isEmpty &&
          topId == null &&
          bottomId == null &&
          shoesId == null &&
          accessoryId == null) {
        return null;
      }

      return AiStylingResult(
        explanation: explanation,
        topId: topId,
        bottomId: bottomId,
        shoesId: shoesId,
        accessoryId: accessoryId,
      );
    } catch (_) {
      return null;
    }
  }
}