import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class StyleFeedbackService {
  StyleFeedbackService._();

  static CollectionReference<Map<String, dynamic>> _feedbackCollection(String uid) => FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .collection('styleFeedback');

  static String _safeKey(String value) => value.trim().replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');

  static Future<void> recordItemFeedback({
    required String itemId,
    required String category,
    required bool liked,
    String occasion = '',
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid.trim();
    final cleanItemId = itemId.trim();
    if (uid == null || uid.isEmpty || cleanItemId.isEmpty) return;
    await _feedbackCollection(uid).doc('item_${_safeKey(cleanItemId)}').set({
      'type': 'item',
      'itemId': cleanItemId,
      'category': category.trim(),
      'liked': liked,
      'occasion': occasion.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static Future<void> recordLookFeedback({
    required List<String> itemIds,
    required bool liked,
    String occasion = '',
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid.trim();
    final ids = itemIds.map((id) => id.trim()).where((id) => id.isNotEmpty).toSet().toList()..sort();
    if (uid == null || uid.isEmpty || ids.isEmpty) return;
    await _feedbackCollection(uid).doc('look_${ids.map(_safeKey).join('_')}').set({
      'type': 'look',
      'itemIds': ids,
      'liked': liked,
      'occasion': occasion.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static Future<List<Map<String, dynamic>>> getRecentFeedback({int limit = 40}) async {
    final uid = FirebaseAuth.instance.currentUser?.uid.trim();
    if (uid == null || uid.isEmpty) return const [];
    final snapshot = await _feedbackCollection(uid)
        .orderBy('updatedAt', descending: true)
        .limit(limit.clamp(1, 100))
        .get();
    return snapshot.docs.map((doc) => doc.data()).toList(growable: false);
  }

  static Future<Map<String, double>> getItemBias({int limit = 100}) async {
    final feedback = await getRecentFeedback(limit: limit);
    final bias = <String, double>{};
    for (final entry in feedback) {
      if (entry['type'] != 'item') continue;
      final itemId = entry['itemId'] as String?;
      final liked = entry['liked'] as bool?;
      if (itemId == null || itemId.isEmpty || liked == null) continue;
      bias[itemId] = liked ? (bias[itemId] ?? 0) + 12 : (bias[itemId] ?? 0) - 16;
    }
    return bias;
  }

  static Future<Map<String, double>> getCombinationBias({int limit = 100}) async {
    final feedback = await getRecentFeedback(limit: limit);
    final bias = <String, double>{};
    for (final entry in feedback) {
      if (entry['type'] != 'look') continue;
      final rawIds = entry['itemIds'];
      final liked = entry['liked'] as bool?;
      if (rawIds is! List || liked == null) continue;
      final ids = rawIds.map((item) => item.toString().trim()).where((id) => id.isNotEmpty).toList()..sort();
      if (ids.length < 2) continue;
      final key = ids.join('|');
      bias[key] = liked ? (bias[key] ?? 0) + 18 : (bias[key] ?? 0) - 20;
    }
    return bias;
  }

  static Future<void> recordGeneratedLook({
    required List<String> itemIds,
    required String occasion,
    int? matchScore,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid.trim();
    final ids = itemIds.map((id) => id.trim()).where((id) => id.isNotEmpty).toSet().toList()..sort();
    if (uid == null || uid.isEmpty || ids.isEmpty) return;
    final generatedKey = ids.map(_safeKey).join('_');
    final payload = <String, dynamic>{
      'type': 'generated',
      'itemIds': ids,
      'occasion': occasion.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
      ...?matchScore == null ? null : {'matchScore': matchScore},
    };
    await _feedbackCollection(uid).doc('generated_$generatedKey').set(payload, SetOptions(merge: true));
  }
}
