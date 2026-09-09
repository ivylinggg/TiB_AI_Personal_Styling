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

  static Future<AdminPreviewData> loadCustomerProfile(String uid) async {
    final customerUid = uid.trim();
    if (customerUid.isEmpty) {
      throw StateError('No customer was selected for preview.');
    }

    final results = await Future.wait<dynamic>([
      _db.collection('users').doc(customerUid).get(),
      _db.collection('users').doc(customerUid).collection('analysis').orderBy('createdAt', descending: true).limit(1).get(),
      _db.collection('users').doc(customerUid).collection('preferences').doc('style').get(),
      _db.collection('users').doc(customerUid).collection('wardrobe').get(),
      _db.collection('users').doc(customerUid).collection('savedLooks').get(),
    ], eagerError: false);

    final userSnapshot = results[0] as DocumentSnapshot<Map<String, dynamic>>;
    if (!userSnapshot.exists) {
      throw StateError('The selected customer profile does not exist.');
    }

    final data = userSnapshot.data() ?? <String, dynamic>{};
    final user = UserModel.fromFirestore(userSnapshot);

    final analysisSnapshot = results[1] as QuerySnapshot<Map<String, dynamic>>;
    final colourAnalysis = analysisSnapshot.docs.isEmpty
        ? null
        : _resultFromData(analysisSnapshot.docs.first.data());

    final preferenceSnapshot = results[2] as DocumentSnapshot<Map<String, dynamic>>;
    final preferenceData = preferenceSnapshot.data();

    final wardrobeSnapshot = results[3] as QuerySnapshot<Map<String, dynamic>>;
    final wardrobe = wardrobeSnapshot.docs
        .map(WardrobeItem.fromFirestore)
        .where((item) => item.userId.isEmpty || item.userId == customerUid)
        .toList(growable: false);

    final savedLooksSnapshot = results[4] as QuerySnapshot<Map<String, dynamic>>;
    final savedLooks = savedLooksSnapshot.docs
        .map((doc) => <String, dynamic>{'id': doc.id, ...doc.data()})
        .toList(growable: false);

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
    final raw = data['faceMeasurements'];
    if (raw is Map) {
      raw.forEach((key, value) {
        if (value is num) measurements[key.toString()] = value.toDouble();
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
      faceMeasurements: measurements,
      faceStylingGuidance: _stringList(data['faceStylingGuidance']),
      colourReasons: _stringList(data['colourReasons']),
    );
  }

  static List<String> _stringList(dynamic value) {
    if (value is Iterable) {
      return value
          .whereType<dynamic>()
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList(growable: false);
    }
    return const <String>[];
  }
}
