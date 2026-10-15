import 'package:cloud_firestore/cloud_firestore.dart';

class ContentService {
  ContentService._();

  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static const _maxTypeLength = 80;
  static const _maxTitleLength = 180;
  static const _maxDescriptionLength = 500;
  static const _maxBodyLength = 5000;
  static const _maxSeedItems = 50;

  static String _clean(String value) => value.trim();

  static bool _isValidId(String value) =>
      _clean(value).isNotEmpty && _clean(value).length <= 120;

  static bool _isValidText(String value, int maxLength) {
    final cleaned = _clean(value);
    return cleaned.isNotEmpty && cleaned.length <= maxLength;
  }

  static Stream<QuerySnapshot<Map<String, dynamic>>> publishedContentStream() {
    return _db
        .collection('content')
        .where('isPublished', isEqualTo: true)
        .snapshots();
  }

  static Stream<QuerySnapshot<Map<String, dynamic>>> publishedContentByTypeStream(
    String type,
  ) {
    final cleanedType = _clean(type);
    if (cleanedType.isEmpty || cleanedType.length > _maxTypeLength) {
      return const Stream.empty();
    }

    return _db
        .collection('content')
        .where('isPublished', isEqualTo: true)
        .where('type', isEqualTo: cleanedType)
        .snapshots();
  }

  static Future<void> seedDefaultContent({required bool isAdmin}) async {
    if (!isAdmin) return;

    final snapshot = await _db.collection('content').limit(1).get();
    if (snapshot.docs.isNotEmpty) return;

    const seed = <Map<String, dynamic>>[
      {
        'title': 'Understanding Your Colour Season',
        'description':
            'A simple guide to using your personal colour season when choosing clothes.',
        'body':
            'Start with your recommended colour season, then build outfits around colours that support your natural colouring. Use your analysis results as a guide, not a strict rule.',
        'type': 'Colour Guide',
        'isPublished': true,
        'isFeatured': true,
        'isPremium': false,
      },
      {
        'title': 'Build a Better Everyday Wardrobe',
        'description':
            'Simple wardrobe principles for creating more outfits with fewer pieces.',
        'body':
            'Begin with versatile essentials, then add statement pieces that reflect your personality. Keep your wardrobe organised by category and season so styling becomes easier.',
        'type': 'Learning',
        'isPublished': true,
        'isFeatured': true,
        'isPremium': false,
      },
      {
        'title': 'Three Ways to Look More Put Together',
        'description':
            'Small styling adjustments that can make an everyday outfit feel intentional.',
        'body':
            'Pay attention to proportions, colour balance and one finishing detail. A simple outfit often looks more polished when these three elements work together.',
        'type': 'Style Tip',
        'isPublished': true,
        'isFeatured': false,
        'isPremium': false,
      },
      {
        'title': 'How TiB Builds an Outfit',
        'description':
            'Learn how your wardrobe, colour profile and occasion work together in TiB styling.',
        'body':
            'TiB combines the information you provide with the clothes saved in your wardrobe to suggest looks that fit your personal style context.',
        'type': 'AI Styling',
        'isPublished': true,
        'isFeatured': false,
        'isPremium': false,
      },
    ];

    if (seed.length > _maxSeedItems) return;

    for (final item in seed) {
      final title = item['title'];
      final description = item['description'];
      final body = item['body'];
      final type = item['type'];
      if (title is! String ||
          description is! String ||
          body is! String ||
          type is! String ||
          !_isValidText(title, _maxTitleLength) ||
          !_isValidText(description, _maxDescriptionLength) ||
          !_isValidText(body, _maxBodyLength) ||
          !_isValidText(type, _maxTypeLength)) {
        return;
      }
    }

    final batch = _db.batch();
    for (final item in seed) {
      final ref = _db.collection('content').doc();
      batch.set(ref, {
        ...item,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  static Future<DocumentReference<Map<String, dynamic>>> createContent({
    required String title,
    required String description,
    required String body,
    required String type,
    bool isPublished = false,
    bool isFeatured = false,
    bool isPremium = false,
  }) async {
    final cleanedTitle = _clean(title);
    final cleanedDescription = _clean(description);
    final cleanedBody = _clean(body);
    final cleanedType = _clean(type);

    if (!_isValidText(cleanedTitle, _maxTitleLength) ||
        !_isValidText(cleanedDescription, _maxDescriptionLength) ||
        !_isValidText(cleanedBody, _maxBodyLength) ||
        !_isValidText(cleanedType, _maxTypeLength)) {
      throw ArgumentError('Invalid content data.');
    }

    return _db.collection('content').add({
      'title': cleanedTitle,
      'description': cleanedDescription,
      'body': cleanedBody,
      'type': cleanedType,
      'isPublished': isPublished,
      'isFeatured': isFeatured,
      'isPremium': isPremium,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> updateContent({
    required String contentId,
    String? title,
    String? description,
    String? body,
    String? type,
    bool? isPublished,
    bool? isFeatured,
    bool? isPremium,
  }) async {
    final cleanedId = _clean(contentId);
    if (!_isValidId(cleanedId)) {
      throw ArgumentError('Invalid content ID.');
    }

    final update = <String, dynamic>{};
    if (title != null) {
      final value = _clean(title);
      if (!_isValidText(value, _maxTitleLength)) {
        throw ArgumentError('Invalid content title.');
      }
      update['title'] = value;
    }
    if (description != null) {
      final value = _clean(description);
      if (!_isValidText(value, _maxDescriptionLength)) {
        throw ArgumentError('Invalid content description.');
      }
      update['description'] = value;
    }
    if (body != null) {
      final value = _clean(body);
      if (!_isValidText(value, _maxBodyLength)) {
        throw ArgumentError('Invalid content body.');
      }
      update['body'] = value;
    }
    if (type != null) {
      final value = _clean(type);
      if (!_isValidText(value, _maxTypeLength)) {
        throw ArgumentError('Invalid content type.');
      }
      update['type'] = value;
    }
    if (isPublished != null) update['isPublished'] = isPublished;
    if (isFeatured != null) update['isFeatured'] = isFeatured;
    if (isPremium != null) update['isPremium'] = isPremium;

    if (update.isEmpty) return;
    update['updatedAt'] = FieldValue.serverTimestamp();
    await _db.collection('content').doc(cleanedId).update(update);
  }
}
