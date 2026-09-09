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

class _DashboardDesignedScreenState extends State<DashboardDesignedScreen>
    with WidgetsBindingObserver {
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
    if (state == AppLifecycleState.resumed && mounted) {
      _load(force: true);
    }
  }

  Future<void> _load({bool force = false}) async {
    final style = context.read<PersonalStyleProvider>();
    if (force) {
      await style.refresh(force: true);
    } else {
      await style.refresh();
    }

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

    final recommendation = TodayRecommendationService().getTodayRecommendation(uid);
    final challenge = DailyChallengeService().getTodayChallenge(uid);
    final journey = TibStyleJourneyService().getJourney(uid);

    setState(() {
      _recommendationFuture = recommendation;
      _challengeFuture = challenge;
      _journeyFuture = journey;
    });

    try {
      final result = await challenge;
      if (!mounted || _requestUid != uid) return;
      setState(() => _challengeCompleted = result.isCompleted);
    } catch (_) {
      if (!mounted || _requestUid != uid) return;
      setState(() => _challengeCompleted = false);
    }
  }

  Future<void> _refresh() async {
    await _load(force: true);
  }

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
      await DailyChallengeService().completeChallenge(uid, challenge.id);
      if (!mounted || _requestUid != uid) return;
      setState(() {
        _challengeCompleted = true;
        _completingChallenge = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _completingChallenge = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save today\'s challenge.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<PersonalStyleProvider, TibSession>(
      builder: (context, style, session, _) {
        final user = style.user ?? session.profile;
        final firstName = (user?.displayName ?? '').trim().split(' ').first;
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
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'VYEA  /  STYLE COMMAND CENTER',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.4,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              greeting,
                              style: const TextStyle(
                                fontSize: 28,
                                height: 1.05,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -1,
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Your personal styling system, in one place.',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                                height: 1.45,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Refresh',
                        onPressed: _refresh,
                        icon: const Icon(Icons.refresh_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _welcomeCard(context, style),
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
                      _systemCard(
                        context,
                        icon: Icons.palette_outlined,
                        title: 'Colour Profile',
                        status: style.hasColourProfile ? 'Ready' : 'Set up',
                        subtitle: style.hasColourProfile
                            ? _colourSummary(style)
                            : 'Discover your colouring and face traits.',
                        onTap: () => _open(const AnalysisScreen()),
                      ),
                      _systemCard(
                        context,
                        icon: Icons.person_outline_rounded,
                        title: 'Personal TiB',
                        status: style.hasTiBModel ? 'Ready' : 'Set up',
                        subtitle: style.hasTiBModel
                            ? 'Your styling model is ready to use.'
                            : 'Create your personal model for better styling.',
                        onTap: () => _open(const CreateTibModelScreen()),
                      ),
                      _systemCard(
                        context,
                        icon: Icons.checkroom_outlined,
                        title: 'Wardrobe',
                        status: '${style.wardrobe.length} pieces',
                        subtitle: style.hasWardrobe
                            ? 'Your real wardrobe can power outfit decisions.'
                            : 'Add your first fashion item.',
                        onTap: () => _open(const WardrobeScreen()),
                      ),
                      _systemCard(
                        context,
                        icon: Icons.auto_awesome_rounded,
                        title: 'AI Stylist',
                        status: style.hasSavedLooks ? '${style.savedLooks.length} looks' : 'Explore',
                        subtitle: 'Generate looks from your personal context.',
                        onTap: () => _open(const AIHubScreen()),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  _sectionLabel('STYLE JOURNEY', 'Your progress builds as your profile gets smarter.'),
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
    final season = colour.season.isEmpty ? '' : colour.season;
    final face = colour.faceShape.isEmpty ? '' : colour.faceShape;
    if (season.isNotEmpty && face.isNotEmpty) return '$season · $face';
    if (season.isNotEmpty) return season;
    if (face.isNotEmpty) return face;
    return 'Colour profile available.';
  }

  Widget _welcomeCard(BuildContext context, PersonalStyleProvider style) {
    final completed = [
      style.hasColourProfile,
      style.hasTiBModel,
      style.hasWardrobe,
    ].where((value) => value).length;
    final progress = completed / 3;

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 17),
      decoration: BoxDecoration(
        gradient: AppGradients.soft,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: AppColors.primary,
                  size: 22,
                ),
              ),
              const Spacer(),
              _statusPill(completed == 3 ? 'READY' : '$completed/3 SET'),
            ],
          ),
          const SizedBox(height: 17),
          const Text(
            'Make the system yours.',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: -.6,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            completed == 3
                ? 'Your core styling inputs are ready to power more personal recommendations.'
                : 'Complete your colour profile, Personal TiB and wardrobe to make every recommendation more personal.',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11.5,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              minHeight: 7,
              value: progress,
              backgroundColor: Colors.white.withValues(alpha: .55),
              valueColor: const AlwaysStoppedAnimation(AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 9,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.35,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 11.5,
            height: 1.35,
          ),
        ),
      ],
    );
  }

  Widget _systemCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String status,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(21),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(21),
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(21),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 39,
                    height: 39,
                    decoration: const BoxDecoration(
                      color: AppColors.secondary,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: AppColors.primary, size: 19),
                  ),
                  const Spacer(),
                  Flexible(child: _statusPill(status)),
                ],
              ),
              const Spacer(),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 10.3,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _journeyCard() {
    return FutureBuilder<TibStyleJourney>(
      future: _journeyFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _loadingCard();
        }
        if (snapshot.hasError || snapshot.data == null) {
          return _emptyCard('Your style journey will appear here as you build more of your profile.');
        }

        final journey = snapshot.data!;
        return Container(
          padding: const EdgeInsets.all(17),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      journey.currentStage,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                    ),
                  ),
                  Text(
                    '${journey.progressPercent}%',
                    style: const TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w900),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                journey.description,
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 11, height: 1.4),
              ),
              const SizedBox(height: 13),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  minHeight: 7,
                  value: journey.progress.clamp(0, 1),
                  backgroundColor: AppColors.secondary,
                  valueColor: const AlwaysStoppedAnimation(AppColors.primary),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _todayCard() {
    return FutureBuilder<TodayRecommendation>(
      future: _recommendationFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _loadingCard();
        }
        if (snapshot.hasError || snapshot.data == null) {
          return _emptyCard('Your daily style signal will appear once your personal inputs are available.');
        }

        final recommendation = snapshot.data!;
        return Container(
          padding: const EdgeInsets.fromLTRB(17, 17, 14, 17),
          decoration: BoxDecoration(
            gradient: AppGradients.premium,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 45,
                height: 45,
                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                child: const Icon(Icons.wb_sunny_outlined, color: AppColors.primaryDark, size: 21),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      recommendation.title,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      recommendation.description,
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 10.8, height: 1.4),
                    ),
                    if (recommendation.actionLabel.isNotEmpty) ...[
                      const SizedBox(height: 9),
                      Text(
                        recommendation.actionLabel,
                        style: const TextStyle(color: AppColors.primary, fontSize: 9.5, fontWeight: FontWeight.w900),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _challengeCard() {
    return FutureBuilder<DailyChallenge>(
      future: _challengeFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _loadingCard();
        }
        if (snapshot.hasError || snapshot.data == null) {
          return _emptyCard('Your next style challenge will appear here.');
        }

        final challenge = snapshot.data!;
        final completed = _challengeCompleted || challenge.isCompleted;
        return Container(
          padding: const EdgeInsets.all(17),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(color: AppColors.secondary, shape: BoxShape.circle),
                child: Icon(
                  completed ? Icons.check_rounded : Icons.flag_outlined,
                  color: AppColors.primary,
                  size: 21,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(challenge.title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 5),
                    Text(
                      challenge.description,
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 10.8, height: 1.4),
                    ),
                    const SizedBox(height: 11),
                    if (completed)
                      const Text(
                        'Completed today',
                        style: TextStyle(color: AppColors.primary, fontSize: 9.5, fontWeight: FontWeight.w900),
                      )
                    else
                      Align(
                        alignment: Alignment.centerLeft,
                        child: OutlinedButton.icon(
                          onPressed: _completingChallenge ? null : () => _completeChallenge(challenge),
                          icon: _completingChallenge
                              ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 1.8))
                              : const Icon(Icons.check_rounded, size: 15),
                          label: const Text('Mark complete'),
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

  Widget _loadingCard() {
    return Container(
      height: 108,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      alignment: Alignment.center,
      child: const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }

  Widget _emptyCard(String text) {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        text,
        style: const TextStyle(color: AppColors.textSecondary, fontSize: 11, height: 1.45),
      ),
    );
  }

  Widget _statusPill(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .72),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: AppColors.primaryDark,
          fontSize: 7.8,
          fontWeight: FontWeight.w900,
          letterSpacing: .65,
        ),
      ),
    );
  }
}
