import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../config/google_drive_config.dart';
import '../models/colour_analysis_result.dart';
import '../models/wardrobe_item.dart';
import 'style_feedback_service.dart';
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

  String get displayTitle =>
      lookTitle == null || lookTitle!.trim().isEmpty ? 'Your personal look' : lookTitle!.trim();
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

  static String _normaliseColour(String value) =>
      value.trim().toLowerCase().replaceAll(RegExp(r'[_-]+'), ' ');

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
      if (entry.value.any(value.contains)) {
        return entry.key;
      }
    }
    return 'unknown';
  }

  static bool _isNeutral(String family) => _neutralColourFamilies.contains(family);

  static bool _colourMatches(String colour, String target) {
    final a = _colourFamily(colour);
    final b = _colourFamily(target);
    return a != 'unknown' &&
        b != 'unknown' &&
        (a == b || (_isNeutral(a) && _isNeutral(b)));
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
      'beige': {'orange', 'green', 'brown', 'white'},
      'black': {'white', 'grey', 'red', 'pink', 'beige'},
      'white': {'black', 'grey', 'navy', 'blue', 'pink', 'brown', 'beige'},
      'grey': {'black', 'white', 'blue', 'purple', 'pink'},
    };
    return compatible[a]?.contains(b) == true || compatible[b]?.contains(a) == true;
  }

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
    if (value.contains('street') || value.contains('edgy')) {
      return 'street';
    }
    if (value.contains('sport') || value.contains('athleisure')) {
      return 'sport';
    }
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
    final ids = look
        .map((item) => item.id.trim())
        .where((id) => id.isNotEmpty)
        .toList()
      ..sort();
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
    Map<String, double> combinationBias = const {},
  }) {
    final unique = <String, WardrobeItem>{};
    for (final item in items) {
      final id = item.id.trim();
      if (id.isEmpty || !_knownCategories.contains(item.category.trim())) {
        continue;
      }
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
      final pool = candidates
          .where((item) => item.category == category && !used.contains(item.id))
          .toList(growable: false);
      final ranked = _rankItems(
        pool,
        profile: profile,
        occasion: occasion,
        styles: styles,
        preferences: preferences,
        anchors: anchors,
        feedbackBias: feedbackBias,
        combinationBias: combinationBias,
      );
      return ranked.isEmpty ? null : ranked.first;
    }

    if (selected?.category == 'Dresses') {
      return _buildOnePiece(
        selected!,
        choose,
        selectedItem: selected,
        profile: profile,
        occasion: occasion,
        styles: styles,
        preferences: preferences,
        excludedLookKeys: excludedLookKeys,
        combinationBias: combinationBias,
      );
    }
    if (selected?.category == 'Suits') {
      return _buildSuit(
        selected!,
        choose,
        selectedItem: selected,
        profile: profile,
        occasion: occasion,
        styles: styles,
        preferences: preferences,
        excludedLookKeys: excludedLookKeys,
        combinationBias: combinationBias,
      );
    }

    final top = selected?.category == 'Tops' ? selected : choose('Tops');
    final lower = selected?.category == 'Bottoms' || selected?.category == 'Skirts'
        ? selected
        : _bestPartner(
            candidates,
            const {'Bottoms', 'Skirts'},
            anchors: top == null ? const [] : [top],
            profile: profile,
            occasion: occasion,
            styles: styles,
            preferences: preferences,
            feedbackBias: feedbackBias,
            combinationBias: combinationBias,
          );

    if (top != null && lower != null) {
      final look = _buildTwoPiece(
        top,
        lower,
        choose,
        profile: profile,
        occasion: occasion,
        styles: styles,
        preferences: preferences,
        combinationBias: combinationBias,
      );
      final key = _lookKey(look);
      if (key != null && !excludedLookKeys.contains(key)) {
        return look;
      }
    }

    final dresses = _rankItems(
      candidates.where((item) => item.category == 'Dresses').toList(growable: false),
      profile: profile,
      occasion: occasion,
      styles: styles,
      preferences: preferences,
      feedbackBias: feedbackBias,
      combinationBias: combinationBias,
    );
    for (final dress in dresses) {
      final look = _buildOnePiece(
        dress,
        choose,
        selectedItem: selected ?? dress,
        profile: profile,
        occasion: occasion,
        styles: styles,
        preferences: preferences,
        excludedLookKeys: excludedLookKeys,
        combinationBias: combinationBias,
      );
      if (look.isNotEmpty) {
        return look;
      }
    }

    final suits = _rankItems(
      candidates.where((item) => item.category == 'Suits').toList(growable: false),
      profile: profile,
      occasion: occasion,
      styles: styles,
      preferences: preferences,
      feedbackBias: feedbackBias,
      combinationBias: combinationBias,
    );
    for (final suit in suits) {
      final look = _buildSuit(
        suit,
        choose,
        selectedItem: selected ?? suit,
        profile: profile,
        occasion: occasion,
        styles: styles,
        preferences: preferences,
        excludedLookKeys: excludedLookKeys,
        combinationBias: combinationBias,
      );
      if (look.isNotEmpty) {
        return look;
      }
    }

    final simpleTop = top ?? _firstAvailable(candidates, 'Tops');
    final simpleLower = lower ??
        _firstAvailable(candidates, 'Bottoms') ??
        _firstAvailable(candidates, 'Skirts');
    if (simpleTop != null && simpleLower != null) {
      final look = _buildSimpleLook(simpleTop, simpleLower, choose);
      final key = _lookKey(look);
      if (key != null && !excludedLookKeys.contains(key) && _isValidSimpleStructure(look)) {
        return look;
      }
    }

    final simpleDress = _firstAvailable(candidates, 'Dresses');
    if (simpleDress != null) {
      final look = _buildSimpleOnePiece(simpleDress, choose);
      final key = _lookKey(look);
      if (key != null && !excludedLookKeys.contains(key)) {
        return look;
      }
    }

    final simpleSuit = _firstAvailable(candidates, 'Suits');
    if (simpleSuit != null) {
      final look = _buildSimpleSuit(simpleSuit, choose);
      final key = _lookKey(look);
      if (key != null && !excludedLookKeys.contains(key)) {
        return look;
      }
    }
    return const [];
  }

  static WardrobeItem? _firstAvailable(List<WardrobeItem> items, String category) {
    for (final item in items) {
      if (item.category.trim() == category && item.id.trim().isNotEmpty) {
        return item;
      }
    }
    return null;
  }

  static bool _isValidSimpleStructure(List<WardrobeItem> look) {
    final categories = look.map((item) => item.category.trim()).toSet();
    return categories.contains('Tops') &&
        (categories.contains('Bottoms') || categories.contains('Skirts')) &&
        !categories.contains('Dresses') &&
        !categories.contains('Suits');
  }

  static List<WardrobeItem> _buildSimpleLook(
    WardrobeItem top,
    WardrobeItem bottom,
    WardrobeItem? Function(String, {Set<String> used, List<WardrobeItem> anchors}) choose,
  ) {
    final result = <WardrobeItem>[top, bottom];
    final used = <String>{top.id, bottom.id};
    final shoes = choose('Shoes', used: used, anchors: result);
    if (shoes != null) {
      result.add(shoes);
      used.add(shoes.id);
    }
    final accessory = choose('Accessories', used: used, anchors: result);
    if (accessory != null) {
      result.add(accessory);
    }
    return result;
  }

  static List<WardrobeItem> _buildSimpleOnePiece(
    WardrobeItem piece,
    WardrobeItem? Function(String, {Set<String> used, List<WardrobeItem> anchors}) choose,
  ) {
    final result = <WardrobeItem>[piece];
    final used = <String>{piece.id};
    final shoes = choose('Shoes', used: used, anchors: result);
    if (shoes != null) {
      result.add(shoes);
      used.add(shoes.id);
    }
    final accessory = choose('Accessories', used: used, anchors: result);
    if (accessory != null) {
      result.add(accessory);
    }
    return result;
  }

  static List<WardrobeItem> _buildSimpleSuit(
    WardrobeItem suit,
    WardrobeItem? Function(String, {Set<String> used, List<WardrobeItem> anchors}) choose,
  ) {
    final result = <WardrobeItem>[suit];
    final used = <String>{suit.id};
    final shoes = choose('Shoes', used: used, anchors: [suit]);
    if (shoes != null) {
      result.add(shoes);
      used.add(shoes.id);
    }
    final accessory = choose('Accessories', used: used, anchors: result);
    if (accessory != null) {
      result.add(accessory);
    }
    return result;
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
    Map<String, double> combinationBias = const {},
  }) {
    final pool = items.where((item) => categories.contains(item.category)).toList(growable: false);
    final ranked = _rankItems(
      pool,
      profile: profile,
      occasion: occasion,
      styles: styles,
      preferences: preferences,
      anchors: anchors,
      feedbackBias: feedbackBias,
      combinationBias: combinationBias,
    );
    return ranked.isEmpty ? null : ranked.first;
  }

  static List<WardrobeItem> _buildTwoPiece(
    WardrobeItem top,
    WardrobeItem lower,
    WardrobeItem? Function(String, {Set<String> used, List<WardrobeItem> anchors}) choose, {
    required ColourAnalysisResult? profile,
    required String occasion,
    required List<String> styles,
    required List<String> preferences,
    Map<String, double> combinationBias = const {},
  }) {
    final result = <WardrobeItem>[top, lower];
    final used = <String>{top.id, lower.id};
    final jacket = choose('Jackets', used: used, anchors: result);
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
    if (accessory != null) {
      result.add(accessory);
    }
    return _finalizeLook(
      result,
      selectedItem: top,
      profile: profile,
      occasion: occasion,
      styles: styles,
      preferences: preferences,
      combinationBias: combinationBias,
      allowLowScore: true,
    );
  }

  static List<WardrobeItem> _buildOnePiece(
    WardrobeItem piece,
    WardrobeItem? Function(String, {Set<String> used, List<WardrobeItem> anchors}) choose, {
    required WardrobeItem selectedItem,
    required ColourAnalysisResult? profile,
    required String occasion,
    required List<String> styles,
    required List<String> preferences,
    Set<String> excludedLookKeys = const {},
    Map<String, double> combinationBias = const {},
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
    if (accessory != null) {
      result.add(accessory);
    }
    final look = _finalizeLook(
      result,
      selectedItem: selectedItem,
      profile: profile,
      occasion: occasion,
      styles: styles,
      preferences: preferences,
      combinationBias: combinationBias,
      allowLowScore: true,
    );
    final key = _lookKey(look);
    return key != null && excludedLookKeys.contains(key) ? const [] : look;
  }

  static List<WardrobeItem> _buildSuit(
    WardrobeItem suit,
    WardrobeItem? Function(String, {Set<String> used, List<WardrobeItem> anchors}) choose, {
    required WardrobeItem selectedItem,
    required ColourAnalysisResult? profile,
    required String occasion,
    required List<String> styles,
    required List<String> preferences,
    Set<String> excludedLookKeys = const {},
    Map<String, double> combinationBias = const {},
  }) {
    final result = <WardrobeItem>[suit];
    final used = <String>{suit.id};
    final shoes = choose('Shoes', used: used, anchors: [suit]);
    if (shoes != null) {
      result.add(shoes);
      used.add(shoes.id);
    }
    final accessory = choose('Accessories', used: used, anchors: result);
    if (accessory != null) {
      result.add(accessory);
    }
    final look = _finalizeLook(
      result,
      selectedItem: selectedItem,
      profile: profile,
      occasion: occasion,
      styles: styles,
      preferences: preferences,
      combinationBias: combinationBias,
      allowLowScore: true,
    );
    final key = _lookKey(look);
    return key != null && excludedLookKeys.contains(key) ? const [] : look;
  }

  static List<WardrobeItem> _finalizeLook(
    List<WardrobeItem> result, {
    required WardrobeItem? selectedItem,
    required ColourAnalysisResult? profile,
    required String occasion,
    required List<String> styles,
    required List<String> preferences,
    Map<String, double> combinationBias = const {},
    bool allowLowScore = false,
  }) {
    final unique = <String, WardrobeItem>{};
    for (final item in result) {
      if (_knownCategories.contains(item.category.trim())) {
        unique[item.id] = item;
      }
    }
    final sanitized = unique.values.toList(growable: false);
    if (sanitized.isEmpty) {
      return const [];
    }
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
    if (!validStructure) {
      return const [];
    }
    final score = _scoreLook(
      sanitized,
      profile: profile,
      occasion: occasion,
      styles: styles,
      preferences: preferences,
      selectedItem: selectedItem,
      combinationBias: combinationBias,
    );
    if (!allowLowScore && score < 18) {
      return const [];
    }
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
    Map<String, double> combinationBias = const {},
  }) {
    final cleanStyles = _cleanTokenSet(styles);
    final cleanPreferences = _cleanTokenSet(preferences);
    final scored = items.map((item) {
      var score = (feedbackBias[item.id] ?? 0).round();
      final colour = _normaliseColour(item.colour);
      final combined = '${item.name} ${item.style} ${item.season} ${item.occasion} ${item.formality} ${item.pattern} ${item.material} ${item.silhouette} ${item.fit} ${item.length} ${item.notes}'.toLowerCase();
      final season = profile?.season.trim().toLowerCase() ?? '';
      if (item.isFavourite) {
        score += 18;
      }
      if (profile != null && profile.colours.any((value) => _colourMatches(colour, value))) {
        score += 24;
      }
      if (profile != null && profile.bestNeutrals.any((value) => _colourMatches(colour, value))) {
        score += 12;
      }
      if (profile != null && profile.accentColours.any((value) => _colourMatches(colour, value))) {
        score += 8;
      }
      if (profile != null && profile.lessIdealColours.any((value) => _colourMatches(colour, value))) {
        score -= 10;
      }
      if (season.isNotEmpty && (combined.contains(season) || item.season.toLowerCase().contains('all seasons'))) {
        score += 12;
      }
      if (cleanStyles.any(combined.contains)) {
        score += 14;
      }
      if (cleanPreferences.any(combined.contains)) {
        score += 10;
      }
      if (_occasionTokens(occasion).any(combined.contains)) {
        score += 14;
      }
      if (_isNeutral(_colourFamily(colour))) {
        score += 3;
      }
      if (item.warmth != null &&
          (occasion.toLowerCase().contains('weekend') ||
              occasion.toLowerCase().contains('cafe')) &&
          item.warmth! <= 2) {
        score += 3;
      }
      for (final anchor in anchors) {
        score += _pairCompatibilityScore(item, anchor);
        score += _pairCombinationBias(item, anchor, combinationBias).round();
      }
      return _ScoredItem(item, score);
    }).toList(growable: false);
    scored.sort((a, b) => b.score == a.score
        ? a.item.name.toLowerCase().compareTo(b.item.name.toLowerCase())
        : b.score.compareTo(a.score));
    return scored.map((entry) => entry.item).toList(growable: false);
  }

  static double _pairCombinationBias(
    WardrobeItem first,
    WardrobeItem second,
    Map<String, double> bias,
  ) {
    if (bias.isEmpty) return 0;
    final ids = [first.id.trim(), second.id.trim()]..sort();
    return bias[ids.join('|')] ?? 0;
  }

  static int _scoreLook(
    List<WardrobeItem> look, {
    required ColourAnalysisResult? profile,
    required String occasion,
    required List<String> styles,
    required List<String> preferences,
    WardrobeItem? selectedItem,
    Map<String, double> combinationBias = const {},
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
        score += (combinationBias[_lookKey([look[i], look[j]])] ?? 0).round();
      }
    }
    if (selectedItem != null && look.any((item) => item.id == selectedItem.id)) {
      score += 8;
    }
    final categories = look.map((item) => item.category).toSet();
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
    if (validStructure) {
      score += 20;
    }
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
    if (item.isFavourite) {
      score += 5;
    }
    if (profile != null && profile.colours.any((value) => _colourMatches(colour, value))) {
      score += 8;
    }
    if (profile != null && profile.bestNeutrals.any((value) => _colourMatches(colour, value))) {
      score += 4;
    }
    if (profile != null && profile.accentColours.any((value) => _colourMatches(colour, value))) {
      score += 2;
    }
    if (season.isNotEmpty && (combined.contains(season) || item.season.toLowerCase().contains('all seasons'))) {
      score += 3;
    }
    if (_cleanTokenSet(styles).any(combined.contains)) {
      score += 4;
    }
    if (_cleanTokenSet(preferences).any(combined.contains)) {
      score += 3;
    }
    if (_occasionTokens(occasion).any(combined.contains)) {
      score += 4;
    }
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
      score -= 4;
    }
    return score;
  }

  static bool _stylesCanBlend(String a, String b) {
    final pairs = <String>{'$a|$b', '$b|$a'};
    return pairs.contains('formal|minimal') ||
        pairs.contains('elegant|minimal') ||
        pairs.contains('casual|sport') ||
        pairs.contains('casual|street') ||
        pairs.contains('elegant|feminine');
  }

  static List<WardrobeItem> rankReplacementItems(
    List<WardrobeItem> candidates, {
    required ColourAnalysisResult profile,
    required String occasion,
    List<String> styles = const [],
    List<String> preferences = const [],
    List<WardrobeItem> anchors = const [],
  }) => _rankItems(
        candidates,
        profile: profile,
        occasion: occasion,
        styles: styles,
        preferences: preferences,
        anchors: anchors,
      );

  static Future<AiStylingResult?> getRecommendation({
    required String uid,
    required ColourAnalysisResult profile,
    required List<WardrobeItem> wardrobe,
    List<String> styles = const [],
    List<String> preferences = const [],
    String occasion = '',
    WardrobeItem? selectedItem,
    Set<String> excludedLookKeys = const {},
  }) async {
    final cleanUid = uid.trim();
    final currentUid = FirebaseAuth.instance.currentUser?.uid.trim();
    if (cleanUid.isEmpty || currentUid == null || cleanUid != currentUid) return null;
    final owned = wardrobe.where((item) => item.userId.isEmpty || item.userId == cleanUid).toList(growable: false);
    if (owned.isEmpty) return null;
    final feedbackBias = await StyleFeedbackService.getItemBias();
    final combinationBias = await StyleFeedbackService.getCombinationBias();
    final tibModel = await TibModelService.loadForUser(cleanUid);

    String colourSummary(ColourAnalysisResult value) => jsonEncode({
          'season': value.season,
          'undertone': value.undertone,
          'brightness': value.brightness,
          'contrast': value.contrast,
          'chroma': value.chroma,
          'clarity': value.clarity,
          'colours': value.colours,
          'bestNeutrals': value.bestNeutrals,
          'accentColours': value.accentColours,
          'lessIdealColours': value.lessIdealColours,
          'faceShape': value.faceShape,
          'faceStylingGuidance': value.faceStylingGuidance,
          'colourReasons': value.colourReasons,
        });

    Map<String, dynamic> tibModelData(TibModelProfile model) => {
          ...model.personalIdentityData,
          'measurementData': model.measurementData,
          'facePathAvailable': model.facePath != null,
          'bodyPathAvailable': model.bodyPath != null,
        };

    final personalBrand = colourSummary(profile);
    try {
      final token = await FirebaseAuth.instance.currentUser?.getIdToken();
      final response = await http
          .post(
            Uri.parse(GoogleDriveConfig.uploadUrl),
            headers: {
              'Content-Type': 'application/json',
              if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              'action': 'aiStyling',
              'uid': cleanUid,
              'profile': personalBrand,
              'tibModel': tibModelData(tibModel),
              'wardrobe': owned.map((item) => item.toMap()).toList(growable: false),
              'styles': styles,
              'preferences': preferences,
              'occasion': occasion,
              'personalBrand': personalBrand,
              'feedbackBias': feedbackBias,
              'combinationBias': combinationBias,
              'selectedItem': selectedItem?.toMap(),
              'outfitRules': const {
                'allowedCategories': [
                  'Tops',
                  'Bottoms',
                  'Dresses',
                  'Suits',
                  'Jackets',
                  'Skirts',
                  'Shoes',
                  'Accessories',
                ],
                'dressCannotCombineWith': ['Tops', 'Bottoms', 'Skirts', 'Suits'],
                'suitCannotCombineWith': ['Tops', 'Bottoms', 'Skirts', 'Dresses'],
                'separateUpperAndLowerRequired': true,
              },
            }),
          )
          .timeout(_requestTimeout);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          final payload = decoded['result'] is Map
              ? Map<String, dynamic>.from(decoded['result'] as Map)
              : decoded;
          final result = _fromPayload(payload, owned);
          if (result != null) {
            final aiItems = result.itemIds
                .map((id) => _findById(owned, id))
                .whereType<WardrobeItem>()
                .toList(growable: false);
            final sanitized = sanitizeLook(
              aiItems,
              selectedItem: selectedItem,
              occasion: occasion,
              profile: profile,
              styles: styles,
              preferences: preferences,
              excludedLookKeys: excludedLookKeys,
              feedbackBias: feedbackBias,
              combinationBias: combinationBias,
            );
            if (sanitized.isNotEmpty) {
              return _resultFromLook(
                sanitized,
                source: result,
                profile: profile,
                occasion: occasion,
                selectedItem: selectedItem,
                styles: styles,
                preferences: preferences,
                combinationBias: combinationBias,
              );
            }
          }
        }
      }
    } catch (_) {}

    final fallback = sanitizeLook(
      owned,
      selectedItem: selectedItem,
      occasion: occasion,
      profile: profile,
      styles: styles,
      preferences: preferences,
      excludedLookKeys: excludedLookKeys,
      feedbackBias: feedbackBias,
      combinationBias: combinationBias,
    );
    if (fallback.isEmpty) return null;
    return _resultFromLook(
      fallback,
      source: null,
      profile: profile,
      occasion: occasion,
      selectedItem: selectedItem,
      styles: styles,
      preferences: preferences,
      combinationBias: combinationBias,
    );
  }

  static WardrobeItem? _findById(List<WardrobeItem> items, String id) {
    for (final item in items) {
      if (item.id == id) {
        return item;
      }
    }
    return null;
  }

  static AiStylingResult? _fromPayload(Map<String, dynamic> payload, List<WardrobeItem> owned) {
    String? stringValue(String key) {
      final value = payload[key];
      if (value == null) return null;
      final text = value.toString().trim();
      return text.isEmpty ? null : text;
    }

    String? validId(String key) {
      final value = stringValue(key);
      if (value == null) return null;
      return _findById(owned, value) == null ? null : value;
    }

    final explanation = stringValue('explanation') ?? stringValue('reason') ?? '';
    final notesRaw = payload['stylingNotes'] ?? payload['notes'];
    final stylingNotes = notesRaw is List
        ? notesRaw
            .map((value) => value.toString().trim())
            .where((value) => value.isNotEmpty)
            .toList(growable: false)
        : const <String>[];
    final breakdownRaw = payload['scoreBreakdown'];
    final breakdown = <String, int>{};
    if (breakdownRaw is Map) {
      breakdownRaw.forEach((key, value) {
        final parsed = value is num ? value.round() : int.tryParse(value.toString());
        if (parsed != null) {
          breakdown[key.toString()] = parsed;
        }
      });
    }
    final rawScore = payload['matchScore'];
    final matchScore = rawScore is num
        ? rawScore.round().clamp(0, 100)
        : int.tryParse(rawScore?.toString() ?? '')?.clamp(0, 100) ?? 0;
    return AiStylingResult(
      explanation: explanation,
      topId: validId('topId') ?? validId('top'),
      bottomId: validId('bottomId') ?? validId('bottom'),
      dressId: validId('dressId') ?? validId('dress'),
      suitId: validId('suitId') ?? validId('suit'),
      jacketId: validId('jacketId') ?? validId('jacket'),
      shoesId: validId('shoesId') ?? validId('shoes'),
      accessoryId: validId('accessoryId') ?? validId('accessory'),
      lookTitle: stringValue('lookTitle') ?? stringValue('title'),
      colourDirection: stringValue('colourDirection'),
      stylingNotes: stylingNotes,
      matchScore: matchScore,
      scoreBreakdown: breakdown,
    );
  }

  static AiStylingResult _resultFromLook(
    List<WardrobeItem> look, {
    AiStylingResult? source,
    required ColourAnalysisResult profile,
    required String occasion,
    WardrobeItem? selectedItem,
    List<String> styles = const [],
    List<String> preferences = const [],
    Map<String, double> combinationBias = const {},
  }) {
    final categories = <String, String>{for (final item in look) item.category: item.id};
    final score = _scoreLook(
      look,
      profile: profile,
      occasion: occasion,
      styles: styles,
      preferences: preferences,
      selectedItem: selectedItem,
      combinationBias: combinationBias,
    );
    final computedBreakdown = <String, int>{
      'Colour': _scoreColourDimension(look, profile),
      'Style': _scoreStyleDimension(look),
      'Occasion': _scoreOccasionDimension(look, occasion),
      'Compatibility': _scoreCompatibilityDimension(look),
    };
    return AiStylingResult(
      explanation: source?.explanation ?? _fallbackExplanation(look, profile, occasion),
      topId: categories['Tops'],
      bottomId: categories['Bottoms'] ?? categories['Skirts'],
      dressId: categories['Dresses'],
      suitId: categories['Suits'],
      jacketId: categories['Jackets'],
      shoesId: categories['Shoes'],
      accessoryId: categories['Accessories'],
      lookTitle: source?.lookTitle ??
          'Your ${occasion.trim().isEmpty ? 'personal' : occasion.toLowerCase()} look',
      colourDirection: source?.colourDirection ?? profile.colours.take(3).join(' · '),
      stylingNotes: source?.stylingNotes.isNotEmpty == true
          ? source!.stylingNotes
          : _fallbackNotes(look, profile),
      matchScore: source?.matchScore == 0
          ? score
          : source?.matchScore.clamp(0, 100) ?? score,
      scoreBreakdown: source?.scoreBreakdown.isNotEmpty == true
          ? source!.scoreBreakdown
          : computedBreakdown,
    );
  }

  static int _scoreColourDimension(List<WardrobeItem> look, ColourAnalysisResult profile) {
    if (look.isEmpty) return 0;
    var total = 0;
    for (final item in look) {
      final colour = _normaliseColour(item.colour);
      if (profile.colours.any((value) => _colourMatches(colour, value))) {
        total += 25;
      } else if (profile.bestNeutrals.any((value) => _colourMatches(colour, value))) {
        total += 18;
      } else if (profile.accentColours.any((value) => _colourMatches(colour, value))) {
        total += 14;
      } else if (profile.lessIdealColours.any((value) => _colourMatches(colour, value))) {
        total += 4;
      } else {
        total += 10;
      }
    }
    return (total / look.length).round().clamp(0, 100);
  }

  static int _scoreStyleDimension(List<WardrobeItem> look) {
    if (look.isEmpty) return 0;
    final families = look
        .map((item) => _styleFamily(item.style))
        .where((value) => value != 'unknown')
        .toList(growable: false);
    if (families.isEmpty) return 40;
    final dominant = families.where((value) => value == families.first).length;
    return ((dominant / families.length) * 100).round();
  }

  static int _scoreOccasionDimension(List<WardrobeItem> look, String occasion) {
    if (look.isEmpty) return 0;
    final tokens = _occasionTokens(occasion);
    if (tokens.isEmpty) return 60;
    var matches = 0;
    for (final item in look) {
      final combined = '${item.name} ${item.style} ${item.occasion} ${item.formality} ${item.notes}'.toLowerCase();
      if (tokens.any(combined.contains)) {
        matches += 1;
      }
    }
    return ((matches / look.length) * 100).round().clamp(0, 100);
  }

  static int _scoreCompatibilityDimension(List<WardrobeItem> look) {
    if (look.length < 2) return 50;
    var total = 0;
    var pairs = 0;
    for (var i = 0; i < look.length; i++) {
      for (var j = i + 1; j < look.length; j++) {
        total += _pairCompatibilityScore(look[i], look[j]);
        pairs += 1;
      }
    }
    return ((total / (pairs * 20)) * 100).round().clamp(0, 100);
  }

  static String _fallbackExplanation(
    List<WardrobeItem> look,
    ColourAnalysisResult profile,
    String occasion,
  ) {
    final colours = look
        .map((item) => item.colour.trim())
        .where((value) => value.isNotEmpty)
        .take(3)
        .join(', ');
    final palette = profile.colours.take(3).join(', ');
    return colours.isEmpty
        ? 'I built this ${occasion.toLowerCase()} look around your personal style and colour profile.'
        : 'I paired $colours for ${occasion.toLowerCase()} and kept the direction aligned with your palette: $palette.';
  }

  static List<String> _fallbackNotes(
    List<WardrobeItem> look,
    ColourAnalysisResult profile,
  ) {
    final notes = <String>[];
    if (profile.undertone.isNotEmpty) {
      notes.add('Colour direction respects your ${profile.undertone.toLowerCase()} undertone.');
    }
    if (profile.faceShape.isNotEmpty && profile.faceShape != 'Unknown') {
      notes.add('The styling keeps your ${profile.faceShape} face shape in mind.');
    }
    final neutrals = profile.bestNeutrals.take(2).join(' + ');
    if (neutrals.isNotEmpty) {
      notes.add('Neutral support: $neutrals.');
    }
    if (notes.isEmpty) {
      notes.add('The look is assembled from your own wardrobe with colour and pairing compatibility in mind.');
    }
    return notes.take(3).toList(growable: false);
  }
}

class _ScoredItem {
  const _ScoredItem(this.item, this.score);
  final WardrobeItem item;
  final int score;
}
