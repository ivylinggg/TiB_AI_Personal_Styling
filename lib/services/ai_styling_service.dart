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
/// Claude receives the user's observed personal-colour traits and face shape
/// together with wardrobe, preferences and optional TiB Model measurements.
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
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        final raw = userDoc.data()?['personalBrand'];
        if (raw is Map<String, dynamic>) personalBrand = raw;
      } catch (_) {}

      final tibModel = await TibModelService.load();
      final tibContext = {
        if (tibModel.isComplete) ...{
          'faceShape': tibModel.faceShape,
          'bodyShape': tibModel.bodyShape,
          'weightKg': tibModel.weight,
          'heightCm': tibModel.height,
          'bustCm': tibModel.bust,
          'waistCm': tibModel.waist,
          'hipsCm': tibModel.hips,
        },
        if (profile.faceShape != 'Unknown') 'scannedFaceShape': profile.faceShape,
      };

      final role = personalBrand['role'] is String ? (personalBrand['role'] as String).trim() : '';
      final impressions = personalBrand['impressions'] is List
          ? (personalBrand['impressions'] as List).whereType<String>().map((value) => value.trim()).where((value) => value.isNotEmpty).take(4).toList()
          : const <String>[];
      final statement = personalBrand['statement'] is String ? (personalBrand['statement'] as String).trim() : '';

      final brandContext = <String>[];
      if (role.isNotEmpty) brandContext.add('Role: $role');
      if (impressions.isNotEmpty) brandContext.add('Desired impression: ${impressions.join(', ')}');
      if (statement.isNotEmpty) brandContext.add('Personal brand statement: $statement');

      final enrichedOccasion = brandContext.isEmpty ? occasion : '$occasion\n\nPersonal Brand context:\n${brandContext.join('\n')}';

      final response = await http.post(
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
            'colourReasons': profile.colourReasons,
            'faceShape': profile.faceShape,
          },
          'tibModel': tibContext,
          'wardrobe': wardrobe.map((item) => {
                'id': item.id,
                'name': item.name,
                'category': item.category,
                'colour': item.colour,
                'style': item.style,
                'season': item.season,
                'isFavourite': item.isFavourite,
              }).toList(),
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
              'season': selectedItem.season,
            },
        }),
      ).timeout(const Duration(seconds: 20));

      if (response.statusCode != 200) return null;
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic> || decoded['success'] != true) return null;

      final explanation = decoded['explanation'] is String ? (decoded['explanation'] as String).trim() : '';
      String? asId(dynamic value) => value is String && value.trim().isNotEmpty ? value.trim() : null;
      final wardrobeIds = wardrobe.map((item) => item.id).toSet();
      String? validId(dynamic value) {
        final id = asId(value);
        if (id == null || !wardrobeIds.contains(id)) return null;
        return id;
      }

      final topId = validId(decoded['topId']);
      final bottomId = validId(decoded['bottomId']);
      final shoesId = validId(decoded['shoesId']);
      final accessoryId = validId(decoded['accessoryId']);
      final hasRecommendation = explanation.isNotEmpty || topId != null || bottomId != null || shoesId != null || accessoryId != null;
      if (!hasRecommendation) return null;

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
