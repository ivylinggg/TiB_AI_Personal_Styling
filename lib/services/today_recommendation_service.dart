import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../models/colour_analysis_result.dart';

class TodayRecommendation {
  final String style;
  final List<String> tags;
  final String colour;
  final String outfit;
  final String reason;
  final String stylingTip;
  final bool isAiGenerated;

  const TodayRecommendation({
    required this.style,
    required this.tags,
    required this.colour,
    required this.outfit,
    required this.reason,
    this.stylingTip = '',
    this.isAiGenerated = false,
  });

  factory TodayRecommendation.fromJson(
    Map<String, dynamic> json, {
    String fallbackColour = '—',
  }) {
    List<String> readTags(dynamic value) {
      if (value is List) {
        return value
            .map((item) => item.toString().trim())
            .where((item) => item.isNotEmpty)
            .take(5)
            .toList();
      }
      return const [];
    }

    String read(String key, String fallback) {
      final value = json[key];
      final text = value?.toString().trim() ?? '';
      return text.isEmpty ? fallback : text;
    }

    return TodayRecommendation(
      style: read('styleDirection', 'Personal Style'),
      tags: readTags(json['styleTags']),
      colour: read('recommendedColour', fallbackColour),
      outfit: read(
        'outfitFormula',
        'A balanced outfit built around your personal proportions.',
      ),
      reason: read(
        'whyItWorks',
        'This recommendation is tailored to your VYEA profile.',
      ),
      stylingTip: read('stylingTip', ''),
      isAiGenerated: true,
    );
  }
}

class TodayRecommendationService {
  const TodayRecommendationService._();

  static const String _endpoint =
      'https://script.google.com/macros/s/AKfycbwWXoyKGqkMfM9XDRQuFidMv5ZGxwqIqGjAVv-qTvdTiJM2xUqlfOyXfsestk9uqazN3g/exec';

  static Future<TodayRecommendation> getRecommendation({
    ColourAnalysisResult? analysis,
    String? bodyShape,
    String? faceShape,
    double? weight,
    double? height,
    double? bust,
    double? waist,
    double? hips,
    String? personalStyle,
    List<Map<String, dynamic>> wardrobe = const [],
    String? occasion,
  }) async {
    final fallback = build(
      analysis: analysis,
      personalStyle: personalStyle,
    );

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return fallback;

      final token = await user.getIdToken();
      if (token == null || token.isEmpty) return fallback;

      final profile = await _loadProfile(user.uid);
      final colour = _todayColour(analysis);

      final profilePayload = <String, dynamic>{...profile};
      if (bodyShape != null && bodyShape.trim().isNotEmpty) {
        profilePayload['bodyShape'] = bodyShape.trim();
      }
      if (faceShape != null && faceShape.trim().isNotEmpty) {
        profilePayload['faceShape'] = faceShape.trim();
      }
      if (weight != null) profilePayload['weight'] = weight;
      if (height != null) profilePayload['height'] = height;
      if (bust != null) profilePayload['bust'] = bust;
      if (waist != null) profilePayload['waist'] = waist;
      if (hips != null) profilePayload['hips'] = hips;
      if (personalStyle != null && personalStyle.trim().isNotEmpty) {
        profilePayload['personalStyle'] = personalStyle.trim();
      }

      final response = await http
          .post(
            Uri.parse(_endpoint),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({
              'action': 'todayRecommendation',
              'idToken': token,
              'todayColour': colour,
              'occasion': occasion?.trim().isNotEmpty == true
                  ? occasion!.trim()
                  : 'Everyday',
              'profile': profilePayload,
              'colourAnalysis': analysis == null
                  ? null
                  : {
                      'season': analysis.season,
                      'undertone': analysis.undertone,
                      'brightness': analysis.brightness,
                      'contrast': analysis.contrast,
                      'colours': analysis.colours,
                    },
              'wardrobe': wardrobe,
            }),
          )
          .timeout(const Duration(seconds: 25));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return fallback;
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) return fallback;

      final data = decoded['data'];
      if (data is Map<String, dynamic>) {
        return _sanitiseAiResponse(
          TodayRecommendation.fromJson(data, fallbackColour: colour),
          fallback,
          colour,
        );
      }

      if (decoded['styleDirection'] != null ||
          decoded['recommendedColour'] != null ||
          decoded['outfitFormula'] != null) {
        return _sanitiseAiResponse(
          TodayRecommendation.fromJson(decoded, fallbackColour: colour),
          fallback,
          colour,
        );
      }

      return fallback;
    } catch (_) {
      return fallback;
    }
  }

  static TodayRecommendation _sanitiseAiResponse(
    TodayRecommendation recommendation,
    TodayRecommendation fallback,
    String colour,
  ) {
    final style = recommendation.style.trim();
    final outfit = recommendation.outfit.trim();
    final reason = recommendation.reason.trim();

    if (style.isEmpty || outfit.isEmpty || reason.isEmpty) {
      return fallback;
    }

    return TodayRecommendation(
      style: style,
      tags: recommendation.tags,
      colour: colour == '—' ? recommendation.colour : colour,
      outfit: outfit,
      reason: reason,
      stylingTip: recommendation.stylingTip.trim(),
      isAiGenerated: true,
    );
  }

  static Future<Map<String, dynamic>> _loadProfile(String uid) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      return snapshot.data() ?? <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  static TodayRecommendation build({
    ColourAnalysisResult? analysis,
    String? personalStyle,
  }) {
    final colour = _todayColour(analysis);
    final key = colour.toLowerCase();
    final styleHint = personalStyle?.trim() ?? '';

    if (_contains(key, ['pink', 'rose', 'red', 'burgundy'])) {
      return TodayRecommendation(
        style: styleHint.isEmpty ? 'Soft & Romantic' : styleHint,
        tags: const ['Feminine', 'Sweet', 'Elegant'],
        colour: colour,
        outfit: 'A soft blouse with a flattering skirt and simple heels.',
        reason:
            'A gentle colour story helps create a polished, feminine look without feeling overdone.',
      );
    }

    if (_contains(key, ['blue', 'navy', 'cobalt', 'teal', 'turquoise'])) {
      return TodayRecommendation(
        style: styleHint.isEmpty ? 'Smart Casual' : styleHint,
        tags: const ['Relaxed', 'Refined', 'Confident'],
        colour: colour,
        outfit:
            'A clean top with tailored trousers, loafers or minimal sneakers.',
        reason:
            'Cool tones pair naturally with clean silhouettes for an effortless but put-together look.',
      );
    }

    if (_contains(key, ['black', 'grey', 'gray', 'white', 'charcoal'])) {
      return TodayRecommendation(
        style: styleHint.isEmpty ? 'Minimal Chic' : styleHint,
        tags: const ['Simple', 'Clean', 'Polished'],
        colour: colour,
        outfit:
            'A clean monochrome base with one structured statement piece.',
        reason:
            'A restrained palette lets your silhouette and styling details become the focus.',
      );
    }

    if (_contains(key, ['orange', 'yellow', 'coral', 'peach'])) {
      return TodayRecommendation(
        style: styleHint.isEmpty ? 'Bright & Playful' : styleHint,
        tags: const ['Sunny', 'Fresh', 'Energetic'],
        colour: colour,
        outfit:
            'A light top with relaxed bottoms and one playful accessory.',
        reason:
            'A brighter colour works best when balanced with simple shapes and an easy silhouette.',
      );
    }

    if (_contains(key, ['purple', 'lavender', 'mauve'])) {
      return TodayRecommendation(
        style: styleHint.isEmpty ? 'Soft Creative' : styleHint,
        tags: const ['Gentle', 'Creative', 'Unique'],
        colour: colour,
        outfit:
            'A soft-toned top with a clean bottom and delicate accessories.',
        reason:
            'The softer palette gives you room to show personality while keeping the outfit refined.',
      );
    }

    final weekday = DateTime.now().weekday;
    final styles = <TodayRecommendation>[
      TodayRecommendation(
        style: styleHint.isEmpty ? 'Clean Start' : styleHint,
        tags: const ['Simple', 'Fresh', 'Put-together'],
        colour: '—',
        outfit:
            'A fresh everyday outfit built around one clean, versatile piece.',
        reason:
            'Simple foundations make it easier to look polished with less effort.',
      ),
      TodayRecommendation(
        style: styleHint.isEmpty ? 'Easy Smart' : styleHint,
        tags: const ['Casual', 'Neat', 'Versatile'],
        colour: '—',
        outfit:
            'A neat top with comfortable tailored bottoms and simple shoes.',
        reason:
            'A balanced casual-smart formula works across most everyday plans.',
      ),
      TodayRecommendation(
        style: styleHint.isEmpty ? 'Balanced Chic' : styleHint,
        tags: const ['Simple', 'Elegant', 'Comfortable'],
        colour: '—',
        outfit:
            'A comfortable base with one elegant finishing detail.',
        reason:
            'Keeping the base easy lets one polished detail elevate the whole look.',
      ),
      TodayRecommendation(
        style: styleHint.isEmpty ? 'Modern Feminine' : styleHint,
        tags: const ['Soft', 'Stylish', 'Polished'],
        colour: '—',
        outfit:
            'A softly fitted top with a clean skirt or tailored trousers.',
        reason:
            'A soft silhouette with structure creates an easy modern feminine balance.',
      ),
      TodayRecommendation(
        style: styleHint.isEmpty ? 'Casual Glow' : styleHint,
        tags: const ['Relaxed', 'Bright', 'Fun'],
        colour: '—',
        outfit:
            'A relaxed outfit with one brighter accent or accessory.',
        reason:
            'One playful detail keeps a casual look intentional and fresh.',
      ),
      TodayRecommendation(
        style: styleHint.isEmpty ? 'Effortless Weekend' : styleHint,
        tags: const ['Casual', 'Easy', 'Cool'],
        colour: '—',
        outfit:
            'An easy top, relaxed bottoms and comfortable statement shoes.',
        reason:
            'Comfort-first styling can still look considered when proportions stay clean.',
      ),
      TodayRecommendation(
        style: styleHint.isEmpty ? 'Soft Sunday' : styleHint,
        tags: const ['Comfortable', 'Calm', 'Clean'],
        colour: '—',
        outfit:
            'A soft, comfortable outfit in a calm neutral or muted tone.',
        reason:
            'A relaxed palette and comfortable silhouette create an effortless finish.',
      ),
    ];

    final fallback = styles[weekday - 1];
    return TodayRecommendation(
      style: fallback.style,
      tags: fallback.tags,
      colour: colour,
      outfit: fallback.outfit,
      reason: fallback.reason,
    );
  }

  static String _todayColour(ColourAnalysisResult? result) {
    if (result == null || result.colours.isEmpty) return '—';

    final colours = result.colours
        .map((colour) => colour.trim())
        .where((colour) => colour.isNotEmpty)
        .toList();
    if (colours.isEmpty) return '—';

    final start = DateTime(DateTime.now().year, 1, 1);
    final day = DateTime.now().difference(start).inDays;
    return colours[day % colours.length];
  }

  static bool _contains(String value, List<String> values) =>
      values.any(value.contains);
}
