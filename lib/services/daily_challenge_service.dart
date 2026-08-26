import 'package:cloud_firestore/cloud_firestore.dart';

class DailyChallenge {
  final String id;
  final String title;
  final String description;
  final String category;
  final int points;
  final String icon;

  const DailyChallenge({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.points,
    required this.icon,
  });
}

class DailyChallengeService {
  DailyChallengeService._();

  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static const List<DailyChallenge> challenges = [
    DailyChallenge(
      id: 'colour_confidence',
      title: 'Wear your best colour',
      description: 'Choose one colour from your personal palette and wear it today.',
      category: 'Colour',
      points: 10,
      icon: 'palette',
    ),
    DailyChallenge(
      id: 'outfit_photo',
      title: 'Take an outfit photo',
      description: 'Take a quick photo of today’s outfit and save it as a style memory.',
      category: 'Style',
      points: 10,
      icon: 'camera',
    ),
    DailyChallenge(
      id: 'accessory_finish',
      title: 'Add one finishing touch',
      description: 'Complete your outfit with one intentional accessory.',
      category: 'Styling',
      points: 10,
      icon: 'sparkle',
    ),
    DailyChallenge(
      id: 'wardrobe_refresh',
      title: 'Refresh one wardrobe item',
      description: 'Choose one item you have not worn recently and style it differently.',
      category: 'Wardrobe',
      points: 10,
      icon: 'hanger',
    ),
    DailyChallenge(
      id: 'mirror_check',
      title: 'Do a 30-second mirror check',
      description: 'Check your proportions, colours and finishing details before heading out.',
      category: 'Confidence',
      points: 10,
      icon: 'mirror',
    ),
    DailyChallenge(
      id: 'style_learning',
      title: 'Learn one styling tip',
      description: 'Read one TiB learning tip and try to apply it today.',
      category: 'Learning',
      points: 10,
      icon: 'menu_book',
    ),
    DailyChallenge(
      id: 'closet_match',
      title: 'Build a new outfit combination',
      description: 'Combine three pieces from your wardrobe into a look you have not tried before.',
      category: 'Creative',
      points: 15,
      icon: 'checkroom',
    ),
  ];

  static DailyChallenge today() {
    final day = DateTime.now().difference(DateTime(DateTime.now().year, 1, 1)).inDays;
    return challenges[day % challenges.length];
  }

  static String todayKey() {
    final now = DateTime.now();
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    return '${now.year}-$month-$day';
  }

  static Future<List<Map<String, dynamic>>> history(String uid) async {
    if (uid.trim().isEmpty) return const [];
    final snapshot = await _db.collection('users').doc(uid).get();
    final value = snapshot.data()?['dailyChallengeHistory'];
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  static Future<bool> isCompleted(String uid) async {
    final entries = await history(uid);
    return entries.any((entry) => entry['date']?.toString() == todayKey());
  }

  static Future<bool> complete(String uid) async {
    if (uid.trim().isEmpty) return false;

    final challenge = today();
    final date = todayKey();
    final ref = _db.collection('users').doc(uid);
    final snapshot = await ref.get();
    final existing = snapshot.data()?['dailyChallengeHistory'];

    if (existing is List &&
        existing.any((item) => item is Map && item['date']?.toString() == date)) {
      return false;
    }

    await ref.set({
      'dailyChallengeHistory': FieldValue.arrayUnion([
        {
          'date': date,
          'challengeId': challenge.id,
          'title': challenge.title,
          'points': challenge.points,
          'completedAt': FieldValue.serverTimestamp(),
        },
      ]),
      'challengePoints': FieldValue.increment(challenge.points),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    return true;
  }

  static Future<int> totalPoints(String uid) async {
    final entries = await history(uid);
    return entries.fold<int>(0, (sum, entry) {
      final value = entry['points'];
      return sum + (value is num ? value.toInt() : 0);
    });
  }

  static Future<int> streak(String uid) async {
    final entries = await history(uid);
    final dates = entries
        .map((entry) => DateTime.tryParse(entry['date']?.toString() ?? ''))
        .whereType<DateTime>()
        .map((date) => DateTime(date.year, date.month, date.day))
        .toSet();

    if (dates.isEmpty) return 0;

    var current = DateTime.now();
    current = DateTime(current.year, current.month, current.day);
    if (!dates.contains(current)) return 0;

    var count = 0;
    while (dates.contains(current)) {
      count++;
      current = current.subtract(const Duration(days: 1));
    }
    return count;
  }
}
