import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_gradients.dart';
import '../../core/session/tib_session.dart';
import '../../core/state/personal_style_provider.dart';
import '../../services/daily_challenge_service.dart';
import '../../services/tib_style_journey_service.dart';
import '../../services/today_recommendation_service.dart';
import '../ai/ai_hub_screen.dart';
import '../analysis/analysis_screen.dart';
import '../premium/create_tib_model_screen.dart';
import '../wardrobe/wardrobe_screen.dart';

class DashboardDesignedScreen extends StatefulWidget {
  const DashboardDesignedScreen({super.key});

  @override
  State<DashboardDesignedScreen> createState() => _DashboardDesignedScreenState();
}

class _DashboardDesignedScreenState extends State<DashboardDesignedScreen> with WidgetsBindingObserver {
  Future<TodayRecommendation>? _recommendationFuture;
  Future<DailyChallenge>? _challengeFuture;
  Future<TibStyleJourney>? _journeyFuture;
  bool _challengeCompleted = false;
  bool _completingChallenge = false;
  String? _requestUid;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) _load(force: true);
  }

  Future<void> _load({bool force = false}) async {
    final style = context.read<PersonalStyleProvider>();
    await style.refresh(force: force);
    if (!mounted) return;
    final uid = style.uid;
    _requestUid = uid;
    if (uid == null) {
      setState(() {
        _recommendationFuture = null;
        _challengeFuture = null;
        _journeyFuture = null;
        _challengeCompleted = false;
      });
      return;
    }

    final recommendation = TodayRecommendationService.getRecommendation(
      analysis: style.colourAnalysis,
      personalStyle: style.styles.isNotEmpty ? style.styles.first : null,
      wardrobe: style.wardrobe.map((item) => item.toMap()).toList(),
    );
    final challenge = DailyChallengeService.personalizedToday(uid, analysis: style.colourAnalysis);
    final journey = TibStyleJourneyService.load(uid);

    if (!mounted) return;
    setState(() {
      _recommendationFuture = recommendation;
      _challengeFuture = challenge;
      _journeyFuture = journey;
      _challengeCompleted = false;
    });

    try {
      await challenge;
      if (!mounted || _requestUid != uid) return;
      final completed = await DailyChallengeService.isCompleted(uid);
      if (!mounted || _requestUid != uid) return;
      setState(() => _challengeCompleted = completed);
    } catch (_) {
      if (!mounted || _requestUid != uid) return;
      setState(() => _challengeCompleted = false);
    }
  }

  Future<void> _refresh() => _load(force: true);

  Future<void> _open(Widget screen) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    if (mounted) await _load(force: true);
  }

  Future<void> _completeChallenge(DailyChallenge challenge) async {
    if (_completingChallenge || _challengeCompleted) return;
    final uid = context.read<PersonalStyleProvider>().uid;
    if (uid == null) return;
    setState(() => _completingChallenge = true);
    try {
      final saved = await DailyChallengeService.complete(uid, challenge: challenge);
      if (!mounted || _requestUid != uid) return;
      if (!saved) {
        setState(() => _completingChallenge = false);
        return;
      }
      setState(() {
        _challengeCompleted = true;
        _completingChallenge = false;
      });
      _journeyFuture = TibStyleJourneyService.load(uid);
    } catch (_) {
      if (!mounted) return;
      setState(() => _completingChallenge = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Could not save today's challenge.")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<PersonalStyleProvider, TibSession>(
      builder: (context, style, session, _) {
        final profile = style.profile ?? session.profile;
        final rawName = profile?.name.trim() ?? '';
        final firstName = rawName.isEmpty ? '' : rawName.split(RegExp(r'\s+')).first;
        final greeting = firstName.isEmpty ? 'Your style space' : 'Welcome back, $firstName';

        return Scaffold(
          backgroundColor: AppColors.background,
          body: SafeArea(
            child: RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 38),
                children: [
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('VYEA  /  STYLE COMMAND CENTER', style: TextStyle(color: AppColors.primary, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1.4)),
                      const SizedBox(height: 8),
                      Text(greeting, style: const TextStyle(fontSize: 28, height: 1.05, fontWeight: FontWeight.w900, letterSpacing: -1)),
                      const SizedBox(height: 6),
                      const Text('Your personal styling system, in one place.', style: TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.45)),
                    ])),
                    IconButton(tooltip: 'Refresh', onPressed: _refresh, icon: const Icon(Icons.refresh_rounded)),
                  ]),
                  const SizedBox(height: 18),
                  _welcomeCard(style),
                  const SizedBox(height: 20),
                  _sectionLabel('PERSONAL SYSTEM', 'The foundation behind your recommendations.'),
                  const SizedBox(height: 11),
                  GridView.count(
                    crossAxisCount: 2,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 1.13,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _systemCard(icon: Icons.palette_outlined, title: 'Colour Profile', status: style.hasColourProfile ? 'Ready' : 'Set up', subtitle: style.hasColourProfile ? _colourSummary(style) : 'Discover your colouring and face traits.', onTap: () => _open(const AnalysisScreen())),
                      _systemCard(icon: Icons.person_outline_rounded, title: 'Personal TiB', status: style.hasTiBModel ? 'Ready' : 'Set up', subtitle: style.hasTiBModel ? 'Your styling model is ready to use.' : 'Create your personal model for better styling.', onTap: () => _open(const CreateTibModelScreen())),
                      _systemCard(icon: Icons.checkroom_outlined, title: 'Wardrobe', status: '${style.wardrobe.length} pieces', subtitle: style.hasWardrobe ? 'Your real wardrobe can power outfit decisions.' : 'Add your first fashion item.', onTap: () => _open(const WardrobeScreen())),
                      _systemCard(icon: Icons.auto_awesome_rounded, title: 'AI Stylist', status: style.hasSavedLooks ? '${style.savedLooks.length} looks' : 'Explore', subtitle: 'Generate looks from your personal context.', onTap: () => _open(const AIHubScreen())),
                    ],
                  ),
                  const SizedBox(height: 22),
                  _sectionLabel('STYLE JOURNEY', 'Your progress builds as you use TiB.'),
                  const SizedBox(height: 11),
                  _journeyCard(),
                  const SizedBox(height: 22),
                  _sectionLabel('TODAY', 'A small signal to help you style with intention.'),
                  const SizedBox(height: 11),
                  _todayCard(),
                  const SizedBox(height: 22),
                  _sectionLabel('DAILY CHALLENGE', 'One simple action. A little more style confidence.'),
                  const SizedBox(height: 11),
                  _challengeCard(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _colourSummary(PersonalStyleProvider style) {
    final colour = style.colourAnalysis;
    if (colour == null) return 'Colour profile available.';
    final season = colour.season.trim();
    final face = colour.faceShape.trim();
    if (season.isNotEmpty && face.isNotEmpty) return '$season · $face';
    if (season.isNotEmpty) return season;
    if (face.isNotEmpty) return face;
    return 'Colour profile available.';
  }

  Widget _welcomeCard(PersonalStyleProvider style) {
    final completed = [style.hasColourProfile, style.hasTiBModel, style.hasWardrobe].where((value) => value).length;
    final progress = completed / 3;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 17),
      decoration: BoxDecoration(gradient: AppGradients.soft, borderRadius: BorderRadius.circular(26), border: Border.all(color: AppColors.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 46, height: 46, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle), child: const Icon(Icons.auto_awesome_rounded, color: AppColors.primary, size: 22)),
          const Spacer(),
          _statusPill(completed == 3 ? 'READY' : '$completed/3 SET'),
        ]),
        const SizedBox(height: 17),
        const Text('Make the system yours.', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -.6)),
        const SizedBox(height: 6),
        Text(completed == 3 ? 'Your core styling inputs are ready to power more personal recommendations.' : 'Complete your colour profile, Personal TiB and wardrobe to make every recommendation more personal.', style: const TextStyle(color: AppColors.textSecondary, fontSize: 11.5, height: 1.45)),
        const SizedBox(height: 14),
        ClipRRect(borderRadius: BorderRadius.circular(10), child: LinearProgressIndicator(minHeight: 7, value: progress, backgroundColor: Colors.white.withValues(alpha: .55), valueColor: const AlwaysStoppedAnimation(AppColors.primary))),
      ]),
    );
  }

  Widget _sectionLabel(String title, String subtitle) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(color: AppColors.textMuted, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1.35)), const SizedBox(height: 4), Text(subtitle, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11.5, height: 1.35))]);

  Widget _systemCard({required IconData icon, required String title, required String status, required String subtitle, required VoidCallback onTap}) {
    return Material(color: Colors.transparent, borderRadius: BorderRadius.circular(21), child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(21), child: Ink(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(21), border: Border.all(color: AppColors.border)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Container(width: 39, height: 39, decoration: const BoxDecoration(color: AppColors.secondary, shape: BoxShape.circle), child: Icon(icon, color: AppColors.primary, size: 19)), const Spacer(), Flexible(child: _statusPill(status))]),
      const Spacer(),
      Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
      const SizedBox(height: 4),
      Text(subtitle, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.textSecondary, fontSize: 10.3, height: 1.35)),
    ]))));
  }

  Widget _journeyCard() {
    return FutureBuilder<TibStyleJourney>(future: _journeyFuture, builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) return _loadingCard();
      if (snapshot.hasError || snapshot.data == null) return _emptyCard('Your style journey will appear here as you build more of your profile.');
      final journey = snapshot.data!;
      return Container(padding: const EdgeInsets.all(17), decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(22), border: Border.all(color: AppColors.border)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Expanded(child: Text(journey.levelTitle, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900))), Text('${(journey.progress * 100).round()}%', style: const TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w900))]),
        const SizedBox(height: 8),
        Text('${journey.points} XP · ${journey.streak} day streak · ${journey.completedChallenges} challenges', style: const TextStyle(color: AppColors.textSecondary, fontSize: 11, height: 1.4)),
        const SizedBox(height: 13),
        ClipRRect(borderRadius: BorderRadius.circular(10), child: LinearProgressIndicator(minHeight: 7, value: journey.progress.clamp(0.0, 1.0), backgroundColor: AppColors.secondary, valueColor: const AlwaysStoppedAnimation(AppColors.primary))),
      ]));
    });
  }

  Widget _todayCard() {
    return FutureBuilder<TodayRecommendation>(future: _recommendationFuture, builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) return _loadingCard();
      if (snapshot.hasError || snapshot.data == null) return _emptyCard('Your daily style signal will appear once your personal inputs are available.');
      final recommendation = snapshot.data!;
      return Container(padding: const EdgeInsets.fromLTRB(17, 17, 14, 17), decoration: BoxDecoration(gradient: AppGradients.premium, borderRadius: BorderRadius.circular(22), border: Border.all(color: AppColors.border)), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(width: 45, height: 45, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle), child: const Icon(Icons.wb_sunny_outlined, color: AppColors.primaryDark, size: 21)),
        const SizedBox(width: 13),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Expanded(child: Text(recommendation.style, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900))), if (recommendation.isAiGenerated) _statusPill('AI')]),
          const SizedBox(height: 5),
          Text(recommendation.outfit, style: const TextStyle(fontSize: 11.2, height: 1.4)),
          const SizedBox(height: 6),
          Text(recommendation.reason, style: const TextStyle(color: AppColors.textSecondary, fontSize: 10.5, height: 1.35)),
          if (recommendation.stylingTip.trim().isNotEmpty) ...[
            const SizedBox(height: 7),
            Text('Tip · ${recommendation.stylingTip}', style: const TextStyle(color: AppColors.primaryDark, fontSize: 10.3, fontWeight: FontWeight.w700, height: 1.35)),
          ],
        ])),
      ]));
    });
  }

  Widget _challengeCard() {
    return FutureBuilder<DailyChallenge>(future: _challengeFuture, builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) return _loadingCard();
      if (snapshot.hasError || snapshot.data == null) return _emptyCard('Your next personal styling challenge will appear here.');
      final challenge = snapshot.data!;
      final completed = _challengeCompleted;
      return Container(padding: const EdgeInsets.all(17), decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(22), border: Border.all(color: AppColors.border)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Container(width: 44, height: 44, decoration: const BoxDecoration(color: AppColors.secondary, shape: BoxShape.circle), child: const Icon(Icons.checkroom_outlined, color: AppColors.primary, size: 21)), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(challenge.category.toUpperCase(), style: const TextStyle(color: AppColors.textMuted, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 1)), const SizedBox(height: 3), Text(challenge.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900))])), _statusPill('${challenge.points} XP')]),
        const SizedBox(height: 11),
        Text(challenge.description, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11, height: 1.4)),
        const SizedBox(height: 13),
        SizedBox(width: double.infinity, child: FilledButton(onPressed: completed || _completingChallenge ? null : () => _completeChallenge(challenge), child: Text(_completingChallenge ? 'Saving…' : completed ? 'Completed today' : 'Mark as completed'))),
      ]));
    });
  }

  Widget _statusPill(String text) => Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5), decoration: BoxDecoration(color: AppColors.secondary.withValues(alpha: .65), borderRadius: BorderRadius.circular(999)), child: Text(text, style: const TextStyle(color: AppColors.primaryDark, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: .7)));

  Widget _loadingCard() => Container(height: 92, decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(22), border: Border.all(color: AppColors.border)), alignment: Alignment.center, child: const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)));

  Widget _emptyCard(String text) => Container(padding: const EdgeInsets.all(17), decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(22), border: Border.all(color: AppColors.border)), child: Text(text, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11, height: 1.4)));
}
