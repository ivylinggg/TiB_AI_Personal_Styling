import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_gradients.dart';
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

class _DashboardDesignedScreenState extends State<DashboardDesignedScreen>
    with SingleTickerProviderStateMixin {
  Future<TodayRecommendation>? _recommendationFuture;
  Future<DailyChallenge>? _challengeFuture;
  Future<TibStyleJourney>? _journeyFuture;

  bool _challengeCompleted = false;
  bool _completingChallenge = false;

  late final AnimationController _revealController;
  late final Animation<double> _heroReveal;
  late final Animation<double> _profileReveal;
  late final Animation<double> _journeyReveal;
  late final Animation<double> _taskReveal;

  @override
  void initState() {
    super.initState();
    _revealController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _heroReveal = _stage(0.00, 0.32);
    _profileReveal = _stage(0.16, 0.55);
    _journeyReveal = _stage(0.32, 0.78);
    _taskReveal = _stage(0.55, 1.00);
    _revealController.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) => _loadDashboard());
  }

  Animation<double> _stage(double begin, double end) {
    return CurvedAnimation(
      parent: _revealController,
      curve: Interval(begin, end, curve: Curves.easeOut),
    );
  }

  Widget _reveal(Animation<double> animation, Widget child) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, animatedChild) {
        final value = animation.value.clamp(0.0, 1.0);
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 12),
            child: animatedChild,
          ),
        );
      },
      child: child,
    );
  }

  @override
  void dispose() {
    _revealController.dispose();
    super.dispose();
  }

  void _loadDashboard() {
    if (!mounted) return;

    final provider = context.read<AnalysisProvider>();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final analysis = provider.result;

    _recommendationFuture =
        TodayRecommendationService.getRecommendation(analysis: analysis);

    if (uid != null) {
      _challengeFuture =
          DailyChallengeService.personalizedToday(uid, analysis: analysis);
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
      final challenge = await
          (_challengeFuture ?? Future.value(DailyChallengeService.today()));
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
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 34),
            children: [
              _reveal(_heroReveal, _buildWelcome(result)),
              const SizedBox(height: 18),
              _reveal(_profileReveal, _colourProfileCard(result)),
              const SizedBox(height: 14),
              _reveal(_journeyReveal, _styleJourneyCard()),
              const SizedBox(height: 14),
              _reveal(_taskReveal, _todayTaskCard()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWelcome(ColourAnalysisResult? result) {
    final user = FirebaseAuth.instance.currentUser;
    final displayName = user?.displayName?.trim();
    final greeting = displayName?.isNotEmpty == true
        ? 'Good to see you, $displayName.'
        : 'Good to see you.';
    final recommendation = _recommendationFuture;

    return Container(
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
      decoration: BoxDecoration(
        gradient: AppGradients.ai,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'VYEA',
                  style: TextStyle(
                    color: AppColors.brown,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 3.4,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: AppColors.surface.withValues(alpha: 0.75),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  'STYLE BUT PERSONAL',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.7,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Text(
            greeting,
            style: const TextStyle(
              fontSize: 27,
              height: 1.08,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.6,
              color: AppColors.primaryDark,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'A more personal way to understand your style, dress with intention, and keep your own identity in every look.',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13.2,
              height: 1.5,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 20),
          FutureBuilder<TodayRecommendation>(
            future: recommendation,
            builder: (context, snapshot) {
              final recommendationData = snapshot.data;
              final style = recommendationData?.style;
              if (style == null || style.isEmpty) return const SizedBox.shrink();

              return Container(
                padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
                decoration: BoxDecoration(
                  color: AppColors.surface.withValues(alpha: 0.72),
                  borderRadius: BorderRadius.circular(17),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.auto_awesome_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 11),
                    const Text(
                      'TODAY',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        style,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.primaryDark,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _card({
    required Widget child,
    EdgeInsets padding = const EdgeInsets.all(20),
    Color? color,
  }) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    );
  }

  Widget _colourProfileCard(ColourAnalysisResult? result) {
    if (result == null) {
      return _card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _eyebrow('YOUR COLOUR PROFILE'),
            const SizedBox(height: 12),
            const Text(
              'Your colour story starts here.',
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w800,
                color: AppColors.primaryDark,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Complete a colour analysis to unlock your personalised palette.',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12.8,
                height: 1.45,
              ),
            ),
          ],
        ),
      );
    }

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _eyebrow('YOUR COLOUR PROFILE'),
                    const SizedBox(height: 8),
                    Text(
                      result.season,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primaryDark,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: AppGradients.season(result.season),
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              _profileChip('Undertone', result.undertone),
              _profileChip('Brightness', result.brightness),
              _profileChip('Contrast', result.contrast),
            ],
          ),
          if (result.colours.isNotEmpty) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: result.colours
                  .take(6)
                  .map((colour) => ColourSwatch(name: colour, size: 28))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _profileChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '$label  $value',
        style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _styleJourneyCard() {
    if (_journeyFuture == null) return _loadingCard('YOUR STYLE JOURNEY');

    return FutureBuilder<TibStyleJourney>(
      future: _journeyFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _loadingCard('YOUR STYLE JOURNEY');
        }

        final journey = snapshot.data;
        if (journey == null) return _loadingCard('YOUR STYLE JOURNEY');

        final progress = journey.progress.clamp(0.0, 1.0);

        return _card(
          padding: const EdgeInsets.fromLTRB(20, 19, 20, 18),
          child: InkWell(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const TibStyleJourneyScreen(),
              ),
            ),
            borderRadius: BorderRadius.circular(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(child: _EyebrowText('YOUR STYLE JOURNEY')),
                    Text(
                      'Level ${journey.level}',
                      style: const TextStyle(
                        color: AppColors.primaryDark,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${journey.points}',
                      style: const TextStyle(
                        fontSize: 25,
                        height: 1,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primaryDark,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Padding(
                      padding: EdgeInsets.only(bottom: 2),
                      child: Text(
                        'XP',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${journey.completedChallenges} challenges',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 7,
                    backgroundColor: AppColors.surfaceMuted,
                  ),
                ),
                const SizedBox(height: 9),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        journey.levelTitle,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Text(
                      '${journey.streak}-day streak',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11.5,
                      ),
                    ),
                    const SizedBox(width: 2),
                    const Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: AppColors.textMuted,
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
    if (_challengeFuture == null) return _loadingCard("TODAY'S STYLE TASK");

    return FutureBuilder<DailyChallenge>(
      future: _challengeFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _loadingCard("TODAY'S STYLE TASK");
        }

        final challenge = snapshot.data ?? DailyChallengeService.today();

        return _card(
          padding: const EdgeInsets.fromLTRB(20, 19, 20, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(child: _EyebrowText("TODAY'S STYLE TASK")),
                  Icon(
                    _challengeCompleted
                        ? Icons.check_circle_rounded
                        : Icons.today_rounded,
                    color: _challengeCompleted
                        ? AppColors.success
                        : AppColors.primary,
                    size: 19,
                  ),
                ],
              ),
              const SizedBox(height: 9),
              Text(
                challenge.title,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primaryDark,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                challenge.description,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12.5,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _challengeCompleted || _completingChallenge
                      ? null
                      : _completeChallenge,
                  child: Text(
                    _challengeCompleted
                        ? 'Completed today'
                        : _completingChallenge
                            ? 'Saving...'
                            : 'Mark as completed',
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: .35,
            ),
          ),
          const SizedBox(height: 14),
          const LinearProgressIndicator(minHeight: 5),
        ],
      ),
    );
  }

  Widget _eyebrow(String text) => Text(
        text,
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 9.8,
          fontWeight: FontWeight.w800,
          letterSpacing: .55,
        ),
      );
}

class _EyebrowText extends StatelessWidget {
  final String text;

  const _EyebrowText(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: AppColors.textSecondary,
        fontSize: 9.8,
        fontWeight: FontWeight.w800,
        letterSpacing: .55,
      ),
    );
  }
}
