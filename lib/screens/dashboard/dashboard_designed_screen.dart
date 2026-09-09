import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_gradients.dart';
import '../../models/colour_analysis_result.dart';
import '../../providers/analysis_provider.dart';
import '../../services/daily_challenge_service.dart';
import '../../services/firestore_service.dart';
import '../../services/style_preference_service.dart';
import '../../services/tib_style_journey_service.dart';
import '../../services/today_recommendation_service.dart';
import '../../widgets/colour_swatch.dart';
import '../ai/ai_stylist_screen.dart';
import '../wardrobe/wardrobe_screen.dart';
import 'tib_style_journey_screen.dart';

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
  bool _refreshingFromLifecycle = false;
  bool _loadingContext = false;
  bool _dashboardLoaded = false;
  String? _loadedUid;
  List<String> _stylePreferences = const [];
  int _wardrobeCount = 0;
  int _savedLookCount = 0;

  late final AnimationController _revealController;
  late final Animation<double> _heroReveal;
  late final Animation<double> _profileReveal;
  late final Animation<double> _journeyReveal;
  late final Animation<double> _taskReveal;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _revealController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    );
    _heroReveal = _stage(0.00, 0.30);
    _profileReveal = _stage(0.14, 0.52);
    _journeyReveal = _stage(0.30, 0.76);
    _taskReveal = _stage(0.52, 1.00);
    _revealController.forward();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadDashboard(force: true));
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
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshWhenResumed();
    }
  }

  Future<void> _refreshWhenResumed() async {
    if (!mounted || _refreshingFromLifecycle) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    _refreshingFromLifecycle = true;
    try {
      // Only refresh persistent context when the app actually returns to the
      // foreground. Do not rebuild the whole dashboard on every provider tick.
      final provider = context.read<AnalysisProvider>();
      await provider.loadLatestResult(uid);
      await _loadPersonalContext(uid, force: true);
      if (!mounted) return;
      _loadDashboard(uid: uid, force: true);
    } finally {
      _refreshingFromLifecycle = false;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _revealController.dispose();
    super.dispose();
  }

  Future<void> _loadPersonalContext(String uid, {bool force = false}) async {
    if (!force && (_loadingContext || _loadedUid == uid)) return;
    if (_loadingContext) return;

    _loadingContext = true;
    try {
      final results = await Future.wait<dynamic>([
        StylePreferenceService.getStylePreferences(uid),
        FirestoreService.getWardrobeItems(uid),
        FirestoreService.getSavedOutfitLooks(uid),
      ]);
      if (!mounted || FirebaseAuth.instance.currentUser?.uid != uid) return;

      final preferences = results[0] as Map<String, dynamic>?;
      final wardrobe = results[1] as List;
      final savedLooks = results[2] as List;
      setState(() {
        _stylePreferences = List<String>.from(preferences?['styles'] ?? const []);
        _wardrobeCount = wardrobe.length;
        _savedLookCount = savedLooks.length;
        _loadedUid = uid;
      });
    } catch (_) {
      // Secondary dashboard context is optional. Keep the page usable.
    } finally {
      _loadingContext = false;
    }
  }

  void _loadDashboard({String? uid, bool force = false}) {
    if (!mounted) return;
    final currentUid = uid ?? FirebaseAuth.instance.currentUser?.uid;
    if (currentUid == null) {
      if (_dashboardLoaded || _recommendationFuture != null) {
        setState(() {
          _dashboardLoaded = false;
          _recommendationFuture = null;
          _challengeFuture = null;
          _journeyFuture = null;
        });
      }
      return;
    }

    if (!force && _dashboardLoaded && _loadedUid == currentUid) return;

    final provider = context.read<AnalysisProvider>();
    final analysis = provider.result;
    _recommendationFuture = TodayRecommendationService.getRecommendation(
      analysis: analysis,
      personalStyle: _stylePreferences.isEmpty ? null : _stylePreferences.take(3).join(', '),
      wardrobe: const [],
    );
    _challengeFuture = DailyChallengeService.personalizedToday(
      currentUid,
      analysis: analysis,
    );
    _journeyFuture = TibStyleJourneyService.load(currentUid);
    _dashboardLoaded = true;
    _loadCompletion(currentUid);
    _loadPersonalContext(currentUid);
    setState(() {});
  }

  Future<void> _loadCompletion(String uid) async {
    try {
      final completed = await DailyChallengeService.isCompleted(uid);
      if (!mounted || FirebaseAuth.instance.currentUser?.uid != uid) return;
      setState(() => _challengeCompleted = completed);
    } catch (_) {
      // Optional engagement state should never interrupt the dashboard.
    }
  }

  Future<void> _refresh(AnalysisProvider provider) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      await provider.loadLatestResult(uid);
      await _loadPersonalContext(uid, force: true);
      if (!mounted) return;
      _loadDashboard(uid: uid, force: true);
    }
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
      if (!mounted || FirebaseAuth.instance.currentUser?.uid != uid) return;
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
              _sectionHeading(
                'YOUR STYLE TODAY',
                'A quick read on what feels like you.',
              ),
              const SizedBox(height: 12),
              _reveal(_profileReveal, _colourProfileCard(result)),
              const SizedBox(height: 22),
              _sectionHeading(
                'YOUR JOURNEY',
                'Keep building your personal style.',
              ),
              const SizedBox(height: 12),
              _reveal(_journeyReveal, _styleJourneyCard()),
              const SizedBox(height: 22),
              _sectionHeading(
                'ONE SMALL STYLE MOVE',
                'A simple task for today.',
              ),
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
          if (_stylePreferences.isNotEmpty || _wardrobeCount > 0 || _savedLookCount > 0) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: AppColors.surfaceMuted,
                borderRadius: BorderRadius.circular(17),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Expanded(child: _contextMetric('${_stylePreferences.length}', 'style choices')),
                  _contextDivider(),
                  Expanded(child: _contextMetric('$_wardrobeCount', 'wardrobe pieces')),
                  _contextDivider(),
                  Expanded(child: _contextMetric('$_savedLookCount', 'saved looks')),
                ],
              ),
            ),
          ],
          const SizedBox(height: 18),
          FutureBuilder<TodayRecommendation>(
            future: _recommendationFuture,
            builder: (context, snapshot) {
              final data = snapshot.data;
              if (data == null || data.style.isEmpty) {
                return const SizedBox.shrink();
              }
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
                    ColourSwatch(
                      name: colour == 'Your palette' ? 'Neutral' : colour,
                      size: 24,
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

  Widget _contextMetric(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: AppColors.primary,
            fontSize: 15,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 8.5,
          ),
        ),
      ],
    );
  }

  Widget _contextDivider() => Container(width: 1, height: 27, color: AppColors.border);

  Widget _card({
    required Widget child,
    EdgeInsets padding = const EdgeInsets.all(19),
  }) {
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
                  Text(
                    'Discover your colours',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Complete your colour analysis to unlock your personal palette.',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11.8,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
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
                const Text(
                  'COLOUR PROFILE',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${result.season} • ${result.undertone}',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 5),
                Text(
                  '${result.brightness} value • ${result.contrast} contrast',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 10.8),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: result.colours
                      .take(5)
                      .map((colour) => ColourSwatch(name: colour, size: 24))
                      .toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _styleJourneyCard() {
    return FutureBuilder<TibStyleJourney>(
      future: _journeyFuture,
      builder: (context, snapshot) {
        final journey = snapshot.data;
        if (journey == null) {
          return _card(
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: const BoxDecoration(
                    color: AppColors.secondary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.auto_awesome_rounded, color: AppColors.primary),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Your style journey will grow as you use VYEA.',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        final unlocked = journey.badges.where((badge) => badge.unlocked).length;
        return Container(
          padding: const EdgeInsets.all(18),
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
                  Container(
                    width: 46,
                    height: 46,
                    decoration: const BoxDecoration(
                      gradient: AppGradients.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.auto_awesome_rounded, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Level ${journey.level} · ${journey.levelTitle}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
                        const SizedBox(height: 3),
                        Text('${journey.points} XP · ${journey.streak} day streak · ${journey.completedChallenges} challenges', style: const TextStyle(color: AppColors.textSecondary, fontSize: 10.5)),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TibStyleJourneyScreen())),
                    child: const Text('View'),
                  ),
                ],
              ),
              const SizedBox(height: 15),
              Row(children: [const Text('NEXT LEVEL', style: TextStyle(color: AppColors.textMuted, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: .9)), const Spacer(), Text(journey.nextLevelPoints > journey.currentLevelPoints ? '${journey.points} / ${journey.nextLevelPoints} XP' : 'MAX LEVEL', style: const TextStyle(color: AppColors.primary, fontSize: 9.5, fontWeight: FontWeight.w900))]),
              const SizedBox(height: 7),
              ClipRRect(borderRadius: BorderRadius.circular(99), child: LinearProgressIndicator(value: journey.progress, minHeight: 8, backgroundColor: AppColors.secondary, valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary))),
              const SizedBox(height: 14),
              Row(children: [const Text('BADGES', style: TextStyle(color: AppColors.textMuted, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: .9)), const Spacer(), Text('$unlocked / ${journey.badges.length} unlocked', style: const TextStyle(color: AppColors.textSecondary, fontSize: 9.5, fontWeight: FontWeight.w700))]),
              const SizedBox(height: 8),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: journey.badges.map((badge) => Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7), decoration: BoxDecoration(color: badge.unlocked ? AppColors.secondary : AppColors.surfaceMuted, borderRadius: BorderRadius.circular(13), border: Border.all(color: AppColors.border)), child: Row(mainAxisSize: MainAxisSize.min, children: [Text(badge.icon, style: const TextStyle(fontSize: 13)), const SizedBox(width: 5), Text(badge.title, style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: badge.unlocked ? AppColors.textPrimary : AppColors.textMuted))]))).toList(),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _todayTaskCard() {
    return FutureBuilder<DailyChallenge>(
      future: _challengeFuture,
      builder: (context, snapshot) {
        final challenge = snapshot.data;
        if (challenge == null) {
          return _card(
            child: const Row(
              children: [
                Icon(Icons.auto_awesome_outlined, color: AppColors.primary),
                SizedBox(width: 11),
                Expanded(child: Text('Your daily style move will appear here.', style: TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.4))),
              ],
            ),
          );
        }

        return _card(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 17),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(
                      color: AppColors.secondary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.checkroom_outlined, color: AppColors.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(challenge.category.toUpperCase(), style: const TextStyle(color: AppColors.textMuted, fontSize: 8.5, fontWeight: FontWeight.w900, letterSpacing: 1)),
                        const SizedBox(height: 4),
                        Text(challenge.title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
                        const SizedBox(height: 4),
                        Text(challenge.description, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11.5, height: 1.4)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceMuted,
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Text('+${challenge.points} XP', style: const TextStyle(color: AppColors.primary, fontSize: 9.5, fontWeight: FontWeight.w900)),
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: _challengeCompleted || _completingChallenge ? null : _completeChallenge,
                    icon: Icon(_challengeCompleted ? Icons.check_rounded : Icons.done_outline_rounded, size: 17),
                    label: Text(_challengeCompleted ? 'Completed' : _completingChallenge ? 'Saving…' : 'Complete'),
                    style: FilledButton.styleFrom(backgroundColor: AppColors.primaryDark, minimumSize: const Size(0, 44)),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
