import 'package:cloud_firestore/cloud_firestore.dart';

/// Persists lightweight styling feedback so TiB can learn which wardrobe
/// pieces the user tends to like or avoid across AI sessions.
class AiFeedbackService {
  AiFeedbackService._();

  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static CollectionReference<Map<String, dynamic>> _feedback(String uid) =>
      _db.collection('users').doc(uid).collection('aiFeedback');

  static Future<void> saveLookFeedback({
    required String uid,
    required String feedback,
    required List<String> itemIds,
    required String occasion,
  }) async {
    if (itemIds.isEmpty) return;

    await _feedback(uid).add({
      'feedback': feedback,
      'itemIds': itemIds,
      'occasion': occasion,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<List<Map<String, dynamic>>> getRecentFeedback(
    String uid, {
    int limit = 40,
  }) async {
    final snapshot = await _feedback(uid)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();

    return snapshot.docs
        .map((doc) => <String, dynamic>{'id': doc.id, ...doc.data()})
        .toList();
  }

  static Future<Map<String, int>> getPieceFeedbackScores(String uid) async {
    final recent = await getRecentFeedback(uid);
    final scores = <String, int>{};

    for (final entry in recent) {
      final rawIds = entry['itemIds'];
      if (rawIds is! List) continue;

      final feedback = entry['feedback'] as String? ?? '';
      final delta = feedback == 'love' ? 1 : feedback == 'dislike' ? -1 : 0;
      if (delta == 0) continue;

      for (final rawId in rawIds) {
        final id = rawId.toString();
        if (id.isEmpty) continue;
        scores[id] = (scores[id] ?? 0) + delta;
      }
    }

    return scores;
  }
}
