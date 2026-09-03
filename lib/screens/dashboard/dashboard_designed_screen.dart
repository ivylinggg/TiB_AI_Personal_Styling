import 'package:cloud_firestore/cloud_firestore.dart';
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

    _recommendationFuture = TodayRecommendationService.getRecommendation(analysis: analysis);
    if (uid != null) {
      _challengeFuture = DailyChallengeService.personalizedToday(uid, analysis: analysis);
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

  Widget _card({required Widget child, EdgeInsets padding = const EdgeInsets.all(20)}) {
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
    if (_recommendationFuture == null) return _loadingCard("TODAY'S RECOMMENDATION");
    return FutureBuilder<TodayRecommendation>(
      future: _recommendationFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return _loadingCard("TODAY'S RECOMMENDATION");
        final recommendation = snapshot.data ?? TodayRecommendationService.build(analysis: result);
        final colour = recommendation.colour == '—' ? 'Choose from your palette' : recommendation.colour;
        return _card(
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 21),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Expanded(child: Text("TODAY'S RECOMMENDATION STYLE  ✦", style: TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: .35))),
              Text('${DateTime.now().day}/${DateTime.now().month}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(height: 17),
            Text(recommendation.style, style: const TextStyle(fontSize: 27, height: 1.1, fontWeight: FontWeight.w800, color: AppColors.primaryDark)),
            const SizedBox(height: 22),
            Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
              const Expanded(child: Text("TODAY'S RECOMMENDATION COLOUR :", style: TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w700))),
              ColourSwatch(name: recommendation.colour == '—' ? 'Neutral' : recommendation.colour, size: 30),
              const SizedBox(width: 11),
              Flexible(child: Text(colour, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary))),
            ]),
            const SizedBox(height: 21),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Padding(padding: EdgeInsets.only(top: 1), child: Icon(Icons.auto_awesome_rounded, color: AppColors.primary, size: 19)),
              const SizedBox(width: 9),
              Expanded(child: Text(_colourEncouragement(recommendation.colour), style: const TextStyle(fontSize: 13, height: 1.45, fontWeight: FontWeight.w500, color: AppColors.textSecondary))),
            ]),
          ]),
        );
      },
    );
  }

  Widget _colourProfileCard(ColourAnalysisResult? result) {
    if (result == null) {
      return _card(child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('YOUR COLOUR PROFILE', style: TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: .35)),
        SizedBox(height: 12),
        Text('Your colour story starts here.', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
        SizedBox(height: 6),
        Text('Complete a colour analysis to unlock your personalised palette.', style: TextStyle(color: AppColors.textSecondary)),
      ]));
    }
    return _card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('YOUR COLOUR PROFILE', style: TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: .35)),
      const SizedBox(height: 10),
      Text(result.season, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.primaryDark)),
      const SizedBox(height: 9),
      Wrap(spacing: 8, runSpacing: 8, children: [
        _profileChip('Undertone', result.undertone),
        _profileChip('Brightness', result.brightness),
        _profileChip('Contrast', result.contrast),
      ]),
      if (result.colours.isNotEmpty) ...[
        const SizedBox(height: 14),
        Wrap(spacing: 7, children: result.colours.take(6).map((colour) => ColourSwatch(name: colour, size: 28)).toList()),
      ],
    ]));
  }

  Widget _profileChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(color: AppColors.surfaceMuted, borderRadius: BorderRadius.circular(12)),
      child: Text('$label  $value', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700)),
    );
  }

  Widget _styleJourneyCard() {
    if (_journeyFuture == null) return _loadingCard('YOUR STYLE JOURNEY');
    return FutureBuilder<TibStyleJourney>(
      future: _journeyFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return _loadingCard('YOUR STYLE JOURNEY');
        final journey = snapshot.data;
        if (journey == null) return _loadingCard('YOUR STYLE JOURNEY');
        final progress = journey.progress.clamp(0.0, 1.0);
        final levelText = 'Level ${journey.level} • ${journey.levelTitle}';
        return _card(child: InkWell(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TibStyleJourneyScreen())),
          borderRadius: BorderRadius.circular(18),
          child: Padding(padding: const EdgeInsets.all(2), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [const Expanded(child: Text('YOUR STYLE JOURNEY', style: TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: .35))), Text(levelText, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12))]),
            const SizedBox(height: 10),
            Text('${journey.points} XP • ${journey.completedChallenges} challenges', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            ClipRRect(borderRadius: BorderRadius.circular(20), child: LinearProgressIndicator(value: progress, minHeight: 8, backgroundColor: AppColors.surfaceMuted)),
            const SizedBox(height: 8),
            Text('${journey.streak}-day streak', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          ])),
        ));
      },
    );
  }

  Widget _todayTaskCard() {
    if (_challengeFuture == null) return _loadingCard("TODAY'S STYLE TASK");
    return FutureBuilder<DailyChallenge>(
      future: _challengeFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return _loadingCard("TODAY'S STYLE TASK");
        final challenge = snapshot.data ?? DailyChallengeService.today();
        return _card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [const Expanded(child: Text("TODAY'S STYLE TASK", style: TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: .35))), Icon(_challengeCompleted ? Icons.check_circle_rounded : Icons.today_rounded, color: _challengeCompleted ? Colors.green : AppColors.primary)]),
          const SizedBox(height: 10),
          Text(challenge.title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 5),
          Text(challenge.description, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5, height: 1.4)),
          const SizedBox(height: 14),
          SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _challengeCompleted || _completingChallenge ? null : _completeChallenge, child: Text(_challengeCompleted ? 'Completed today' : _completingChallenge ? 'Saving...' : 'Mark as completed')),
        ]));
      },
    );
  }

  Widget _loadingCard(String title) {
    return _card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: .35)),
      const SizedBox(height: 14),
      const LinearProgressIndicator(minHeight: 6),
    ]));
  }

  String _colourEncouragement(String colour) {
    if (colour == '—') return 'Start with your colour analysis and let your palette guide today’s look.';
    return '$colour can be a beautiful anchor for today’s outfit. Keep the rest simple and let it stand out.';
  }
}
