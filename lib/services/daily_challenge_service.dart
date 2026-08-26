import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/colour_analysis_result.dart';

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
    DailyChallenge(id: 'colour_confidence', title: 'Wear your best colour', description: 'Choose one colour from your personal palette and wear it today.', category: 'Colour', points: 10, icon: 'palette'),
    DailyChallenge(id: 'outfit_photo', title: 'Take an outfit photo', description: 'Take a quick photo of today’s outfit and save it as a style memory.', category: 'Style', points: 10, icon: 'camera'),
    DailyChallenge(id: 'accessory_finish', title: 'Add one finishing touch', description: 'Complete your outfit with one intentional accessory.', category: 'Styling', points: 10, icon: 'sparkle'),
    DailyChallenge(id: 'wardrobe_refresh', title: 'Refresh one wardrobe item', description: 'Choose one item you have not worn recently and style it differently.', category: 'Wardrobe', points: 10, icon: 'hanger'),
    DailyChallenge(id: 'mirror_check', title: 'Do a 30-second mirror check', description: 'Check your proportions, colours and finishing details before heading out.', category: 'Confidence', points: 10, icon: 'mirror'),
    DailyChallenge(id: 'style_learning', title: 'Learn one styling tip', description: 'Read one TiB learning tip and try to apply it today.', category: 'Learning', points: 10, icon: 'menu_book'),
    DailyChallenge(id: 'closet_match', title: 'Build a new outfit combination', description: 'Combine three pieces from your wardrobe into a look you have not tried before.', category: 'Creative', points: 15, icon: 'checkroom'),
    DailyChallenge(id: 'work_polish', title: 'Polish your work look', description: 'Build one polished outfit that feels appropriate for your work environment while still feeling like you.', category: 'Occupation', points: 15, icon: 'business_center'),
    DailyChallenge(id: 'campus_style', title: 'Create a campus-ready look', description: 'Put together a comfortable everyday look with one intentional styling detail.', category: 'Occupation', points: 15, icon: 'school'),
    DailyChallenge(id: 'creative_detail', title: 'Add one creative detail', description: 'Use one colour, texture, accessory or styling detail to make today’s outfit feel more like you.', category: 'Personal Style', points: 15, icon: 'brush'),
    DailyChallenge(id: 'service_ready', title: 'Style for your day', description: 'Create a practical look that stays comfortable and polished throughout your working day.', category: 'Occupation', points: 15, icon: 'storefront'),
    DailyChallenge(id: 'colour_pairing', title: 'Try a new colour pairing', description: 'Choose two colours from your recommended palette and wear them together today.', category: 'Colour', points: 15, icon: 'palette'),
  ];

  static DailyChallenge today() {
    final day = DateTime.now().difference(DateTime(DateTime.now().year, 1, 1)).inDays;
    return challenges[day % challenges.length];
  }

  static Future<DailyChallenge> personalizedToday(
    String uid, {
    ColourAnalysisResult? analysis,
  }) async {
    if (uid.trim().isEmpty) return today();

    try {
      final snapshot = await _db.collection('users').doc(uid).get();
      final data = snapshot.data() ?? <String, dynamic>{};
      final onboarding = data['onboardingProfile'] is Map
          ? Map<String, dynamic>.from(data['onboardingProfile'] as Map)
          : <String, dynamic>{};

      final occupation = (data['occupation'] ?? onboarding['occupation'] ?? onboarding['occupationCategory'] ?? '').toString().toLowerCase();
      final season = (data['season'] ?? data['colourSeason'] ?? analysis?.season ?? '').toString().toLowerCase();

      final occupationMatches = <DailyChallenge>[];
      final colourMatches = <DailyChallenge>[];

      if (_matchesOccupation(occupation, ['office', 'corporate', 'business', 'finance', 'bank', 'law', 'admin', 'manager'])) {
        occupationMatches.add(challenges.firstWhere((item) => item.id == 'work_polish'));
      } else if (_matchesOccupation(occupation, ['student', 'university', 'college'])) {
        occupationMatches.add(challenges.firstWhere((item) => item.id == 'campus_style'));
      } else if (_matchesOccupation(occupation, ['creative', 'design', 'designer', 'artist', 'fashion', 'beauty', 'content', 'media'])) {
        occupationMatches.add(challenges.firstWhere((item) => item.id == 'creative_detail'));
      } else if (_matchesOccupation(occupation, ['hospitality', 'service', 'retail', 'sales', 'healthcare', 'nurse', 'doctor'])) {
        occupationMatches.add(challenges.firstWhere((item) => item.id == 'service_ready'));
      }

      if (season.isNotEmpty) {
        colourMatches.add(challenges.firstWhere((item) => item.id == 'colour_confidence'));
        if (analysis != null && analysis.colours.length >= 2) {
          colourMatches.add(challenges.firstWhere((item) => item.id == 'colour_pairing'));
        }
      }

      final preferred = <DailyChallenge>[...occupationMatches, ...colourMatches];
      final remaining = challenges.where((item) => !preferred.any((selected) => selected.id == item.id)).toList();
      final day = DateTime.now().difference(DateTime(DateTime.now().year, 1, 1)).inDays;

      if (preferred.isNotEmpty) return preferred[day % preferred.length];
      return remaining[day % remaining.length];
    } catch (_) {
      return today();
    }
  }

  static bool _matchesOccupation(String occupation, List<String> keywords) =>
      occupation.isNotEmpty && keywords.any(occupation.contains);

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
    return value.whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList();
  }

  static Future<bool> isCompleted(String uid) async {
    final entries = await history(uid);
    return entries.any((entry) => entry['date']?.toString() == todayKey());
  }

  static Future<bool> complete(String uid, {DailyChallenge? challenge}) async {
    if (uid.trim().isEmpty) return false;

    final selectedChallenge = challenge ?? today();
    final date = todayKey();
    final ref = _db.collection('users').doc(uid);
    final snapshot = await ref.get();
    final existing = snapshot.data()?['dailyChallengeHistory'];

    if (existing is List && existing.any((item) => item is Map && item['date']?.toString() == date)) {
      return false;
    }

    await ref.set({
      'dailyChallengeHistory': FieldValue.arrayUnion([
        {
          'date': date,
          'challengeId': selectedChallenge.id,
          'title': selectedChallenge.title,
          'points': selectedChallenge.points,
          'completedAt': FieldValue.serverTimestamp(),
        },
      ]),
      'challengePoints': FieldValue.increment(selectedChallenge.points),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    return true;
  }

  static Future<int> totalPoints(String uid) async {
    final entries = await history(uid);
    return entries.fold<int>(0, (total, entry) {
      final value = entry['points'];
      return total + (value is num ? value.toInt() : 0);
    });
  }

  static Future<int> streak(String uid) async {
    final entries = await history(uid);
    final dates = entries.map((entry) => DateTime.tryParse(entry['date']?.toString() ?? '')).whereType<DateTime>().map((date) => DateTime(date.year, date.month, date.day)).toSet();
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
