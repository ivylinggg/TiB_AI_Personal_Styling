import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/colour_analysis_result.dart';

class StyleScoreSnapshot {
  final int appearance;
  final int behavior;
  final int communication;
  final int digitalEtiquette;
  final int challengeXp;
  final int challengeStreak;

  const StyleScoreSnapshot({
    required this.appearance,
    required this.behavior,
    required this.communication,
    required this.digitalEtiquette,
    this.challengeXp = 0,
    this.challengeStreak = 0,
  });

  int get total =>
      (appearance + behavior + communication + digitalEtiquette)
          .clamp(0, 100);
}

/// Calculates the dashboard Style Score from real user progress.
///
/// The score maps to the TiB-style Appearance / Behavior / Communication /
/// Digital Etiquette framework. Appearance now rewards both wardrobe growth
/// and how well the wardrobe reflects the user's personal colour palette.
class StyleScoreService {
  StyleScoreService._();

  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static Future<StyleScoreSnapshot> calculate({
    required String uid,
    required ColourAnalysisResult? analysis,
  }) async {
    if (uid.trim().isEmpty) {
      return const StyleScoreSnapshot(
        appearance: 0,
        behavior: 0,
        communication: 0,
        digitalEtiquette: 0,
      );
    }

    final userRef = _db.collection('users').doc(uid);

    final results = await Future.wait([
      userRef.get(),
      userRef.collection('wardrobe').get(),
      userRef.collection('preferences').doc('style').get(),
    ]);

    final userDoc = results[0] as DocumentSnapshot<Map<String, dynamic>>;
    final wardrobeSnapshot =
        results[1] as QuerySnapshot<Map<String, dynamic>>;
    final preferenceDoc =
        results[2] as DocumentSnapshot<Map<String, dynamic>>;

    final user = userDoc.data() ?? const <String, dynamic>{};
    final preferences = preferenceDoc.data() ?? const <String, dynamic>{};

    // Appearance / 40:
    // 20 points reward completing a colour profile + having a usable wardrobe.
    // A further 20 points reward wardrobe items that match the user's
    // personal best-colour palette, so adding the right clothes improves the
    // score rather than rewarding quantity alone.
    final analysisColours = analysis?.colours.length ?? 0;
    final analysisPoints = analysis == null
        ? 0
        : analysisColours >= 8
            ? 20
            : analysisColours * 2;

    final wardrobeCount = wardrobeSnapshot.docs.length;
    final wardrobeQuantityPoints = wardrobeCount >= 10
        ? 10
        : wardrobeCount;

    final palette = (analysis?.colours ?? const <String>[])
        .map(_normalise)
        .where((colour) => colour.isNotEmpty)
        .toSet();

    var paletteMatches = 0;
    if (palette.isNotEmpty) {
      for (final doc in wardrobeSnapshot.docs) {
        final colour = _normalise(doc.data()['colour']?.toString() ?? '');
        if (colour.isNotEmpty && _matchesPalette(colour, palette)) {
          paletteMatches++;
        }
      }
    }

    final palettePoints = paletteMatches >= 10
        ? 10
        : paletteMatches;
    final appearance =
        (analysisPoints + wardrobeQuantityPoints + palettePoints).clamp(0, 40);

    // Behavior / 25.
    final history = user['dailyChallengeHistory'];
    final challengeDates = <String>{};
    if (history is List) {
      for (final item in history) {
        if (item is Map) {
          final date = item['date']?.toString().trim();
          if (date != null && date.isNotEmpty) {
            challengeDates.add(date);
          }
        }
      }
    }

    final challengeCount = challengeDates.length;
    final challengeXp = challengeCount * 10;
    final challengeStreak = _calculateStreak(challengeDates);

    final completionPoints =
        (challengeCount >= 5 ? 15 : challengeCount * 3).clamp(0, 15);
    final streakPoints =
        (challengeStreak >= 5 ? 10 : challengeStreak * 2).clamp(0, 10);
    final behavior = (completionPoints + streakPoints).clamp(0, 25);

    // Communication / 20.
    final styles = preferences['styles'];
    final selectedStyles = styles is List ? styles.length : 0;
    final selectedPreferences = preferences['preferences'];
    final preferenceCount =
        selectedPreferences is List ? selectedPreferences.length : 0;
    final communication =
        ((selectedStyles >= 3 ? 12 : selectedStyles * 4) +
                (preferenceCount >= 2 ? 8 : preferenceCount * 4))
            .clamp(0, 20);

    // Digital Etiquette / 15.
    final hasPhoto = (user['photoUrl'] ?? '').toString().trim().isNotEmpty;
    final hasName = (user['displayName'] ?? user['name'] ?? '')
        .toString()
        .trim()
        .isNotEmpty;
    final hasEmail = (user['email'] ?? '').toString().trim().isNotEmpty;
    final digitalEtiquette =
        ((hasPhoto ? 5 : 0) + (hasName ? 5 : 0) + (hasEmail ? 5 : 0))
            .clamp(0, 15);

    return StyleScoreSnapshot(
      appearance: appearance,
      behavior: behavior,
      communication: communication,
      digitalEtiquette: digitalEtiquette,
      challengeXp: challengeXp,
      challengeStreak: challengeStreak,
    );
  }

  static String _normalise(String value) =>
      value.toLowerCase().replaceAll('-', ' ').replaceAll('_', ' ').trim();

  static bool _matchesPalette(String wardrobeColour, Set<String> palette) {
    if (palette.contains(wardrobeColour)) return true;

    for (final preferred in palette) {
      if (wardrobeColour.contains(preferred) || preferred.contains(wardrobeColour)) {
        return true;
      }

      if (_colourFamily(wardrobeColour) == _colourFamily(preferred)) {
        return true;
      }
    }

    return false;
  }

  static String _colourFamily(String colour) {
    if (colour.contains('pink') ||
        colour.contains('rose') ||
        colour.contains('coral') ||
        colour.contains('peach')) {
      return 'pink';
    }
    if (colour.contains('red') ||
        colour.contains('ruby') ||
        colour.contains('burgundy') ||
        colour.contains('wine')) {
      return 'red';
    }
    if (colour.contains('orange') || colour.contains('terracotta')) {
      return 'orange';
    }
    if (colour.contains('yellow') || colour.contains('gold') || colour.contains('mustard')) {
      return 'yellow';
    }
    if (colour.contains('green') ||
        colour.contains('olive') ||
        colour.contains('sage') ||
        colour.contains('mint') ||
        colour.contains('emerald')) {
      return 'green';
    }
    if (colour.contains('teal') ||
        colour.contains('turquoise') ||
        colour.contains('cyan') ||
        colour.contains('aqua')) {
      return 'teal';
    }
    if (colour.contains('blue') ||
        colour.contains('navy') ||
        colour.contains('cobalt') ||
        colour.contains('sapphire')) {
      return 'blue';
    }
    if (colour.contains('purple') ||
        colour.contains('lavender') ||
        colour.contains('lilac') ||
        colour.contains('mauve') ||
        colour.contains('plum')) {
      return 'purple';
    }
    if (colour.contains('brown') ||
        colour.contains('camel') ||
        colour.contains('chocolate') ||
        colour.contains('tan')) {
      return 'brown';
    }
    if (colour.contains('beige') ||
        colour.contains('cream') ||
        colour.contains('ivory') ||
        colour.contains('taupe')) {
      return 'beige';
    }
    if (colour.contains('white')) return 'white';
    if (colour.contains('black') || colour.contains('charcoal')) return 'black';
    if (colour.contains('grey') || colour.contains('gray')) return 'grey';
    return colour;
  }

  static int _calculateStreak(Set<String> dates) {
    if (dates.isEmpty) return 0;

    final parsed = dates
        .map(DateTime.tryParse)
        .whereType<DateTime>()
        .map((date) => DateTime(date.year, date.month, date.day))
        .toSet()
        .toList()
      ..sort((a, b) => b.compareTo(a));

    if (parsed.isEmpty) return 0;

    final today = DateTime.now();
    var expected = DateTime(today.year, today.month, today.day);

    if (parsed.first.isBefore(expected.subtract(const Duration(days: 1)))) {
      return 0;
    }
    if (parsed.first.isAfter(expected)) {
      expected = parsed.first;
    }

    var streak = 0;
    for (final date in parsed) {
      if (date == expected) {
        streak++;
        expected = expected.subtract(const Duration(days: 1));
      } else if (date.isBefore(expected)) {
        break;
      }
    }
    return streak;
  }
}
