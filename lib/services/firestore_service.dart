import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/analysis_model.dart';
import '../models/colour_analysis_result.dart';
import '../models/user_model.dart';
import '../models/wardrobe_item.dart';

class CustomerDeletionResult {
  final int wardrobeItemsDeleted;
  final int preferencesDeleted;
  final int analysisRecordsDeleted;
  final bool userDocDeleted;
  final List<String> imageUrls;

  const CustomerDeletionResult({
    required this.wardrobeItemsDeleted,
    required this.preferencesDeleted,
    required this.analysisRecordsDeleted,
    required this.userDocDeleted,
    required this.imageUrls,
  });
}

class FirestoreService {
  FirestoreService._();

  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static Future<void> createUser(UserModel user) async {
    await _db
        .collection('users')
        .doc(user.uid)
        .set(user.toMap())
        .timeout(
          const Duration(seconds: 15),
          onTimeout: () => throw TimeoutException(
            'Creating your profile timed out. Please check your connection and try again.',
          ),
        );
  }

  /// Reads the profile from the server when possible and falls back to the
  /// local Firestore cache when the device is temporarily offline.
  ///
  /// The cached profile is especially important for the Profile tab: being
  /// offline should not turn an already-created profile into a blank error
  /// screen.
  static Future<UserModel?> getUser(String uid) async {
    final ref = _db.collection('users').doc(uid);

    try {
      final doc = await ref.get();
      if (!doc.exists) return null;
      return UserModel.fromFirestore(doc);
    } on FirebaseException catch (error) {
      if (error.code != 'unavailable') rethrow;

      try {
        final cachedDoc = await ref.get(
          const GetOptions(source: Source.cache),
        );
        if (!cachedDoc.exists) return null;
        return UserModel.fromFirestore(cachedDoc);
      } on FirebaseException {
        rethrow;
      }
    }
  }

  static Future<void> updateUser(String uid, Map<String, dynamic> data) async {
    await _db.collection('users').doc(uid).update({
      ...data,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> updateColourProfile({
    required String uid,
    required String colourSeason,
    required String skinTone,
  }) async {
    await updateUser(uid, {'colourSeason': colourSeason, 'skinTone': skinTone});
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
    return snapshot.docs
        .map((doc) => AnalysisModel.fromFirestore(doc))
        .toList();
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
      'imageUrl': result.imageUrl,
      'colours': result.colours,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

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
    if (snapshot.docs.isEmpty) return null;
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

  static CollectionReference<Map<String, dynamic>> _wardrobe(String uid) =>
      _db.collection('users').doc(uid).collection('wardrobe');

  static Future<String> addWardrobeItem(WardrobeItem item) async {
    final ref = await _wardrobe(item.userId).add(item.toMap());
    return ref.id;
  }

  static Future<List<WardrobeItem>> getWardrobeItems(String uid) async {
    final snapshot = await _wardrobe(
      uid,
    ).orderBy('createdAt', descending: true).get();
    return snapshot.docs.map(WardrobeItem.fromFirestore).toList();
  }

  static Stream<List<WardrobeItem>> watchWardrobeItems(String uid) {
    return _wardrobe(uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.map(WardrobeItem.fromFirestore).toList(),
        );
  }

  static Future<void> updateWardrobeItem(
    String uid,
    String itemId,
    Map<String, dynamic> data,
  ) async {
    await _wardrobe(uid).doc(itemId).update(data);
  }

  static Future<void> deleteWardrobeItem(String uid, String itemId) async {
    await _wardrobe(uid).doc(itemId).delete();
  }

  static Future<String> saveOutfitLook({
    required String uid,
    required String occasion,
    required List<String> itemIds,
    required int matchScore,
    required String season,
  }) async {
    final ref = await _db
        .collection('users')
        .doc(uid)
        .collection('savedLooks')
        .add({
          'occasion': occasion,
          'itemIds': itemIds,
          'matchScore': matchScore,
          'season': season,
          'createdAt': FieldValue.serverTimestamp(),
        });
    return ref.id;
  }

  static Future<List<Map<String, dynamic>>> getSavedOutfitLooks(
    String uid,
  ) async {
    final snapshot = await _db
        .collection('users')
        .doc(uid)
        .collection('savedLooks')
        .orderBy('createdAt', descending: true)
        .get();
    return snapshot.docs
        .map((doc) => {'id': doc.id, ...doc.data()})
        .toList();
  }

  static Future<void> deleteSavedOutfitLook(
    String uid,
    String lookId,
  ) async {
    await _db
        .collection('users')
        .doc(uid)
        .collection('savedLooks')
        .doc(lookId)
        .delete();
  }

  static Future<CustomerDeletionResult> deleteCustomerData(String uid) async {
    final userRef = _db.collection('users').doc(uid);
    final consultationRef = _db.collection('consultations').doc(uid);

    // Read every customer-owned collection that is currently stored under
    // the user document, plus the top-level consultation document/messages.
    final userDoc = await userRef.get();
    final analysisSnapshot = await userRef.collection('analysis').get();
    final wardrobeSnapshot = await userRef.collection('wardrobe').get();
    final preferencesSnapshot = await userRef.collection('preferences').get();
    final savedLooksSnapshot = await userRef.collection('savedLooks').get();
    final consultationDoc = await consultationRef.get();
    final messagesSnapshot = await consultationRef.collection('messages').get();

    final imageUrls = <String>[];

    final profilePhotoUrl = userDoc.data()?['photoUrl'];
    if (profilePhotoUrl is String && profilePhotoUrl.isNotEmpty) {
      imageUrls.add(profilePhotoUrl);
    }

    for (final doc in wardrobeSnapshot.docs) {
      final url = doc.data()['imageUrl'];
      if (url is String && url.isNotEmpty) imageUrls.add(url);
    }

    for (final doc in analysisSnapshot.docs) {
      final url = doc.data()['imageUrl'];
      if (url is String && url.isNotEmpty) imageUrls.add(url);
    }

    final references = <DocumentReference<Map<String, dynamic>>>[
      ...wardrobeSnapshot.docs.map((doc) => doc.reference),
      ...preferencesSnapshot.docs.map((doc) => doc.reference),
      ...analysisSnapshot.docs.map((doc) => doc.reference),
      ...savedLooksSnapshot.docs.map((doc) => doc.reference),
      ...messagesSnapshot.docs.map((doc) => doc.reference),
      if (consultationDoc.exists) consultationRef,
      userRef,
    ];

    const chunkSize = 450;

    for (var start = 0; start < references.length; start += chunkSize) {
      final end = (start + chunkSize < references.length)
          ? start + chunkSize
          : references.length;
      final batch = _db.batch();
      for (final ref in references.sublist(start, end)) {
        batch.delete(ref);
      }
      await batch.commit();
    }

    return CustomerDeletionResult(
      wardrobeItemsDeleted: wardrobeSnapshot.docs.length,
      preferencesDeleted: preferencesSnapshot.docs.length,
      analysisRecordsDeleted: analysisSnapshot.docs.length,
      userDocDeleted: true,
      imageUrls: imageUrls,
    );
  }
}