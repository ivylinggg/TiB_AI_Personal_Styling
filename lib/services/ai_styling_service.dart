import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
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

  List<String> get itemIds => [
        topId,
        bottomId,
        dressId,
        suitId,
        jacketId,
        shoesId,
        accessoryId,
      ].whereType<String>().where((id) => id.isNotEmpty).toSet().toList(growable: false);

  String get displayTitle => lookTitle == null || lookTitle!.trim().isEmpty
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
    final ids = look.map((item) => item.id.trim()).where((id) => id.isNotEmpty).toList()..sort();
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
      final pool = candidates.where((item) => item.category == category && !used.contains(item.id)).toList(growable: false);
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
        candidates,
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
      if (look.isNotEmpty) return look;
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
      if (look.isNotEmpty) return look;
    }
    return const [];
  }

  static List<WardrobeItem> _buildTwoPiece(
    List<WardrobeItem> candidates,
    WardrobeItem top,
    WardrobeItem lower,
    WardrobeItem? Function(String, {List<WardrobeItem> anchors, Set<String> used}) choose, {
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
    if (accessory != null) result.add(accessory);
    return _finalizeLook(
      result,
      selectedItem: top,
      profile: profile,
      occasion: occasion,
      styles: styles,
      preferences: preferences,
      combinationBias: combinationBias,
    );
  }

  static List<WardrobeItem> _buildOnePiece(
    WardrobeItem piece,
    WardrobeItem? Function(String, {List<WardrobeItem> anchors, Set<String> used}) choose, {
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
    if (accessory != null) result.add(accessory);
    final look = _finalizeLook(
      result,
      selectedItem: selectedItem,
      profile: profile,
      occasion: occasion,
      styles: styles,
      preferences: preferences,
      combinationBias: combinationBias,
    );
    final key = _lookKey(look);
    return key != null && excludedLookKeys.contains(key) ? const [] : look;
  }

  static List<WardrobeItem> _buildSuit(
    WardrobeItem suit,
    WardrobeItem? Function(String, {List<WardrobeItem> anchors, Set<String> used}) choose, {
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
    if (accessory != null) result.add(accessory);
    final look = _finalizeLook(
      result,
      selectedItem: selectedItem,
      profile: profile,
      occasion: occasion,
      styles: styles,
      preferences: preferences,
      combinationBias: combinationBias,
    );
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

  static List<WardrobeItem> _finalizeLook(
    List<WardrobeItem> result, {
    required WardrobeItem? selectedItem,
    required ColourAnalysisResult? profile,
    required String occasion,
    required List<String> styles,
    required List<String> preferences,
    Map<String, double> combinationBias = const {},
  }) {
    final unique = <String, WardrobeItem>{};
    for (final item in result) {
      if (_knownCategories.contains(item.category.trim())) {
        unique[item.id] = item;
      }
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
    final score = _scoreLook(
      sanitized,
      profile: profile,
      occasion: occasion,
      styles: styles,
      preferences: preferences,
      selectedItem: selectedItem,
      combinationBias: combinationBias,
    );
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
    Map<String, double> combinationBias = const {},
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
        score += _pairCombinationBias(item, anchor, combinationBias).round();
      }
      return _ScoredItem(item, score);
    }).toList(growable: false);
    scored.sort((a, b) => b.score == a.score
        ? a.item.name.toLowerCase().compareTo(b.item.name.toLowerCase())
        : b.score.compareTo(a.score));
    return scored.map((entry) => entry.item).toList(growable: false);
  }

  static double _pairCombinationBias(WardrobeItem first, WardrobeItem second, Map<String, double> bias) {
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
    if (selectedItem != null && look.any((item) => item.id == selectedItem.id)) score += 8;
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
    if (validStructure) score += 20;
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
      score -= 4;
    }
    return score;
  }

  static bool _stylesCanBlend(String first, String second) {
    const blends = <String, Set<String>>{
      'formal': {'minimal', 'elegant'},
      'elegant': {'formal', 'minimal'},
      'casual': {'minimal', 'street', 'sport'},
      'minimal': {'formal', 'elegant', 'casual', 'street'},
      'street': {'casual', 'minimal'},
      'sport': {'casual'},
    };
    return blends[first]?.contains(second) == true || blends[second]?.contains(first) == true;
  }

  static WardrobeItem? _findOwned(List<WardrobeItem> owned, String? id) {
    if (id == null || id.trim().isEmpty) return null;
    for (final item in owned) {
      if (item.id == id.trim()) return item;
    }
    return null;
  }

  static AiStylingResult? _fromPayload(Map<String, dynamic> payload, List<WardrobeItem> owned, {
    required ColourAnalysisResult? profile,
    required String occasion,
    required List<String> styles,
    required List<String> preferences,
    WardrobeItem? selectedItem,
    Set<String> excludedLookKeys = const {},
    Map<String, double> feedbackBias = const {},
    Map<String, double> combinationBias = const {},
  }) {
    final topId = payload['topId']?.toString();
    final bottomId = payload['bottomId']?.toString();
    final dressId = payload['dressId']?.toString();
    final suitId = payload['suitId']?.toString();
    final jacketId = payload['jacketId']?.toString();
    final shoesId = payload['shoesId']?.toString();
    final accessoryId = payload['accessoryId']?.toString();

    final selected = <WardrobeItem?>[
      _findOwned(owned, topId),
      _findOwned(owned, bottomId),
      _findOwned(owned, dressId),
      _findOwned(owned, suitId),
      _findOwned(owned, jacketId),
      _findOwned(owned, shoesId),
      _findOwned(owned, accessoryId),
    ].whereType<WardrobeItem>().toList(growable: false);
    final sanitized = sanitizeLook(
      selected,
      selectedItem: selectedItem,
      occasion: occasion,
      profile: profile,
      styles: styles,
      preferences: preferences,
      excludedLookKeys: excludedLookKeys,
      feedbackBias: feedbackBias,
      combinationBias: combinationBias,
    );
    if (sanitized.isEmpty) return null;

    final ids = sanitized.map((item) => item.id).toSet();
    return AiStylingResult(
      explanation: payload['explanation']?.toString().trim() ?? '',
      topId: ids.contains(topId) ? topId : sanitized.firstWhere((item) => item.category == 'Tops', orElse: () => sanitized.first).id,
      bottomId: ids.contains(bottomId) ? bottomId : sanitized.cast<WardrobeItem?>().firstWhere((item) => item?.category == 'Bottoms', orElse: () => null)?.id,
      dressId: ids.contains(dressId) ? dressId : sanitized.cast<WardrobeItem?>().firstWhere((item) => item?.category == 'Dresses', orElse: () => null)?.id,
      suitId: ids.contains(suitId) ? suitId : sanitized.cast<WardrobeItem?>().firstWhere((item) => item?.category == 'Suits', orElse: () => null)?.id,
      jacketId: ids.contains(jacketId) ? jacketId : sanitized.cast<WardrobeItem?>().firstWhere((item) => item?.category == 'Jackets', orElse: () => null)?.id,
      shoesId: ids.contains(shoesId) ? shoesId : sanitized.cast<WardrobeItem?>().firstWhere((item) => item?.category == 'Shoes', orElse: () => null)?.id,
      accessoryId: ids.contains(accessoryId) ? accessoryId : sanitized.cast<WardrobeItem?>().firstWhere((item) => item?.category == 'Accessories', orElse: () => null)?.id,
      lookTitle: payload['lookTitle']?.toString(),
      colourDirection: payload['colourDirection']?.toString(),
      stylingNotes: payload['stylingNotes'] is List
          ? (payload['stylingNotes'] as List).map((item) => item.toString()).where((item) => item.trim().isNotEmpty).toList(growable: false)
          : const [],
      matchScore: payload['matchScore'] is num ? (payload['matchScore'] as num).round().clamp(0, 100) : _scoreLook(sanitized, profile: profile, occasion: occasion, styles: styles, preferences: preferences, selectedItem: selectedItem, combinationBias: combinationBias),
      scoreBreakdown: payload['scoreBreakdown'] is Map
          ? Map<String, int>.fromEntries((payload['scoreBreakdown'] as Map).entries.map((entry) => MapEntry(entry.key.toString(), (entry.value as num?)?.round() ?? 0)))
          : const {},
    );
  }

  static Future<AiStylingResult?> getRecommendation({
    required String uid,
    required ColourAnalysisResult? profile,
    required List<WardrobeItem> wardrobe,
    List<String> styles = const [],
    List<String> preferences = const [],
    required String occasion,
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
    final personalBrand = profile == null ? '' : '${profile.season} ${profile.undertone} ${profile.brightness} ${profile.contrast}';
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
              'profile': profile?.toMap(),
              'tibModel': tibModel?.toMap(),
              'wardrobe': owned.map((item) => item.toMap()).toList(growable: false),
              'styles': styles,
              'preferences': preferences,
              'occasion': occasion,
              'personalBrand': personalBrand,
              'feedbackBias': feedbackBias,
              'combinationBias': combinationBias,
              'selectedItem': selectedItem?.toMap(),
              'outfitRules': const {
                'allowedCategories': ['Tops', 'Bottoms', 'Dresses', 'Suits', 'Jackets', 'Skirts', 'Shoes', 'Accessories'],
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
          final result = _fromPayload(
            payload,
            owned,
            profile: profile,
            occasion: occasion,
            styles: styles,
            preferences: preferences,
            selectedItem: selectedItem,
            excludedLookKeys: excludedLookKeys,
            feedbackBias: feedbackBias,
            combinationBias: combinationBias,
          );
          if (result != null) return result;
        }
      }
    } catch (_) {
      // Fall through to the local deterministic wardrobe engine.
    }

    final localLook = sanitizeLook(
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
    if (localLook.isEmpty) return null;

    final localScore = _scoreLook(
      localLook,
      profile: profile,
      occasion: occasion,
      styles: styles,
      preferences: preferences,
      selectedItem: selectedItem,
      combinationBias: combinationBias,
    );
    final idSet = localLook.map((item) => item.id).toSet();
    return AiStylingResult(
      explanation: 'Built from your wardrobe using your colour profile, style preferences and item compatibility.',
      topId: localLook.cast<WardrobeItem?>().firstWhere((item) => item?.category == 'Tops', orElse: () => null)?.id,
      bottomId: localLook.cast<WardrobeItem?>().firstWhere((item) => item?.category == 'Bottoms', orElse: () => null)?.id ?? localLook.cast<WardrobeItem?>().firstWhere((item) => item?.category == 'Skirts', orElse: () => null)?.id,
      dressId: localLook.cast<WardrobeItem?>().firstWhere((item) => item?.category == 'Dresses', orElse: () => null)?.id,
      suitId: localLook.cast<WardrobeItem?>().firstWhere((item) => item?.category == 'Suits', orElse: () => null)?.id,
      jacketId: localLook.cast<WardrobeItem?>().firstWhere((item) => item?.category == 'Jackets', orElse: () => null)?.id,
      shoesId: localLook.cast<WardrobeItem?>().firstWhere((item) => item?.category == 'Shoes', orElse: () => null)?.id,
      accessoryId: localLook.cast<WardrobeItem?>().firstWhere((item) => item?.category == 'Accessories', orElse: () => null)?.id,
      lookTitle: occasion.trim().isEmpty ? 'Your personal look' : '${occasion.trim()} look',
      colourDirection: profile == null ? null : '${profile.undertone} · ${profile.brightness} · ${profile.contrast}',
      stylingNotes: [
        if (profile != null) 'Uses your ${profile.season} colour context.',
        if (styles.isNotEmpty) 'Prioritises ${styles.take(2).join(' and ')} style preferences.',
        if (localLook.isNotEmpty) 'Keeps the outfit to pieces already in your wardrobe.',
      ],
      matchScore: localScore,
      scoreBreakdown: {
        'wardrobeFit': localScore,
        'pieceCount': idSet.length,
      },
    );
  }

  static List<WardrobeItem> rankReplacementItems({
    required List<WardrobeItem> candidates,
    required List<WardrobeItem> anchors,
    required String occasion,
    ColourAnalysisResult? profile,
    List<String> styles = const [],
    List<String> preferences = const [],
    Map<String, double> feedbackBias = const {},
    Map<String, double> combinationBias = const {},
  }) {
    return _rankItems(
      candidates,
      profile: profile,
      occasion: occasion,
      styles: styles,
      preferences: preferences,
      anchors: anchors,
      feedbackBias: feedbackBias,
      combinationBias: combinationBias,
    );
  }
}

class _ScoredItem {
  final WardrobeItem item;
  final int score;

  const _ScoredItem(this.item, this.score);
}