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
  final String? lookTitle;
  final String? colourDirection;
  final List<String> stylingNotes;

  const AiStylingResult({
    required this.explanation,
    required this.topId,
    required this.bottomId,
    required this.shoesId,
    required this.accessoryId,
    this.lookTitle,
    this.colourDirection,
    this.stylingNotes = const [],
  });

  bool get hasAnyItems =>
      topId != null || bottomId != null || shoesId != null || accessoryId != null;

  List<String> get itemIds => [topId, bottomId, shoesId, accessoryId]
      .whereType<String>()
      .where((id) => id.isNotEmpty)
      .toSet()
      .toList(growable: false);

  String get displayTitle =>
      lookTitle == null || lookTitle!.trim().isEmpty ? 'Your personal look' : lookTitle!.trim();
}

class AiStylingService {
  AiStylingService._();

  static const Duration _requestTimeout = Duration(seconds: 20);

  /// Outfit grammar used by both AI Outfit and VYEA Personal Stylist.
  ///
  /// A top requires a bottom (trousers/skirt/etc. represented by Bottoms or
  /// Skirts). A dress is a one-piece garment and therefore cannot be paired
  /// with a bottom. Suits are also one complete garment family and should not
  /// be combined with a dress or another bottom. Jackets are layering pieces
  /// and may sit over either a top+bottom combination or a dress.
  static const Map<String, Set<String>> _compatibleCategories = {
    'Tops': {'Bottoms', 'Skirts'},
    'Bottoms': {'Tops', 'Jackets'},
    'Skirts': {'Tops', 'Jackets'},
    'Dresses': {'Shoes', 'Accessories', 'Jackets'},
    'Suits': {'Shoes', 'Accessories', 'Tops', 'Jackets'},
    'Jackets': {'Tops', 'Bottoms', 'Skirts', 'Dresses', 'Suits'},
    'Shoes': {'Tops', 'Bottoms', 'Skirts', 'Dresses', 'Suits', 'Jackets'},
    'Accessories': {'Tops', 'Bottoms', 'Skirts', 'Dresses', 'Suits', 'Jackets', 'Shoes'},
  };

  static bool areCategoriesCompatible(String first, String second) {
    final a = first.trim();
    final b = second.trim();
    if (a.isEmpty || b.isEmpty) return false;
    if (a == b) return a == 'Shoes' || a == 'Accessories' || a == 'Jackets';
    return _compatibleCategories[a]?.contains(b) == true ||
        _compatibleCategories[b]?.contains(a) == true;
  }

  static List<WardrobeItem> sanitizeLook(
    List<WardrobeItem> items, {
    WardrobeItem? selectedItem,
  }) {
    final unique = <String, WardrobeItem>{};
    for (final item in items) {
      if (item.id.trim().isEmpty) continue;
      unique[item.id] = item;
    }

    final candidates = unique.values.toList(growable: false);
    if (candidates.isEmpty) return const [];

    final selected = selectedItem;
    final result = <WardrobeItem>[];

    // One-piece garments are exclusive with separate bottoms.
    final hasDress = candidates.any((item) => item.category == 'Dresses');
    final hasBottom = candidates.any((item) =>
        item.category == 'Bottoms' || item.category == 'Skirts');

    if (hasDress) {
      final dress = selected?.category == 'Dresses'
          ? selected
          : candidates.firstWhere((item) => item.category == 'Dresses');
      result.add(dress);
      for (final category in ['Jackets', 'Shoes', 'Accessories']) {
        final item = candidates.firstWhere(
          (candidate) =>
              candidate.category == category &&
              areCategoriesCompatible(dress.category, candidate.category),
          orElse: () => _emptyItem,
        );
        if (item.id.isNotEmpty && !result.any((entry) => entry.id == item.id)) {
          result.add(item);
        }
      }
      return result.take(4).toList(growable: false);
    }

    // Two-piece route: Top + Bottom/Skirt, with optional jacket/shoes/accessory.
    final top = selected?.category == 'Tops'
        ? selected
        : candidates.cast<WardrobeItem?>().firstWhere(
              (item) => item?.category == 'Tops',
              orElse: () => null,
            );
    final bottom = selected?.category == 'Bottoms' || selected?.category == 'Skirts'
        ? selected
        : candidates.cast<WardrobeItem?>().firstWhere(
              (item) => item?.category == 'Bottoms' || item?.category == 'Skirts',
              orElse: () => null,
            );

    if (top != null && bottom != null) {
      result.add(top);
      result.add(bottom);
    } else if (selected != null && selected.category == 'Suits') {
      result.add(selected);
    } else {
      // Do not manufacture an invalid outfit from unrelated pieces.
      return candidates.take(2).toList(growable: false);
    }

    final baseCategories = result.map((item) => item.category).toSet();
    for (final candidate in candidates) {
      if (result.length >= 4 || result.any((item) => item.id == candidate.id)) continue;
      if (baseCategories.any((category) =>
          areCategoriesCompatible(category, candidate.category))) {
        result.add(candidate);
      }
    }

    return result.take(4).toList(growable: false);
  }

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

    final ownedWardrobe = wardrobe
        .where((item) => item.userId.isEmpty || item.userId == requestUid)
        .where((item) => _knownCategory(item.category))
        .toList(growable: false);
    if (ownedWardrobe.isEmpty) return null;

    final safeSelectedItem = selectedItem != null &&
            ownedWardrobe.any((item) => item.id == selectedItem.id)
        ? selectedItem
        : null;

    try {
      final idToken = await user.getIdToken();
      if (idToken == null || idToken.isEmpty) return null;

      final personalBrand = await _loadPersonalBrand(requestUid);
      final tibModel = await TibModelService.loadForUser(requestUid);

      final response = await http
          .post(
            Uri.parse(GoogleDriveConfig.uploadUrl),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({
              'action': 'aiStyling',
              'uid': requestUid,
              'idToken': idToken,
              'profile': _profilePayload(profile),
              'tibModel': _tibModelPayload(tibModel, profile),
              'wardrobe': ownedWardrobe.map(_wardrobePayload).toList(growable: false),
              'styles': _cleanStrings(styles, limit: 8),
              'preferences': _cleanStrings(preferences, limit: 8),
              'occasion': cleanOccasion,
              'personalBrand': personalBrand,
              'outfitRules': _outfitRulesPayload(),
              if (safeSelectedItem != null)
                'selectedItem': _wardrobePayload(safeSelectedItem),
            }),
          )
          .timeout(_requestTimeout);

      if (response.statusCode < 200 || response.statusCode >= 300) return null;

      final decoded = jsonDecode(response.body);
      final data = _extractResponseMap(decoded);
      if (data == null || data['success'] != true) return null;

      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null || currentUser.uid != requestUid) return null;

      final allowedIds = ownedWardrobe
          .map((item) => item.id.trim())
          .where((id) => id.isNotEmpty)
          .toSet();

      final result = AiStylingResult(
        explanation: _readText(data['explanation']),
        topId: _validWardrobeId(data['topId'], allowedIds),
        bottomId: _validWardrobeId(data['bottomId'], allowedIds),
        shoesId: _validWardrobeId(data['shoesId'], allowedIds),
        accessoryId: _validWardrobeId(data['accessoryId'], allowedIds),
        lookTitle: _readOptionalText(data['lookTitle'] ?? data['title']),
        colourDirection: _readOptionalText(data['colourDirection'] ?? data['colourStory']),
        stylingNotes: _readStringList(
          data['stylingNotes'] ?? data['notes'] ?? data['tips'],
          limit: 6,
        ),
      );

      final rawLook = [
        _findById(ownedWardrobe, result.topId),
        _findById(ownedWardrobe, result.bottomId),
        _findById(ownedWardrobe, result.shoesId),
        _findById(ownedWardrobe, result.accessoryId),
      ].whereType<WardrobeItem>().toList(growable: false);
      final sanitizedLook = sanitizeLook(rawLook, selectedItem: safeSelectedItem);

      if (sanitizedLook.isEmpty && result.explanation.isEmpty) return null;

      return AiStylingResult(
        explanation: result.explanation,
        topId: _idForCategory(sanitizedLook, 'Tops'),
        bottomId: _idForFirstCategories(sanitizedLook, const {'Bottoms', 'Skirts'}),
        shoesId: _idForCategory(sanitizedLook, 'Shoes'),
        accessoryId: _idForCategory(sanitizedLook, 'Accessories'),
        lookTitle: result.lookTitle,
        colourDirection: result.colourDirection,
        stylingNotes: result.stylingNotes,
      );
    } catch (_) {
      return null;
    }
  }

  static bool _knownCategory(String category) =>
      const {'Tops', 'Bottoms', 'Dresses', 'Suits', 'Jackets', 'Skirts', 'Shoes', 'Accessories'}
          .contains(category.trim());

  static Map<String, dynamic> _outfitRulesPayload() => {
        'noDressWithBottom': true,
        'topRequiresBottomOrSkirt': true,
        'dressIsOnePiece': true,
        'suitIsOnePieceFamily': true,
        'jacketIsLayeringPiece': true,
        'allowedCategories': const [
          'Tops',
          'Bottoms',
          'Dresses',
          'Suits',
          'Jackets',
          'Skirts',
          'Shoes',
          'Accessories',
        ],
      };

  static WardrobeItem? _findById(List<WardrobeItem> items, String? id) {
    if (id == null || id.isEmpty) return null;
    for (final item in items) {
      if (item.id == id) return item;
    }
    return null;
  }

  static String? _idForCategory(List<WardrobeItem> items, String category) {
    for (final item in items) {
      if (item.category == category) return item.id;
    }
    return null;
  }

  static String? _idForFirstCategories(
    List<WardrobeItem> items,
    Set<String> categories,
  ) {
    for (final item in items) {
      if (categories.contains(item.category)) return item.id;
    }
    return null;
  }

  static final WardrobeItem _emptyItem = WardrobeItem(
    id: '',
    userId: '',
    imageUrl: '',
    name: '',
    category: '',
    colour: '',
    style: '',
    season: '',
    isFavourite: false,
    notes: '',
    createdAt: null,
  );

  static Future<Map<String, dynamic>> _loadPersonalBrand(String uid) async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final raw = snapshot.data()?['personalBrand'];
      return raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
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
        'faceMeasurements': profile.faceMeasurements,
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
    TibModelProfile model,
    ColourAnalysisResult profile,
  ) {
    final payload = <String, dynamic>{
      'scannedFaceShape': profile.faceShape,
      'hasPersonalModel': model.isComplete,
      'personalIdentity': model.personalIdentityData,
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
      'measurementData': model.measurementData,
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

  static List<String> _cleanStrings(List<String> values, {required int limit}) => values
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

  static String _readText(dynamic value) => value is String ? value.trim() : '';

  static String? _readOptionalText(dynamic value) {
    final text = _readText(value);
    return text.isEmpty ? null : text;
  }

  static List<String> _readStringList(dynamic value, {required int limit}) {
    if (value is! List) return const [];
    return value
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toSet()
        .take(limit)
        .toList(growable: false);
  }

  static String? _validWardrobeId(dynamic value, Set<String> allowedIds) {
    if (value is! String) return null;
    final id = value.trim();
    return id.isEmpty || !allowedIds.contains(id) ? null : id;
  }
}
