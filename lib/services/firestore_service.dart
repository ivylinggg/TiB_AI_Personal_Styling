import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/user_model.dart';

import '../models/analysis_model.dart';

import '../models/colour_analysis_result.dart';

class FirestoreService {
  FirestoreService._();

  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static Future<void> createUser(UserModel user) async {
    await _db.collection('users').doc(user.uid).set(user.toMap());
  }

  static Future<UserModel?> getUser(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();

    if (!doc.exists) {
      return null;
    }

    return UserModel.fromFirestore(doc);
  }

  static Future<void> updateUser(String uid, Map<String, dynamic> data) async {
    await _db.collection('users').doc(uid).update(data);
  }

  static Future<void> saveAnalysis({
    required String uid,
    required AnalysisModel analysis,
  }) async {
    await _db
        .collection('users')
        .doc(uid)
        .collection('analysis')
        .add(analysis.toMap());
  }

  static Future<List<AnalysisModel>> getAnalysisHistory(String uid) async {
    final snapshot = await _db
        .collection('users')
        .doc(uid)
        .collection('analysis')
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs.map((e) => AnalysisModel.fromFirestore(e)).toList();
  }

  static Future<void> saveAnalysisResult({
    required String uid,
    required ColourAnalysisResult result,
  }) async {
    await _db.collection('users').doc(uid).collection('analysis').add({
      'season': result.season,
      'undertone': result.undertone,
      'brightness': result.brightness,
      'contrast': result.contrast,
      'colours': result.colours,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
