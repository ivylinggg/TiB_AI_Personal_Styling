import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/analysis_model.dart';
import '../models/colour_analysis_result.dart';
import '../models/user_model.dart';

class FirestoreService {
  FirestoreService._();

  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ============================================================
  // USERS
  // ============================================================

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
    await _db.collection('users').doc(uid).update({
      ...data,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ============================================================
  // ANALYSIS - OLD / EXISTING
  // ============================================================

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

    return snapshot.docs
        .map((doc) => AnalysisModel.fromFirestore(doc))
        .toList();
  }

  // ============================================================
  // COLOUR ANALYSIS
  // ============================================================

  static Future<void> saveAnalysisResult({
    required String uid,
    required ColourAnalysisResult result,
  }) async {
    await _db.collection('users').doc(uid).collection('analysis').add({
      'season': result.season,
      'undertone': result.undertone,
      'brightness': result.brightness,
      'contrast': result.contrast,
      'imageUrl': result.imageUrl,
      'colours': result.colours,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // ============================================================
  // GET COLOUR ANALYSIS HISTORY
  // ============================================================

  static Future<List<ColourAnalysisResult>> getColourAnalysisHistory(
    String uid,
  ) async {
    final snapshot = await _db
        .collection('users')
        .doc(uid)
        .collection('analysis')
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();

      final colours = data['colours'];

      return ColourAnalysisResult(
        season: data['season'] as String? ?? 'Unknown',
        undertone: data['undertone'] as String? ?? 'Unknown',
        brightness: data['brightness'] as String? ?? 'Unknown',
        contrast: data['contrast'] as String? ?? 'Unknown',
        imageUrl: data['imageUrl'] as String? ?? '',
        colours: colours is List
            ? colours.map((item) => item.toString()).toList()
            : const [],
      );
    }).toList();
  }

  // ============================================================
  // GET LATEST COLOUR ANALYSIS
  // ============================================================

  static Future<ColourAnalysisResult?> getLatestColourAnalysis(
    String uid,
  ) async {
    final snapshot = await _db
        .collection('users')
        .doc(uid)
        .collection('analysis')
        .orderBy('createdAt', descending: true)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) {
      return null;
    }

    final data = snapshot.docs.first.data();

    final colours = data['colours'];

    return ColourAnalysisResult(
      season: data['season'] as String? ?? 'Unknown',
      undertone: data['undertone'] as String? ?? 'Unknown',
      brightness: data['brightness'] as String? ?? 'Unknown',
      contrast: data['contrast'] as String? ?? 'Unknown',
      imageUrl: data['imageUrl'] as String? ?? '',
      colours: colours is List
          ? colours.map((item) => item.toString()).toList()
          : const [],
    );
  }
}
