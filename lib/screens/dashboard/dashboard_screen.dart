import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_gradients.dart';
import '../../core/constants/app_radius.dart';
import '../../core/constants/app_spacing.dart';
import '../../models/colour_analysis_result.dart';
import '../../models/wardrobe_item.dart';
import '../../providers/analysis_provider.dart';
import '../../services/firestore_service.dart';
import '../../services/style_preference_service.dart';
import '../../widgets/colour_swatch.dart';
import '../../widgets/premium_badge.dart';
import '../ai/ai_stylist_screen.dart';
import '../ai/style_preferences_screen.dart';
import '../analysis/analysis_result_screen.dart';
import '../analysis/analysis_screen.dart';
import '../analysis/history/analysis_history_screen.dart';
import '../premium/premium_screen.dart';
import '../wardrobe/wardrobe_screen.dart';

/// Editorial home experience.
///
/// Quick Access is intentionally gone. The home screen is now a personalised
/// feed: greeting -> colour identity -> today's styling prompt -> AI stylist ->
/// wardrobe snapshot -> personal preferences -> Premium. Every card either
/// uses real saved data or clearly asks the user to create it.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  String _name = '';
  String? _photoUrl;
  bool _isPremium = false;
  bool _loading = true;
  List<WardrobeItem> _wardrobe = const [];
  List<String> _styles = const [];
  List<String> _preferences = const [];

  late final AnimationController _revealController;
  late final Animation<double> _greeting;
  late final Animation<double> _hero;
  late final Animation<double> _today;
  late final Animation<double> _ai;
  late final Animation<double> _wardrobeReveal;
  late final Animation<double> _personal;

  @override
  void initState() {
    super.initState();
    _load();
    _revealController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 950),
    );
    _greeting = _stage(0.00, 0.30);
    _hero = _stage(0.08, 0.44);
    _today = _stage(0.18, 0.56);
    _ai = _stage(0.30, 0.68);
    _wardrobeReveal = _stage(0.42, 0.82);
    _personal = _stage(0.56, 1.00);
    _revealController.forward();
  }

  Animation<double> _stage(double begin, double end) {
    return CurvedAnimation(
      parent: _revealController,
      curve: Interval(begin, end, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _revealController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    try {
      final results = await Future.wait<dynamic>([
        FirebaseFirestore.instance.collection('users').doc(uid).get(),
        FirestoreService.getWardrobeItems(uid),
        StylePreferenceService.getStylePreferences(uid),
      ]);

      if (!mounted) return;

      final userSnapshot = results[0] as DocumentSnapshot<Map<String, dynamic>>;
      final userData = userSnapshot.data() ?? const <String, dynamic>{};
      final preferences = results[2] as Map<String, dynamic>?;

      setState(() {
        _name = (userData['name'] as String? ?? '').trim();
        _photoUrl = userData['photoUrl'] as String?;
        _isPremium = userData['isPremium'] == true;
        _wardrobe = results[1] as List<WardrobeItem>;
        _styles = List<String>.from(preferences?['styles'] ?? const []);
        _preferences = List<String>.from(
          preferences?['preferences'] ?? const [],
        );
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _refresh() async {
    await _load();
  }

  Widget _reveal(Animation<double> animation, Widget child) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, animatedChild) {
        final value = animation.value.clamp(0.0, 1.0);
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 18 * (1 - value)),
            child: animatedChild,
          ),
        );
      },
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final analysis = context.watch<AnalysisProvider>().result;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: _refresh,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  16,
                  AppSpacing.lg,
                  36,
                ),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _reveal(_greeting, _buildGreeting(analysis)),
                    const SizedBox(height: 24),
                    _reveal(_hero, _buildColourHero(analysis)),
                    if (analysis != null) ...[
                      const SizedBox(height: 18),
                      _reveal(_today, _buildTodayCard(analysis)),
                    ],
                    const SizedBox(height: 22),
                    _reveal(_ai, _buildAiCard(analysis)),
                    const SizedBox(height: 28),
                    _reveal(_wardrobeReveal, _buildWardrobeSection()),
                    const SizedBox(height: 28),
                    _reveal(
                      _personal,
                      _buildPersonalSection(analysis),
                    ),
                    if (!_isPremium) ...[
                      const SizedBox(height: 22),
                      _reveal(_personal, _buildPremiumCard()),
                    ],
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGreeting(ColourAnalysisResult? analysis) {
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning'
        : hour < 18
        ? 'Good afternoon'
        : 'Good evening';
    final name = _name.isEmpty ? 'there' : _name;

    return Row(
      children: [
        Hero(
          tag: 'profile-avatar',
          child: CircleAvatar(
            radius: 26,
            backgroundColor: AppColors.surfaceMuted,
            backgroundImage: _photoUrl != null && _photoUrl!.isNotEmpty
                ? CachedNetworkImageProvider(_photoUrl!)
                : null,
            child: _photoUrl == null || _photoUrl!.isEmpty
                ? const Icon(Icons.person_rounded, color: AppColors.primary)
                : null,
          ),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$greeting 👋',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 2),
              Text(
                'Hi, $name',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              Text(
                analysis == null
                    ? 'Let’s build your personal style profile.'
                    : '${analysis.season} • ${analysis.undertone}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        _roundIconButton(
          icon: Icons.notifications_none_rounded,
          onTap: () => _showMessage('You’re all caught up.'),
        ),
      ],
    );
  }

  Widget _buildColourHero(ColourAnalysisResult? result) {
    if (result == null) {
      return _brandCard(
        onTap: () => _open(const AnalysisScreen()),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _eyebrow('YOUR STYLE STARTS HERE'),
            const SizedBox(height: 10),
            const Text(
              'Find the colours\nthat feel like you.',
              style: TextStyle(
                color: Colors.white,
                fontSize: 30,
                height: 1.04,
                fontWeight: FontWeight.w800,
                letterSpacing: -1,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Take a guided colour analysis and unlock a wardrobe built around your natural colouring.',
              style: TextStyle(color: Colors.white70, height: 1.45),
            ),
            const SizedBox(height: 20),
            _whiteAction('Start Colour Analysis'),
          ],
        ),
      );
    }

    final accent = AppColors.seasonAccent(result.season);

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, Color.lerp(AppColors.primaryDark, accent, .28)!],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: .18),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => _open(AnalysisResultScreen(result: result)),
        borderRadius: BorderRadius.circular(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: _eyebrow('YOUR COLOUR PROFILE')),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.eggYolk,
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                  child: const Text(
                    'PERSONALISED',
                    style: TextStyle(
                      color: AppColors.primaryDark,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: .7,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              result.season,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 29,
                fontWeight: FontWeight.w800,
                letterSpacing: -.7,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              '${result.undertone} • ${result.brightness} • ${result.contrast}',
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
            if (result.colours.isNotEmpty) ...[
              const SizedBox(height: 19),
              Row(
                children: result.colours.take(6).map((colour) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ColourSwatch(name: colour, size: 30),
                  );
                }).toList(),
              ),
            ],
            const SizedBox(height: 19),
            Row(
              children: const [
                Text(
                  'View my full colour profile',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                SizedBox(width: 5),
                Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 17),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTodayCard(ColourAnalysisResult result) {
    if (result.colours.isEmpty) return const SizedBox.shrink();
    final colour = result.colours[DateTime.now().day % result.colours.length];

    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          ColourSwatch(name: colour, size: 54),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("TODAY'S COLOUR", style: _labelStyle()),
                const SizedBox(height: 3),
                Text(
                  colour,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 2),
                const Text(
                  'A shade from your personal palette to try today.',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
        ],
      ),
    );
  }

  Widget _buildAiCard(ColourAnalysisResult? analysis) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppGradients.ai,
        borderRadius: BorderRadius.circular(25),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.auto_awesome_rounded, color: AppColors.primary),
              ),
              const SizedBox(width: 11),
              Expanded(child: _eyebrow('AI STYLIST')),
              if (_isPremium) const PremiumBadge(compact: true),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            _wardrobe.isEmpty
                ? 'Tell me what you’re dressing for.'
                : 'Let’s build a look from your real wardrobe.',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            analysis == null
                ? 'Add your colour profile for more personalised recommendations.'
                : 'Your ${analysis.season} palette, preferences and saved pieces stay at the centre.',
            style: const TextStyle(color: Colors.white70, height: 1.4, fontSize: 13),
          ),
          const SizedBox(height: 17),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => _open(const AIStylistScreen()),
              icon: const Icon(Icons.auto_awesome_rounded),
              label: const Text('Style Me'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.eggYolk,
                foregroundColor: AppColors.primaryDark,
                minimumSize: const Size.fromHeight(50),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWardrobeSection() {
    final favourites = _wardrobe.where((item) => item.isFavourite).length;
    final preview = _wardrobe.take(4).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(
          'My Wardrobe',
          '${_wardrobe.length} pieces • $favourites favourites',
          action: 'Open',
          onAction: () => _open(const WardrobeScreen()),
        ),
        const SizedBox(height: 12),
        if (_loading)
          const SizedBox(
            height: 142,
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_wardrobe.isEmpty)
          _emptyWardrobeCard()
        else
          SizedBox(
            height: 198,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: preview.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) => _wardrobePreviewCard(preview[index]),
            ),
          ),
      ],
    );
  }

  Widget _wardrobePreviewCard(WardrobeItem item) {
    return SizedBox(
      width: 145,
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: () => _open(const WardrobeScreen()),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(7),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(15),
                    child: item.imageUrl.isEmpty
                        ? Container(
                            color: AppColors.surfaceMuted,
                            child: const Center(
                              child: Icon(Icons.checkroom_outlined, color: AppColors.primary),
                            ),
                          )
                        : CachedNetworkImage(
                            imageUrl: item.imageUrl,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => const ColoredBox(
                              color: AppColors.surfaceMuted,
                              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                            ),
                            errorWidget: (_, __, ___) => const ColoredBox(
                              color: AppColors.surfaceMuted,
                              child: Center(child: Icon(Icons.image_not_supported_outlined)),
                            ),
                          ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 7, 4, 2),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                        ),
                      ),
                      if (item.isFavourite)
                        const Icon(Icons.favorite_rounded, size: 15, color: AppColors.eggYolk),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _emptyWardrobeCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: const BoxDecoration(
              color: AppColors.surfaceMuted,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.add_a_photo_outlined, color: AppColors.primary),
          ),
          const SizedBox(width: 13),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Your wardrobe is waiting.', style: TextStyle(fontWeight: FontWeight.w800)),
                SizedBox(height: 3),
                Text(
                  'Add your clothes and AI Stylist can build looks around what you actually own.',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.35),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
        ],
      ),
    );
  }

  Widget _buildPersonalSection(ColourAnalysisResult? analysis) {
    return Container(
      padding: const EdgeInsets.all(19),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(23),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.tune_rounded, color: AppColors.primary),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Your Style Preferences',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                ),
              ),
              TextButton(
                onPressed: () async {
                  await _open(const StylePreferencesScreen());
                  await _load();
                },
                child: const Text('Edit'),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            analysis == null
                ? 'Set your preferences so future outfit recommendations feel more like you.'
                : 'Your recommendations prioritise your colour profile and saved preferences.',
            style: const TextStyle(color: AppColors.textSecondary, height: 1.4, fontSize: 12.5),
          ),
          const SizedBox(height: 14),
          if (_styles.isEmpty && _preferences.isEmpty)
            _miniPreference('No style preferences saved yet.', Icons.add_rounded)
          else ...[
            if (_styles.isNotEmpty) _chipRow('Styles', _styles),
            if (_preferences.isNotEmpty) ...[
              const SizedBox(height: 10),
              _chipRow('Preferences', _preferences),
            ],
          ],
        ],
      ),
    );
  }

  Widget _chipRow(String title, List<String> values) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title.toUpperCase(), style: _labelStyle()),
        const SizedBox(height: 7),
        Wrap(
          spacing: 7,
          runSpacing: 7,
          children: values.take(6).map((value) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: AppColors.surfaceMuted,
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
              child: Text(
                value,
                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _miniPreference(String text, IconData icon) {
    return Row(
      children: [
        const Icon(Icons.auto_awesome_rounded, size: 18, color: AppColors.eggYolk),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12))),
        Icon(icon, size: 17, color: AppColors.primary),
      ],
    );
  }

  Widget _buildPremiumCard() {
    return InkWell(
      onTap: () => _open(const PremiumScreen()),
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.premiumAccentLight,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.eggYolk.withValues(alpha: .65)),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(
                color: AppColors.eggYolk,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.workspace_premium_rounded, color: AppColors.primaryDark),
            ),
            const SizedBox(width: 13),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Make your styling more personal', style: TextStyle(fontWeight: FontWeight.w800)),
                  SizedBox(height: 3),
                  Text(
                    'Unlock Premium AI styling and deeper personal recommendations.',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.35),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_rounded, color: AppColors.primary),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(
    String title,
    String subtitle, {
    String? action,
    VoidCallback? onAction,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 2),
              Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
        if (action != null)
          TextButton(onPressed: onAction, child: Text(action)),
      ],
    );
  }

  Widget _brandCard({required VoidCallback onTap, required Widget child}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(28),
        child: Ink(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: AppGradients.primary,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: .18),
                blurRadius: 25,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _eyebrow(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.white70,
        fontSize: 10,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.25,
      ),
    );
  }

  Widget _whiteAction(String label) {
    return Container(
      height: 48,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.primaryDark,
          fontWeight: FontWeight.w800,
          fontSize: 13,
        ),
      ),
    );
  }

  Widget _roundIconButton({required IconData icon, required VoidCallback onTap}) {
    return Material(
      color: AppColors.surfaceMuted,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 42,
          height: 42,
          child: Icon(icon, color: AppColors.primary, size: 20),
        ),
      ),
    );
  }

  TextStyle _labelStyle() {
    return const TextStyle(
      color: AppColors.textMuted,
      fontSize: 10,
      fontWeight: FontWeight.w800,
      letterSpacing: 1.1,
    );
  }

  void _open(Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}
