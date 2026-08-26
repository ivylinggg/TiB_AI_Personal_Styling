import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_gradients.dart';
import '../../models/colour_analysis_result.dart';
import '../../providers/analysis_provider.dart';
import '../../services/daily_challenge_service.dart';
import '../../services/today_recommendation_service.dart';
import '../../widgets/colour_swatch.dart';
import '../analysis/analysis_result_screen.dart';
import '../analysis/analysis_screen.dart';
import 'daily_challenge_screen.dart';

class DashboardDesignedScreen extends StatefulWidget {
  const DashboardDesignedScreen({super.key});

  @override
  State<DashboardDesignedScreen> createState() => _DashboardDesignedScreenState();
}

class _DashboardDesignedScreenState extends State<DashboardDesignedScreen> {
  Future<TodayRecommendation>? _recommendationFuture;

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

    if (_recommendationFuture == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadRecommendation());
    }

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
              _dailyChallengeCard(context, uid),
            ],
          ),
        ),
      ),
    );
  }

  Widget _todayRecommendationCard(BuildContext context, ColourAnalysisResult? result) {
    final target = result == null
        ? const AnalysisScreen()
        : AnalysisResultScreen(analysisProvider: context.read<AnalysisProvider>(), result: result);

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
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => target)),
            child: Ink(
              decoration: BoxDecoration(
                gradient: AppGradients.soft,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.primarySoft),
                boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: .06), blurRadius: 18, offset: const Offset(0, 7))],
              ),
              padding: const EdgeInsets.fromLTRB(18, 17, 18, 17),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const Expanded(child: Text("TODAY'S RECOMMENDATION", style: TextStyle(color: AppColors.textMuted, fontSize: 9.5, fontWeight: FontWeight.w900, letterSpacing: .75))),
                  if (aiReady) Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4), decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: .10), borderRadius: BorderRadius.circular(9)), child: const Text('AI', style: TextStyle(color: AppColors.primaryDark, fontSize: 7.5, fontWeight: FontWeight.w900, letterSpacing: .7))),
                  const SizedBox(width: 7),
                  Text('${DateTime.now().day}/${DateTime.now().month}', style: const TextStyle(color: AppColors.textMuted, fontSize: 9, fontWeight: FontWeight.w800)),
                ]),
                const SizedBox(height: 16),
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(width: 58, height: 58, decoration: const BoxDecoration(color: AppColors.primarySoft, shape: BoxShape.circle), child: Icon(aiReady ? Icons.auto_awesome_rounded : Icons.checkroom_rounded, color: AppColors.primaryDark, size: 25)),
                  const SizedBox(width: 13),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(recommendation.style, style: const TextStyle(fontSize: 20, height: 1.1, fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
                    const SizedBox(height: 8),
                    Wrap(spacing: 6, runSpacing: 6, children: recommendation.tags.map(_styleTag).toList()),
                  ])),
                ]),
                const SizedBox(height: 13),
                Text(result == null ? 'Complete your colour analysis to unlock personalised styling.' : recommendation.reason, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11, height: 1.45)),
                const SizedBox(height: 13),
                _recommendationOutfit(recommendation),
                if (recommendation.stylingTip.isNotEmpty) ...[const SizedBox(height: 9), _recommendationTip(recommendation.stylingTip)],
                const SizedBox(height: 9),
                _recommendationColour(result, recommendation.colour),
              ]),
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
      padding: const EdgeInsets.fromLTRB(18, 17, 18, 17),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [const Expanded(child: Text("TODAY'S RECOMMENDATION", style: TextStyle(color: AppColors.textMuted, fontSize: 9.5, fontWeight: FontWeight.w900, letterSpacing: .75))), SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 1.8, color: AppColors.primary))]),
        const SizedBox(height: 18),
        const Row(children: [SizedBox(width: 58, height: 58, child: DecoratedBox(decoration: BoxDecoration(color: AppColors.primarySoft, shape: BoxShape.circle))), SizedBox(width: 13), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [SizedBox(width: 150, height: 17, child: DecoratedBox(decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.all(Radius.circular(8))))), SizedBox(height: 9), SizedBox(width: 190, height: 12, child: DecoratedBox(decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.all(Radius.circular(8)))))]))]),
        const SizedBox(height: 16),
        const Text('Creating a recommendation around your personal profile…', style: TextStyle(color: AppColors.textSecondary, fontSize: 11, height: 1.45)),
      ]),
    ),
  );

  Widget _recommendationOutfit(TodayRecommendation recommendation) => Container(
    padding: const EdgeInsets.fromLTRB(11, 10, 11, 10),
    decoration: BoxDecoration(color: AppColors.background.withValues(alpha: .72), borderRadius: BorderRadius.circular(15), border: Border.all(color: AppColors.border)),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [const Icon(Icons.checkroom_rounded, color: AppColors.primary, size: 19), const SizedBox(width: 9), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text("TRY THIS TODAY", style: TextStyle(color: AppColors.textMuted, fontSize: 7.8, fontWeight: FontWeight.w900, letterSpacing: .55)), const SizedBox(height: 3), Text(recommendation.outfit, style: const TextStyle(fontSize: 10.5, height: 1.35, fontWeight: FontWeight.w700, color: AppColors.textPrimary))]))]),
  );

  Widget _recommendationTip(String tip) => Container(
    padding: const EdgeInsets.fromLTRB(11, 10, 11, 10),
    decoration: BoxDecoration(color: AppColors.background.withValues(alpha: .55), borderRadius: BorderRadius.circular(15), border: Border.all(color: AppColors.border)),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [const Icon(Icons.lightbulb_outline_rounded, color: AppColors.primary, size: 18), const SizedBox(width: 9), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('STYLING TIP', style: TextStyle(color: AppColors.textMuted, fontSize: 7.8, fontWeight: FontWeight.w900, letterSpacing: .55)), const SizedBox(height: 3), Text(tip, style: const TextStyle(fontSize: 10.2, height: 1.35, color: AppColors.textSecondary))]))]),
  );

  Widget _recommendationColour(ColourAnalysisResult? result, String colour) => Container(
    padding: const EdgeInsets.fromLTRB(10, 9, 9, 9),
    decoration: BoxDecoration(color: AppColors.background.withValues(alpha: .72), borderRadius: BorderRadius.circular(15), border: Border.all(color: AppColors.border)),
    child: Row(children: [ColourSwatch(name: colour, size: 24), const SizedBox(width: 9), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text("TODAY'S COLOUR", style: TextStyle(color: AppColors.textMuted, fontSize: 7.8, fontWeight: FontWeight.w900, letterSpacing: .55)), const SizedBox(height: 2), Text(result == null ? 'Complete your colour analysis' : colour, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: AppColors.textPrimary))])), const Icon(Icons.arrow_forward_ios_rounded, color: AppColors.primary, size: 14)]),
  );

  Widget _styleTag(String label) => Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5), decoration: BoxDecoration(color: AppColors.primarySoft.withValues(alpha: .68), borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.primarySoft)), child: Text(label, style: const TextStyle(fontSize: 8.8, fontWeight: FontWeight.w800, color: AppColors.primaryDark)));

  Widget _dailyChallengeCard(BuildContext context, String? uid) {
    final challenge = DailyChallengeService.today();
    return FutureBuilder<bool>(
      future: uid == null ? Future.value(false) : DailyChallengeService.isCompleted(uid),
      builder: (context, snapshot) {
        final completed = snapshot.data == true;
        return Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DailyChallengeScreen())),
            child: Ink(
              padding: const EdgeInsets.fromLTRB(17, 16, 17, 16),
              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(22), border: Border.all(color: AppColors.border)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(width: 44, height: 44, decoration: const BoxDecoration(color: AppColors.primarySoft, shape: BoxShape.circle), child: Icon(completed ? Icons.check_rounded : Icons.bolt_rounded, color: AppColors.primaryDark, size: 22)),
                  const SizedBox(width: 12),
                  const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('DAILY CHALLENGE', style: TextStyle(color: AppColors.textMuted, fontSize: 8.5, fontWeight: FontWeight.w900, letterSpacing: .7)), SizedBox(height: 4), Text('One small action. Better style.', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: AppColors.textPrimary))])),
                  Text('+${challenge.points} XP', style: const TextStyle(color: AppColors.primaryDark, fontSize: 10, fontWeight: FontWeight.w900)),
                ]),
                const SizedBox(height: 14),
                Text(challenge.title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
                const SizedBox(height: 5),
                Text(challenge.description, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, height: 1.4, color: AppColors.textSecondary)),
                const SizedBox(height: 12),
                Row(children: [Expanded(child: Text(completed ? 'Completed today ✓' : 'Tap to complete today’s task', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: completed ? AppColors.primaryDark : AppColors.textMuted))), const Icon(Icons.arrow_forward_ios_rounded, size: 13, color: AppColors.primary)]),
              ]),
            ),
          ),
        );
      },
    );
  }
}
