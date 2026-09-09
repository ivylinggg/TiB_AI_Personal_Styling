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
      lookTitle == null || lookTitle!.trim().isEmpty
          ? 'Your personal look'
          : lookTitle!.trim();
}

class AiStylingService {
  AiStylingService._();

  static const Duration _requestTimeout = Duration(seconds: 20);

  static const Set<String> _knownCategories = {
    'Tops',
    'Bottoms',
    'Dresses',
    'Suits',
    'Jackets',
    'Skirts',
    'Shoes',
    'Accessories',
  };

  /// Converts an AI/fallback selection into a coherent outfit while keeping
  /// the strongest wardrobe preferences, colour compatibility, style language,
  /// season fit, and occasion relevance.
  static List<WardrobeItem> sanitizeLook(
    List<WardrobeItem> items, {
    WardrobeItem? selectedItem,
    String occasion = '',
    ColourAnalysisResult? profile,
    List<String> styles = const [],
    List<String> preferences = const [],
  }) {
    final unique = <String, WardrobeItem>{};
    for (final item in items) {
      final id = item.id.trim();
      final category = item.category.trim();
      if (id.isEmpty || !_knownCategories.contains(category)) continue;
      unique[id] = item;
    }

    final candidates = unique.values.toList(growable: false);
    if (candidates.isEmpty) return const [];

    final selected = selectedItem == null
        ? null
        : unique[selectedItem.id.trim()];

    WardrobeItem? choose(String category, {Set<String> used = const {}}) {
      final pool = candidates
          .where((item) =>
              item.category == category && !used.contains(item.id))
          .toList(growable: false);
      if (pool.isEmpty) return null;
      return _rankItems(
        pool,
        profile: profile,
        occasion: occasion,
        styles: styles,
        preferences: preferences,
      ).first;
    }

    final selectedCategory = selected?.category;

    if (selectedCategory == 'Dresses') {
      return _buildOnePiece(
        candidates,
        selected!,
        choose,
      );
    }
    if (selectedCategory == 'Suits') {
      return _buildSuit(candidates, selected!, choose);
    }

    final top = selectedCategory == 'Tops'
        ? selected
        : choose('Tops');
    final lower = selectedCategory == 'Bottoms' || selectedCategory == 'Skirts'
        ? selected
        : _bestLower(
            candidates,
            profile: profile,
            occasion: occasion,
            styles: styles,
            preferences: preferences,
          );

    if (top != null && lower != null) {
      return _buildTwoPiece(
        candidates,
        top,
        lower,
        choose,
      );
    }

    final dress = choose('Dresses');
    if (dress != null) return _buildOnePiece(candidates, dress, choose);

    final suit = choose('Suits');
    if (suit != null) return _buildSuit(candidates, suit, choose);

    return const [];
  }

  static List<WardrobeItem> _buildTwoPiece(
    List<WardrobeItem> candidates,
    WardrobeItem top,
    WardrobeItem lower,
    WardrobeItem? Function(String, {Set<String> used}) choose,
  ) {
    final result = <WardrobeItem>[top, lower];
    final used = <String>{top.id, lower.id};

    final jacket = choose('Jackets', used: used);
    if (jacket != null) {
      result.add(jacket);
      used.add(jacket.id);
    }

    final shoes = choose('Shoes', used: used);
    if (shoes != null) {
      result.add(shoes);
      used.add(shoes.id);
    }

    if (result.length < 5) {
      final accessory = choose('Accessories', used: used);
      if (accessory != null) result.add(accessory);
    }

    return result.take(5).toList(growable: false);
  }

  static List<WardrobeItem> _buildOnePiece(
    List<WardrobeItem> candidates,
    WardrobeItem piece,
    WardrobeItem? Function(String, {Set<String> used}) choose,
  ) {
    final result = <WardrobeItem>[piece];
    final used = <String>{piece.id};

    final jacket = choose('Jackets', used: used);
    if (jacket != null) {
      result.add(jacket);
      used.add(jacket.id);
    }

    final shoes = choose('Shoes', used: used);
    if (shoes != null) {
      result.add(shoes);
      used.add(shoes.id);
    }

    if (result.length < 5) {
      final accessory = choose('Accessories', used: used);
      if (accessory != null) result.add(accessory);
    }

    return result.take(5).toList(growable: false);
  }

  static List<WardrobeItem> _buildSuit(
    List<WardrobeItem> candidates,
    WardrobeItem suit,
    WardrobeItem? Function(String, {Set<String> used}) choose,
  ) {
    final result = <WardrobeItem>[suit];
    final used = <String>{suit.id};

    final shoes = choose('Shoes', used: used);
    if (shoes != null) {
      result.add(shoes);
      used.add(shoes.id);
    }

    final accessory = choose('Accessories', used: used);
    if (accessory != null) result.add(accessory);

    return result.take(5).toList(growable: false);
  }

  static WardrobeItem? _bestLower(
    List<WardrobeItem> items, {
    ColourAnalysisResult? profile,
    String occasion = '',
    List<String> styles = const [],
    List<String> preferences = const [],
  }) {
    final pool = items
        .where((item) => item.category == 'Bottoms' || item.category == 'Skirts')
        .toList(growable: false);
    if (pool.isEmpty) return null;
    return _rankItems(
      pool,
      profile: profile,
      occasion: occasion,
      styles: styles,
      preferences: preferences,
    ).first;
  }

  static List<WardrobeItem> _rankItems(
    List<WardrobeItem> items, {
    ColourAnalysisResult? profile,
    required String occasion,
    required List<String> styles,
    required List<String> preferences,
  }) {
    final cleanStyles = _cleanTokenSet(styles);
    final cleanPreferences = _cleanTokenSet(preferences);
    final profileColours = profile?.colours
            .map((value) => value.trim().toLowerCase())
            .where((value) => value.isNotEmpty)
            .toSet() ??
        <String>{};
    final season = profile?.season.trim().toLowerCase() ?? '';
    final occasionTokens = _occasionTokens(occasion);

    final scored = items.map((item) {
      var score = 0;
      final colour = item.colour.trim().toLowerCase();
      final style = item.style.trim().toLowerCase();
      final itemSeason = item.season.trim().toLowerCase();
      final combined = '${item.name} $colour $style $itemSeason'.toLowerCase();

      if (item.isFavourite) score += 28;
      if (profileColours.any((target) =>
          colour.contains(target) || target.contains(colour))) score += 24;
      if (season.isNotEmpty &&
          (itemSeason.contains(season) || season.contains(itemSeason))) {
        score += 14;
      }
      if (cleanStyles.any((token) => combined.contains(token))) score += 16;
      if (cleanPreferences.any((token) => combined.contains(token))) score += 12;
      if (occasionTokens.any((token) => combined.contains(token))) score += 15;

      if (combined.contains('black') || combined.contains('white') ||
          combined.contains('navy') || combined.contains('beige')) {
        score += 2;
      }

      return _ScoredItem(item, score);
    }).toList(growable: false);

    scored.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      if (byScore != 0) return byScore;
      return a.item.name.toLowerCase().compareTo(b.item.name.toLowerCase());
    });
    return scored.map((entry) => entry.item).toList(growable: false);
  }

  static Set<String> _cleanTokenSet(List<String> values) => values
      .map((value) => value.trim().toLowerCase())
      .where((value) => value.isNotEmpty)
      .expand((value) => value.split(RegExp(r'[^a-z0-9]+')))
      .where((value) => value.length >= 3)
      .toSet();

  static Set<String> _occasionTokens(String value) {
    final normalized = value.trim().toLowerCase();
    final tokens = <String>{..._cleanTokenSet([normalized])};
    if (normalized.contains('work') || normalized.contains('office')) {
      tokens.addAll({'smart', 'formal', 'elegant', 'tailored'});
    }
    if (normalized.contains('date') || normalized.contains('dinner')) {
      tokens.addAll({'elegant', 'feminine', 'dress', 'polished'});
    }
    if (normalized.contains('weekend') || normalized.contains('cafe')) {
      tokens.addAll({'casual', 'relaxed', 'everyday', 'comfortable'});
    }
    return tokens;
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
        .where((item) => _knownCategories.contains(item.category.trim()))
        .toList(growable: false);
    if (ownedWardrobe.isEmpty) return null;

    final selectedId = selectedItem?.id.trim();
    final safeSelectedItem = selectedId == null || selectedId.isEmpty
        ? null
        : _findById(ownedWardrobe, selectedId);

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

      final rawResult = AiStylingResult(
        explanation: _readText(data['explanation']),
        topId: _validWardrobeId(data['topId'], allowedIds),
        bottomId: _validWardrobeId(data['bottomId'], allowedIds),
        shoesId: _validWardrobeId(data['shoesId'], allowedIds),
        accessoryId: _validWardrobeId(data['accessoryId'], allowedIds),
        lookTitle: _readOptionalText(data['lookTitle'] ?? data['title']),
        colourDirection:
            _readOptionalText(data['colourDirection'] ?? data['colourStory']),
        stylingNotes: _readStringList(
          data['stylingNotes'] ?? data['notes'] ?? data['tips'],
          limit: 6,
        ),
      );

      final rawLook = [
        _findById(ownedWardrobe, rawResult.topId),
        _findById(ownedWardrobe, rawResult.bottomId),
        _findById(ownedWardrobe, rawResult.shoesId),
        _findById(ownedWardrobe, rawResult.accessoryId),
      ].whereType<WardrobeItem>().toList(growable: false);

      final sanitized = sanitizeLook(
        rawLook,
        selectedItem: safeSelectedItem,
        occasion: cleanOccasion,
        profile: profile,
        styles: styles,
        preferences: preferences,
      );

      if (sanitized.isEmpty && rawResult.explanation.isEmpty) return null;

      return AiStylingResult(
        explanation: rawResult.explanation,
        topId: _idForCategory(sanitized, 'Tops'),
        bottomId:
            _idForFirstCategories(sanitized, const {'Bottoms', 'Skirts'}),
        shoesId: _idForCategory(sanitized, 'Shoes'),
        accessoryId: _idForCategory(sanitized, 'Accessories'),
        lookTitle: rawResult.lookTitle,
        colourDirection: rawResult.colourDirection,
        stylingNotes: rawResult.stylingNotes,
      );
    } catch (_) {
      return null;
    }
  }

  static Map<String, dynamic> _outfitRulesPayload() => {
        'noDressWithBottomOrSkirt': true,
        'topRequiresBottomOrSkirt': true,
        'dressIsOnePiece': true,
        'suitIsOnePiece': true,
        'jacketIsLayerOnly': true,
        'maxFiveItems': true,
        'rankWithinCategoryByPersonalFit': true,
        'prioritiseFavouriteItems': true,
        'considerPersonalColours': true,
        'considerSeason': true,
        'considerStylePreferences': true,
        'considerOccasion': true,
        'allowedRoutes': const [
          'Tops + Bottoms',
          'Tops + Skirts',
          'Tops + Bottoms + Jacket',
          'Tops + Skirts + Jacket',
          'Tops + Bottoms + Shoes',
          'Tops + Skirts + Shoes',
          'Tops + Bottoms + Jacket + Shoes',
          'Tops + Skirts + Jacket + Shoes',
          'Tops + Bottoms + Jacket + Shoes + Accessories',
          'Tops + Skirts + Jacket + Shoes + Accessories',
          'Dresses + Shoes',
          'Dresses + Jacket + Shoes',
          'Dresses + Shoes + Accessories',
          'Dresses + Jacket + Shoes + Accessories',
          'Suits + Shoes',
          'Suits + Shoes + Accessories',
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

  static Future<Map<String, dynamic>> _loadPersonalBrand(String uid) async {
    try {
      final snapshot =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final raw = snapshot.data()?['personalBrand'];
      return raw is Map
          ? Map<String, dynamic>.from(raw)
          : <String, dynamic>{};
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

class _ScoredItem {
  final WardrobeItem item;
  final int score;

  const _ScoredItem(this.item, this.score);
}
