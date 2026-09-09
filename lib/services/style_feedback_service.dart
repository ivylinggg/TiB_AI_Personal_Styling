import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class StyleFeedbackService {
  StyleFeedbackService._();

  static CollectionReference<Map<String, dynamic>> _feedbackCollection(String uid) => FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .collection('styleFeedback');

  static Future<void> recordItemFeedback({
    required String itemId,
    required String category,
    required bool liked,
    String occasion = '',
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid.trim();
    final cleanItemId = itemId.trim();
    if (uid == null || uid.isEmpty || cleanItemId.isEmpty) return;
    await _feedbackCollection(uid).doc('item_$cleanItemId').set({
      'type': 'item',
      'itemId': cleanItemId,
      'category': category,
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
    final key = ids.join('_');
    await _feedbackCollection(uid).doc('look_$key').set({
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
}
