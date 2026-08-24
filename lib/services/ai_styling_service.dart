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
}

/// Calls the existing Apps Script Web App's `aiStyling` action.
///
/// Claude receives the user's colour profile, wardrobe, preferences and,
/// when available, the TiB Model measurements plus automatically scanned
/// face/body shapes. The five body-shape rules remain deterministic in
/// TibModelService; Claude uses the resulting profile for styling decisions.
class AiStylingService {
  AiStylingService._();

  static Future<AiStylingResult?> getRecommendation({
    required ColourAnalysisResult profile,
    required List<WardrobeItem> wardrobe,
    required List<String> styles,
    required List<String> preferences,
    required String occasion,
    WardrobeItem? selectedItem,
  }) async {
    if (wardrobe.isEmpty) return null;

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return null;

      final idToken = await user.getIdToken();
      if (idToken == null || idToken.isEmpty) return null;

      Map<String, dynamic> personalBrand = const {};
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        final raw = userDoc.data()?['personalBrand'];
        if (raw is Map<String, dynamic>) personalBrand = raw;
      } catch (_) {
        // Optional context; styling continues without it.
      }

      final tibModel = await TibModelService.load();
      final tibContext = tibModel.isComplete
          ? {
              'faceShape': tibModel.faceShape,
              'bodyShape': tibModel.bodyShape,
              'weightKg': tibModel.weight,
              'heightCm': tibModel.height,
              'bustCm': tibModel.bust,
              'waistCm': tibModel.waist,
              'hipsCm': tibModel.hips,
            }
          : <String, dynamic>{};

      final role = personalBrand['role'] is String
          ? (personalBrand['role'] as String).trim()
          : '';
      final impressions = personalBrand['impressions'] is List
          ? (personalBrand['impressions'] as List)
              .whereType<String>()
              .map((value) => value.trim())
              .where((value) => value.isNotEmpty)
              .take(4)
              .toList()
          : const <String>[];
      final statement = personalBrand['statement'] is String
          ? (personalBrand['statement'] as String).trim()
          : '';

      final brandContext = <String>[];
      if (role.isNotEmpty) brandContext.add('Role: $role');
      if (impressions.isNotEmpty) {
        brandContext.add('Desired impression: ${impressions.join(', ')}');
      }
      if (statement.isNotEmpty) {
        brandContext.add('Personal brand statement: $statement');
      }

      final enrichedOccasion = brandContext.isEmpty
          ? occasion
          : '$occasion\n\nPersonal Brand context:\n${brandContext.join('\n')}';

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
              'tibModel': tibContext,
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
              'occasion': enrichedOccasion,
              'personalBrand': personalBrand,
              if (selectedItem != null)
                'selectedItem': {
                  'id': selectedItem.id,
                  'name': selectedItem.name,
                  'category': selectedItem.category,
                  'colour': selectedItem.colour,
                  'style': selectedItem.style,
                },
            }),
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body);
      if (data is! Map<String, dynamic> || data['success'] != true) return null;

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
