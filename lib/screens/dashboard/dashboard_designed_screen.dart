import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_gradients.dart';
import '../../core/session/tib_session.dart';
import '../../core/state/personal_style_provider.dart';
import '../../services/daily_challenge_service.dart';
import '../../services/tib_style_journey_service.dart';
import '../../services/today_recommendation_service.dart';
import '../../widgets/colour_swatch.dart';
import '../ai/ai_hub_screen.dart';
import '../analysis/analysis_screen.dart';
import '../premium/create_tib_model_screen.dart';
import '../wardrobe/wardrobe_screen.dart';

class DashboardDesignedScreen extends StatefulWidget {
  const DashboardDesignedScreen({super.key});

  @override
  State<DashboardDesignedScreen> createState() => _DashboardDesignedScreenState();
}

class _DashboardDesignedScreenState extends State<DashboardDesignedScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  Future<TodayRecommendation>? _recommendationFuture;
  Future<DailyChallenge>? _challengeFuture;
  Future<TibStyleJourney>? _journeyFuture;
  bool _challengeCompleted = false;
  bool _completingChallenge = false;
  bool _refreshing = false;

  late final AnimationController _revealController;
  late final Animation<double> _heroReveal;
  late final Animation<double> _systemReveal;
  late final Animation<double> _journeyReveal;
  late final Animation<double> _todayReveal;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _revealController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 780),
    )..forward();
    _heroReveal = _stage(0, .24);
    _systemReveal = _stage(.10, .52);
    _journeyReveal = _stage(.28, .75);
    _todayReveal = _stage(.52, 1);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Animation<double> _stage(double begin, double end) => CurvedAnimation(
        parent: _revealController,
        curve: Interval(begin, end, curve: Curves.easeOutCubic),
      );

  Widget _reveal(Animation<double> animation, Widget child) => AnimatedBuilder(
        animation: animation,
        builder: (_, animatedChild) {
          final value = animation.value.clamp(0.0, 1.0);
          return Opacity(
            opacity: value,
            child: Transform.translate(
              offset: Offset(0, (1 - value) * 10),
              child: animatedChild,
            ),
          );
        },
        child: child,
      );

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load(force: true);
  }

  Future<void> _load({bool force = false}) async {
    if (!mounted) return;
    final style = context.read<PersonalStyleProvider>();
    final uid = style.uid;
    if (uid == null) return;
    await style.refresh(force: force);
    if (!mounted || style.uid != uid) return;

    _recommendationFuture = TodayRecommendationService.getRecommendation(
      analysis: style.colourAnalysis,
      personalStyle: style.styles.isEmpty ? null : style.styles.take(3).join(', '),
    );
    _challengeFuture = DailyChallengeService.personalizedToday(uid, analysis: style.colourAnalysis);
    _journeyFuture = TibStyleJourneyService.load(uid);
    try {
      _challengeCompleted = await DailyChallengeService.isCompleted(uid);
    } catch (_) {
      _challengeCompleted = false;
    }
    if (!mounted || style.uid != uid) return;
    setState(() {});
  }

  Future<void> _refresh() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    try {
      await _load(force: true);
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  Future<void> _completeChallenge() async {
    final style = context.read<PersonalStyleProvider>();
    final uid = style.uid;
    if (uid == null || _challengeCompleted || _completingChallenge) return;
    setState(() => _completingChallenge = true);
    try {
      final challenge = await (_challengeFuture ?? Future.value(DailyChallengeService.today()));
      final completed = await DailyChallengeService.complete(uid, challenge: challenge);
      if (!mounted || style.uid != uid) return;
      setState(() {
        _challengeCompleted = completed || _challengeCompleted;
        _journeyFuture = TibStyleJourneyService.load(uid);
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not update today’s style move. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _completingChallenge = false);
    }
  }

  Future<void> _open(Widget screen) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
    if (!mounted) return;
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<TibSession>();
    final style = context.watch<PersonalStyleProvider>();
    final colour = style.colourAnalysis;
    final profileName = session.profile?.name.trim();
    final authName = session.user?.displayName?.trim();
    final firstName = (profileName?.isNotEmpty ?? false)
        ? profileName!.split(RegExp(r'\s+')).first
        : (authName?.isNotEmpty ?? false)
            ? authName!.split(RegExp(r'\s+')).first
            : 'there';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 34),
            children: [
              _reveal(_heroReveal, _welcomeCard(firstName, style, colour, session)),
              const SizedBox(height: 22),
              _sectionHeading('YOUR PERSONAL SYSTEM', 'Four signals working together to style you.'),
              const SizedBox(height: 11),
              _reveal(_systemReveal, _personalSystem(style)),
              const SizedBox(height: 22),
              _sectionHeading('YOUR STYLE JOURNEY', 'Progress that stays personal.'),
              const SizedBox(height: 11),
              _reveal(_journeyReveal, _journeyCard()),
              const SizedBox(height: 22),
              _sectionHeading('TODAY', 'One useful signal. One small action.'),
              const SizedBox(height: 11),
              _reveal(_todayReveal, _todayCard(style)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _welcomeCard(String firstName, PersonalStyleProvider style, dynamic colour, TibSession session) {
    return Container(
      padding: const EdgeInsets.fromLTRB(21, 20, 21, 19),
      decoration: BoxDecoration(
        gradient: AppGradients.soft,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('VYEA', style: TextStyle(color: AppColors.brown, fontSize: 10.5, fontWeight: FontWeight.w900, letterSpacing: 3.4)),
              ),
              if (style.isLoading || _refreshing)
                const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              else
                _statusPill(style, session),
            ],
          ),
          const SizedBox(height: 19),
          Text(
            'Good to see you, $firstName.',
            style: const TextStyle(color: AppColors.primaryDark, fontSize: 29, height: 1.04, fontWeight: FontWeight.w800, letterSpacing: -.8),
          ),
          const SizedBox(height: 8),
          const Text(
            'TiB brings your colour, body, wardrobe and personal taste into one styling system.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5, height: 1.5),
          ),
          const SizedBox(height: 16),
          _contextStrip(style),
          if (colour != null && (colour.season.isNotEmpty || colour.faceShape.isNotEmpty)) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(color: AppColors.surface.withValues(alpha: .72), borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
              child: Row(children: [
                const Icon(Icons.auto_awesome_outlined, size: 17, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(child: Text('${colour.season} · ${colour.undertone} · ${colour.brightness}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.2, fontWeight: FontWeight.w800, color: AppColors.primaryDark))),
                if (colour.faceShape != 'Unknown') Text(colour.faceShape, style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w900, color: AppColors.textSecondary)),
              ]),
            ),
          ],
        ],
      ),
    );
  }

  Widget _statusPill(PersonalStyleProvider style, TibSession session) {
    final label = !session.isSignedIn
        ? 'OFFLINE'
        : style.hasColourProfile && style.hasWardrobe && style.hasTiBModel
            ? 'PROFILE READY'
            : 'PROFILE BUILDING';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
      child: Text(label, style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.w900, letterSpacing: .9, color: AppColors.primaryDark)),
    );
  }

  Widget _contextStrip(PersonalStyleProvider style) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: AppColors.surfaceMuted, borderRadius: BorderRadius.circular(17), border: Border.all(color: AppColors.border)),
      child: Row(children: [
        Expanded(child: _metric('${style.wardrobe.length}', 'wardrobe')),
        _divider(),
        Expanded(child: _metric('${style.savedLooks.length}', 'saved looks')),
        _divider(),
        Expanded(child: _metric('${style.styles.length}', 'style choices')),
      ]),
    );
  }

  Widget _personalSystem(PersonalStyleProvider style) {
    return Column(children: [
      Row(children: [
        Expanded(child: _systemCard(icon: Icons.palette_outlined, title: 'Colour profile', value: style.hasColourProfile ? style.colourAnalysis!.season : 'Not analysed', detail: style.hasColourProfile ? '${style.colourAnalysis!.undertone} · ${style.colourAnalysis!.brightness}' : 'Find your palette and face shape', onTap: () => _open(const AnalysisScreen()))),
        const SizedBox(width: 10),
        Expanded(child: _systemCard(icon: Icons.accessibility_new_rounded, title: 'Personal TiB', value: style.hasTiBModel ? style.tibModel!.bodyShape : 'Not built', detail: style.hasTiBModel ? '${style.tibModel!.faceShape} · ${style.tibModel!.height.toStringAsFixed(0)} cm' : 'Add your body reference', onTap: () => _open(const CreateTibModelScreen()))),
      ]),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(child: _systemCard(icon: Icons.checkroom_outlined, title: 'Wardrobe', value: '${style.wardrobe.length} pieces', detail: style.favouriteCount > 0 ? '${style.favouriteCount} favourites' : 'Build your personal wardrobe', onTap: () => _open(const WardrobeScreen()))),
        const SizedBox(width: 10),
        Expanded(child: _systemCard(icon: Icons.auto_awesome_outlined, title: 'AI Stylist', value: style.hasColourProfile && style.hasWardrobe ? 'Ready' : 'Needs setup', detail: style.hasColourProfile && style.hasWardrobe ? 'Personal outfit recommendations' : 'Complete colour + wardrobe', onTap: () => _open(const AIHubScreen()))),
      ]),
    ]);
  }

  Widget _systemCard({required IconData icon, required String title, required String value, required String detail, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(21),
      child: Ink(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(21), border: Border.all(color: AppColors.border)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(width: 38, height: 38, decoration: const BoxDecoration(color: AppColors.secondary, shape: BoxShape.circle), child: Icon(icon, size: 18, color: AppColors.primary)),
            const Spacer(),
            const Icon(Icons.arrow_outward_rounded, size: 16, color: AppColors.textMuted),
          ]),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: AppColors.primaryDark)),
          const SizedBox(height: 4),
          Text(detail, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 9.8, color: AppColors.textSecondary, height: 1.35)),
        ]),
      ),
    );
  }

  Widget _journeyCard() {
    return FutureBuilder<TibStyleJourney>(
      future: _journeyFuture,
      builder: (_, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting || snapshot.data == null) {
          return _card(const Row(children: [CircularProgressIndicator(strokeWidth: 2), SizedBox(width: 12), Expanded(child: Text('Loading your style journey…', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)))]));
        }
        final journey = snapshot.data!;
        final span = (journey.nextLevelPoints - journey.currentLevelPoints).clamp(1, 1000000);
        final progress = ((journey.points - journey.currentLevelPoints) / span).clamp(0.0, 1.0).toDouble();
        return _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(width: 46, height: 46, decoration: const BoxDecoration(gradient: AppGradients.primary, shape: BoxShape.circle), child: const Icon(Icons.auto_awesome_rounded, color: Colors.white)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Level ${journey.level} · ${journey.levelTitle}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900)), const SizedBox(height: 3), Text('${journey.points} XP · ${journey.streak} day streak', style: const TextStyle(fontSize: 10.5, color: AppColors.textSecondary))])),
            Text('${journey.completedChallenges}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.primary)),
          ]),
          const SizedBox(height: 15),
          ClipRRect(borderRadius: BorderRadius.circular(20), child: LinearProgressIndicator(value: progress, minHeight: 7, backgroundColor: AppColors.surfaceMuted)),
          const SizedBox(height: 7),
          Row(children: [const Text('NEXT LEVEL', style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w900, color: AppColors.textMuted, letterSpacing: .9)), const Spacer(), Text('${journey.points} / ${journey.nextLevelPoints} XP', style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: AppColors.textSecondary))]),
        ]));
      },
    );
  }

  Widget _todayCard(PersonalStyleProvider style) {
    return _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      FutureBuilder<TodayRecommendation>(
        future: _recommendationFuture,
        builder: (_, snapshot) {
          final recommendation = snapshot.data;
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [const Icon(Icons.lightbulb_outline_rounded, color: AppColors.primary), const SizedBox(width: 9), const Text('STYLE SIGNAL', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: AppColors.textMuted, letterSpacing: 1))]),
            const SizedBox(height: 8),
            Text(recommendation?.style.isNotEmpty == true ? recommendation!.style : style.hasColourProfile ? 'Start with your personal palette and build around one piece you already love.' : 'Complete your colour profile to unlock a stronger daily styling signal.', style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w900, height: 1.15, color: AppColors.primaryDark)),
            if (recommendation != null && recommendation.reason.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(recommendation.reason, style: const TextStyle(fontSize: 10.5, color: AppColors.textSecondary, height: 1.45)),
            ],
          ]);
        },
      ),
      const SizedBox(height: 16),
      Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(color: AppColors.surfaceMuted, borderRadius: BorderRadius.circular(17), border: Border.all(color: AppColors.border)),
        child: Row(children: [
          const Icon(Icons.flag_outlined, size: 18, color: AppColors.primary),
          const SizedBox(width: 9),
          Expanded(child: FutureBuilder<DailyChallenge>(
            future: _challengeFuture,
            builder: (_, snapshot) {
              final challenge = snapshot.data;
              return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(challenge?.title ?? 'Today’s style move', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w900)),
                const SizedBox(height: 3),
                Text(challenge?.description ?? 'Build one small styling habit today.', style: const TextStyle(fontSize: 9.8, color: AppColors.textSecondary, height: 1.35)),
              ]);
            },
          )),
          const SizedBox(width: 8),
          FilledButton(onPressed: _challengeCompleted || _completingChallenge ? null : _completeChallenge, child: Text(_challengeCompleted ? 'Done' : _completingChallenge ? '…' : 'Done')),
        ]),
      ),
    ]));
  }

  Widget _sectionHeading(String title, String subtitle) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.35)), const SizedBox(height: 4), Text(subtitle, style: const TextStyle(fontSize: 12.2, color: AppColors.textSecondary, height: 1.35))]);

  Widget _card(Widget child) => Container(padding: const EdgeInsets.all(18), decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(22), border: Border.all(color: AppColors.border)), child: child);

  Widget _metric(String value, String label) => Column(children: [Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: AppColors.primary)), const SizedBox(height: 2), Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 8.5, color: AppColors.textSecondary))]);

  Widget _divider() => Container(width: 1, height: 26, color: AppColors.border);
}
