import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/colour_analysis_result.dart';
import '../models/user_model.dart';
import '../models/wardrobe_item.dart';

class AdminPreviewData {
  final UserModel? user;
  final ColourAnalysisResult? colourAnalysis;
  final List<String> styles;
  final List<String> preferences;
  final List<WardrobeItem> wardrobe;
  final List<Map<String, dynamic>> savedLooks;

  const AdminPreviewData({
    required this.user,
    required this.colourAnalysis,
    required this.styles,
    required this.preferences,
    required this.wardrobe,
    required this.savedLooks,
  });
}

class AdminPreviewService {
  AdminPreviewService._();

  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static const _maxUidLength = 128;
  static const _maxSavedLooks = 200;

  static Future<AdminPreviewData> loadCustomerProfile(String uid) async {
    final customerUid = _normalizeId(uid);
    if (customerUid == null) {
      throw StateError('No customer was selected for preview.');
    }

    final userRef = _db.collection('users').doc(customerUid);
    final results = await Future.wait<dynamic>([
      userRef.get(),
      userRef.collection('analysis').orderBy('createdAt', descending: true).limit(1).get(),
      userRef.collection('preferences').doc('style').get(),
      userRef.collection('wardrobe').get(),
      userRef.collection('savedLooks').limit(_maxSavedLooks).get(),
    ], eagerError: false);

    final userSnapshot = results[0];
    if (userSnapshot is! DocumentSnapshot<Map<String, dynamic>> || !userSnapshot.exists) {
      throw StateError('The selected customer profile does not exist.');
    }

    final data = userSnapshot.data() ?? <String, dynamic>{};
    final user = UserModel.fromFirestore(userSnapshot);

    final analysisSnapshot = results[1];
    final colourAnalysis = analysisSnapshot is QuerySnapshot<Map<String, dynamic>> && analysisSnapshot.docs.isNotEmpty
        ? _resultFromData(analysisSnapshot.docs.first.data())
        : null;

    final preferenceSnapshot = results[2];
    final preferenceData = preferenceSnapshot is DocumentSnapshot<Map<String, dynamic>>
        ? preferenceSnapshot.data()
        : null;

    final wardrobeSnapshot = results[3];
    final wardrobe = wardrobeSnapshot is QuerySnapshot<Map<String, dynamic>>
        ? wardrobeSnapshot.docs
            .map((doc) {
              try {
                return WardrobeItem.fromFirestore(doc);
              } catch (_) {
                return null;
              }
            })
            .whereType<WardrobeItem>()
            .where((item) => item.userId.isEmpty || item.userId == customerUid)
            .toList(growable: false)
        : const <WardrobeItem>[];

    final savedLooksSnapshot = results[4];
    final savedLooks = savedLooksSnapshot is QuerySnapshot<Map<String, dynamic>>
        ? savedLooksSnapshot.docs
            .map((doc) => <String, dynamic>{'id': doc.id, ...doc.data()})
            .toList(growable: false)
        : const <Map<String, dynamic>>[];

    return AdminPreviewData(
      user: user,
      colourAnalysis: colourAnalysis,
      styles: _stringList(preferenceData?['styles'] ?? data['styles']),
      preferences: _stringList(preferenceData?['preferences'] ?? data['preferences']),
      wardrobe: wardrobe,
      savedLooks: savedLooks,
    );
  }

  static ColourAnalysisResult _resultFromData(Map<String, dynamic> data) {
    final measurements = <String, double>{};

    final rawMeasurements = data['faceMeasurements'];
    if (rawMeasurements is Map) {
      rawMeasurements.forEach((key, value) {
        if (value is num && value.isFinite) {
          measurements[key.toString()] = value.toDouble();
        }
      });
    }

    return ColourAnalysisResult(
      season: _stringValue(data['season'], fallback: 'Unknown'),
      undertone: _stringValue(data['undertone'], fallback: 'Unknown'),
      brightness: _stringValue(data['brightness'], fallback: 'Unknown'),
      contrast: _stringValue(data['contrast'], fallback: 'Unknown'),
      imageUrl: _stringValue(data['imageUrl']),
      colours: _stringList(data['colours']),
      faceShape: _stringValue(data['faceShape'], fallback: 'Unknown'),
      faceShapeDescription: _stringValue(data['faceShapeDescription']),
      faceMeasurements: measurements,
      faceStylingGuidance: _stringList(data['faceStylingGuidance']),
      colourReasons: _stringList(data['colourReasons']),
    );
  }

  static String _stringValue(dynamic value, {String fallback = ''}) {
    if (value is! String) return fallback;
    final trimmed = value.trim();
    return trimmed.isEmpty ? fallback : trimmed;
  }

  static String? _normalizeId(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty || trimmed.length > _maxUidLength) return null;
    return trimmed;
  }

  static List<String> _stringList(dynamic value) {
    if (value is! Iterable) return const <String>[];

    final result = <String>[];
    for (final item in value) {
      if (item is! String) continue;
      final trimmed = item.trim();
      if (trimmed.isNotEmpty) result.add(trimmed);
    }
    return result.toList(growable: false);
  }
}
