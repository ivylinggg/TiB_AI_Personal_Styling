import 'package:cloud_firestore/cloud_firestore.dart';

class ContentService {
  ContentService._();

  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static Stream<QuerySnapshot<Map<String, dynamic>>> publishedContentStream() {
    return _db.collection('content').where('isPublished', isEqualTo: true).snapshots();
  }

  static Stream<QuerySnapshot<Map<String, dynamic>>> publishedContentByTypeStream(String type) {
    return _db
        .collection('content')
        .where('isPublished', isEqualTo: true)
        .where('type', isEqualTo: type)
        .snapshots();
  }

  static Future<void> seedDefaultContent({required bool isAdmin}) async {
    if (!isAdmin) return;

    final snapshot = await _db.collection('content').limit(1).get();
    if (snapshot.docs.isNotEmpty) return;

    const seed = [
      {
        'title': 'Understanding Your Colour Season',
        'description': 'A simple guide to using your personal colour season when choosing clothes.',
        'body': 'Start with your recommended colour season, then build outfits around colours that support your natural colouring. Use your analysis results as a guide, not a strict rule.',
        'type': 'Colour Guide',
        'isPublished': true,
        'isFeatured': true,
        'isPremium': false,
      },
      {
        'title': 'Build a Better Everyday Wardrobe',
        'description': 'Simple wardrobe principles for creating more outfits with fewer pieces.',
        'body': 'Begin with versatile essentials, then add statement pieces that reflect your personality. Keep your wardrobe organised by category and season so styling becomes easier.',
        'type': 'Learning',
        'isPublished': true,
        'isFeatured': true,
        'isPremium': false,
      },
      {
        'title': 'Three Ways to Look More Put Together',
        'description': 'Small styling adjustments that can make an everyday outfit feel intentional.',
        'body': 'Pay attention to proportions, colour balance and one finishing detail. A simple outfit often looks more polished when these three elements work together.',
        'type': 'Style Tip',
        'isPublished': true,
        'isFeatured': false,
        'isPremium': false,
      },
      {
        'title': 'How TiB Builds an Outfit',
        'description': 'Learn how your wardrobe, colour profile and occasion work together in TiB styling.',
        'body': 'TiB combines the information you provide with the clothes saved in your wardrobe to suggest looks that fit your personal style context.',
        'type': 'AI Styling',
        'isPublished': true,
        'isFeatured': false,
        'isPremium': false,
      },
    ];

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
}
