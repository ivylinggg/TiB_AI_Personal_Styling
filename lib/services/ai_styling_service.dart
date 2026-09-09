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
  final String? dressId;
  final String? suitId;
  final String? jacketId;
  final String? shoesId;
  final String? accessoryId;
  final String? lookTitle;
  final String? colourDirection;
  final List<String> stylingNotes;
  final int matchScore;
  final Map<String, int> scoreBreakdown;

  const AiStylingResult({
    required this.explanation,
    required this.topId,
    required this.bottomId,
    required this.dressId,
    required this.suitId,
    required this.jacketId,
    required this.shoesId,
    required this.accessoryId,
    this.lookTitle,
    this.colourDirection,
    this.stylingNotes = const [],
    this.matchScore = 0,
    this.scoreBreakdown = const {},
  });

  List<String> get itemIds => [topId, bottomId, dressId, suitId, jacketId, shoesId, accessoryId]
      .whereType<String>()
      .where((id) => id.isNotEmpty)
      .toSet()
      .toList(growable: false);

  bool get hasAnyItems => itemIds.isNotEmpty;

  String get displayTitle => lookTitle == null || lookTitle!.trim().isEmpty ? 'Your personal look' : lookTitle!.trim();
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

  static const Set<String> _neutralColourFamilies = {
    'black',
    'white',
    'grey',
    'beige',
    'brown',
  };

  static String _normaliseColour(String value) => value.trim().toLowerCase().replaceAll(RegExp(r'[_-]+'), ' ');

  static String _colourFamily(String raw) {
    final value = _normaliseColour(raw);
    const families = <String, List<String>>{
      'red': ['red', 'crimson', 'burgundy', 'maroon', 'wine', 'scarlet', 'berry'],
      'orange': ['orange', 'rust', 'terracotta', 'coral', 'peach'],
      'yellow': ['yellow', 'mustard', 'gold', 'golden'],
      'green': ['green', 'olive', 'sage', 'mint', 'khaki', 'emerald'],
      'blue': ['blue', 'denim', 'cobalt', 'teal', 'turquoise', 'aqua'],
      'navy': ['navy'],
      'purple': ['purple', 'lavender', 'lilac', 'plum', 'violet', 'mauve'],
      'pink': ['pink', 'rose', 'blush', 'fuchsia', 'magenta'],
      'brown': ['brown', 'camel', 'tan', 'caramel', 'chocolate', 'mocha'],
      'beige': ['beige', 'cream', 'ivory', 'sand', 'stone'],
      'black': ['black', 'charcoal'],
      'white': ['white', 'snow'],
      'grey': ['grey', 'gray', 'silver'],
    };
    for (final entry in families.entries) {
      if (entry.value.any(value.contains)) return entry.key;
    }
    return 'unknown';
  }

  static bool _isNeutral(String family) => _neutralColourFamilies.contains(family);

  static bool _colourMatches(String colour, String target) {
    final a = _colourFamily(colour);
    final b = _colourFamily(target);
    return a != 'unknown' && b != 'unknown' && (a == b || (_isNeutral(a) && _isNeutral(b)));
  }

  static bool _compatibleColourFamilies(String a, String b) {
    const compatible = <String, Set<String>>{
      'red': {'pink', 'orange', 'purple', 'brown'},
      'orange': {'red', 'yellow', 'brown', 'beige'},
      'yellow': {'orange', 'green', 'brown', 'navy'},
      'green': {'yellow', 'blue', 'brown', 'beige'},
      'blue': {'green', 'purple', 'navy', 'white', 'grey'},
      'navy': {'blue', 'yellow', 'white', 'beige', 'grey'},
      'purple': {'red', 'pink', 'blue', 'grey'},
      'pink': {'red', 'purple', 'grey', 'white'},
      'brown': {'orange', 'green', 'beige', 'white'},
    };
    return compatible[a]?.contains(b) == true || compatible[b]?.contains(a) == true;
  }

  static String _styleFamily(String raw) {
    final value = raw.trim().toLowerCase();
    if (value.isEmpty) return 'unknown';
    if (value.contains('formal') || value.contains('tailored') || value.contains('office') || value.contains('business')) return 'formal';
    if (value.contains('elegant') || value.contains('feminine') || value.contains('romantic')) return 'elegant';
    if (value.contains('casual') || value.contains('relaxed') || value.contains('everyday')) return 'casual';
    if (value.contains('minimal') || value.contains('classic') || value.contains('clean')) return 'minimal';
    if (value.contains('street') || value.contains('edgy')) return 'street';
    if (value.contains('sport') || value.contains('athleisure')) return 'sport';
    return 'unknown';
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
      tokens.addAll({'smart', 'formal', 'elegant', 'tailored', 'business'});
    }
    if (normalized.contains('date') || normalized.contains('dinner')) {
      tokens.addAll({'elegant', 'feminine', 'dress', 'polished', 'refined'});
    }
    if (normalized.contains('weekend') || normalized.contains('cafe')) {
      tokens.addAll({'casual', 'relaxed', 'everyday', 'comfortable'});
    }
    return tokens;
  }

  static String? _lookKey(List<WardrobeItem> look) {
    if (look.isEmpty) return null;
    final ids = look.map((item) => item.id).where((id) => id.isNotEmpty).toList()..sort();
    return ids.isEmpty ? null : ids.join('|');
  }

  static List<WardrobeItem> sanitizeLook(
    List<WardrobeItem> items, {
    WardrobeItem? selectedItem,
    String occasion = '',
    ColourAnalysisResult? profile,
    List<String> styles = const [],
    List<String> preferences = const [],
    Set<String> excludedLookKeys = const {},
    Map<String, double> feedbackBias = const {},
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
    final selected = selectedItem == null ? null : unique[selectedItem.id.trim()];

    WardrobeItem? choose(
      String category, {
      Set<String> used = const {},
      List<WardrobeItem> anchors = const [],
    }) {
      final pool = candidates.where((item) => item.category == category && !used.contains(item.id)).toList(growable: false);
      if (pool.isEmpty) return null;
      final ranked = _rankItems(
        pool,
        profile: profile,
        occasion: occasion,
        styles: styles,
        preferences: preferences,
        anchors: anchors,
        feedbackBias: feedbackBias,
      );
      return ranked.isEmpty ? null : ranked.first;
    }

    if (selected?.category == 'Dresses') {
      return _buildOnePiece(candidates, selected!, choose, profile: profile, occasion: occasion, styles: styles, preferences: preferences, excludedLookKeys: excludedLookKeys);
    }
    if (selected?.category == 'Suits') {
      return _buildSuit(candidates, selected!, choose, profile: profile, occasion: occasion, styles: styles, preferences: preferences, excludedLookKeys: excludedLookKeys);
    }

    final top = selected?.category == 'Tops' ? selected : choose('Tops');
    final lower = selected?.category == 'Bottoms' || selected?.category == 'Skirts'
        ? selected
        : _bestPartner(candidates, const {'Bottoms', 'Skirts'}, anchors: top == null ? const [] : [top], profile: profile, occasion: occasion, styles: styles, preferences: preferences, feedbackBias: feedbackBias);
    if (top != null && lower != null) {
      final look = _buildTwoPiece(candidates, top, lower, choose, profile: profile, occasion: occasion, styles: styles, preferences: preferences);
      final key = _lookKey(look);
      if (key != null && !excludedLookKeys.contains(key)) return look;
    }

    final dress = choose('Dresses');
    if (dress != null) {
      final look = _buildOnePiece(candidates, dress, choose, profile: profile, occasion: occasion, styles: styles, preferences: preferences, excludedLookKeys: excludedLookKeys);
      if (look.isNotEmpty) return look;
    }

    final suit = choose('Suits');
    if (suit != null) {
      final look = _buildSuit(candidates, suit, choose, profile: profile, occasion: occasion, styles: styles, preferences: preferences, excludedLookKeys: excludedLookKeys);
      if (look.isNotEmpty) return look;
    }
    return const [];
  }

  static List<WardrobeItem> _buildTwoPiece(
    List<WardrobeItem> candidates,
    WardrobeItem top,
    WardrobeItem lower,
    WardrobeItem? Function(String, {Set<String> used, List<WardrobeItem> anchors}) choose, {
    required ColourAnalysisResult? profile,
    required String occasion,
    required List<String> styles,
    required List<String> preferences,
  }) {
    final result = <WardrobeItem>[top, lower];
    final used = <String>{top.id, lower.id};
    final jacket = choose('Jackets', used: used, anchors: [top, lower]);
    if (jacket != null) {
      result.add(jacket);
      used.add(jacket.id);
    }
    final shoes = choose('Shoes', used: used, anchors: result);
    if (shoes != null) {
      result.add(shoes);
      used.add(shoes.id);
    }
    final accessory = choose('Accessories', used: used, anchors: result);
    if (accessory != null) result.add(accessory);
    return _finalizeLook(result, selectedItem: top, profile: profile, occasion: occasion, styles: styles, preferences: preferences);
  }

  static List<WardrobeItem> _buildOnePiece(
    List<WardrobeItem> candidates,
    WardrobeItem piece,
    WardrobeItem? Function(String, {Set<String> used, List<WardrobeItem> anchors}) choose, {
    required ColourAnalysisResult? profile,
    required String occasion,
    required List<String> styles,
    required List<String> preferences,
    Set<String> excludedLookKeys = const {},
  }) {
    final result = <WardrobeItem>[piece];
    final used = <String>{piece.id};
    final jacket = choose('Jackets', used: used, anchors: [piece]);
    if (jacket != null) {
      result.add(jacket);
      used.add(jacket.id);
    }
    final shoes = choose('Shoes', used: used, anchors: result);
    if (shoes != null) {
      result.add(shoes);
      used.add(shoes.id);
    }
    final accessory = choose('Accessories', used: used, anchors: result);
    if (accessory != null) result.add(accessory);
    final look = _finalizeLook(result, selectedItem: piece, profile: profile, occasion: occasion, styles: styles, preferences: preferences);
    final key = _lookKey(look);
    return key != null && excludedLookKeys.contains(key) ? const [] : look;
  }

  static List<WardrobeItem> _buildSuit(
    List<WardrobeItem> candidates,
    WardrobeItem suit,
    WardrobeItem? Function(String, {Set<String> used, List<WardrobeItem> anchors}) choose, {
    required ColourAnalysisResult? profile,
    required String occasion,
    required List<String> styles,
    required List<String> preferences,
    Set<String> excludedLookKeys = const {},
  }) {
    final result = <WardrobeItem>[suit];
    final used = <String>{suit.id};
    final shoes = choose('Shoes', used: used, anchors: [suit]);
    if (shoes != null) {
      result.add(shoes);
      used.add(shoes.id);
    }
    final accessory = choose('Accessories', used: used, anchors: result);
    if (accessory != null) result.add(accessory);
    final look = _finalizeLook(result, selectedItem: suit, profile: profile, occasion: occasion, styles: styles, preferences: preferences);
    final key = _lookKey(look);
    return key != null && excludedLookKeys.contains(key) ? const [] : look;
  }

  static WardrobeItem? _bestPartner(
    List<WardrobeItem> items,
    Set<String> categories, {
    required List<WardrobeItem> anchors,
    ColourAnalysisResult? profile,
    required String occasion,
    required List<String> styles,
    required List<String> preferences,
    Map<String, double> feedbackBias = const {},
  }) {
    final pool = items.where((item) => categories.contains(item.category)).toList(growable: false);
    if (pool.isEmpty) return null;
    final ranked = _rankItems(pool, profile: profile, occasion: occasion, styles: styles, preferences: preferences, anchors: anchors, feedbackBias: feedbackBias);
    return ranked.isEmpty ? null : ranked.first;
  }

  static List<WardrobeItem> _finalizeLook(
    List<WardrobeItem> result, {
    required WardrobeItem? selectedItem,
    required ColourAnalysisResult? profile,
    required String occasion,
    required List<String> styles,
    required List<String> preferences,
  }) {
    final unique = <String, WardrobeItem>{};
    for (final item in result) {
      if (_knownCategories.contains(item.category)) unique[item.id] = item;
    }
    final sanitized = unique.values.toList(growable: false);
    if (sanitized.isEmpty) return const [];

    final categories = sanitized.map((item) => item.category).toSet();
    final validStructure =
        (categories.contains('Dresses') &&
                !categories.contains('Bottoms') &&
                !categories.contains('Skirts') &&
                !categories.contains('Tops') &&
                !categories.contains('Suits')) ||
        (categories.contains('Suits') &&
                !categories.contains('Bottoms') &&
                !categories.contains('Skirts') &&
                !categories.contains('Tops') &&
                !categories.contains('Dresses')) ||
        (categories.contains('Tops') &&
                (categories.contains('Bottoms') || categories.contains('Skirts')) &&
                !categories.contains('Dresses') &&
                !categories.contains('Suits'));

    if (!validStructure) return const [];
    final score = _scoreLook(sanitized, profile: profile, occasion: occasion, styles: styles, preferences: preferences, selectedItem: selectedItem);
    if (score < 18) return const [];
    return sanitized.take(5).toList(growable: false);
  }

  static List<WardrobeItem> _rankItems(
    List<WardrobeItem> items, {
    ColourAnalysisResult? profile,
    required String occasion,
    required List<String> styles,
    required List<String> preferences,
    List<WardrobeItem> anchors = const [],
    Map<String, double> feedbackBias = const {},
  }) {
    final cleanStyles = _cleanTokenSet(styles);
    final cleanPreferences = _cleanTokenSet(preferences);
    final scored = items.map((item) {
      var score = (feedbackBias[item.id] ?? 0).round();
      final colour = _normaliseColour(item.colour);
      final combined = '${item.name} ${item.style} ${item.season} ${item.occasion} ${item.formality} ${item.pattern} ${item.material} ${item.silhouette} ${item.fit} ${item.length} ${item.notes}'.toLowerCase();
      final season = profile?.season.trim().toLowerCase() ?? '';

      if (item.isFavourite) score += 18;
      if (profile != null && profile.colours.any((value) => _colourMatches(colour, value))) score += 24;
      if (profile != null && profile.bestNeutrals.any((value) => _colourMatches(colour, value))) score += 12;
      if (profile != null && profile.accentColours.any((value) => _colourMatches(colour, value))) score += 8;
      if (profile != null && profile.lessIdealColours.any((value) => _colourMatches(colour, value))) score -= 10;
      if (season.isNotEmpty && (combined.contains(season) || item.season.toLowerCase().contains('all seasons'))) score += 12;
      if (cleanStyles.any(combined.contains)) score += 14;
      if (cleanPreferences.any(combined.contains)) score += 10;
      if (_occasionTokens(occasion).any(combined.contains)) score += 14;
      if (_isNeutral(_colourFamily(colour))) score += 3;
      if (item.warmth != null &&
          (occasion.toLowerCase().contains('weekend') || occasion.toLowerCase().contains('cafe')) &&
          item.warmth! <= 2) {
        score += 3;
      }

      for (final anchor in anchors) {
        score += _pairCompatibilityScore(item, anchor);
      }
      return _ScoredItem(item, score);
    }).toList(growable: false);

    scored.sort((a, b) => b.score == a.score
        ? a.item.name.toLowerCase().compareTo(b.item.name.toLowerCase())
        : b.score.compareTo(a.score));
    return scored.map((entry) => entry.item).toList(growable: false);
  }

  static int _scoreLook(
    List<WardrobeItem> look, {
    required ColourAnalysisResult? profile,
    required String occasion,
    required List<String> styles,
    required List<String> preferences,
    WardrobeItem? selectedItem,
  }) {
    if (look.isEmpty) return 0;
    var score = 0;
    for (final item in look) {
      score += _individualFitScore(item, profile: profile, occasion: occasion, styles: styles, preferences: preferences);
    }
    for (var i = 0; i < look.length; i++) {
      for (var j = i + 1; j < look.length; j++) {
        score += _pairCompatibilityScore(look[i], look[j]);
      }
    }
    if (selectedItem != null && look.any((item) => item.id == selectedItem.id)) score += 8;

    final categories = look.map((item) => item.category).toSet();
    final validStructure =
        (categories.contains('Dresses') && !categories.contains('Bottoms') && !categories.contains('Skirts') && !categories.contains('Tops') && !categories.contains('Suits')) ||
        (categories.contains('Suits') && !categories.contains('Bottoms') && !categories.contains('Skirts') && !categories.contains('Tops') && !categories.contains('Dresses')) ||
        (categories.contains('Tops') && (categories.contains('Bottoms') || categories.contains('Skirts')) && !categories.contains('Dresses') && !categories.contains('Suits'));
    if (validStructure) score += 18;
    return score.clamp(0, 100);
  }

  static int _individualFitScore(
    WardrobeItem item, {
    required ColourAnalysisResult? profile,
    required String occasion,
    required List<String> styles,
    required List<String> preferences,
  }) {
    var score = 0;
    final colour = _normaliseColour(item.colour);
    final combined = '${item.name} ${item.style} ${item.season} ${item.occasion} ${item.formality} ${item.pattern} ${item.material} ${item.silhouette} ${item.fit} ${item.length} ${item.notes}'.toLowerCase();
    final season = profile?.season.trim().toLowerCase() ?? '';

    if (item.isFavourite) score += 5;
    if (profile != null && profile.colours.any((value) => _colourMatches(colour, value))) score += 8;
    if (profile != null && profile.bestNeutrals.any((value) => _colourMatches(colour, value))) score += 4;
    if (profile != null && profile.accentColours.any((value) => _colourMatches(colour, value))) score += 2;
    if (season.isNotEmpty && (combined.contains(season) || item.season.toLowerCase().contains('all seasons'))) score += 3;
    if (_cleanTokenSet(styles).any(combined.contains)) score += 4;
    if (_cleanTokenSet(preferences).any(combined.contains)) score += 3;
    if (_occasionTokens(occasion).any(combined.contains)) score += 4;
    return score;
  }

  static int _pairCompatibilityScore(WardrobeItem first, WardrobeItem second) {
    if (first.id == second.id) return -100;
    var score = 0;
    final a = _colourFamily(first.colour);
    final b = _colourFamily(second.colour);
    if (a == b && a != 'unknown') {
      score += 12;
    } else if (_isNeutral(a) || _isNeutral(b)) {
      score += 10;
    } else if (_compatibleColourFamilies(a, b)) {
      score += 9;
    } else if (a != 'unknown' && b != 'unknown') {
      score -= 7;
    }

    final styleA = _styleFamily(first.style);
    final styleB = _styleFamily(second.style);
    if (styleA == styleB && styleA != 'unknown') {
      score += 9;
    } else if (_stylesCanBlend(styleA, styleB)) {
      score += 5;
    } else if (styleA != 'unknown' && styleB != 'unknown') {
      score -= 5;
    }

    final formalityA = first.formality.toLowerCase();
    final formalityB = second.formality.toLowerCase();
    if (formalityA.isNotEmpty && formalityB.isNotEmpty && formalityA == formalityB) score += 4;

    final seasonA = first.season.trim().toLowerCase();
    final seasonB = second.season.trim().toLowerCase();
    if (seasonA.isNotEmpty && seasonB.isNotEmpty &&
        (seasonA == seasonB || seasonA.contains('all seasons') || seasonB.contains('all seasons'))) {
      score += 3;
    }

    final patternA = first.pattern.trim().toLowerCase();
    final patternB = second.pattern.trim().toLowerCase();
    if (patternA.isNotEmpty && patternB.isNotEmpty && patternA != 'solid' && patternB != 'solid') score -= 2;

    final silhouetteA = first.silhouette.trim().toLowerCase();
    final silhouetteB = second.silhouette.trim().toLowerCase();
    if (silhouetteA.isNotEmpty && silhouetteB.isNotEmpty && silhouetteA == silhouetteB) score += 3;
    return score;
  }

  static bool _stylesCanBlend(String a, String b) {
    if (a == 'unknown' || b == 'unknown') return false;
    if (a == b) return true;
    const blends = <Set<String>>{
      {'formal', 'minimal'},
      {'formal', 'elegant'},
      {'elegant', 'minimal'},
      {'casual', 'minimal'},
      {'casual', 'street'},
      {'street', 'sport'},
    };
    return blends.any((pair) => pair.contains(a) && pair.contains(b));
  }

  static Future<AiStylingResult?> getRecommendation({
    required ColourAnalysisResult profile,
    required List<WardrobeItem> wardrobe,
    required List<String> styles,
    required List<String> preferences,
    required String occasion,
    WardrobeItem? selectedItem,
    Set<String> excludedLookKeys = const {},
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || wardrobe.isEmpty || occasion.trim().isEmpty) return null;

    final requestUid = user.uid;
    final ownedWardrobe = wardrobe
        .where((item) => item.userId.isEmpty || item.userId == requestUid)
        .where((item) => _knownCategories.contains(item.category.trim()))
        .toList(growable: false);
    if (ownedWardrobe.isEmpty) return null;

    final safeSelectedItem = selectedItem == null ? null : _findById(ownedWardrobe, selectedItem.id.trim());

    try {
      final idToken = await user.getIdToken();
      if (idToken == null || idToken.isEmpty) return null;

      final personalBrand = await _loadPersonalBrand(requestUid);
      final tibModel = await TibModelService.loadForUser(requestUid);
      final feedbackBias = await _feedbackBiasForUser(requestUid);

      final response = await http.post(
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
          'occasion': occasion.trim(),
          'personalBrand': personalBrand,
          'feedbackBias': feedbackBias,
          'outfitRules': _outfitRulesPayload(),
          if (safeSelectedItem != null) 'selectedItem': _wardrobePayload(safeSelectedItem),
        }),
      ).timeout(_requestTimeout);

      if (response.statusCode < 200 || response.statusCode >= 300) return null;
      final decoded = jsonDecode(response.body);
      final data = _extractResponseMap(decoded);
      if (data == null || data['success'] != true) return null;
      if (FirebaseAuth.instance.currentUser?.uid != requestUid) return null;

      final allowedIds = ownedWardrobe.map((item) => item.id.trim()).where((id) => id.isNotEmpty).toSet();
      final rawResult = AiStylingResult(
        explanation: _readText(data['explanation']),
        topId: _validWardrobeId(data['topId'], allowedIds),
        bottomId: _validWardrobeId(data['bottomId'], allowedIds),
        dressId: _validWardrobeId(data['dressId'] ?? data['onePieceId'], allowedIds),
        suitId: _validWardrobeId(data['suitId'], allowedIds),
        jacketId: _validWardrobeId(data['jacketId'], allowedIds),
        shoesId: _validWardrobeId(data['shoesId'], allowedIds),
        accessoryId: _validWardrobeId(data['accessoryId'], allowedIds),
        lookTitle: _readOptionalText(data['lookTitle'] ?? data['title']),
        colourDirection: _readOptionalText(data['colourDirection'] ?? data['colourStory']),
        stylingNotes: _readStringList(data['stylingNotes'] ?? data['notes'] ?? data['tips'], limit: 6),
        matchScore: ((data['matchScore'] as num?)?.round() ?? 0).clamp(0, 100),
        scoreBreakdown: _readIntMap(data['scoreBreakdown'] ?? data['matchBreakdown']),
      );

      final rawLook = <WardrobeItem?>[
        _findById(ownedWardrobe, rawResult.topId),
        _findById(ownedWardrobe, rawResult.bottomId),
        _findById(ownedWardrobe, rawResult.dressId),
        _findById(ownedWardrobe, rawResult.suitId),
        _findById(ownedWardrobe, rawResult.jacketId),
        _findById(ownedWardrobe, rawResult.shoesId),
        _findById(ownedWardrobe, rawResult.accessoryId),
      ];
      final typedRawLook = rawLook.whereType<WardrobeItem>().toList(growable: false);

      final sanitized = sanitizeLook(
        typedRawLook,
        selectedItem: safeSelectedItem,
        occasion: occasion.trim(),
        profile: profile,
        styles: styles,
        preferences: preferences,
        excludedLookKeys: excludedLookKeys,
        feedbackBias: feedbackBias,
      );

      if (sanitized.isEmpty && rawResult.explanation.isEmpty) return null;
      final localScore = _scoreLook(
        sanitized,
        profile: profile,
        occasion: occasion.trim(),
        styles: styles,
        preferences: preferences,
        selectedItem: safeSelectedItem,
      );
      final localBreakdown = _localBreakdown(
        sanitized,
        profile: profile,
        occasion: occasion.trim(),
        styles: styles,
        preferences: preferences,
        selectedItem: safeSelectedItem,
      );

      return AiStylingResult(
        explanation: rawResult.explanation,
        topId: _idForCategory(sanitized, 'Tops'),
        bottomId: _idForFirstCategories(sanitized, const {'Bottoms', 'Skirts'}),
        dressId: _idForCategory(sanitized, 'Dresses'),
        suitId: _idForCategory(sanitized, 'Suits'),
        jacketId: _idForCategory(sanitized, 'Jackets'),
        shoesId: _idForCategory(sanitized, 'Shoes'),
        accessoryId: _idForCategory(sanitized, 'Accessories'),
        lookTitle: rawResult.lookTitle,
        colourDirection: rawResult.colourDirection,
        stylingNotes: rawResult.stylingNotes,
        matchScore: rawResult.matchScore > 0 ? rawResult.matchScore : localScore,
        scoreBreakdown: rawResult.scoreBreakdown.isNotEmpty ? rawResult.scoreBreakdown : localBreakdown,
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
        'rankByPairCompatibility': true,
        'scoreWholeOutfit': true,
        'feedbackAware': true,
        'excludedLooksSupported': true,
        'wardrobeMetadataAware': true,
        'traitFirstColourProfile': true,
        'allowedRoutes': const [
          'Tops + Bottoms + Jacket? + Shoes + Accessories?',
          'Tops + Skirts + Jacket? + Shoes + Accessories?',
          'Dresses + Jacket? + Shoes + Accessories?',
          'Suits + Shoes + Accessories?',
        ],
      };

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
        'chroma': profile.chroma,
        'clarity': profile.clarity,
        'contrast': profile.contrast,
        'colours': profile.colours,
        'bestNeutrals': profile.bestNeutrals,
        'accentColours': profile.accentColours,
        'lessIdealColours': profile.lessIdealColours,
        'colourReasons': profile.colourReasons,
        'faceShape': profile.faceShape,
        'faceShapeDescription': profile.faceShapeDescription,
        'faceMeasurements': profile.faceMeasurements,
        'faceStylingGuidance': profile.faceStylingGuidance,
        'personalColour': {
          'undertone': profile.undertone,
          'value': profile.brightness,
          'chroma': profile.chroma,
          'clarity': profile.clarity,
          'contrast': profile.contrast,
          'recommendedColours': profile.colours,
          'bestNeutrals': profile.bestNeutrals,
          'accentColours': profile.accentColours,
          'lessIdealColours': profile.lessIdealColours,
          'analysisReasons': profile.colourReasons,
        },
      };

  static Map<String, dynamic> _tibModelPayload(TibModelProfile model, ColourAnalysisResult profile) {
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
        'occasion': item.occasion,
        'formality': item.formality,
        'pattern': item.pattern,
        'material': item.material,
        'silhouette': item.silhouette,
        'fit': item.fit,
        'length': item.length,
        'layering': item.layering,
        'warmth': item.warmth,
        'statementLevel': item.statementLevel,
        'notes': item.notes,
      };

  static Map<String, int> _localBreakdown(
    List<WardrobeItem> look, {
    required ColourAnalysisResult? profile,
    required String occasion,
    required List<String> styles,
    required List<String> preferences,
    WardrobeItem? selectedItem,
  }) {
    if (look.isEmpty) return const {};
    var colour = 0;
    var occasionScore = 0;
    var style = 0;
    var harmony = 0;
    var personal = 0;

    for (final item in look) {
      final text = '${item.name} ${item.style} ${item.colour} ${item.formality} ${item.occasion} ${item.pattern} ${item.material}'.toLowerCase();
      final normalized = _normaliseColour(item.colour);
      if (profile != null && profile.colours.any((value) => _colourMatches(normalized, value))) colour += 1;
      if (profile != null && profile.bestNeutrals.any((value) => _colourMatches(normalized, value))) colour += 1;
      if (_occasionTokens(occasion).any(text.contains)) occasionScore += 1;
      if (_cleanTokenSet(styles).any(text.contains)) style += 1;
      if (item.isFavourite) personal += 1;
      if (selectedItem != null && item.id == selectedItem.id) personal += 2;
    }

    for (var i = 0; i < look.length; i++) {
      for (var j = i + 1; j < look.length; j++) {
        final pair = _pairCompatibilityScore(look[i], look[j]);
        if (pair > 0) harmony += pair;
      }
    }

    return <String, int>{
      'colour': colour,
      'occasion': occasionScore,
      'style': style,
      'harmony': harmony,
      'personal': personal,
    };
  }

  static Future<Map<String, double>> _feedbackBiasForUser(String uid) async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('users').doc(uid).collection('styleFeedback').get();
      final bias = <String, double>{};
      for (final doc in snapshot.docs) {
        final data = doc.data();
        if (data['type'] != 'item') continue;
        final itemId = data['itemId'] as String?;
        final liked = data['liked'] as bool?;
        if (itemId == null || itemId.isEmpty || liked == null) continue;
        bias[itemId] = (bias[itemId] ?? 0) + (liked ? 12 : -16);
      }
      return bias;
    } catch (_) {
      return <String, double>{};
    }
  }

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

  static Map<String, int> _readIntMap(dynamic value) {
    if (value is! Map) return const {};
    final output = <String, int>{};
    for (final entry in value.entries) {
      final key = entry.key.toString().trim();
      final raw = entry.value;
      if (key.isEmpty || raw is! num) continue;
      output[key] = raw.round().clamp(0, 100);
    }
    return output;
  }

  static String? _validWardrobeId(dynamic value, Set<String> allowedIds) {
    if (value is! String) return null;
    final id = value.trim();
    return id.isEmpty || !allowedIds.contains(id) ? null : id;
  }

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

  static String? _idForFirstCategories(List<WardrobeItem> items, Set<String> categories) {
    for (final item in items) {
      if (categories.contains(item.category)) return item.id;
    }
    return null;
  }
}

class _ScoredItem {
  final WardrobeItem item;
  final int score;

  const _ScoredItem(this.item, this.score);
}
