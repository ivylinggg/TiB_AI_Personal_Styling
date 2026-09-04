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
      duration: const Duration(milliseconds: 850),
    );
    _heroReveal = _stage(0.00, 0.30);
    _profileReveal = _stage(0.14, 0.52);
    _journeyReveal = _stage(0.30, 0.76);
    _taskReveal = _stage(0.52, 1.00);
    _revealController.forward();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadDashboard());
  }

  Animation<double> _stage(double begin, double end) => CurvedAnimation(
        parent: _revealController,
        curve: Interval(begin, end, curve: Curves.easeOutCubic),
      );

  Widget _reveal(Animation<double> animation, Widget child) => AnimatedBuilder(
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
      final challenge =
          await (_challengeFuture ?? Future.value(DailyChallengeService.today()));
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

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => _refresh(provider),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              _reveal(_heroReveal, _buildWelcome(result)),
              const SizedBox(height: 24),
              _sectionHeading('YOUR STYLE TODAY', 'A quick read on what feels like you.'),
              const SizedBox(height: 12),
              _reveal(_profileReveal, _colourProfileCard(result)),
              const SizedBox(height: 22),
              _sectionHeading('YOUR JOURNEY', 'Keep building your personal style.'),
              const SizedBox(height: 12),
              _reveal(_journeyReveal, _styleJourneyCard()),
              const SizedBox(height: 22),
              _sectionHeading('ONE SMALL STYLE MOVE', 'A simple task for today.'),
              const SizedBox(height: 12),
              _reveal(_taskReveal, _todayTaskCard()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionHeading(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.4,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12.5,
            height: 1.35,
          ),
        ),
      ],
    );
  }

  Widget _buildWelcome(ColourAnalysisResult? result) {
    final user = FirebaseAuth.instance.currentUser;
    final displayName = user?.displayName?.trim();
    final greeting = displayName?.isNotEmpty == true
        ? 'Good to see you, ${displayName!}.'
        : 'Good to see you.';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
      decoration: BoxDecoration(
        color: AppColors.surface,
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
                    fontWeight: FontWeight.w900,
                    letterSpacing: 3.6,
                  ),
                ),
              ),
              Container(
                width: 34,
                height: 34,
                decoration: const BoxDecoration(
                  color: AppColors.secondary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  size: 17,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Text(
            greeting,
            style: const TextStyle(
              color: AppColors.primaryDark,
              fontSize: 29,
              height: 1.03,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.9,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Your wardrobe, colours and personal taste — brought together in one place.',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12.8,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 18),
          FutureBuilder<TodayRecommendation>(
            future: _recommendationFuture,
            builder: (context, snapshot) {
              final data = snapshot.data;
              if (data == null || data.style.isEmpty) return const SizedBox.shrink();
              final colour = data.colour == '—' ? 'Your palette' : data.colour;
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
                decoration: BoxDecoration(
                  color: AppColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    const Text(
                      'TODAY',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: .9,
                      ),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        data.style,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.primaryDark,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ColourSwatch(name: colour == 'Your palette' ? 'Neutral' : colour, size: 24),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _card({required Widget child, EdgeInsets padding = const EdgeInsets.all(19)}) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    );
  }

  Widget _colourProfileCard(ColourAnalysisResult? result) {
    if (result == null) {
      return _card(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 17),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(
                color: AppColors.secondary,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.palette_outlined, color: AppColors.primary),
            ),
            const SizedBox(width: 13),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Discover your colours', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                  SizedBox(height: 4),
                  Text('Complete your colour analysis to unlock your personal palette.', style: TextStyle(color: AppColors.textSecondary, fontSize: 11.8, height: 1.4)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
          ],
        ),
      );
    }

    return _card(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              gradient: AppGradients.season(result.season),
              borderRadius: BorderRadius.circular(19),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('COLOUR PROFILE', style: TextStyle(color: AppColors.textMuted, fontSize: 9.5, fontWeight: FontWeight.w900, letterSpacing: 1.1)),
                const SizedBox(height: 5),
                Text(result.season, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: AppColors.primaryDark)),
                const SizedBox(height: 5),
                Text('${result.undertone} · ${result.brightness} · ${result.contrast}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 11.5)),
                if (result.colours.isNotEmpty) ...[
                  const SizedBox(height: 11),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: result.colours.take(5).map((name) => ColourSwatch(name: name, size: 25)).toList(),
                  ),
                ],
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
        ],
      ),
    );
  }

  Widget _styleJourneyCard() {
    if (_journeyFuture == null) return _loadingCard('STYLE JOURNEY');
    return FutureBuilder<TibStyleJourney>(
      future: _journeyFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _loadingCard('STYLE JOURNEY');
        }
        final journey = snapshot.data;
        if (journey == null) return _loadingCard('STYLE JOURNEY');
        final progress = journey.progress.clamp(0.0, 1.0);
        return _card(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 17),
          child: InkWell(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TibStyleJourneyScreen())),
            borderRadius: BorderRadius.circular(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(child: Text('STYLE JOURNEY', style: TextStyle(color: AppColors.textMuted, fontSize: 9.5, fontWeight: FontWeight.w900, letterSpacing: 1.1))),
                    Text('Level ${journey.level}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.primaryDark)),
                  ],
                ),
                const SizedBox(height: 9),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('${journey.points}', style: const TextStyle(fontSize: 27, height: 1, fontWeight: FontWeight.w800, color: AppColors.primaryDark)),
                    const SizedBox(width: 5),
                    const Padding(padding: EdgeInsets.only(bottom: 2), child: Text('XP', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: AppColors.textSecondary))),
                    const Spacer(),
                    Text('${journey.completedChallenges} challenges', style: const TextStyle(fontSize: 10.5, color: AppColors.textSecondary)),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: LinearProgressIndicator(value: progress, minHeight: 7, backgroundColor: AppColors.surfaceMuted),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: Text(journey.levelTitle, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.textSecondary))),
                    Text('${journey.streak}-day streak', style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
                    const Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.textMuted),
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
    if (_challengeFuture == null) return _loadingCard('TODAY\'S STYLE TASK');
    return FutureBuilder<DailyChallenge>(
      future: _challengeFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _loadingCard('TODAY\'S STYLE TASK');
        }
        final challenge = snapshot.data ?? DailyChallengeService.today();
        return _card(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 17),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _challengeCompleted ? AppColors.surfaceMuted : AppColors.secondary,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _challengeCompleted ? Icons.check_rounded : Icons.auto_awesome_rounded,
                  color: _challengeCompleted ? AppColors.success : AppColors.primary,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(child: Text('TODAY\'S STYLE TASK', style: TextStyle(color: AppColors.textMuted, fontSize: 9.5, fontWeight: FontWeight.w900, letterSpacing: 1.1))),
                        if (_challengeCompleted) const Text('DONE', style: TextStyle(color: AppColors.success, fontSize: 9.5, fontWeight: FontWeight.w900)),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(challenge.title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text(challenge.description, style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary, height: 1.4)),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: _challengeCompleted || _completingChallenge ? null : _completeChallenge,
                        style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(43)),
                        child: Text(_challengeCompleted ? 'Completed today' : _completingChallenge ? 'Saving…' : 'Mark as completed'),
                      ),
                    ),
                  ],
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
          Text(title, style: const TextStyle(color: AppColors.textMuted, fontSize: 9.5, fontWeight: FontWeight.w900, letterSpacing: 1.1)),
          const SizedBox(height: 14),
          const LinearProgressIndicator(minHeight: 6),
        ],
      ),
    );
  }
}
