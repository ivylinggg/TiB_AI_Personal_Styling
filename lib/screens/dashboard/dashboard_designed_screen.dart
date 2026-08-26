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
import '../analysis/analysis_result_screen.dart';
import '../analysis/analysis_screen.dart';
import 'daily_challenge_screen.dart';
import 'tib_style_journey_screen.dart';

class DashboardDesignedScreen extends StatefulWidget {
  const DashboardDesignedScreen({super.key});

  @override
  State<DashboardDesignedScreen> createState() => _DashboardDesignedScreenState();
}

class _DashboardDesignedScreenState extends State<DashboardDesignedScreen> {
  Future<TodayRecommendation>? _recommendationFuture;
  bool _recommendationExpanded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadRecommendation());
  }

  void _loadRecommendation() {
    if (!mounted) return;
    final provider = context.read<AnalysisProvider>();
    _recommendationFuture = TodayRecommendationService.getRecommendation(analysis: provider.result);
    setState(() {});
  }

  Future<void> _refresh(AnalysisProvider provider) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) await provider.loadLatestResult(uid);
    if (!mounted) return;
    _loadRecommendation();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AnalysisProvider>();
    final result = provider.result;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final userName = FirebaseAuth.instance.currentUser?.displayName?.trim();
    final greeting = userName?.isNotEmpty == true ? 'Hi, $userName' : 'Welcome back';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => _refresh(provider),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
            children: [
              Text(greeting, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
              const SizedBox(height: 5),
              const Text('Your personal styling space', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              const SizedBox(height: 18),
              _todayRecommendationCard(context, result),
              const SizedBox(height: 14),
              _challengeJourneyCard(context, uid),
            ],
          ),
        ),
      ),
    );
  }

  Widget _todayRecommendationCard(BuildContext context, ColourAnalysisResult? result) {
    if (_recommendationFuture == null) return _recommendationLoadingCard();

    return FutureBuilder<TodayRecommendation>(
      future: _recommendationFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return _recommendationLoadingCard();
        final recommendation = snapshot.data ?? TodayRecommendationService.build(analysis: result);
        final aiReady = recommendation.isAiGenerated;

        return Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: () => setState(() => _recommendationExpanded = !_recommendationExpanded),
            child: Ink(
              decoration: BoxDecoration(
                gradient: AppGradients.soft,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.primarySoft),
                boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: .05), blurRadius: 16, offset: const Offset(0, 6))],
              ),
              child: AnimatedSize(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Container(width: 42, height: 42, decoration: const BoxDecoration(color: AppColors.primarySoft, shape: BoxShape.circle), child: Icon(aiReady ? Icons.auto_awesome_rounded : Icons.checkroom_rounded, color: AppColors.primaryDark, size: 21)),
                      const SizedBox(width: 11),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          const Expanded(child: Text("TODAY'S RECOMMENDATION", style: TextStyle(color: AppColors.textMuted, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: .7))),
                          if (aiReady) Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3), decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: .10), borderRadius: BorderRadius.circular(8)), child: const Text('AI', style: TextStyle(color: AppColors.primaryDark, fontSize: 7, fontWeight: FontWeight.w900))),
                        ]),
                        const SizedBox(height: 4),
                        Text(recommendation.style, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 18, height: 1.1, fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
                      ])),
                      const SizedBox(width: 8),
                      AnimatedRotation(turns: _recommendationExpanded ? .5 : 0, duration: const Duration(milliseconds: 220), child: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.primary, size: 24)),
                    ]),
                    const SizedBox(height: 11),
                    Row(children: [
                      Expanded(child: Wrap(spacing: 6, runSpacing: 5, children: recommendation.tags.take(3).map(_styleTag).toList())),
                      Text('${DateTime.now().day}/${DateTime.now().month}', style: const TextStyle(color: AppColors.textMuted, fontSize: 9, fontWeight: FontWeight.w800)),
                    ]),
                    if (_recommendationExpanded) ...[
                      const SizedBox(height: 14),
                      const Divider(height: 1, color: AppColors.border),
                      const SizedBox(height: 14),
                      Text(result == null ? 'Complete your colour analysis to unlock personalised styling.' : recommendation.reason, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11, height: 1.45)),
                      const SizedBox(height: 12),
                      _recommendationOutfit(recommendation),
                      if (recommendation.stylingTip.isNotEmpty) ...[const SizedBox(height: 9), _recommendationTip(recommendation.stylingTip)],
                      const SizedBox(height: 9),
                      _recommendationColour(result, recommendation.colour),
                      const SizedBox(height: 10),
                      Row(children: [const Icon(Icons.touch_app_rounded, color: AppColors.primary, size: 15), const SizedBox(width: 6), Text(result == null ? 'Tap to complete your colour analysis' : 'Tap again to collapse', style: const TextStyle(color: AppColors.textMuted, fontSize: 9, fontWeight: FontWeight.w700))]),
                    ],
                  ]),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _recommendationLoadingCard() => Material(
    color: Colors.transparent,
    child: Ink(
      decoration: BoxDecoration(gradient: AppGradients.soft, borderRadius: BorderRadius.circular(24), border: Border.all(color: AppColors.primarySoft)),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: Row(children: [
        const SizedBox(width: 42, height: 42, child: DecoratedBox(decoration: BoxDecoration(color: AppColors.primarySoft, shape: BoxShape.circle))),
        const SizedBox(width: 11),
        const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text("TODAY'S RECOMMENDATION", style: TextStyle(color: AppColors.textMuted, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: .7)), SizedBox(height: 6), SizedBox(width: 150, height: 16, child: DecoratedBox(decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.all(Radius.circular(8)))))])),
        const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 1.8, color: AppColors.primary)),
      ]),
    ),
  );

  Widget _recommendationOutfit(TodayRecommendation recommendation) => Container(
    padding: const EdgeInsets.fromLTRB(11, 10, 11, 10),
    decoration: BoxDecoration(color: AppColors.background.withValues(alpha: .72), borderRadius: BorderRadius.circular(15), border: Border.all(color: AppColors.border)),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [const Icon(Icons.checkroom_rounded, color: AppColors.primary, size: 19), const SizedBox(width: 9), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('TRY THIS TODAY', style: TextStyle(color: AppColors.textMuted, fontSize: 7.8, fontWeight: FontWeight.w900, letterSpacing: .55)), const SizedBox(height: 3), Text(recommendation.outfit, style: const TextStyle(fontSize: 10.5, height: 1.35, fontWeight: FontWeight.w700, color: AppColors.textPrimary))]))]),
  );

  Widget _recommendationTip(String tip) => Container(
    padding: const EdgeInsets.fromLTRB(11, 10, 11, 10),
    decoration: BoxDecoration(color: AppColors.background.withValues(alpha: .55), borderRadius: BorderRadius.circular(15), border: Border.all(color: AppColors.border)),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [const Icon(Icons.lightbulb_outline_rounded, color: AppColors.primary, size: 18), const SizedBox(width: 9), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('STYLING TIP', style: TextStyle(color: AppColors.textMuted, fontSize: 7.8, fontWeight: FontWeight.w900, letterSpacing: .55)), const SizedBox(height: 3), Text(tip, style: const TextStyle(fontSize: 10.2, height: 1.35, color: AppColors.textSecondary))]))]),
  );

  Widget _recommendationColour(ColourAnalysisResult? result, String colour) => Container(
    padding: const EdgeInsets.fromLTRB(10, 9, 9, 9),
    decoration: BoxDecoration(color: AppColors.background.withValues(alpha: .72), borderRadius: BorderRadius.circular(15), border: Border.all(color: AppColors.border)),
    child: Row(children: [ColourSwatch(name: colour, size: 24), const SizedBox(width: 9), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text("TODAY'S COLOUR", style: TextStyle(color: AppColors.textMuted, fontSize: 7.8, fontWeight: FontWeight.w900, letterSpacing: .55)), const SizedBox(height: 2), Text(result == null ? 'Complete your colour analysis' : colour, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: AppColors.textPrimary))]))]),
  );

  Widget _styleTag(String label) => Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5), decoration: BoxDecoration(color: AppColors.primarySoft.withValues(alpha: .68), borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.primarySoft)), child: Text(label, style: const TextStyle(fontSize: 8.8, fontWeight: FontWeight.w800, color: AppColors.primaryDark)));

  Widget _challengeJourneyCard(BuildContext context, String? uid) {
    if (uid == null) return const SizedBox.shrink();
    final challenge = DailyChallengeService.today();
    return FutureBuilder<bool>(
      future: DailyChallengeService.isCompleted(uid),
      builder: (context, challengeSnapshot) {
        final completed = challengeSnapshot.data == true;
        return FutureBuilder<TibStyleJourney>(
          future: TibStyleJourneyService.load(uid),
          builder: (context, journeySnapshot) {
            final journey = journeySnapshot.data;
            return Material(
              color: Colors.transparent,
              child: Container(
                decoration: BoxDecoration(gradient: AppGradients.soft, borderRadius: BorderRadius.circular(24), border: Border.all(color: AppColors.primarySoft), boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: .05), blurRadius: 16, offset: const Offset(0, 6))]),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  InkWell(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DailyChallengeScreen())),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(17, 17, 17, 16),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [Container(width: 44, height: 44, decoration: const BoxDecoration(color: AppColors.primarySoft, shape: BoxShape.circle), child: Icon(completed ? Icons.check_rounded : Icons.bolt_rounded, color: AppColors.primaryDark, size: 22)), const SizedBox(width: 12), const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('TODAY’S CHALLENGE', style: TextStyle(color: AppColors.textMuted, fontSize: 8.5, fontWeight: FontWeight.w900, letterSpacing: .7)), SizedBox(height: 4), Text('One small action. Better style.', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: AppColors.textPrimary))])), Text('+${challenge.points} XP', style: const TextStyle(color: AppColors.primaryDark, fontSize: 10, fontWeight: FontWeight.w900))]),
                        const SizedBox(height: 14),
                        Text(challenge.title, style: const TextStyle(fontSize: 18, height: 1.15, fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
                        const SizedBox(height: 5),
                        Text(challenge.description, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, height: 1.4, color: AppColors.textSecondary)),
                        const SizedBox(height: 12),
                        Row(children: [Expanded(child: Text(completed ? 'Completed today ✓' : 'Tap to complete today’s task', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: completed ? AppColors.primaryDark : AppColors.textMuted))), const Icon(Icons.arrow_forward_ios_rounded, size: 13, color: AppColors.primary)]),
                      ]),
                    ),
                  ),
                  const Divider(height: 1, color: AppColors.border),
                  InkWell(
                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TibStyleJourneyScreen())),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(17, 16, 17, 16),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [Container(width: 44, height: 44, decoration: const BoxDecoration(color: AppColors.primarySoft, shape: BoxShape.circle), child: const Icon(Icons.auto_awesome_rounded, color: AppColors.primaryDark, size: 21)), const SizedBox(width: 12), const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('YOUR STYLE JOURNEY', style: TextStyle(color: AppColors.textMuted, fontSize: 8.5, fontWeight: FontWeight.w900, letterSpacing: .7)), SizedBox(height: 4), Text('Build your style through small wins', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: AppColors.textPrimary))])), const Icon(Icons.arrow_forward_ios_rounded, size: 13, color: AppColors.primary)]),
                        const SizedBox(height: 13),
                        if (journeySnapshot.connectionState == ConnectionState.waiting)
                          const LinearProgressIndicator(minHeight: 7, backgroundColor: AppColors.primarySoft, valueColor: AlwaysStoppedAnimation(AppColors.primary))
                        else if (journey != null) ...[
                          Row(children: [Expanded(child: Text('Level ${journey.level} · ${journey.levelTitle}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: AppColors.textPrimary))), Text('${journey.points} XP', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.primaryDark))]),
                          const SizedBox(height: 8),
                          ClipRRect(borderRadius: BorderRadius.circular(20), child: LinearProgressIndicator(minHeight: 7, value: journey.progress, backgroundColor: AppColors.primarySoft, valueColor: const AlwaysStoppedAnimation(AppColors.primary))),
                          const SizedBox(height: 9),
                          Row(children: [Expanded(child: Text('🔥 ${journey.streak} day streak', style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: AppColors.textMuted))), Text('${journey.completedChallenges} completed', style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: AppColors.textMuted))]),
                        ],
                      ]),
                    ),
                  ),
                ]),
              ),
            );
          },
        );
      },
    );
  }
}
