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
      final challenge = await (
        _challengeFuture ?? Future.value(DailyChallengeService.today())
      );
      final completed = await DailyChallengeService.complete(
        uid,
        challenge: challenge,
      );

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

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => _refresh(provider),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 34),
            children: [
              _todayRecommendation(result),
              const SizedBox(height: 16),
              _colourProfileCard(result),
              const SizedBox(height: 16),
              _styleJourneyCard(),
              const SizedBox(height: 16),
              _todayTaskCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _card({
    required Widget child,
    EdgeInsets padding = const EdgeInsets.all(20),
  }) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.primarySoft),
      ),
      child: child,
    );
  }

  Widget _todayRecommendation(ColourAnalysisResult? result) {
    if (_recommendationFuture == null) {
      return _loadingCard("TODAY'S RECOMMENDATION");
    }

    return FutureBuilder<TodayRecommendation>(
      future: _recommendationFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _loadingCard("TODAY'S RECOMMENDATION");
        }

        final recommendation = snapshot.data ??
            TodayRecommendationService.build(analysis: result);
        final colour = recommendation.colour == '—'
            ? 'Choose from your palette'
            : recommendation.colour;

        return _card(
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 21),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      "TODAY'S RECOMMENDATION STYLE  ✦",
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: .35,
                      ),
                    ),
                  ),
                  Text(
                    '${DateTime.now().day}/${DateTime.now().month}',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 17),
              Text(
                recommendation.style,
                style: const TextStyle(
                  fontSize: 27,
                  height: 1.1,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primaryDark,
                ),
              ),
              const SizedBox(height: 22),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Expanded(
                    child: Text(
                      "TODAY'S RECOMMENDATION COLOUR :",
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  ColourSwatch(
                    name: recommendation.colour == '—'
                        ? 'Neutral'
                        : recommendation.colour,
                    size: 30,
                  ),
                  const SizedBox(width: 11),
                  Flexible(
                    child: Text(
                      colour,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 21),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 1),
                    child: Icon(
                      Icons.auto_awesome_rounded,
                      color: AppColors.primary,
                      size: 19,
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      _colourEncouragement(recommendation.colour),
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.45,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  String _colourEncouragement(String colour) {
    final value = colour.toLowerCase();

    if (value.contains('pink') || value.contains('rose')) {
      return 'You might just meet some pink bubbles today. 💕';
    }
    if (value.contains('coral')) {
      return 'A little coral glow might brighten your day. 🧡';
    }
    if (value.contains('peach')) {
      return 'Let a little peach warmth follow you today. 🍑';
    }
    if (value.contains('terracotta')) {
      return 'A warm terracotta touch might bring out your glow. 🤎';
    }
    if (value.contains('orange')) {
      return 'A little orange energy might make today brighter. 🧡';
    }
    if (value.contains('olive')) {
      return 'A touch of olive might bring a calm confidence today. 🌿';
    }
    if (value.contains('camel') || value.contains('beige') || value.contains('cream')) {
      return 'Keep it warm and grounded — you have got this. ✨';
    }
    if (value.contains('brown')) {
      return 'Stay grounded in warm tones — today is yours. 🤎';
    }
    if (value.contains('red') || value.contains('burgundy') || value.contains('ruby')) {
      return 'A little red confidence might find you today. ❤️';
    }
    if (value.contains('gold') || value.contains('yellow')) {
      return 'Let a little golden energy brighten your day. ✨';
    }
    return 'Let today\'s colour add a little something special to your day. ✨';
  }

  Widget _colourProfileCard(ColourAnalysisResult? result) {
    final season = result?.season.trim().isNotEmpty == true
        ? result!.season
        : 'Colour Profile';
    final bestColours = result?.colours.take(5).toList() ?? const <String>[];
    final best = bestColours.isEmpty
        ? <String>['Camel', 'Beige', 'Cream', 'Coral', 'Olive']
        : bestColours;

    return _card(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  season,
                  style: const TextStyle(
                    fontSize: 27,
                    height: 1.05,
                    fontWeight: FontWeight.w500,
                    fontStyle: FontStyle.italic,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const Text(
                'Your colour profile',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          _paletteRow('best colour', best),
          const SizedBox(height: 18),
          _paletteRow('lips', _seasonPalette(season, type: 'lips')),
          const SizedBox(height: 18),
          _paletteRow('blush', _seasonPalette(season, type: 'blush')),
        ],
      ),
    );
  }

  Widget _paletteRow(String label, List<String> colours) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 92,
          child: Text(
            '$label :',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        Expanded(
          child: Wrap(
            spacing: 10,
            runSpacing: 8,
            children: colours
                .take(5)
                .map((colour) => ColourSwatch(name: colour, size: 29))
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
          borderRadius: BorderRadius.circular(24),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const TibStyleJourneyScreen()),
          ),
          child: _card(
            padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Your style journey ✦',
                        style: TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w600,
                          fontStyle: FontStyle.italic,
                          color: AppColors.primaryDark,
                        ),
                      ),
                    ),
                    Text(
                      '${journey.points}/${journey.nextLevelPoints} XP',
                      style: const TextStyle(
                        color: AppColors.primaryDark,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 17),
                Text(
                  'Level ${journey.level} · ${journey.levelTitle}',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 14),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    minHeight: 7,
                    value: journey.progress,
                    backgroundColor: AppColors.primarySoft,
                    valueColor: const AlwaysStoppedAnimation(AppColors.primary),
                  ),
                ),
                const SizedBox(height: 14),
                const Row(
                  children: [
                    Icon(
                      Icons.auto_awesome_rounded,
                      color: Colors.orangeAccent,
                      size: 17,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Small steps today, stunning you tomorrow.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
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
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Today Task ✦',
                      style: TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w600,
                        fontStyle: FontStyle.italic,
                        color: AppColors.primaryDark,
                      ),
                    ),
                  ),
                  Text(
                    '+${challenge.points} XP',
                    style: const TextStyle(
                      color: AppColors.primaryDark,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                challenge.title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: _challengeCompleted || _completingChallenge
                    ? null
                    : _completeChallenge,
                icon: _completingChallenge
                    ? const SizedBox(
                        width: 15,
                        height: 15,
                        child: CircularProgressIndicator(strokeWidth: 1.8),
                      )
                    : Icon(
                        _challengeCompleted
                            ? Icons.check_rounded
                            : Icons.check_rounded,
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

  Widget _loadingCard(String title) {
    return _card(
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 10,
                fontWeight: FontWeight.w700,
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
