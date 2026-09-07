import 'package:cloud_firestore/cloud_firestore.dart';

class TibBadge {
  final String id;
  final String title;
  final String description;
  final String icon;
  final bool unlocked;

  const TibBadge({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.unlocked,
  });
}

class TibStyleJourney {
  final int points;
  final int streak;
  final int completedChallenges;
  final int level;
  final String levelTitle;
  final int currentLevelPoints;
  final int nextLevelPoints;
  final List<TibBadge> badges;

  const TibStyleJourney({
    required this.points,
    required this.streak,
    required this.completedChallenges,
    required this.level,
    required this.levelTitle,
    required this.currentLevelPoints,
    required this.nextLevelPoints,
    required this.badges,
  });

  double get progress {
    final span = nextLevelPoints - currentLevelPoints;
    if (span <= 0) return 1;
    return ((points - currentLevelPoints) / span).clamp(0.0, 1.0);
  }
}

class TibStyleJourneyService {
  TibStyleJourneyService._();

  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static const _levels = [
    (0, 'Getting Started'),
    (50, 'Style Explorer'),
    (150, 'Style Builder'),
    (300, 'Style Confident'),
    (500, 'VYEA Stylist'),
  ];

  static Future<TibStyleJourney> load(String uid) async {
    if (uid.trim().isEmpty) return _fromHistory(const []);

    try {
      final snapshot = await _db.collection('users').doc(uid).get();
      return _fromHistory(_readHistory(snapshot.data()));
    } catch (_) {
      return _fromHistory(const []);
    }
  }

  static Future<bool> recordChallenge({
    required String uid,
    required String challengeId,
    required String title,
    int points = 10,
  }) async {
    if (uid.trim().isEmpty || challengeId.trim().isEmpty) return false;

    final safePoints = points.clamp(0, 100);
    final userRef = _db.collection('users').doc(uid);
    final snapshot = await userRef.get();
    final history = _readHistory(snapshot.data());
    final dateKey = _dateKey(DateTime.now());

    final alreadyCompleted = history.any(
      (entry) =>
          entry['date']?.toString() == dateKey &&
          entry['challengeId']?.toString() == challengeId,
    );
    if (alreadyCompleted) return false;

    await userRef.set({
      'dailyChallengeHistory': FieldValue.arrayUnion([
        {
          'challengeId': challengeId.trim(),
          'title': title.trim(),
          'points': safePoints,
          'date': dateKey,
          'completedAt': Timestamp.now(),
        },
      ]),
      'challengePoints': FieldValue.increment(safePoints),
      'styleJourneyUpdatedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    return true;
  }

  static List<Map<String, dynamic>> _readHistory(
    Map<String, dynamic>? data,
  ) {
    final raw = data?['dailyChallengeHistory'];
    if (raw is! List) return <Map<String, dynamic>>[];

    return raw
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .where((item) => item['date']?.toString().trim().isNotEmpty == true)
        .toList();
  }

  static TibStyleJourney _fromHistory(List<Map<String, dynamic>> history) {
    final uniqueHistory = <String, Map<String, dynamic>>{};
    for (final entry in history) {
      final date = entry['date']?.toString() ?? '';
      final challengeId = entry['challengeId']?.toString() ?? '';
      uniqueHistory['$date|$challengeId'] = entry;
    }

    final cleanedHistory = uniqueHistory.values.toList();
    final points = cleanedHistory.fold<int>(0, (total, entry) {
      final value = entry['points'];
      return total + (value is num ? value.toInt().clamp(0, 100) : 0);
    });

    final dates = cleanedHistory
        .map((entry) => DateTime.tryParse(entry['date']?.toString() ?? ''))
        .whereType<DateTime>()
        .map((date) => DateTime(date.year, date.month, date.day))
        .toSet();

    var streak = 0;
    var cursor = DateTime.now();
    cursor = DateTime(cursor.year, cursor.month, cursor.day);
    while (dates.contains(cursor)) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }

    var level = 1;
    var title = _levels.first.$2;
    var current = 0;
    var next = 50;

    for (var index = 0; index < _levels.length; index++) {
      final entry = _levels[index];
      if (points >= entry.$1) {
        level = index + 1;
        title = entry.$2;
        current = entry.$1;
        next = index + 1 < _levels.length ? _levels[index + 1].$1 : entry.$1;
      }
    }

    final badges = [
      TibBadge(
        id: 'first_step',
        title: 'First Step',
        description: 'Complete your first Daily Challenge.',
        icon: '🌱',
        unlocked: cleanedHistory.isNotEmpty,
      ),
      TibBadge(
        id: 'getting_started',
        title: 'Getting Started',
        description: 'Earn 50 XP from your styling journey.',
        icon: '✨',
        unlocked: points >= 50,
      ),
      TibBadge(
        id: 'three_day_streak',
        title: '3-Day Streak',
        description: 'Complete challenges for 3 days in a row.',
        icon: '🔥',
        unlocked: streak >= 3,
      ),
      TibBadge(
        id: 'style_habit',
        title: 'Style Habit',
        description: 'Keep a 7-day styling routine.',
        icon: '💫',
        unlocked: streak >= 7,
      ),
      TibBadge(
        id: 'style_explorer',
        title: 'Style Explorer',
        description: 'Complete 10 Daily Challenges.',
        icon: '👗',
        unlocked: cleanedHistory.length >= 10,
      ),
      TibBadge(
        id: 'vyea_regular',
        title: 'VYEA Regular',
        description: 'Earn 300 XP from your styling journey.',
        icon: '🏆',
        unlocked: points >= 300,
      ),
    ];

    return TibStyleJourney(
      points: points,
      streak: streak,
      completedChallenges: cleanedHistory.length,
      level: level,
      levelTitle: title,
      currentLevelPoints: current,
      nextLevelPoints: next,
      badges: badges,
    );
  }

  static String _dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
