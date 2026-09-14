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

  static Future<T> _withReadTimeout<T>(Future<T> future, String message) {
    return future.timeout(_readTimeout, onTimeout: () => throw TimeoutException(message));
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

    final resultEntries = await Future.wait<dynamic>([
      getUser(ownerUid),
      getLatestColourAnalysis(ownerUid),
      _withReadTimeout(
        _db.collection('users').doc(ownerUid).collection('preferences').doc('style').get(),
        'Loading your style preferences timed out.',
      ),
      getWardrobeItems(ownerUid),
      getSavedOutfitLooks(ownerUid),
    ], eagerError: false).then((results) {
      return results.map((result) => _ContextLoadResult(result)).toList(growable: false);
    });

    var degraded = false;
    String? errorMessage;

    T? unwrap<T>(int index, String message) {
      final entry = resultEntries[index];
      if (entry.error != null) {
        degraded = true;
        errorMessage ??= message;
        return null;
      }
      final value = entry.value;
      if (value is T) return value;
      degraded = true;
      errorMessage ??= message;
      return null;
    }

    final user = unwrap<UserModel?>(0, 'Some personal style data could not be loaded.');
    final colourAnalysis = unwrap<ColourAnalysisResult?>(1, 'Some colour analysis data could not be loaded.');
    final preferenceSnapshot = unwrap<DocumentSnapshot<Map<String, dynamic>>>(
      2,
      'Some style preferences could not be loaded.',
    );
    final wardrobe = unwrap<List<WardrobeItem>>(3, 'Some wardrobe data could not be loaded.') ?? const [];
    final savedLooks = unwrap<List<Map<String, dynamic>>>(4, 'Some saved looks could not be loaded.') ?? const [];

    final preferenceData = preferenceSnapshot?.data();
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

  static List<String> _stringList(dynamic value) {
    if (value is! Iterable) return const [];
    return value
        .whereType<String>()
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }
}

class _ContextLoadResult {
  final dynamic value;
  final Object? error;

  const _ContextLoadResult(this.value, [this.error]);
}
