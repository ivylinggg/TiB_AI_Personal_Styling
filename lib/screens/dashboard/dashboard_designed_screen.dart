import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_gradients.dart';
import '../../core/constants/app_radius.dart';
import '../../models/colour_analysis_result.dart';
import '../../models/wardrobe_item.dart';
import '../../providers/analysis_provider.dart';
import '../../services/firestore_service.dart';
import '../../services/style_preference_service.dart';
import '../../widgets/colour_swatch.dart';
import '../ai/style_me_screen.dart';
import '../ai/style_preferences_screen.dart';
import '../analysis/analysis_result_screen.dart';
import '../analysis/analysis_screen.dart';
import '../auth/login_screen.dart';
import '../wardrobe/wardrobe_screen.dart';

/// Home dashboard built around TiB's personal-colour, wardrobe and
/// professional-image direction.
class DashboardDesignedScreen extends StatefulWidget {
  const DashboardDesignedScreen({super.key});

  @override
  State<DashboardDesignedScreen> createState() => _DashboardDesignedScreenState();
}

class _DashboardDesignedScreenState extends State<DashboardDesignedScreen> {
  String _name = '';
  String? _photoUrl;
  bool _premium = false;
  List<WardrobeItem> _wardrobe = const [];
  Map<String, dynamic>? _stylePrefs;
  bool _challengeCompleted = false;

  static const _challengeNames = <String>[
    'Colour Confidence',
    'Wardrobe Remix',
    'Professional Polish',
    'Digital Presence',
    'Signature Style',
    'Smart Styling',
    'Confidence Check',
  ];

  static const _challengeDescriptions = <String>[
    'Wear today\'s recommended colour near your face and notice how it changes your overall harmony.',
    'Choose one piece from your wardrobe and create a second look with a different styling combination.',
    'Add one polished detail today: structured layering, neat grooming, or a confident finishing touch.',
    'Use natural light and a clean background for one professional photo or video call today.',
    'Build a look around one of your best colours and make it feel unmistakably like you.',
    'Pick one wardrobe piece that matches your colour palette and style it for today\'s occasion.',
    'Take one minute to reset your posture, smile and presence before your next meeting or social moment.',
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      final values = await Future.wait<dynamic>([
        FirebaseFirestore.instance.collection('users').doc(uid).get(),
        FirestoreService.getWardrobeItems(uid),
        StylePreferenceService.getStylePreferences(uid),
      ]);

      if (!mounted) return;

      final userSnapshot = values[0] as DocumentSnapshot<Map<String, dynamic>>;
      final user = userSnapshot.data();
      final now = DateTime.now();
      final currentChallengeId = _challengeId(now);
      final currentDate = _dateKey(now);
      final savedChallengeDate = user?['dailyChallengeDate'] as String?;
      final savedChallengeId = user?['dailyChallengeId'] as int?;

      setState(() {
        _name = (user?['name'] as String? ?? '').trim();
        _photoUrl = user?['photoUrl'] as String?;
        _premium = user?['isPremium'] == true;
        _wardrobe = values[1] as List<WardrobeItem>;
        _stylePrefs = values[2] as Map<String, dynamic>?;
        _challengeCompleted = savedChallengeDate == currentDate && savedChallengeId == currentChallengeId && user?['dailyChallengeCompleted'] == true;
      });
    } catch (_) {
      // Keep the dashboard usable with whatever data has already loaded.
    }
  }

  int _dayOfYear(DateTime date) {
    return date.difference(DateTime(date.year, 1, 1)).inDays + 1;
  }

  int _challengeId(DateTime date) => _dayOfYear(date) % _challengeNames.length;

  String _dateKey(DateTime date) => '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  String _normaliseColour(String value) {
    return value
        .toLowerCase()
        .replaceAll('-', ' ')
        .replaceAll('_', ' ')
        .trim();
  }

  String _todayColourName(ColourAnalysisResult? result) {
    if (result == null || result.colours.isEmpty) return '—';
    final index = _dayOfYear(DateTime.now()) % result.colours.length;
    return result.colours[index];
  }

  String _todayColourMessage(String colour) {
    final key = _normaliseColour(colour);

    if (key.contains('pink') || key.contains('rose') || key.contains('raspberry')) {
      return '今天的你可能会遇到一点甜甜的桃花运噢 ✨';
    }
    if (key.contains('turquoise') || key.contains('teal') || key.contains('cyan') || key.contains('aqua')) {
      return '今天的空气会特别清爽，保持你的好心情与阳光感 ☀️';
    }
    if (key.contains('red') || key.contains('ruby') || key.contains('cranberry')) {
      return '今天适合大胆一点，你的自信会特别有存在感 ❤️';
    }
    if (key.contains('orange') || key.contains('coral') || key.contains('peach') || key.contains('apricot')) {
      return '今天很适合主动一点，好事可能就在你开口以后发生 🧡';
    }
    if (key.contains('yellow') || key.contains('gold') || key.contains('mustard')) {
      return '今天带一点阳光色，灵感和好心情都会跟着来 💛';
    }
    if (key.contains('green') || key.contains('olive') || key.contains('mint') || key.contains('sage')) {
      return '今天适合慢一点、稳一点，你的好状态会自然散发出来 🌿';
    }
    if (key.contains('blue') || key.contains('navy') || key.contains('sapphire') || key.contains('cobalt')) {
      return '今天的沟通会更顺，把你的冷静和可靠穿出来 💙';
    }
    if (key.contains('purple') || key.contains('lavender') || key.contains('lilac') || key.contains('mauve')) {
      return '今天很适合发挥一点创意，让别人记住你的独特感 💜';
    }
    if (key.contains('brown') || key.contains('camel') || key.contains('chocolate') || key.contains('sienna')) {
      return '今天的你自带稳重魅力，温柔又让人觉得很可靠 🤎';
    }
    if (key.contains('beige') || key.contains('cream') || key.contains('ivory') || key.contains('taupe')) {
      return '今天适合轻松一点，简单干净的状态反而最耐看 🤍';
    }
    if (key.contains('white')) {
      return '今天像一个新的开始，保持轻盈，你会发现更多可能 🤍';
    }
    if (key.contains('black') || key.contains('charcoal')) {
      return '今天适合把气场打开一点，你会比自己想象中更有力量 🖤';
    }
    if (key.contains('grey') || key.contains('gray')) {
      return '今天适合保持清醒与从容，低调也可以很有质感 🩶';
    }

    return '今天就穿上它，让属于你的颜色陪你完成一个好日子 ✨';
  }

  List<String> _paletteMatches(ColourAnalysisResult? result) {
    if (result == null || result.colours.isEmpty) return const [];
    final palette = result.colours.map(_normaliseColour).toSet();
    return _wardrobe.where((item) {
      final colour = _normaliseColour(item.colour);
      return palette.any((wanted) => wanted.contains(colour) || colour.contains(wanted));
    }).map((item) => item.id).toList();
  }

  int _styleScore(ColourAnalysisResult? result) {
    if (result == null) return 0;

    final colourProfile = 40;
    final wardrobeReadiness = (_wardrobe.length * 4).clamp(0, 25);
    final preferences = _stylePrefs == null ? 0 : 15;
    final paletteMatches = (_paletteMatches(result).length * 4).clamp(0, 20);

    return (colourProfile + wardrobeReadiness + preferences + paletteMatches).clamp(0, 100);
  }

  String _scoreLabel(int score) {
    if (score >= 90) return 'Signature ready';
    if (score >= 75) return 'Well styled';
    if (score >= 55) return 'Good foundation';
    if (score >= 35) return 'Building your style';
    return 'Start your style journey';
  }

  Future<void> _completeChallenge() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || _challengeCompleted) return;

    final now = DateTime.now();
    final challengeId = _challengeId(now);
    final dateKey = _dateKey(now);

    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'dailyChallengeDate': dateKey,
        'dailyChallengeId': challengeId,
        'dailyChallengeCompleted': true,
      }, SetOptions(merge: true));

      if (!mounted) return;
      setState(() => _challengeCompleted = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nice work — today\'s style challenge is complete! ✨')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save your challenge progress. Please try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final result = context.watch<AnalysisProvider>().result;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: _load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            children: [
              _header(result),
              const SizedBox(height: 18),
              _seasonHero(result),
              const SizedBox(height: 12),
              _todayColour(result),
              const SizedBox(height: 12),
              _styleScoreCard(result),
              const SizedBox(height: 12),
              _challenge(result),
              const SizedBox(height: 12),
              _recentReport(result),
              const SizedBox(height: 20),
              _wardrobePreview(),
              const SizedBox(height: 20),
              _quickActions(result),
              const SizedBox(height: 8),
              if (!_premium) _upgradeHint(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(ColourAnalysisResult? result) {
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning'
        : hour < 18
            ? 'Good afternoon'
            : 'Good evening';
    final name = _name.isEmpty ? 'there' : _name;
    return Row(
      children: [
        CircleAvatar(
          radius: 25,
          backgroundColor: AppColors.primarySoft,
          backgroundImage: _photoUrl?.isNotEmpty == true
              ? CachedNetworkImageProvider(_photoUrl!)
              : null,
          child: _photoUrl?.isNotEmpty == true
              ? null
              : const Icon(Icons.person_rounded, color: AppColors.primaryDark),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(greeting, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              const SizedBox(height: 1),
              Text('$greeting, $name! ✨', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -.5)),
              const SizedBox(height: 1),
              Text(
                result == null ? 'Let’s make today feel more like you.' : '${result.season} • ${result.undertone}',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
              ),
            ],
          ),
        ),
        _iconButton(Icons.notifications_none_rounded, () {}),
        const SizedBox(width: 7),
        _iconButton(Icons.logout_rounded, _confirmLogout),
      ],
    );
  }

  Widget _iconButton(IconData icon, VoidCallback onTap) {
    return Material(
      color: AppColors.surface,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(width: 44, height: 44, child: Icon(icon, color: AppColors.primaryDark)),
      ),
    );
  }

  Widget _seasonHero(ColourAnalysisResult? result) {
    if (result == null) {
      return _card(
        onTap: () => _open(const AnalysisScreen()),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(gradient: AppGradients.primary, borderRadius: BorderRadius.circular(22)),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('YOUR COLOUR SEASON', style: TextStyle(color: Colors.white70, fontSize: 9.5, fontWeight: FontWeight.w800, letterSpacing: 1)),
              SizedBox(height: 8),
              Text('Discover your season', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
              SizedBox(height: 5),
              Text('Take the guided face scan to unlock your personal colour profile.', style: TextStyle(color: Colors.white70, fontSize: 11.5, height: 1.35)),
              SizedBox(height: 14),
              _HeroPill(label: 'Start Colour Analysis'),
            ],
          ),
        ),
      );
    }

    final accent = AppColors.seasonAccent(result.season);
    return _card(
      onTap: () => _open(AnalysisResultScreen(result: result)),
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 16, 16, 15),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Color.lerp(AppColors.primary, accent, .18)!, Color.lerp(AppColors.primaryDark, accent, .34)!],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Text('YOUR COLOUR SEASON', style: TextStyle(color: Colors.white70, fontSize: 9.5, fontWeight: FontWeight.w800, letterSpacing: .8)),
                      SizedBox(width: 7),
                      _MiniTag(label: 'PERSONALISED'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(result.season, style: const TextStyle(color: Colors.white, fontSize: 25, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text('${result.undertone} • ${result.brightness} • ${result.contrast}', style: const TextStyle(color: Colors.white70, fontSize: 11.5)),
                  const SizedBox(height: 12),
                  Row(
                    children: result.colours.take(7).map((name) => Padding(
                      padding: const EdgeInsets.only(right: 5),
                      child: ColourSwatch(name: name, size: 25),
                    )).toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right_rounded, color: Colors.white70, size: 22),
          ],
        ),
      ),
    );
  }

  Widget _todayColour(ColourAnalysisResult? result) {
    final name = _todayColourName(result);
    final message = _todayColourMessage(name);
    return _card(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 15, 16, 16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(19),
          border: Border.all(color: AppColors.border),
        ),
        child: result == null
            ? Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: const BoxDecoration(color: AppColors.primarySoft, shape: BoxShape.circle),
                    child: const Icon(Icons.palette_outlined, color: AppColors.primaryDark),
                  ),
                  const SizedBox(width: 11),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("TODAY'S COLOUR", style: TextStyle(color: AppColors.textMuted, fontSize: 9.5, fontWeight: FontWeight.w900, letterSpacing: .65)),
                        SizedBox(height: 5),
                        Text('Complete your colour analysis to unlock your daily shade.', style: TextStyle(color: AppColors.textSecondary, fontSize: 11, height: 1.35)),
                      ],
                    ),
                  ),
                ],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  ColourSwatch(name: name, size: 54, showLabel: false),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("TODAY'S COLOUR", style: TextStyle(color: AppColors.textMuted, fontSize: 9.5, fontWeight: FontWeight.w900, letterSpacing: .65)),
                        const SizedBox(height: 3),
                        Text(name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                        const SizedBox(height: 4),
                        Text(message, style: const TextStyle(color: AppColors.textSecondary, fontSize: 10.8, height: 1.35)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 7),
                  const Icon(Icons.auto_awesome_rounded, color: AppColors.primary, size: 18),
                ],
              ),
      ),
    );
  }

  Widget _styleScoreCard(ColourAnalysisResult? result) {
    final score = _styleScore(result);
    final paletteMatches = _paletteMatches(result).length;
    final wardrobePoints = (_wardrobe.length * 4).clamp(0, 25);
    final preferencePoints = _stylePrefs == null ? 0 : 15;

    return _card(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 15, 16, 15),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(19),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('STYLE SCORE', style: TextStyle(color: AppColors.textMuted, fontSize: 9.5, fontWeight: FontWeight.w900, letterSpacing: .65)),
                const Spacer(),
                Text(_scoreLabel(score), style: const TextStyle(color: AppColors.primaryDark, fontSize: 10.5, fontWeight: FontWeight.w800)),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('$score', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, height: .95)),
                const Padding(
                  padding: EdgeInsets.only(left: 3, bottom: 2),
                  child: Text('/100', style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w700)),
                ),
                const Spacer(),
                SizedBox(width: 62, height: 38, child: CustomPaint(painter: _ScorePainter(score / 100))),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: score / 100,
                minHeight: 6,
                backgroundColor: AppColors.border,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 9),
            Text(
              result == null
                  ? 'Your score begins after your colour analysis.'
                  : 'Colour harmony 40 • Wardrobe $wardrobePoints • Preferences $preferencePoints • Palette matches $paletteMatches',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 10.5, height: 1.35),
            ),
          ],
        ),
      ),
    );
  }

  Widget _challenge(ColourAnalysisResult? result) {
    final index = _challengeId(DateTime.now());
    final title = _challengeNames[index];
    final description = _challengeDescriptions[index];

    return Container(
      padding: const EdgeInsets.fromLTRB(15, 14, 15, 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.lavenderMist, AppColors.background],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 42, height: 42, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle), child: const Icon(Icons.emoji_events_outlined, color: AppColors.primaryDark)),
              const SizedBox(width: 10),
              const Expanded(child: Text("TODAY'S CHALLENGE", style: TextStyle(color: AppColors.primaryDark, fontSize: 9.5, fontWeight: FontWeight.w900, letterSpacing: .7))),
              Text('Day ${_dayOfYear(DateTime.now())}', style: const TextStyle(color: AppColors.textMuted, fontSize: 10, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 11),
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(description, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11, height: 1.38)),
          const SizedBox(height: 11),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: result == null || _challengeCompleted ? null : _completeChallenge,
              icon: Icon(_challengeCompleted ? Icons.check_rounded : Icons.auto_awesome_rounded, size: 17),
              label: Text(_challengeCompleted ? 'Completed today' : 'Mark as complete'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppColors.primarySoft,
                disabledForegroundColor: AppColors.primaryDark,
                minimumSize: const Size.fromHeight(44),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
              ),
            ),
          ),
          if (result == null)
            const Padding(
              padding: EdgeInsets.only(top: 7),
              child: Text('Complete your colour analysis first to unlock personalised daily challenges.', style: TextStyle(color: AppColors.textMuted, fontSize: 10)),
            ),
        ],
      ),
    );
  }

  Widget _recentReport(ColourAnalysisResult? result) {
    return _card(
      onTap: result == null ? () => _open(const AnalysisScreen()) : () => _open(AnalysisResultScreen(result: result)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(15, 12, 12, 12),
        child: Row(
          children: [
            const Icon(Icons.picture_as_pdf_outlined, color: AppColors.primaryDark, size: 22),
            const SizedBox(width: 10),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Recent Report', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                  SizedBox(height: 3),
                  Text('Your latest colour analysis report', style: TextStyle(color: AppColors.textSecondary, fontSize: 10.5)),
                ],
              ),
            ),
            Text('View', style: TextStyle(color: AppColors.primaryDark, fontWeight: FontWeight.w800, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _wardrobePreview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(child: Text('My Wardrobe', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
            TextButton(onPressed: () => _open(const WardrobeScreen()), child: const Text('View all')),
          ],
        ),
        const SizedBox(height: 3),
        Text('${_wardrobe.length} pieces • ${_wardrobe.where((item) => item.isFavourite).length} favourites', style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
        const SizedBox(height: 10),
        SizedBox(
          height: 116,
          child: _wardrobe.isEmpty
              ? _emptyWardrobe()
              : ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _wardrobe.take(5).length,
                  separatorBuilder: (_, index) => const SizedBox(width: 9),
                  itemBuilder: (_, index) => _wardrobeCard(_wardrobe[index]),
                ),
        ),
      ],
    );
  }

  Widget _wardrobeCard(WardrobeItem item) {
    return InkWell(
      onTap: () => _open(const WardrobeScreen()),
      borderRadius: BorderRadius.circular(18),
      child: Ink(
        width: 94,
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.border)),
        child: Column(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                child: item.imageUrl.isEmpty
                    ? Container(color: AppColors.surfaceMuted, child: const Center(child: Icon(Icons.checkroom_outlined, color: AppColors.primary)))
                    : CachedNetworkImage(imageUrl: item.imageUrl, width: double.infinity, fit: BoxFit.cover),
              ),
            ),
            Padding(padding: const EdgeInsets.fromLTRB(7, 5, 7, 6), child: Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800))),
          ],
        ),
      ),
    );
  }

  Widget _emptyWardrobe() {
    return _card(
      onTap: () => _open(const WardrobeScreen()),
      child: const Center(
        child: Padding(
          padding: EdgeInsets.all(18),
          child: Text('Add a few pieces and TiB will style from what you already own.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary, fontSize: 11.5, height: 1.35)),
        ),
      ),
    );
  }

  Widget _quickActions(ColourAnalysisResult? result) {
    return Row(
      children: [
        Expanded(child: _quickTile(Icons.auto_awesome_rounded, 'Style Me', () => _open(const StyleMeScreen()))),
        const SizedBox(width: 9),
        Expanded(child: _quickTile(Icons.palette_outlined, 'Colours', () => _open(const AnalysisScreen()))),
        const SizedBox(width: 9),
        Expanded(child: _quickTile(Icons.tune_rounded, 'Preferences', () => _open(const StylePreferencesScreen()))),
      ],
    );
  }

  Widget _quickTile(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 13),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.border)),
        child: Column(
          children: [
            Icon(icon, color: AppColors.primary, size: 20),
            const SizedBox(height: 6),
            Text(label, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }

  Widget _upgradeHint() {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(color: AppColors.lavenderMist, borderRadius: BorderRadius.circular(16)),
      child: const Row(
        children: [
          Icon(Icons.auto_awesome_rounded, color: AppColors.primaryDark, size: 18),
          SizedBox(width: 8),
          Expanded(child: Text('Unlock more personalised AI styling with TiB Premium.', style: TextStyle(fontSize: 10.8, height: 1.3, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }

  Widget _smallCard({required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(color: AppColors.textMuted, fontSize: 9.5, fontWeight: FontWeight.w900, letterSpacing: .65)), const SizedBox(height: 8), child]),
    );
  }

  Widget _card({required Widget child, VoidCallback? onTap}) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(18), child: child),
    );
  }

  Future<void> _confirmLogout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('You can sign in again anytime with your account.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (shouldLogout == true) {
      await _logout();
    }
  }

  Future<void> _logout() async {
    try {
      await FirebaseAuth.instance.signOut();
      if (!mounted) return;
      context.read<AnalysisProvider>().clear();
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Logout failed. Please try again.')),
      );
    }
  }

  Future<void> _open(Widget page) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => page));
    if (mounted) _load();
  }
}

class _HeroPill extends StatelessWidget {
  final String label;
  const _HeroPill({required this.label});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: .16), borderRadius: BorderRadius.circular(AppRadius.full)),
      child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w800)),
    );
  }
}

class _MiniTag extends StatelessWidget {
  final String label;
  const _MiniTag({required this.label});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(color: AppColors.eggYolk, borderRadius: BorderRadius.circular(AppRadius.full)),
      child: Text(label, style: const TextStyle(color: AppColors.primaryDark, fontSize: 8, fontWeight: FontWeight.w800)),
    );
  }
}

class _ScorePainter extends CustomPainter {
  final double progress;
  _ScorePainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.height * .25;
    final rect = Rect.fromLTWH(stroke, stroke, size.width - stroke * 2, size.height - stroke * 2);
    final bg = Paint()
      ..color = AppColors.border
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    final fg = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, 3.4, 5.75, false, bg);
    canvas.drawArc(rect, 3.4, 5.75 * progress.clamp(0, 1), false, fg);
  }

  @override
  bool shouldRepaint(covariant _ScorePainter oldDelegate) => oldDelegate.progress != progress;
}
