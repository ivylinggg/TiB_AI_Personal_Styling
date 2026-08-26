import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../models/colour_analysis_result.dart';
import '../../providers/analysis_provider.dart';
import '../../services/daily_challenge_service.dart';
import '../../services/tib_style_journey_service.dart';
import '../../services/today_recommendation_service.dart';
import '../../widgets/colour_swatch.dart';
import 'tib_style_journey_screen.dart';

class DashboardDesignedScreen extends StatefulWidget {
  const DashboardDesignedScreen({super.key});

  @override
  State<DashboardDesignedScreen> createState() => _DashboardDesignedScreenState();
}

class _DashboardDesignedScreenState extends State<DashboardDesignedScreen> {
  Future<TodayRecommendation>? _recommendationFuture;
  Future<DailyChallenge>? _challengeFuture;
  Future<TibStyleJourney>? _journeyFuture;
  bool _challengeCompleted = false;
  bool _completingChallenge = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadDashboard());
  }

  void _loadDashboard() {
    if (!mounted) return;
    final provider = context.read<AnalysisProvider>();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final analysis = provider.result;

    _recommendationFuture = TodayRecommendationService.getRecommendation(
      analysis: analysis,
    );

    if (uid != null) {
      _challengeFuture = DailyChallengeService.personalizedToday(
        uid,
        analysis: analysis,
      );
      _journeyFuture = TibStyleJourneyService.load(uid);
      _loadCompletion(uid);
    }

    setState(() {});
  }

  Future<void> _loadCompletion(String uid) async {
    final completed = await DailyChallengeService.isCompleted(uid);
    if (!mounted) return;
    setState(() => _challengeCompleted = completed);
  }

  Future<void> _refresh(AnalysisProvider provider) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) await provider.loadLatestResult(uid);
    if (!mounted) return;
    _loadDashboard();
  }

  Future<void> _completeChallenge() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || _challengeCompleted || _completingChallenge) return;

    setState(() => _completingChallenge = true);
    try {
      final challenge = await (_challengeFuture ?? Future.value(DailyChallengeService.today()));
      final completed = await DailyChallengeService.complete(uid, challenge: challenge);
      if (!mounted) return;
      setState(() {
        _challengeCompleted = completed || _challengeCompleted;
        _completingChallenge = false;
        _journeyFuture = TibStyleJourneyService.load(uid);
      });
    } catch (_) {
      if (mounted) setState(() => _completingChallenge = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AnalysisProvider>();
    final result = provider.result;
    final userName = FirebaseAuth.instance.currentUser?.displayName?.trim();
    final greeting = userName?.isNotEmpty == true ? 'Hi, $userName' : 'Welcome back';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => _refresh(provider),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 34),
            children: [
              _header(greeting),
              const SizedBox(height: 18),
              _todayRecommendation(result),
              const SizedBox(height: 14),
              _colourProfileCard(result),
              const SizedBox(height: 14),
              _styleJourneyCard(),
              const SizedBox(height: 14),
              _todayTaskCard(),
              const SizedBox(height: 12),
              _journeyStats(),
              const SizedBox(height: 14),
              _badgesCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(String greeting) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                greeting,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 5),
              const Text(
                'Your personal styling space',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        _headerButton(Icons.notifications_none_rounded),
        const SizedBox(width: 9),
        _headerButton(Icons.logout_rounded),
      ],
    );
  }

  Widget _headerButton(IconData icon) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: AppColors.background,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.border),
      ),
      child: Icon(icon, color: AppColors.primary, size: 22),
    );
  }

  Widget _card({required Widget child, EdgeInsets padding = const EdgeInsets.all(18)}) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.primarySoft),
      ),
      child: child,
    );
  }

  Widget _todayRecommendation(ColourAnalysisResult? result) {
    if (_recommendationFuture == null) {
      return _loadingCard('TODAY’S RECOMMENDATION');
    }

    return FutureBuilder<TodayRecommendation>(
      future: _recommendationFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _loadingCard('TODAY’S RECOMMENDATION');
        }

        final recommendation = snapshot.data ??
            TodayRecommendationService.build(analysis: result);

        return _card(
          padding: const EdgeInsets.fromLTRB(18, 17, 18, 17),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      "TODAY'S RECOMMENDATION STYLE",
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: .7,
                      ),
                    ),
                  ),
                  Text(
                    '${DateTime.now().day}/${DateTime.now().month}',
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      recommendation.style,
                      style: const TextStyle(
                        fontSize: 25,
                        fontWeight: FontWeight.w900,
                        color: AppColors.primaryDark,
                      ),
                    ),
                  ),
                  if (recommendation.isAiGenerated)
                    const Icon(
                      Icons.auto_awesome_rounded,
                      color: AppColors.primary,
                      size: 18,
                    ),
                ],
              ),
              const SizedBox(height: 13),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Expanded(
                    child: Text(
                      "TODAY'S RECOMMENDATION COLOUR :",
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  ColourSwatch(
                    name: recommendation.colour == '—'
                        ? 'Neutral'
                        : recommendation.colour,
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      recommendation.colour == '—'
                          ? 'Choose from your palette'
                          : recommendation.colour,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 11),
              const Text(
                'KEYWORDS',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 8,
                  fontWeight: FontWeight.w900,
                  letterSpacing: .7,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                recommendation.tags.isEmpty
                    ? 'Casual · Simple · Elegant · Comfortable'
                    : recommendation.tags.take(5).join(' · '),
                style: const TextStyle(
                  fontSize: 11,
                  height: 1.45,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              if (recommendation.stylingTip.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  recommendation.stylingTip,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 10,
                    height: 1.4,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _colourProfileCard(ColourAnalysisResult? result) {
    final season = result?.season.trim().isNotEmpty == true
        ? result!.season
        : 'Colour Profile';
    final bestColours = result?.colours.take(5).toList() ?? const <String>[];
    final fallbackBest = <String>['Camel', 'Beige', 'Cream', 'Coral', 'Olive'];
    final best = bestColours.isEmpty ? fallbackBest : bestColours;

    final lipPalette = _seasonPalette(season, type: 'lips');
    final blushPalette = _seasonPalette(season, type: 'blush');

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  season,
                  style: const TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.w500,
                    fontStyle: FontStyle.italic,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const Text(
                'Your colour profile',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _paletteRow('best colour', best),
          const SizedBox(height: 13),
          _paletteRow('lips', lipPalette),
          const SizedBox(height: 13),
          _paletteRow('blush', blushPalette),
        ],
      ),
    );
  }

  Widget _paletteRow(String label, List<String> colours) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 82,
          child: Text(
            '$label :',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        Expanded(
          child: Wrap(
            spacing: 7,
            runSpacing: 7,
            children: colours
                .take(5)
                .map((colour) => ColourSwatch(name: colour, size: 27))
                .toList(),
          ),
        ),
      ],
    );
  }

  List<String> _seasonPalette(String season, {required String type}) {
    final value = season.toLowerCase();
    if (type == 'lips') {
      if (value.contains('winter')) {
        return ['Rose', 'Berry', 'Ruby', 'Burgundy', 'Plum'];
      }
      if (value.contains('summer')) {
        return ['Rose', 'Mauve', 'Pink', 'Berry', 'Mauve'];
      }
      if (value.contains('spring')) {
        return ['Peach', 'Coral', 'Rose', 'Warm Pink', 'Terracotta'];
      }
      return ['Terracotta', 'Rust', 'Coral', 'Brick Red', 'Brown'];
    }

    if (value.contains('winter')) {
      return ['Rose', 'Pink', 'Mauve', 'Berry', 'Coral'];
    }
    if (value.contains('summer')) {
      return ['Pink', 'Rose', 'Mauve', 'Peach', 'Coral'];
    }
    if (value.contains('spring')) {
      return ['Peach', 'Coral', 'Rose', 'Orange', 'Pink'];
    }
    return ['Rose', 'Peach', 'Coral', 'Terracotta', 'Orange'];
  }

  Widget _styleJourneyCard() {
    final future = _journeyFuture;
    if (future == null) return _loadingCard('YOUR STYLE JOURNEY');

    return FutureBuilder<TibStyleJourney>(
      future: future,
      builder: (context, snapshot) {
        final journey = snapshot.data;
        if (journey == null) return _loadingCard('YOUR STYLE JOURNEY');

        return InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const TibStyleJourneyScreen()),
          ),
          child: _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Your style journey ✦',
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w500,
                          fontStyle: FontStyle.italic,
                          color: AppColors.primaryDark,
                        ),
                      ),
                    ),
                    Text(
                      '${journey.points}/${journey.nextLevelPoints} XP',
                      style: const TextStyle(
                        color: AppColors.primaryDark,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 11),
                Text(
                  'Level ${journey.level} · ${journey.levelTitle}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    minHeight: 7,
                    value: journey.progress,
                    backgroundColor: AppColors.primarySoft,
                    valueColor: const AlwaysStoppedAnimation(AppColors.primary),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _todayTaskCard() {
    final future = _challengeFuture;
    if (future == null) return _loadingCard('TODAY TASK');

    return FutureBuilder<DailyChallenge>(
      future: future,
      builder: (context, snapshot) {
        final challenge = snapshot.data;
        if (challenge == null) return _loadingCard('TODAY TASK');

        return _card(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Today Task ✦',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w500,
                        fontStyle: FontStyle.italic,
                        color: AppColors.primaryDark,
                      ),
                    ),
                  ),
                  Text(
                    '+${challenge.points} XP',
                    style: const TextStyle(
                      color: AppColors.primaryDark,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                challenge.title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                challenge.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 10.5,
                  height: 1.4,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _challengeCompleted || _completingChallenge
                    ? null
                    : _completeChallenge,
                icon: _completingChallenge
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 1.8),
                      )
                    : Icon(
                        _challengeCompleted
                            ? Icons.check_rounded
                            : Icons.check_box_outline_blank_rounded,
                      ),
                label: Text(
                  _challengeCompleted ? 'Marked as completed' : 'Mark as completed',
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _journeyStats() {
    final future = _journeyFuture;
    if (future == null) return const SizedBox.shrink();

    return FutureBuilder<TibStyleJourney>(
      future: future,
      builder: (context, snapshot) {
        final journey = snapshot.data;
        if (journey == null) return const SizedBox.shrink();

        return Row(
          children: [
            Expanded(child: _statCard('✦', '${journey.points}', 'XP')),
            const SizedBox(width: 8),
            Expanded(child: _statCard('🔥', '${journey.streak}', 'Day Streak')),
            const SizedBox(width: 8),
            Expanded(child: _statCard('🏆', '${journey.completedChallenges}', 'Completed')),
          ],
        );
      },
    );
  }

  Widget _statCard(String icon, String value, String label) {
    return _card(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 13),
      child: Column(
        children: [
          Text(icon, style: const TextStyle(fontSize: 18)),
          const SizedBox(height: 3),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 8.5,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _badgesCard() {
    final future = _journeyFuture;
    if (future == null) return const SizedBox.shrink();

    return FutureBuilder<TibStyleJourney>(
      future: future,
      builder: (context, snapshot) {
        final journey = snapshot.data;
        if (journey == null) return const SizedBox.shrink();

        return _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Your badges',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w500,
                  fontStyle: FontStyle.italic,
                  color: AppColors.primaryDark,
                ),
              ),
              const SizedBox(height: 10),
              ...journey.badges.map(
                (badge) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: badge.unlocked
                              ? AppColors.primarySoft
                              : AppColors.background,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.primarySoft),
                        ),
                        child: Text(
                          badge.icon,
                          style: TextStyle(
                            fontSize: 16,
                            color: badge.unlocked
                                ? null
                                : AppColors.textMuted,
                          ),
                        ),
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Text(
                          badge.title,
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      Icon(
                        badge.unlocked
                            ? Icons.check_circle_rounded
                            : Icons.lock_outline_rounded,
                        color: badge.unlocked
                            ? AppColors.primary
                            : AppColors.textMuted,
                        size: 19,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _loadingCard(String title) {
    return _card(
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 9,
                fontWeight: FontWeight.w900,
                letterSpacing: .7,
              ),
            ),
          ),
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 1.7),
          ),
        ],
      ),
    );
  }
}
