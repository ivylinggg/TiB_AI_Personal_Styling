import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/analysis_model.dart';
import '../models/colour_analysis_result.dart';
import '../models/user_model.dart';
import '../models/wardrobe_item.dart';

class PersonalStyleContext {
  final UserModel? user;
  final ColourAnalysisResult? colourAnalysis;
  final List<String> styles;
  final List<String> preferences;
  final List<WardrobeItem> wardrobe;
  final List<Map<String, dynamic>> savedLooks;

  const PersonalStyleContext({
    required this.user,
    required this.colourAnalysis,
    required this.styles,
    required this.preferences,
    required this.wardrobe,
    required this.savedLooks,
  });

  String get styleDirection => styles.isEmpty ? '' : styles.take(3).join(' · ');
  bool get hasColourProfile => colourAnalysis != null;
  int get favouriteWardrobeCount => wardrobe.where((item) => item.isFavourite).length;
}

class CustomerDeletionResult {
  final int wardrobeItemsDeleted;
  final int preferencesDeleted;
  final int analysisRecordsDeleted;
  final int savedLooksDeleted;
  final int notificationRecordsDeleted;
  final int consultationMessagesDeleted;
  final bool consultationDeleted;
  final bool userDocDeleted;
  final List<String> imageUrls;

  const CustomerDeletionResult({
    required this.wardrobeItemsDeleted,
    required this.preferencesDeleted,
    required this.analysisRecordsDeleted,
    required this.savedLooksDeleted,
    required this.notificationRecordsDeleted,
    required this.consultationMessagesDeleted,
    required this.consultationDeleted,
    required this.userDocDeleted,
    required this.imageUrls,
  });
}

class FirestoreService {
  FirestoreService._();

  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static String? _normalizeUid(String uid) {
    final requested = uid.trim();
    final current = FirebaseAuth.instance.currentUser?.uid.trim();
    if (requested.isEmpty || current == null || current.isEmpty) return null;
    return requested == current ? current : null;
  }

  static Future<PersonalStyleContext> getPersonalStyleContext(String uid) async {
    final ownerUid = _normalizeUid(uid);
    if (ownerUid == null) {
      return const PersonalStyleContext(user: null, colourAnalysis: null, styles: [], preferences: [], wardrobe: [], savedLooks: []);
    }

    final userFuture = getUser(ownerUid);
    final analysisFuture = getLatestColourAnalysis(ownerUid);
    final preferencesFuture = _db.collection('users').doc(ownerUid).collection('preferences').doc('style').get();
    final wardrobeFuture = getWardrobeItems(ownerUid);
    final savedLooksFuture = getSavedOutfitLooks(ownerUid);

    try {
      final results = await Future.wait<dynamic>([userFuture, analysisFuture, preferencesFuture, wardrobeFuture, savedLooksFuture]);
      final preferenceData = (results[2] as DocumentSnapshot<Map<String, dynamic>>).data();
      return PersonalStyleContext(
        user: results[0] as UserModel?,
        colourAnalysis: results[1] as ColourAnalysisResult?,
        styles: _stringList(preferenceData?['styles']),
        preferences: _stringList(preferenceData?['preferences']),
        wardrobe: results[3] as List<WardrobeItem>,
        savedLooks: results[4] as List<Map<String, dynamic>>,
      );
    } catch (_) {
      return PersonalStyleContext(
        user: await userFuture.catchError((_) => null),
        colourAnalysis: await analysisFuture.catchError((_) => null),
        styles: const [],
        preferences: const [],
        wardrobe: const [],
        savedLooks: const [],
      );
    }
  }

  static Future<void> createUser(UserModel user) async {
    final currentUid = FirebaseAuth.instance.currentUser?.uid.trim();
    if (currentUid == null || currentUid != user.uid.trim()) {
      throw StateError('Cannot create a profile for a different account.');
    }
    await _db.collection('users').doc(currentUid).set(user.toMap()).timeout(
      const Duration(seconds: 15),
      onTimeout: () => throw TimeoutException('Creating your profile timed out. Please check your connection and try again.'),
    );
  }

  static Future<UserModel?> getUser(String uid) async {
    final ownerUid = _normalizeUid(uid);
    if (ownerUid == null) return null;
    final ref = _db.collection('users').doc(ownerUid);
    try {
      final doc = await ref.get();
      if (!doc.exists) return null;
      return UserModel.fromFirestore(doc);
    } on FirebaseException catch (error) {
      if (error.code != 'unavailable') rethrow;
      final cachedDoc = await ref.get(const GetOptions(source: Source.cache));
      if (!cachedDoc.exists) return null;
      return UserModel.fromFirestore(cachedDoc);
    }
  }

  static Future<void> updateUser(String uid, Map<String, dynamic> data) async {
    final ownerUid = _normalizeUid(uid);
    if (ownerUid == null) throw StateError('User session does not match the requested account.');
    await _db.collection('users').doc(ownerUid).update({...data, 'updatedAt': FieldValue.serverTimestamp()});
  }

  static Future<void> updateColourProfile({required String uid, required String colourSeason, required String skinTone}) async {
    await updateUser(uid, {'colourSeason': colourSeason, 'skinTone': skinTone});
  }

  static Future<void> saveAnalysis({required String uid, required AnalysisModel analysis}) async {
    final ownerUid = _normalizeUid(uid);
    if (ownerUid == null) throw StateError('User session does not match the requested account.');
    await _db.collection('users').doc(ownerUid).collection('analysis').add(analysis.toMap());
  }

  static Future<List<AnalysisModel>> getAnalysisHistory(String uid) async {
    final ownerUid = _normalizeUid(uid);
    if (ownerUid == null) return const [];
    final snapshot = await _db.collection('users').doc(ownerUid).collection('analysis').orderBy('createdAt', descending: true).get();
    return snapshot.docs.map(AnalysisModel.fromFirestore).toList();
  }

  static Future<void> saveAnalysisResult({required String uid, required ColourAnalysisResult result}) async {
    final ownerUid = _normalizeUid(uid);
    if (ownerUid == null) throw StateError('User session does not match the requested account.');
    await _db.collection('users').doc(ownerUid).collection('analysis').add({
      'season': result.season,
      'undertone': result.undertone,
      'brightness': result.brightness,
      'contrast': result.contrast,
      'imageUrl': result.imageUrl,
      'colours': result.colours,
      'faceShape': result.faceShape,
      'faceShapeDescription': result.faceShapeDescription,
      'faceMeasurements': result.faceMeasurements,
      'faceStylingGuidance': result.faceStylingGuidance,
      'colourReasons': result.colourReasons,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  static ColourAnalysisResult _resultFromData(Map<String, dynamic> data) {
    final colours = data['colours'];
    final measurements = data['faceMeasurements'];
    final guidance = data['faceStylingGuidance'];
    final reasons = data['colourReasons'];
    final rawMeasurements = <String, double>{};
    if (measurements is Map) {
      measurements.forEach((key, value) {
        if (value is num) rawMeasurements[key.toString()] = value.toDouble();
      });
    }
    return ColourAnalysisResult(
      season: data['season'] as String? ?? 'Unknown',
      undertone: data['undertone'] as String? ?? 'Unknown',
      brightness: data['brightness'] as String? ?? 'Unknown',
      contrast: data['contrast'] as String? ?? 'Unknown',
      imageUrl: data['imageUrl'] as String? ?? '',
      colours: _stringList(colours),
      faceShape: data['faceShape'] as String? ?? 'Unknown',
      faceShapeDescription: data['faceShapeDescription'] as String? ?? '',
      faceMeasurements: rawMeasurements,
      faceStylingGuidance: _stringList(guidance),
      colourReasons: _stringList(reasons),
    );
  }

  static Future<List<ColourAnalysisResult>> getColourAnalysisHistory(String uid) async {
    final ownerUid = _normalizeUid(uid);
    if (ownerUid == null) return const [];
    final snapshot = await _db.collection('users').doc(ownerUid).collection('analysis').orderBy('createdAt', descending: true).get();
    return snapshot.docs.map((doc) => _resultFromData(doc.data())).toList();
  }

  static Future<ColourAnalysisResult?> getLatestColourAnalysis(String uid) async {
    final ownerUid = _normalizeUid(uid);
    if (ownerUid == null) return null;
    final snapshot = await _db.collection('users').doc(ownerUid).collection('analysis').orderBy('createdAt', descending: true).limit(1).get();
    if (snapshot.docs.isEmpty) return null;
    return _resultFromData(snapshot.docs.first.data());
  }

  static CollectionReference<Map<String, dynamic>> _wardrobe(String uid) => _db.collection('users').doc(uid).collection('wardrobe');

  static Future<String> addWardrobeItem(WardrobeItem item) async {
    final ownerUid = _normalizeUid(item.userId);
    if (ownerUid == null) throw ArgumentError('A wardrobe item must belong to the signed-in user.');
    final ref = await _wardrobe(ownerUid).add(item.toMap());
    return ref.id;
  }

  static Future<List<WardrobeItem>> getWardrobeItems(String uid) async {
    final ownerUid = _normalizeUid(uid);
    if (ownerUid == null) return const [];
    final snapshot = await _wardrobe(ownerUid).orderBy('createdAt', descending: true).get();
    return snapshot.docs
        .map(WardrobeItem.fromFirestore)
        .where((item) => item.userId.isEmpty || item.userId == ownerUid)
        .toList();
  }

  static Stream<List<WardrobeItem>> watchWardrobeItems(String uid) {
    final ownerUid = _normalizeUid(uid);
    if (ownerUid == null) return const Stream<List<WardrobeItem>>.empty();
    return _wardrobe(ownerUid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map(WardrobeItem.fromFirestore)
            .where((item) => item.userId.isEmpty || item.userId == ownerUid)
            .toList());
  }

  static Future<void> updateWardrobeItem(String uid, String itemId, Map<String, dynamic> data) async {
    final ownerUid = _normalizeUid(uid);
    final cleanId = itemId.trim();
    if (ownerUid == null || cleanId.isEmpty) throw ArgumentError('Invalid wardrobe ownership or item ID.');
    final safeData = Map<String, dynamic>.from(data);
    safeData.remove('userId');
    safeData.remove('imageUrl');
    await _wardrobe(ownerUid).doc(cleanId).update(safeData);
  }

  static Future<void> deleteWardrobeItem(String uid, String itemId) async {
    final ownerUid = _normalizeUid(uid);
    final cleanId = itemId.trim();
    if (ownerUid == null || cleanId.isEmpty) throw ArgumentError('Invalid wardrobe ownership or item ID.');
    await _wardrobe(ownerUid).doc(cleanId).delete();
  }

  static Future<String> saveOutfitLook({required String uid, required String occasion, required List<String> itemIds, required int matchScore, required String season, String? title, String? notes}) async {
    final ownerUid = _normalizeUid(uid);
    if (ownerUid == null) throw StateError('User session does not match the requested account.');
    final sanitizedItemIds = itemIds.map((id) => id.trim()).where((id) => id.isNotEmpty).toSet().toList();
    if (sanitizedItemIds.isEmpty) throw ArgumentError('A saved look must contain at least one wardrobe item.');

    final wardrobeSnapshot = await _wardrobe(ownerUid).get();
    final ownedIds = wardrobeSnapshot.docs.map((doc) => doc.id).toSet();
    final safeItemIds = sanitizedItemIds.where(ownedIds.contains).toList();
    if (safeItemIds.isEmpty || safeItemIds.length != sanitizedItemIds.length) {
      throw StateError('A saved look can only contain items from the current user wardrobe.');
    }

    final payload = <String, dynamic>{
      'uid': ownerUid,
      'occasion': occasion.trim().isEmpty ? 'Everyday' : occasion.trim(),
      'itemIds': safeItemIds,
      'matchScore': matchScore.clamp(0, 100),
      'season': season.trim().isEmpty ? 'Unknown' : season.trim(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      if (title != null && title.trim().isNotEmpty) 'title': title.trim(),
      if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
    };
    return (await _db.collection('users').doc(ownerUid).collection('savedLooks').add(payload)).id;
  }

  static Future<List<Map<String, dynamic>>> getSavedOutfitLooks(String uid) async {
    final ownerUid = _normalizeUid(uid);
    if (ownerUid == null) return const [];
    final snapshot = await _db.collection('users').doc(ownerUid).collection('savedLooks').orderBy('createdAt', descending: true).get();
    return snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
  }

  static Future<void> deleteSavedOutfitLook(String uid, String lookId) async {
    final ownerUid = _normalizeUid(uid);
    final cleanId = lookId.trim();
    if (ownerUid == null || cleanId.isEmpty) throw ArgumentError('Invalid saved look ownership or ID.');
    await _db.collection('users').doc(ownerUid).collection('savedLooks').doc(cleanId).delete();
  }

  static Future<CustomerDeletionResult> deleteCustomerData(String uid) async {
    final ownerUid = _normalizeUid(uid);
    if (ownerUid == null) throw StateError('User session does not match the requested account.');

    final userRef = _db.collection('users').doc(ownerUid);
    final consultationRef = _db.collection('consultations').doc(ownerUid);
    final userDoc = await userRef.get();
    final analysisSnapshot = await userRef.collection('analysis').get();
    final wardrobeSnapshot = await userRef.collection('wardrobe').get();
    final preferencesSnapshot = await userRef.collection('preferences').get();
    final savedLooksSnapshot = await userRef.collection('savedLooks').get();
    final notificationsSnapshot = await userRef.collection('notifications').get();
    final consultationDoc = await consultationRef.get();
    final messagesSnapshot = await consultationRef.collection('messages').get();

    final imageUrls = <String>[];
    final profilePhotoUrl = userDoc.data()?['photoUrl'];
    if (profilePhotoUrl is String && profilePhotoUrl.isNotEmpty) imageUrls.add(profilePhotoUrl);
    for (final doc in wardrobeSnapshot.docs) {
      final url = doc.data()['imageUrl'];
      if (url is String && url.isNotEmpty) imageUrls.add(url);
    }
    for (final doc in analysisSnapshot.docs) {
      final url = doc.data()['imageUrl'];
      if (url is String && url.isNotEmpty) imageUrls.add(url);
    }

    final refs = <DocumentReference<Map<String, dynamic>>>[
      ...wardrobeSnapshot.docs.map((doc) => doc.reference),
      ...preferencesSnapshot.docs.map((doc) => doc.reference),
      ...analysisSnapshot.docs.map((doc) => doc.reference),
      ...savedLooksSnapshot.docs.map((doc) => doc.reference),
      ...notificationsSnapshot.docs.map((doc) => doc.reference),
      ...messagesSnapshot.docs.map((doc) => doc.reference),
      if (consultationDoc.exists) consultationRef,
      userRef,
    ];
    const chunkSize = 450;
    for (var start = 0; start < refs.length; start += chunkSize) {
      final end = (start + chunkSize < refs.length) ? start + chunkSize : refs.length;
      final batch = _db.batch();
      for (final ref in refs.sublist(start, end)) {
        batch.delete(ref);
      }
      await batch.commit();
    }

    return CustomerDeletionResult(
      wardrobeItemsDeleted: wardrobeSnapshot.docs.length,
      preferencesDeleted: preferencesSnapshot.docs.length,
      analysisRecordsDeleted: analysisSnapshot.docs.length,
      savedLooksDeleted: savedLooksSnapshot.docs.length,
      notificationRecordsDeleted: notificationsSnapshot.docs.length,
      consultationMessagesDeleted: messagesSnapshot.docs.length,
      consultationDeleted: consultationDoc.exists,
      userDocDeleted: true,
      imageUrls: imageUrls,
    );
  }

  static List<String> _stringList(dynamic value) {
    if (value is! List) return const [];
    return value
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }
}
