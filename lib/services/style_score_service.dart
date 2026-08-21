import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/colour_analysis_result.dart';

class StyleScoreSnapshot {
  final int appearance;
  final int behavior;
  final int communication;
  final int digitalEtiquette;

  const StyleScoreSnapshot({
    required this.appearance,
    required this.behavior,
    required this.communication,
    required this.digitalEtiquette,
  });

  int get total =>
      (appearance + behavior + communication + digitalEtiquette)
          .clamp(0, 100);
}

/// Calculates the dashboard Style Score from real user progress.
///
/// The score is intentionally transparent: each section has a fixed maximum
/// that maps to the TiB-style Appearance / Behavior / Communication /
/// Digital Etiquette framework.
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
    final wardrobeSnapshot = results[1] as QuerySnapshot<Map<String, dynamic>>;
    final preferenceDoc =
        results[2] as DocumentSnapshot<Map<String, dynamic>>;

    final user = userDoc.data() ?? const <String, dynamic>{};
    final preferences = preferenceDoc.data() ?? const <String, dynamic>{};

    // Appearance / 40:
    // 20 points for colour analysis quality + up to 20 for a usable wardrobe.
    final analysisColours = analysis?.colours.length ?? 0;
    final analysisPoints = analysis == null
        ? 0
        : analysisColours >= 8
            ? 20
            : analysisColours * 2;
    final wardrobeCount = wardrobeSnapshot.docs.length;
    final wardrobePoints = wardrobeCount >= 10
        ? 20
        : wardrobeCount * 2;
    final appearance = (analysisPoints + wardrobePoints).clamp(0, 40);

    // Behavior / 25:
    // Challenge completions build the score gradually. Historical challenge
    // entries are retained in the user document.
    final history = user['dailyChallengeHistory'];
    final challengeCount = history is List ? history.length : 0;
    final behavior = (challengeCount >= 5 ? 25 : challengeCount * 5).clamp(0, 25);

    // Communication / 20:
    // Completing onboarding/style preferences provides evidence that the user
    // has articulated their preferred style and communication direction.
    final styles = preferences['styles'];
    final selectedStyles = styles is List ? styles.length : 0;
    final selectedPreferences = preferences['preferences'];
    final preferenceCount =
        selectedPreferences is List ? selectedPreferences.length : 0;
    final communication =
        ((selectedStyles >= 3 ? 12 : selectedStyles * 4) +
                (preferenceCount >= 2 ? 8 : preferenceCount * 4))
            .clamp(0, 20);

    // Digital Etiquette / 15:
    // Profile completeness contributes to a professional digital presence.
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
    );
  }
}
