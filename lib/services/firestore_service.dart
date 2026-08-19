import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/analysis_model.dart';
import '../models/colour_analysis_result.dart';
import '../models/user_model.dart';
import '../models/wardrobe_item.dart';

/// Summary of what an admin-initiated [FirestoreService.deleteCustomerData]
/// call actually removed, so the caller can report an accurate outcome
/// instead of a generic "deleted" message.
class CustomerDeletionResult {
  final int wardrobeItemsDeleted;
  final int preferencesDeleted;
  final int analysisRecordsDeleted;
  final bool userDocDeleted;

  /// Every Google Drive image URL (profile photo, wardrobe items,
  /// analysis photos) that belonged to this customer, collected before
  /// their Firestore documents were deleted. The caller is responsible
  /// for cleaning these up on Google Drive.
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
    await _db.collection('users').doc(user.uid).set(user.toMap());
  }

  static Future<UserModel?> getUser(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    return UserModel.fromFirestore(doc);
  }

  static Future<void> updateUser(String uid, Map<String, dynamic> data) async {
    await _db.collection('users').doc(uid).update({
      ...data,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Syncs the existing UserModel.colourSeason / UserModel.skinTone fields
  /// on the user's profile document after a colour analysis is saved, so
  /// Profile and the admin screens can display them without needing to
  /// read the analysis subcollection themselves.
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

  /// Admin-only: permanently deletes everything this app knows this
  /// customer owns in Firestore — their `wardrobe`, `preferences`, and
  /// `analysis` subcollections, then their `users/{uid}` profile document
  /// itself — and returns the image URLs found along the way so the
  /// caller can clean those up on Google Drive.
  ///
  /// This only ever touches documents that live under `users/{uid}`, so
  /// it cannot affect any other user's data, admin accounts, Learning
  /// content, or any other collection in the database. Deletes are
  /// batched (chunked below Firestore's 500-operation batch limit) so a
  /// customer with a large wardrobe or analysis history is still deleted
  /// atomically per chunk.
  ///
  /// Firestore security rules already grant an admin `delete` on the
  /// `wardrobe`, `preferences`, and `analysis` subcollections and on the
  /// `users/{userId}` document itself, so no rules changes are required
  /// for this to work.
  static Future<CustomerDeletionResult> deleteCustomerData(String uid) async {
    final userRef = _db.collection('users').doc(uid);

    final userDoc = await userRef.get();
    final analysisSnapshot = await userRef.collection('analysis').get();
    final wardrobeSnapshot = await userRef.collection('wardrobe').get();
    final preferencesSnapshot = await userRef.collection('preferences').get();

    final imageUrls = <String>[];

    final profilePhotoUrl = userDoc.data()?['photoUrl'];
    if (profilePhotoUrl is String && profilePhotoUrl.isNotEmpty) {
      imageUrls.add(profilePhotoUrl);
    }

    for (final doc in wardrobeSnapshot.docs) {
      final url = doc.data()['imageUrl'];
      if (url is String && url.isNotEmpty) {
        imageUrls.add(url);
      }
    }

    for (final doc in analysisSnapshot.docs) {
      final url = doc.data()['imageUrl'];
      if (url is String && url.isNotEmpty) {
        imageUrls.add(url);
      }
    }

    final references = <DocumentReference<Map<String, dynamic>>>[
      ...wardrobeSnapshot.docs.map((doc) => doc.reference),
      ...preferencesSnapshot.docs.map((doc) => doc.reference),
      ...analysisSnapshot.docs.map((doc) => doc.reference),
      userRef,
    ];

    // Firestore batches are capped at 500 operations; chunk defensively
    // below that so a customer with a very large wardrobe/history is
    // still handled safely.
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
