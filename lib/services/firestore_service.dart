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
  final DateTime loadedAt;
  final bool isDegraded;
  final String? errorMessage;

  const PersonalStyleContext({
    required this.user,
    required this.colourAnalysis,
    required this.styles,
    required this.preferences,
    required this.wardrobe,
    required this.savedLooks,
    this.loadedAt = const _UninitializedDateTime(),
    this.isDegraded = false,
    this.errorMessage,
  });

  String get styleDirection => styles.isEmpty ? '' : styles.take(3).join(' · ');
  bool get hasColourProfile => colourAnalysis != null;
  bool get hasWardrobe => wardrobe.isNotEmpty;
  bool get hasSavedLooks => savedLooks.isNotEmpty;
  int get favouriteWardrobeCount => wardrobe.where((item) => item.isFavourite).length;
}

class _UninitializedDateTime implements DateTime {
  const _UninitializedDateTime();
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
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

  static const Duration _writeTimeout = Duration(seconds: 15);
  static const Duration _readTimeout = Duration(seconds: 15);

  static String? _normalizeUid(String uid) {
    final requested = uid.trim();
    final current = FirebaseAuth.instance.currentUser?.uid.trim();
    if (requested.isEmpty || current == null || current.isEmpty) return null;
    return requested == current ? current : null;
  }

  static Future<T> _withWriteTimeout<T>(Future<T> future, String message) {
    return future.timeout(
      _writeTimeout,
      onTimeout: () => throw TimeoutException(message),
    );
  }

  static Future<T> _withReadTimeout<T>(Future<T> future, String message) {
    return future.timeout(
      _readTimeout,
      onTimeout: () => throw TimeoutException(message),
    );
  }

  static Future<PersonalStyleContext> getPersonalStyleContext(String uid) async {
    final ownerUid = _normalizeUid(uid);
    if (ownerUid == null) {
      return const PersonalStyleContext(
        user: null,
        colourAnalysis: null,
        styles: [],
        preferences: [],
        wardrobe: [],
        savedLooks: [],
        isDegraded: true,
        errorMessage: 'Your session is no longer active.',
      );
    }

    final results = await Future.wait<dynamic>([
      getUser(ownerUid),
      getLatestColourAnalysis(ownerUid),
      _withReadTimeout(
        _db.collection('users').doc(ownerUid).collection('preferences').doc('style').get(),
        'Loading your style preferences timed out.',
      ),
      getWardrobeItems(ownerUid),
      getSavedOutfitLooks(ownerUid),
    ], eagerError: false);

    var degraded = false;
    String? errorMessage;

    Map<String, dynamic>? preferenceData;
    if (results[2] is DocumentSnapshot<Map<String, dynamic>>) {
      preferenceData = (results[2] as DocumentSnapshot<Map<String, dynamic>>).data();
    } else {
      degraded = true;
      errorMessage = 'Some style preferences could not be loaded.';
    }

    final user = results[0] is UserModel ? results[0] as UserModel? : null;
    final colourAnalysis = results[1] is ColourAnalysisResult ? results[1] as ColourAnalysisResult? : null;
    final wardrobe = results[3] is List<WardrobeItem> ? results[3] as List<WardrobeItem> : const <WardrobeItem>[];
    final savedLooks = results[4] is List<Map<String, dynamic>> ? results[4] as List<Map<String, dynamic>> : const <Map<String, dynamic>>[];

    return PersonalStyleContext(
      user: user,
      colourAnalysis: colourAnalysis,
      styles: _stringList(preferenceData?['styles']),
      preferences: _stringList(preferenceData?['preferences']),
      wardrobe: List<WardrobeItem>.unmodifiable(wardrobe),
      savedLooks: List<Map<String, dynamic>>.unmodifiable(savedLooks),
      isDegraded: degraded,
      errorMessage: errorMessage,
    );
  }

  static Future<void> createUser(UserModel user) async {
    final currentUid = FirebaseAuth.instance.currentUser?.uid.trim();
    if (currentUid == null || currentUid != user.uid.trim()) {
      throw StateError('Cannot create a profile for a different account.');
    }
    await _withWriteTimeout(
      _db.collection('users').doc(currentUid).set(user.toMap()),
      'Creating your profile timed out. Please check your connection and try again.',
    );
  }

  static Future<UserModel?> getUser(String uid) async {
    final ownerUid = _normalizeUid(uid);
    if (ownerUid == null) return null;
    final ref = _db.collection('users').doc(ownerUid);
    try {
      final doc = await _withReadTimeout(ref.get(), 'Loading your profile timed out.');
      if (!doc.exists) return null;
      return UserModel.fromFirestore(doc);
    } on FirebaseException catch (error) {
      if (error.code != 'unavailable') rethrow;
      final cachedDoc = await _withReadTimeout(
        ref.get(const GetOptions(source: Source.cache)),
        'Loading cached profile data timed out.',
      );
      if (!cachedDoc.exists) return null;
      return UserModel.fromFirestore(cachedDoc);
    }
  }

  static Future<void> updateUser(String uid, Map<String, dynamic> data) async {
    final ownerUid = _normalizeUid(uid);
    if (ownerUid == null) throw StateError('User session does not match the requested account.');
    await _withWriteTimeout(
      _db.collection('users').doc(ownerUid).update({
        ...data,
        'updatedAt': FieldValue.serverTimestamp(),
      }),
      'Updating your profile timed out. Please try again.',
    );
  }

  static Future<void> updateColourProfile({
    required String uid,
    required String colourSeason,
    required String skinTone,
  }) async {
    await updateUser(uid, {
      'colourSeason': colourSeason.trim(),
      'skinTone': skinTone.trim(),
    });
  }

  static Future<void> saveAnalysis({required String uid, required AnalysisModel analysis}) async {
    final ownerUid = _normalizeUid(uid);
    if (ownerUid == null) throw StateError('User session does not match the requested account.');
    await _withWriteTimeout(
      _db.collection('users').doc(ownerUid).collection('analysis').add(analysis.toMap()),
      'Saving your analysis timed out. Please try again.',
    );
  }

  static Future<List<AnalysisModel>> getAnalysisHistory(String uid) async {
    final ownerUid = _normalizeUid(uid);
    if (ownerUid == null) return const [];
    final snapshot = await _withReadTimeout(
      _db.collection('users').doc(ownerUid).collection('analysis').orderBy('createdAt', descending: true).get(),
      'Loading analysis history timed out.',
    );
    return snapshot.docs.map(AnalysisModel.fromFirestore).toList(growable: false);
  }

  static Future<void> saveAnalysisResult({required String uid, required ColourAnalysisResult result}) async {
    final ownerUid = _normalizeUid(uid);
    if (ownerUid == null) throw StateError('User session does not match the requested account.');
    await _withWriteTimeout(
      _db.collection('users').doc(ownerUid).collection('analysis').add({
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
      }),
      'Saving your colour analysis timed out. Please try again.',
    );
  }

  static ColourAnalysisResult _resultFromData(Map<String, dynamic> data) {
    final rawMeasurements = <String, double>{};
    final measurements = data['faceMeasurements'];
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
      colours: _stringList(data['colours']),
      faceShape: data['faceShape'] as String? ?? 'Unknown',
      faceShapeDescription: data['faceShapeDescription'] as String? ?? '',
      faceMeasurements: rawMeasurements,
      faceStylingGuidance: _stringList(data['faceStylingGuidance']),
      colourReasons: _stringList(data['colourReasons']),
    );
  }

  static Future<List<ColourAnalysisResult>> getColourAnalysisHistory(String uid) async {
    final ownerUid = _normalizeUid(uid);
    if (ownerUid == null) return const [];
    final snapshot = await _withReadTimeout(
      _db.collection('users').doc(ownerUid).collection('analysis').orderBy('createdAt', descending: true).get(),
      'Loading colour analysis history timed out.',
    );
    return snapshot.docs.map((doc) => _resultFromData(doc.data())).toList(growable: false);
  }

  static Future<ColourAnalysisResult?> getLatestColourAnalysis(String uid) async {
    final ownerUid = _normalizeUid(uid);
    if (ownerUid == null) return null;
    final snapshot = await _withReadTimeout(
      _db.collection('users').doc(ownerUid).collection('analysis').orderBy('createdAt', descending: true).limit(1).get(),
      'Loading your latest colour analysis timed out.',
    );
    if (snapshot.docs.isEmpty) return null;
    return _resultFromData(snapshot.docs.first.data());
  }

  static CollectionReference<Map<String, dynamic>> _wardrobe(String uid) => _db.collection('users').doc(uid).collection('wardrobe');

  static Future<String> addWardrobeItem(WardrobeItem item) async {
    final ownerUid = _normalizeUid(item.userId);
    if (ownerUid == null) throw ArgumentError('A wardrobe item must belong to the signed-in user.');
    final ref = await _withWriteTimeout(
      _wardrobe(ownerUid).add(item.toMap()),
      'Adding this wardrobe item timed out. Please try again.',
    );
    return ref.id;
  }

  static Future<List<WardrobeItem>> getWardrobeItems(String uid) async {
    final ownerUid = _normalizeUid(uid);
    if (ownerUid == null) return const [];
    try {
      final snapshot = await _withReadTimeout(
        _wardrobe(ownerUid).orderBy('createdAt', descending: true).get(),
        'Loading your wardrobe timed out.',
      );
      return snapshot.docs
          .map(WardrobeItem.fromFirestore)
          .where((item) => item.userId.isEmpty || item.userId == ownerUid)
          .toList(growable: false);
    } on FirebaseException catch (error) {
      if (error.code != 'unavailable') rethrow;
      final snapshot = await _withReadTimeout(
        _wardrobe(ownerUid).orderBy('createdAt', descending: true).get(const GetOptions(source: Source.cache)),
        'Loading cached wardrobe data timed out.',
      );
      return snapshot.docs
          .map(WardrobeItem.fromFirestore)
          .where((item) => item.userId.isEmpty || item.userId == ownerUid)
          .toList(growable: false);
    }
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
            .toList(growable: false));
  }

  static Future<void> updateWardrobeItem(String uid, String itemId, Map<String, dynamic> data) async {
    final ownerUid = _normalizeUid(uid);
    final cleanId = itemId.trim();
    if (ownerUid == null || cleanId.isEmpty) throw ArgumentError('Invalid wardrobe ownership or item ID.');
    final safeData = Map<String, dynamic>.from(data)
      ..remove('userId')
      ..remove('imageUrl');
    await _withWriteTimeout(
      _wardrobe(ownerUid).doc(cleanId).update(safeData),
      'Updating this wardrobe item timed out. Please try again.',
    );
  }

  static Future<void> deleteWardrobeItem(String uid, String itemId) async {
    final ownerUid = _normalizeUid(uid);
    final cleanId = itemId.trim();
    if (ownerUid == null || cleanId.isEmpty) throw ArgumentError('Invalid wardrobe ownership or item ID.');
    await _withWriteTimeout(
      _wardrobe(ownerUid).doc(cleanId).delete(),
      'Deleting this wardrobe item timed out. Please try again.',
    );
  }

  static Future<String> saveOutfitLook({
    required String uid,
    required String occasion,
    required List<String> itemIds,
    required int matchScore,
    required String season,
    String? title,
    String? notes,
  }) async {
    final ownerUid = _normalizeUid(uid);
    if (ownerUid == null) throw StateError('User session does not match the requested account.');

    final sanitizedItemIds = itemIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList(growable: false);
    if (sanitizedItemIds.isEmpty) {
      throw ArgumentError('A saved look must contain at least one wardrobe item.');
    }

    final wardrobeSnapshot = await _withReadTimeout(
      _wardrobe(ownerUid).get(),
      'Checking your wardrobe items timed out. Please try again.',
    );
    final ownedIds = wardrobeSnapshot.docs.map((doc) => doc.id).toSet();
    if (sanitizedItemIds.any((id) => !ownedIds.contains(id))) {
      throw StateError('A saved look can only contain items from the current user wardrobe.');
    }

    final payload = <String, dynamic>{
      'uid': ownerUid,
      'occasion': occasion.trim().isEmpty ? 'Everyday' : occasion.trim(),
      'itemIds': sanitizedItemIds,
      'matchScore': matchScore.clamp(0, 100),
      'season': season.trim().isEmpty ? 'Unknown' : season.trim(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      if (title != null && title.trim().isNotEmpty) 'title': title.trim(),
      if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
    };
    return (await _withWriteTimeout(
      _db.collection('users').doc(ownerUid).collection('savedLooks').add(payload),
      'Saving your look timed out. Please try again.',
    )).id;
  }

  static Future<List<Map<String, dynamic>>> getSavedOutfitLooks(String uid) async {
    final ownerUid = _normalizeUid(uid);
    if (ownerUid == null) return const [];
    final snapshot = await _withReadTimeout(
      _db.collection('users').doc(ownerUid).collection('savedLooks').orderBy('createdAt', descending: true).get(),
      'Loading your saved looks timed out.',
    );
    return snapshot.docs
        .map((doc) => {'id': doc.id, ...doc.data()})
        .toList(growable: false);
  }

  static Future<void> deleteSavedOutfitLook(String uid, String lookId) async {
    final ownerUid = _normalizeUid(uid);
    final cleanId = lookId.trim();
    if (ownerUid == null || cleanId.isEmpty) throw ArgumentError('Invalid saved look ownership or ID.');
    await _withWriteTimeout(
      _db.collection('users').doc(ownerUid).collection('savedLooks').doc(cleanId).delete(),
      'Deleting your saved look timed out. Please try again.',
    );
  }

  static Future<CustomerDeletionResult> deleteCustomerData(String uid) async {
    final ownerUid = _normalizeUid(uid);
    if (ownerUid == null) throw StateError('User session does not match the requested account.');

    final userRef = _db.collection('users').doc(ownerUid);
    final consultationRef = _db.collection('consultations').doc(ownerUid);
    final userDoc = await _withReadTimeout(userRef.get(), 'Loading account data for deletion timed out.');
    final analysisSnapshot = await _withReadTimeout(userRef.collection('analysis').get(), 'Loading analysis records for deletion timed out.');
    final wardrobeSnapshot = await _withReadTimeout(userRef.collection('wardrobe').get(), 'Loading wardrobe records for deletion timed out.');
    final preferencesSnapshot = await _withReadTimeout(userRef.collection('preferences').get(), 'Loading preference records for deletion timed out.');
    final savedLooksSnapshot = await _withReadTimeout(userRef.collection('savedLooks').get(), 'Loading saved looks for deletion timed out.');
    final notificationsSnapshot = await _withReadTimeout(userRef.collection('notifications').get(), 'Loading notifications for deletion timed out.');
    final consultationDoc = await _withReadTimeout(consultationRef.get(), 'Loading consultation for deletion timed out.');
    final messagesSnapshot = await _withReadTimeout(consultationRef.collection('messages').get(), 'Loading consultation messages for deletion timed out.');

    final imageUrls = <String>[];
    final profilePhotoUrl = userDoc.data()?['photoUrl'];
    if (profilePhotoUrl is String && profilePhotoUrl.trim().isNotEmpty) {
      imageUrls.add(profilePhotoUrl.trim());
    }
    for (final doc in wardrobeSnapshot.docs) {
      final imageUrl = doc.data()['imageUrl'];
      if (imageUrl is String && imageUrl.trim().isNotEmpty) imageUrls.add(imageUrl.trim());
    }
    for (final doc in analysisSnapshot.docs) {
      final imageUrl = doc.data()['imageUrl'];
      if (imageUrl is String && imageUrl.trim().isNotEmpty) imageUrls.add(imageUrl.trim());
    }

    var batch = _db.batch();
    var operations = 0;
    var wardrobeItemsDeleted = 0;
    var preferencesDeleted = 0;
    var analysisRecordsDeleted = 0;
    var savedLooksDeleted = 0;
    var notificationRecordsDeleted = 0;
    var consultationMessagesDeleted = 0;

    Future<void> commitIfNeeded() async {
      if (operations == 0) return;
      final currentBatch = batch;
      batch = _db.batch();
      operations = 0;
      await _withWriteTimeout(currentBatch.commit(), 'Deleting your account data timed out. Please try again.');
    }

    void queueDelete(DocumentReference<Map<String, dynamic>> ref) {
      batch.delete(ref);
      operations++;
    }

    for (final doc in analysisSnapshot.docs) {
      queueDelete(doc.reference);
      analysisRecordsDeleted++;
      if (operations >= 400) await commitIfNeeded();
    }
    for (final doc in wardrobeSnapshot.docs) {
      queueDelete(doc.reference);
      wardrobeItemsDeleted++;
      if (operations >= 400) await commitIfNeeded();
    }
    for (final doc in preferencesSnapshot.docs) {
      queueDelete(doc.reference);
      preferencesDeleted++;
      if (operations >= 400) await commitIfNeeded();
    }
    for (final doc in savedLooksSnapshot.docs) {
      queueDelete(doc.reference);
      savedLooksDeleted++;
      if (operations >= 400) await commitIfNeeded();
    }
    for (final doc in notificationsSnapshot.docs) {
      queueDelete(doc.reference);
      notificationRecordsDeleted++;
      if (operations >= 400) await commitIfNeeded();
    }
    for (final doc in messagesSnapshot.docs) {
      queueDelete(doc.reference);
      consultationMessagesDeleted++;
      if (operations >= 400) await commitIfNeeded();
    }

    if (consultationDoc.exists) {
      queueDelete(consultationRef);
    }
    queueDelete(userRef);
    await commitIfNeeded();

    return CustomerDeletionResult(
      wardrobeItemsDeleted: wardrobeItemsDeleted,
      preferencesDeleted: preferencesDeleted,
      analysisRecordsDeleted: analysisRecordsDeleted,
      savedLooksDeleted: savedLooksDeleted,
      notificationRecordsDeleted: notificationRecordsDeleted,
      consultationMessagesDeleted: consultationMessagesDeleted,
      consultationDeleted: consultationDoc.exists,
      userDocDeleted: true,
      imageUrls: List<String>.unmodifiable(imageUrls.toSet()),
    );
  }

  static List<String> _stringList(dynamic value) {
    if (value is! Iterable) return const [];
    return value
        .whereType<String>()
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }
}
