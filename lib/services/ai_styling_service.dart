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

  static const Set<String> _neutralColourFamilies = {
    'black',
    'white',
    'grey',
    'beige',
    'brown',
  };

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
      if (id.isEmpty || !_knownCategories.contains(category)) {
        continue;
      }
      unique[id] = item;
    }

    final candidates = unique.values.toList(growable: false);
    if (candidates.isEmpty) return const [];

    final selected = selectedItem == null
        ? null
        : unique[selectedItem.id.trim()];

    WardrobeItem? choose(
      String category, {
      Set<String> used = const {},
      WardrobeItem? anchor,
    }) {
      final pool = candidates
          .where(
            (item) => item.category == category && !used.contains(item.id),
          )
          .toList(growable: false);
      if (pool.isEmpty) return null;

      final ranked = _rankItems(
        pool,
        profile: profile,
        occasion: occasion,
        styles: styles,
        preferences: preferences,
        anchor: anchor,
      );
      return ranked.isEmpty ? null : ranked.first;
    }

    final selectedCategory = selected?.category;
    if (selectedCategory == 'Dresses') {
      return _buildOnePiece(
        candidates,
        selected!,
        choose,
        profile: profile,
        occasion: occasion,
        styles: styles,
        preferences: preferences,
      );
    }

    if (selectedCategory == 'Suits') {
      return _buildSuit(
        candidates,
        selected!,
        choose,
        profile: profile,
        occasion: occasion,
        styles: styles,
        preferences: preferences,
      );
    }

    final top = selectedCategory == 'Tops' ? selected : choose('Tops');
    final lower = selectedCategory == 'Bottoms' || selectedCategory == 'Skirts'
        ? selected
        : _bestPartner(
            candidates,
            categorySet: const {'Bottoms', 'Skirts'},
            anchor: top == null ? const [] : [top],
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
        profile: profile,
        occasion: occasion,
        styles: styles,
        preferences: preferences,
      );
    }

    final dress = choose('Dresses');
    if (dress != null) {
      return _buildOnePiece(
        candidates,
        dress,
        choose,
        profile: profile,
        occasion: occasion,
        styles: styles,
        preferences: preferences,
      );
    }

    final suit = choose('Suits');
    if (suit != null) {
      return _buildSuit(
        candidates,
        suit,
        choose,
        profile: profile,
        occasion: occasion,
        styles: styles,
        preferences: preferences,
      );
    }

    return const [];
  }

  static List<WardrobeItem> _buildTwoPiece(
    List<WardrobeItem> candidates,
    WardrobeItem top,
    WardrobeItem lower,
    WardrobeItem? Function(
      String, {
      Set<String> used,
      WardrobeItem? anchor,
    }) choose, {
    required ColourAnalysisResult? profile,
    required String occasion,
    required List<String> styles,
    required List<String> preferences,
  }) {
    final result = <WardrobeItem>[top, lower];
    final used = <String>{top.id, lower.id};

    final jacket = choose('Jackets', used: used, anchor: top);
    if (jacket != null) {
      result.add(jacket);
      used.add(jacket.id);
    }

    final shoes = choose(
      'Shoes',
      used: used,
      anchor: jacket ?? lower,
    );
    if (shoes != null) {
      result.add(shoes);
      used.add(shoes.id);
    }

    if (result.length < 5) {
      final accessory = choose(
        'Accessories',
        used: used,
        anchor: shoes ?? jacket ?? top,
      );
      if (accessory != null) {
        result.add(accessory);
      }
    }

    return _finalizeLook(
      result,
      selectedItem: top,
      profile: profile,
      occasion: occasion,
      styles: styles,
      preferences: preferences,
    );
  }

  static List<WardrobeItem> _buildOnePiece(
    List<WardrobeItem> candidates,
    WardrobeItem piece,
    WardrobeItem? Function(
      String, {
      Set<String> used,
      WardrobeItem? anchor,
    }) choose, {
    required ColourAnalysisResult? profile,
    required String occasion,
    required List<String> styles,
    required List<String> preferences,
  }) {
    final result = <WardrobeItem>[piece];
    final used = <String>{piece.id};

    final jacket = choose('Jackets', used: used, anchor: piece);
    if (jacket != null) {
      result.add(jacket);
      used.add(jacket.id);
    }

    final shoes = choose('Shoes', used: used, anchor: jacket ?? piece);
    if (shoes != null) {
      result.add(shoes);
      used.add(shoes.id);
    }

    if (result.length < 5) {
      final accessory = choose(
        'Accessories',
        used: used,
        anchor: shoes ?? jacket ?? piece,
      );
      if (accessory != null) {
        result.add(accessory);
      }
    }

    return _finalizeLook(
      result,
      selectedItem: piece,
      profile: profile,
      occasion: occasion,
      styles: styles,
      preferences: preferences,
    );
  }

  static List<WardrobeItem> _buildSuit(
    List<WardrobeItem> candidates,
    WardrobeItem suit,
    WardrobeItem? Function(
      String, {
      Set<String> used,
      WardrobeItem? anchor,
    }) choose, {
    required ColourAnalysisResult? profile,
    required String occasion,
    required List<String> styles,
    required List<String> preferences,
  }) {
    final result = <WardrobeItem>[suit];
    final used = <String>{suit.id};

    final shoes = choose('Shoes', used: used, anchor: suit);
    if (shoes != null) {
      result.add(shoes);
      used.add(shoes.id);
    }

    final accessory = choose(
      'Accessories',
      used: used,
      anchor: shoes ?? suit,
    );
    if (accessory != null) {
      result.add(accessory);
    }

    return _finalizeLook(
      result,
      selectedItem: suit,
      profile: profile,
      occasion: occasion,
      styles: styles,
      preferences: preferences,
    );
  }

  static WardrobeItem? _bestPartner(
    List<WardrobeItem> items, {
    required Set<String> categorySet,
    required List<WardrobeItem> anchor,
    ColourAnalysisResult? profile,
    required String occasion,
    required List<String> styles,
    required List<String> preferences,
  }) {
    final pool = items
        .where((item) => categorySet.contains(item.category))
        .toList(growable: false);
    if (pool.isEmpty) return null;

    final ranked = _rankItems(
      pool,
      profile: profile,
      occasion: occasion,
      styles: styles,
      preferences: preferences,
      anchor: anchor.isEmpty ? null : anchor.first,
    );
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
    final sanitized = <WardrobeItem>[];
    final seen = <String>{};
    for (final item in result) {
      if (_knownCategories.contains(item.category) && seen.add(item.id)) {
        sanitized.add(item);
      }
    }
    if (sanitized.isEmpty) return const [];

    final categories = sanitized.map((item) => item.category).toSet();
    final validStructure =
        (categories.contains('Dresses') &&
            !categories.contains('Bottoms') &&
            !categories.contains('Skirts') &&
            !categories.contains('Tops')) ||
        (categories.contains('Suits') &&
            !categories.contains('Bottoms') &&
            !categories.contains('Skirts') &&
            !categories.contains('Tops')) ||
        (categories.contains('Tops') &&
            (categories.contains('Bottoms') || categories.contains('Skirts')) &&
            !categories.contains('Dresses') &&
            !categories.contains('Suits'));
    if (!validStructure) return const [];

    final score = _scoreLook(
      sanitized,
      profile: profile,
      occasion: occasion,
      styles: styles,
      preferences: preferences,
      selectedItem: selectedItem,
    );
    if (score < 32) return const [];
    return sanitized.take(5).toList(growable: false);
  }

  static List<WardrobeItem> _rankItems(
    List<WardrobeItem> items, {
    ColourAnalysisResult? profile,
    required String occasion,
    required List<String> styles,
    required List<String> preferences,
    WardrobeItem? anchor,
  }) {
    final scored = items
        .map(
          (item) => _ScoredItem(
            item,
            _itemScore(
              item,
              profile: profile,
              occasion: occasion,
              styles: styles,
              preferences: preferences,
              anchor: anchor,
            ),
          ),
        )
        .toList(growable: false);

    scored.sort((a, b) {
      final score = b.score.compareTo(a.score);
      if (score != 0) return score;
      final favourite =
          (b.item.isFavourite ? 1 : 0).compareTo(a.item.isFavourite ? 1 : 0);
      if (favourite != 0) return favourite;
      return a.item.name.toLowerCase().compareTo(b.item.name.toLowerCase());
    });
    return scored.map((entry) => entry.item).toList(growable: false);
  }

  static int _itemScore(
    WardrobeItem item, {
    required ColourAnalysisResult? profile,
    required String occasion,
    required List<String> styles,
    required List<String> preferences,
    WardrobeItem? anchor,
  }) {
    var score = 0;
    final colour = _normaliseColour(item.colour);
    final combined =
        '${item.name} ${item.style} ${item.season} ${item.notes}'.toLowerCase();
    final season = profile?.season.trim().toLowerCase() ?? '';

    if (item.isFavourite) score += 24;
    if (profile != null &&
        profile.colours.any((value) => _colourMatches(colour, value))) {
      score += 22;
    }
    if (season.isNotEmpty &&
        (combined.contains(season) ||
            item.season.trim().toLowerCase().contains('all seasons'))) {
      score += 12;
    }
    final styleTokens = _cleanTokenSet(styles);
    final preferenceTokens = _cleanTokenSet(preferences);
    if (styleTokens.any(combined.contains)) score += 12;
    if (preferenceTokens.any(combined.contains)) score += 10;
    if (_occasionTokens(occasion).any(combined.contains)) score += 12;
    if (_isNeutral(_colourFamily(colour))) score += 3;

    if (anchor != null) {
      score += _pairCompatibilityScore(item, anchor);
    }
    return score;
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
      score += _individualFitScore(
        item,
        profile: profile,
        occasion: occasion,
        styles: styles,
        preferences: preferences,
      );
    }

    for (var i = 0; i < look.length; i++) {
      for (var j = i + 1; j < look.length; j++) {
        score += _pairCompatibilityScore(look[i], look[j]);
      }
    }

    if (selectedItem != null &&
        look.any((item) => item.id == selectedItem.id)) {
      score += 8;
    }

    final categories = look.map((item) => item.category).toSet();
    final validStructure =
        (categories.contains('Dresses') &&
            !categories.contains('Bottoms') &&
            !categories.contains('Skirts') &&
            !categories.contains('Tops')) ||
        (categories.contains('Suits') &&
            !categories.contains('Bottoms') &&
            !categories.contains('Skirts') &&
            !categories.contains('Tops')) ||
        (categories.contains('Tops') &&
            (categories.contains('Bottoms') || categories.contains('Skirts')) &&
            !categories.contains('Dresses') &&
            !categories.contains('Suits'));
    if (validStructure) score += 18;

    return score;
  }

  static int _individualFitScore(
    WardrobeItem item, {
    required ColourAnalysisResult? profile,
    required String occasion,
    required List<String> styles,
    required List<String> preferences,
  }) {
    return _itemScore(
      item,
      profile: profile,
      occasion: occasion,
      styles: styles,
      preferences: preferences,
    );
  }

  static int _pairCompatibilityScore(
    WardrobeItem first,
    WardrobeItem second,
  ) {
    if (first.id == second.id) return -100;

    final firstColour = _colourFamily(first.colour);
    final secondColour = _colourFamily(second.colour);
    var score = 0;

    if (firstColour == 'unknown' || secondColour == 'unknown') {
      score += 1;
    } else if (firstColour == secondColour) {
      score += 10;
    } else if (_neutralColourFamilies.contains(firstColour) ||
        _neutralColourFamilies.contains(secondColour)) {
      score += 9;
    } else if (_colourFamiliesCompatible(firstColour, secondColour)) {
      score += 11;
    } else {
      score -= 8;
    }

    final firstStyle = _styleFamily(first.style);
    final secondStyle = _styleFamily(second.style);
    if (firstStyle != 'unknown' && firstStyle == secondStyle) {
      score += 9;
    } else if (_stylesCanBlend(firstStyle, secondStyle)) {
      score += 7;
    } else if (firstStyle != 'unknown' && secondStyle != 'unknown') {
      score -= 6;
    }

    final firstSeason = first.season.trim().toLowerCase();
    final secondSeason = second.season.trim().toLowerCase();
    if (firstSeason.isNotEmpty && secondSeason.isNotEmpty) {
      if (firstSeason == secondSeason ||
          firstSeason.contains('all seasons') ||
          secondSeason.contains('all seasons')) {
        score += 4;
      }
    }

    return score;
  }

  static bool _colourMatches(String colour, String target) {
    final a = _colourFamily(colour);
    final b = _colourFamily(target);
    if (a == 'unknown' || b == 'unknown') return false;
    if (a == b) return true;
    return _colourFamiliesCompatible(a, b) ||
        (_isNeutral(a) && _isNeutral(b));
  }

  static bool _colourFamiliesCompatible(String first, String second) {
    if (first == second) return true;
    const compatible = <String, Set<String>>{
      'red': {'pink', 'orange', 'purple', 'brown'},
      'orange': {'red', 'yellow', 'brown', 'beige'},
      'yellow': {'orange', 'green', 'brown', 'blue'},
      'green': {'yellow', 'blue', 'brown', 'beige'},
      'blue': {'green', 'purple', 'navy', 'white', 'grey'},
      'navy': {'blue', 'yellow', 'white', 'beige', 'grey'},
      'purple': {'red', 'pink', 'blue', 'grey'},
      'pink': {'red', 'purple', 'white', 'grey'},
      'brown': {'orange', 'green', 'beige', 'cream', 'white'},
      'beige': {'brown', 'orange', 'green', 'navy', 'white'},
    };
    return compatible[first]?.contains(second) ??
        compatible[second]?.contains(first) ??
        false;
  }

  static String _colourFamily(String raw) {
    final value = _normaliseColour(raw);
    if (value.isEmpty || value == 'unknown') return 'unknown';
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

  static bool _isNeutral(String family) =>
      _neutralColourFamilies.contains(family);

  static String _normaliseColour(String value) => value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[_\-]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ');

  static String _styleFamily(String raw) {
    final value = raw.trim().toLowerCase();
    if (value.isEmpty) return 'unknown';
    if (value.contains('formal') ||
        value.contains('tailored') ||
        value.contains('office') ||
        value.contains('business')) {
      return 'formal';
    }
    if (value.contains('elegant') ||
        value.contains('feminine') ||
        value.contains('romantic')) {
      return 'elegant';
    }
    if (value.contains('casual') ||
        value.contains('relaxed') ||
        value.contains('everyday')) {
      return 'casual';
    }
    if (value.contains('minimal') ||
        value.contains('classic') ||
        value.contains('clean')) {
      return 'minimal';
    }
    if (value.contains('street') || value.contains('edgy')) return 'street';
    if (value.contains('sport') || value.contains('athleisure')) return 'sport';
    return 'unknown';
  }

  static bool _stylesCanBlend(String first, String second) {
    if (first == 'unknown' || second == 'unknown') return false;
    if (first == second) return true;
    const blends = <Set<String>>{
      {'formal', 'minimal'},
      {'formal', 'elegant'},
      {'elegant', 'minimal'},
      {'casual', 'minimal'},
      {'casual', 'street'},
      {'street', 'sport'},
    };
    return blends.any((pair) => pair.contains(first) && pair.contains(second));
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
        bottomId: _idForFirstCategories(sanitized, const {'Bottoms', 'Skirts'}),
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
        'rankByPairCompatibility': true,
        'scoreWholeOutfit': true,
        'prioritiseFavouriteItems': true,
        'considerPersonalColours': true,
        'considerSeason': true,
        'considerStylePreferences': true,
        'considerOccasion': true,
        'avoidStrongStyleConflicts': true,
        'avoidStrongColourConflicts': true,
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
