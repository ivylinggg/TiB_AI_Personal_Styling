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
import '../../widgets/gradient_card.dart';
import '../../widgets/premium_badge.dart';
import '../../widgets/section_header.dart';
import '../ai/ai_stylist_screen.dart';
import '../ai/style_preferences_screen.dart';
import '../analysis/analysis_result_screen.dart';
import '../analysis/analysis_screen.dart';
import '../analysis/history/analysis_history_screen.dart';
import '../learning/learning_screen.dart';
import '../wardrobe/wardrobe_screen.dart';

class _PremiumChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _PremiumChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.premiumAccent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.premiumAccentDark, size: 14),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.premiumAccentDark,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Container(
        width: 88,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: AppColors.secondary,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppColors.primaryDark, size: 22),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  bool _isPremium = false;
  bool _dataLoaded = false;
  String _name = '';
  String? _photoUrl;
  List<WardrobeItem> _wardrobe = const [];
  List<String> _styles = const [];
  List<String> _preferences = const [];

  // Subtle entrance animation -- fade + gentle slide-up, no bounce.
  // Staggered per the approved sequence: 0.00 greeting, 0.10 hero,
  // 0.20 today's colour, 0.30 quick actions, 0.40 AI Stylist/Wardrobe,
  // 0.50 Premium/Personal Style.
  late final AnimationController _revealController;
  late final Animation<double> _greetingReveal;
  late final Animation<double> _heroReveal;
  late final Animation<double> _todayReveal;
  late final Animation<double> _actionsReveal;
  late final Animation<double> _promoReveal;
  late final Animation<double> _premiumStyleReveal;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();

    _revealController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _greetingReveal = _stage(0.00, 0.35);
    _heroReveal = _stage(0.10, 0.45);
    _todayReveal = _stage(0.20, 0.55);
    _actionsReveal = _stage(0.30, 0.65);
    _promoReveal = _stage(0.40, 0.75);
    _premiumStyleReveal = _stage(0.50, 1.00);

    _revealController.forward();
  }

  Animation<double> _stage(double begin, double end) {
    return CurvedAnimation(
      parent: _revealController,
      curve: Interval(begin, end, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _revealController.dispose();
    super.dispose();
  }

  /// Loads everything the Dashboard actually displays about the real
  /// signed-in user: Premium status, name and photo (all from the same
  /// users/{uid} read this screen already made), plus their real wardrobe
  /// and Style Preferences -- the same FirestoreService/
  /// StylePreferenceService calls ai_stylist_screen.dart and
  /// profile_screen.dart already use, so no new architecture is
  /// introduced.
  Future<void> _loadDashboardData() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      if (mounted) {
        setState(() => _dataLoaded = true);
      }
      return;
    }

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      final wardrobe = await FirestoreService.getWardrobeItems(uid);
      final stylePreferences = await StylePreferenceService.getStylePreferences(
        uid,
      );

      if (!mounted) {
        return;
      }

      final userData = userDoc.data();

      setState(() {
        _isPremium = userData?['isPremium'] == true;
        _name = (userData?['name'] as String?)?.trim() ?? '';
        _photoUrl = userData?['photoUrl'] as String?;
        _wardrobe = wardrobe;
        _styles = List<String>.from(stylePreferences?['styles'] ?? const []);
        _preferences = List<String>.from(
          stylePreferences?['preferences'] ?? const [],
        );
        _dataLoaded = true;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() => _dataLoaded = true);
    }
  }

  /// Fade + gentle slide-up reveal for one stage of the animation.
  Widget _reveal(Animation<double> animation, Widget child) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, animatedChild) {
        final value = animation.value.clamp(0.0, 1.0);
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 14),
            child: animatedChild,
          ),
        );
      },
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final analysisResult = context.watch<AnalysisProvider>().result;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _reveal(_greetingReveal, _buildGreeting(analysisResult)),

              const SizedBox(height: 26),

              _reveal(_heroReveal, _buildHero(context, analysisResult)),

              _reveal(
                _heroReveal,
                Center(
                  child: TextButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AnalysisHistoryScreen(),
                      ),
                    ),
                    icon: const Icon(Icons.history, size: 18),
                    label: const Text('View Analysis History'),
                  ),
                ),
              ),

              if (analysisResult != null &&
                  analysisResult.colours.isNotEmpty) ...[
                const SizedBox(height: 24),
                _reveal(_todayReveal, _buildTodaysColour(analysisResult)),
              ],

              const SizedBox(height: 30),

              _reveal(_actionsReveal, _buildQuickActions(context)),

              const SizedBox(height: 30),

              _reveal(_promoReveal, _buildAiStylistPromo(context)),

              const SizedBox(height: 20),

              _reveal(_promoReveal, _buildWardrobeSnapshot(context)),

              const SizedBox(height: 20),

              _reveal(_premiumStyleReveal, _buildPersonalStyle(context)),

              const SizedBox(height: 20),

              _reveal(_premiumStyleReveal, _buildPremiumDashboardCard(context)),

              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // GREETING
  // ============================================================

  Widget _buildGreeting(ColourAnalysisResult? analysisResult) {
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good Morning'
        : hour < 18
        ? 'Good Afternoon'
        : 'Good Evening';
    final displayName = _name.isNotEmpty ? _name : 'there';

    final subtitle = analysisResult != null
        ? 'Your ${analysisResult.season} palette is ready.'
        : "Let's find colours that feel like you.";

    return Row(
      children: [
        CircleAvatar(
          radius: 28,
          backgroundColor: AppColors.secondary,
          backgroundImage: _photoUrl != null && _photoUrl!.isNotEmpty
              ? CachedNetworkImageProvider(_photoUrl!)
              : null,
          child: _photoUrl == null || _photoUrl!.isEmpty
              ? const Icon(Icons.person, color: Colors.white)
              : null,
        ),
        const SizedBox(width: 15),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$greeting 👋',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 4),
              Text(
                'Hi, $displayName',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 3),
              Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Notifications',
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'You’re all caught up. New styling updates will appear here.',
                ),
              ),
            );
          },
          icon: const Icon(Icons.notifications_none),
        ),
      ],
    );
  }

  // ============================================================
  // HERO -- real colour profile, or a real onboarding invitation
  // ============================================================

  Widget _buildHero(BuildContext context, ColourAnalysisResult? result) {
    if (result == null) {
      return GradientCard(
        gradient: AppGradients.primary,
        icon: Icons.auto_awesome_rounded,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AnalysisScreen()),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Discover Your Colours',
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(color: Colors.white),
            ),
            const SizedBox(height: 8),
            const Text(
              'Find the shades that make you look and feel your best.',
              style: TextStyle(color: Colors.white70, height: 1.5),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AnalysisScreen()),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.primaryDark,
                ),
                child: const Text('Analyse My Colours'),
              ),
            ),
          ],
        ),
      );
    }

    return GradientCard(
      gradient: AppGradients.season(result.season),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => AnalysisResultScreen(result: result)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'YOUR COLOUR PROFILE',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.4,
              color: Colors.white.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            result.season,
            style: Theme.of(
              context,
            ).textTheme.headlineLarge?.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 6),
          Text(
            '${result.undertone} • ${result.brightness} • ${result.contrast}',
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          if (result.colours.isNotEmpty) ...[
            const SizedBox(height: 18),
            Row(
              children: result.colours
                  .take(5)
                  .map(
                    (colour) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ColourSwatch(name: colour, size: 30),
                    ),
                  )
                  .toList(),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: const [
              Text(
                'View full analysis',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              SizedBox(width: 4),
              Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 16),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================
  // TODAY'S COLOUR -- one real colour, picked deterministically
  // (day-of-month index), never random and never invented.
  // ============================================================

  Widget _buildTodaysColour(ColourAnalysisResult result) {
    final colours = result.colours;
    final todaysColour = colours[DateTime.now().day % colours.length];
    final pairing = colours.firstWhere(
      (c) => c != todaysColour,
      orElse: () => '',
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Text(
            "TODAY'S COLOUR",
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 14),
          ColourSwatch(name: todaysColour, size: 84, showLabel: true),
          const SizedBox(height: 10),
          Text(
            pairing.isNotEmpty
                ? 'Pair it with $pairing for an effortless look today.'
                : 'Try it with your wardrobe today.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  // ============================================================
  // QUICK ACTIONS -- same 4 existing destinations, no new ones
  // ============================================================

  Widget _buildQuickActions(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Quick Access', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 14),
        SizedBox(
          height: 104,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: 4,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              switch (index) {
                case 0:
                  return _QuickActionTile(
                    icon: Icons.palette_outlined,
                    label: 'Colour\nAnalysis',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AnalysisScreen()),
                    ),
                  );
                case 1:
                  return _QuickActionTile(
                    icon: Icons.auto_awesome_outlined,
                    label: 'AI Stylist',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AIStylistScreen(),
                      ),
                    ),
                  );
                case 2:
                  return _QuickActionTile(
                    icon: Icons.checkroom_outlined,
                    label: 'My\nWardrobe',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const WardrobeScreen()),
                    ),
                  );
                default:
                  return _QuickActionTile(
                    icon: Icons.school_outlined,
                    label: 'Learning',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const LearningScreen()),
                    ),
                  );
              }
            },
          ),
        ),
      ],
    );
  }

  // ============================================================
  // AI STYLIST PROMOTION
  // ============================================================

  Widget _buildAiStylistPromo(BuildContext context) {
    return GradientCard(
      gradient: AppGradients.ai,
      icon: Icons.auto_awesome_rounded,
      padding: const EdgeInsets.all(20),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const AIStylistScreen()),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your AI Stylist',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 6),
          const Text(
            'Build an outfit from your wardrobe based on your personal colours.',
            style: TextStyle(color: Colors.white, height: 1.45),
          ),
          const SizedBox(height: 12),
          Row(
            children: const [
              Text(
                'Try AI Stylist',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              SizedBox(width: 4),
              Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 16),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================
  // WARDROBE SNAPSHOT -- real wardrobe items and count
  // ============================================================

  Widget _buildWardrobeSnapshot(BuildContext context) {
    final preview = _wardrobe.take(4).toList();

    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.xl),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const WardrobeScreen()),
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your Wardrobe',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              _dataLoaded
                  ? (_wardrobe.isEmpty
                        ? 'Add your first piece to start building outfits.'
                        : '${_wardrobe.length} piece${_wardrobe.length == 1 ? '' : 's'} saved')
                  : 'Loading your wardrobe...',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 14),
            if (preview.isNotEmpty)
              Row(
                children: preview
                    .map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                          child: item.imageUrl.isEmpty
                              ? Container(
                                  width: 56,
                                  height: 56,
                                  color: AppColors.secondary,
                                  child: const Icon(
                                    Icons.checkroom_outlined,
                                    color: AppColors.primary,
                                    size: 22,
                                  ),
                                )
                              : CachedNetworkImage(
                                  imageUrl: item.imageUrl,
                                  width: 56,
                                  height: 56,
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => Container(
                                    width: 56,
                                    height: 56,
                                    color: AppColors.secondary,
                                  ),
                                  errorWidget: (context, url, error) =>
                                      Container(
                                        width: 56,
                                        height: 56,
                                        color: AppColors.secondary,
                                        child: const Icon(
                                          Icons.checkroom_outlined,
                                          color: AppColors.primary,
                                          size: 22,
                                        ),
                                      ),
                                ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  'View wardrobe',
                  style: TextStyle(
                    color: AppColors.primaryDark,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.arrow_forward_rounded,
                  color: AppColors.primaryDark,
                  size: 16,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // PERSONAL STYLE -- real saved Style Preferences
  // ============================================================

  Widget _buildPersonalStyle(BuildContext context) {
    final hasPreferences = _styles.isNotEmpty || _preferences.isNotEmpty;

    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.xl),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const StylePreferencesScreen()),
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader(title: 'Your Style'),
            const SizedBox(height: 14),
            if (!hasPreferences)
              Row(
                children: [
                  Text(
                    'Tell us what feels like you',
                    style: TextStyle(
                      color: AppColors.primaryDark,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.arrow_forward_rounded,
                    color: AppColors.primaryDark,
                    size: 16,
                  ),
                ],
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [..._styles, ..._preferences]
                    .map(
                      (value) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceMuted,
                          borderRadius: BorderRadius.circular(AppRadius.full),
                        ),
                        child: Text(
                          value,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // PREMIUM -- restrained, real entitlement state
  // ============================================================

  Widget _buildPremiumDashboardCard(BuildContext context) {
    final isPremium = _dataLoaded && _isPremium;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.premiumAccentLight,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(
          color: AppColors.premiumAccent.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const PremiumBadge(),
              const Spacer(),
              if (isPremium)
                Text(
                  'ACTIVE',
                  style: TextStyle(
                    color: AppColors.premiumAccentDark,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            isPremium
                ? 'Your Premium styling tools are ready ✨'
                : 'Unlock deeper styling insights',
            style: TextStyle(
              color: AppColors.premiumAccentDark,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            isPremium
                ? 'Enjoy the full TiB AI styling experience -- advanced colour insights, real AI styling and Premium learning.'
                : 'Advanced colour insights, smart wardrobe tools, Premium learning and personalised AI styling.',
            style: TextStyle(
              color: AppColors.premiumAccentDark.withValues(alpha: 0.85),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          if (isPremium)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: const [
                _PremiumChip(
                  icon: Icons.palette_outlined,
                  label: 'Colour Insights',
                ),
                _PremiumChip(
                  icon: Icons.checkroom_outlined,
                  label: 'Smart Wardrobe',
                ),
                _PremiumChip(icon: Icons.auto_awesome, label: 'AI Stylist'),
                _PremiumChip(
                  icon: Icons.school_outlined,
                  label: 'Premium Learning',
                ),
              ],
            )
          else
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Premium plans will be available soon.'),
                    ),
                  );
                },
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.premiumAccent,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Upgrade to Premium'),
              ),
            ),
        ],
      ),
    );
  }
}
