import 'package:cloud_firestore/cloud_firestore.dart';

class StylePreferenceService {
  StylePreferenceService._();

  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static CollectionReference<Map<String, dynamic>> _preferences(
    String uid,
  ) {
    return _db.collection('users').doc(uid).collection('preferences');
  }

  static DocumentReference<Map<String, dynamic>> _styleDocument(
    String uid,
  ) {
    return _preferences(uid).doc('style');
  }

  static Future<Map<String, dynamic>?> getStylePreferences(String uid) async {
    final snapshot = await _styleDocument(uid).get();

    if (!snapshot.exists) return null;

    return snapshot.data();
  }

  static Future<void> saveStylePreferences({
    required String uid,
    required List<String> styles,
    required List<String> preferences,
  }) async {
    await _styleDocument(uid).set({
      'styles': styles,
      'preferences': preferences,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}