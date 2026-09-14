import 'package:cloud_firestore/cloud_firestore.dart';

/// Persists lightweight styling feedback so TiB can learn which wardrobe
/// pieces the user tends to like or avoid across AI sessions.
class AiFeedbackService {
  AiFeedbackService._();

  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static const _maxUidLength = 128;
  static const _maxFeedbackLength = 32;
  static const _maxOccasionLength = 80;
  static const _maxItemIdLength = 128;
  static const _maxItemCount = 20;
  static const _maxLimit = 100;

  static CollectionReference<Map<String, dynamic>>? _feedback(String uid) {
    final value = uid.trim();
    if (!_isValidId(value, _maxUidLength)) return null;
    return _db.collection('users').doc(value).collection('aiFeedback');
  }

  static bool _isValidId(String value, int maxLength) =>
      value.isNotEmpty && value.length <= maxLength;

  static String? _normalizeText(String value, int maxLength) {
    final normalized = value.trim();
    if (normalized.isEmpty || normalized.length > maxLength) return null;
    return normalized;
  }

  static List<String> _normalizeItemIds(List<String> itemIds) {
    final normalized = <String>[];
    for (final rawId in itemIds) {
      final id = rawId.trim();
      if (!_isValidId(id, _maxItemIdLength)) continue;
      if (normalized.contains(id)) continue;
      normalized.add(id);
      if (normalized.length >= _maxItemCount) break;
    }
    return normalized;
  }

  static Future<void> saveLookFeedback({
    required String uid,
    required String feedback,
    required List<String> itemIds,
    required String occasion,
  }) async {
    final collection = _feedback(uid);
    final normalizedFeedback = _normalizeText(feedback, _maxFeedbackLength);
    final normalizedOccasion = _normalizeText(occasion, _maxOccasionLength);
    final normalizedItemIds = _normalizeItemIds(itemIds);

    if (collection == null ||
        normalizedFeedback == null ||
        normalizedOccasion == null ||
        normalizedItemIds.isEmpty) {
      return;
    }

    await collection.add({
      'feedback': normalizedFeedback,
      'itemIds': normalizedItemIds,
      'occasion': normalizedOccasion,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<List<Map<String, dynamic>>> getRecentFeedback(
    String uid, {
    int limit = 40,
  }) async {
    final collection = _feedback(uid);
    if (collection == null || limit <= 0) return const [];

    final snapshot = await collection
        .orderBy('createdAt', descending: true)
        .limit(limit.clamp(1, _maxLimit))
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

      final feedback = entry['feedback'];
      if (feedback is! String) continue;
      final normalizedFeedback = feedback.trim().toLowerCase();
      final delta = normalizedFeedback == 'love'
          ? 1
          : normalizedFeedback == 'dislike'
              ? -1
              : 0;
      if (delta == 0) continue;

      for (final rawId in rawIds) {
        final id = rawId.toString().trim();
        if (!_isValidId(id, _maxItemIdLength)) continue;
        scores[id] = (scores[id] ?? 0) + delta;
      }
    }

    return scores;
  }
}
