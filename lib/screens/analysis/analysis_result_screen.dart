import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_gradients.dart';
import '../../core/constants/app_radius.dart';
import '../../models/colour_analysis_result.dart';
import '../../widgets/colour_swatch.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/gradient_card.dart';
import '../../widgets/premium_badge.dart';
import '../../widgets/section_header.dart';

class AnalysisResultScreen extends StatefulWidget {
  final ColourAnalysisResult result;

  const AnalysisResultScreen({super.key, required this.result});

  @override
  State<AnalysisResultScreen> createState() => _AnalysisResultScreenState();
}

class _AnalysisResultScreenState extends State<AnalysisResultScreen>
    with SingleTickerProviderStateMixin {
  bool _isPremium = false;
  bool _premiumLoaded = false;

  ColourAnalysisResult get result => widget.result;

  // Staged reveal -- fast (1s total), fade + gentle slide-up, no bounce.
  // Timings follow the approved sequence: 0.0s intro, 0.15s season hero,
  // 0.30s attributes, 0.45s palette, 0.60s supporting content, 0.75s
  // premium insights / actions.
  late final AnimationController _revealController;
  late final Animation<double> _introReveal;
  late final Animation<double> _heroReveal;
  late final Animation<double> _attributesReveal;
  late final Animation<double> _paletteReveal;
  late final Animation<double> _supportingReveal;
  late final Animation<double> _premiumAndActionsReveal;

  @override
  void initState() {
    super.initState();
    _loadPremiumStatus();

    _revealController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _introReveal = _stage(0.00, 0.30);
    _heroReveal = _stage(0.15, 0.45);
    _attributesReveal = _stage(0.30, 0.60);
    _paletteReveal = _stage(0.45, 0.75);
    _supportingReveal = _stage(0.60, 0.90);
    _premiumAndActionsReveal = _stage(0.75, 1.00);

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

  Future<void> _loadPremiumStatus() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      if (mounted) {
        setState(() {
          _premiumLoaded = true;
        });
      }
      return;
    }

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

      if (!mounted) {
        return;
      }

      setState(() {
        _isPremium = snapshot.data()?['isPremium'] == true;
        _premiumLoaded = true;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isPremium = false;
        _premiumLoaded = true;
      });
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
    final textTheme = Theme.of(context).textTheme;
    final seasonAccent = AppColors.seasonAccent(result.season);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Your Colour Result'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Back to analysis',
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 30),
          children: [
            // ========================================================
            // INTRO
            // ========================================================
            _reveal(
              _introReveal,
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      'Here’s what suits you',
                      textAlign: TextAlign.center,
                      style: textTheme.titleLarge,
                    ),
                  ),
                  if (_premiumLoaded && _isPremium) ...[
                    const SizedBox(width: 8),
                    const PremiumBadge(compact: true),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 6),

            _reveal(
              _introReveal,
              Text(
                'Your result gives you a simple starting point for choosing '
                'clothes, accessories and everyday colours.',
                textAlign: TextAlign.center,
                style: textTheme.bodyMedium,
              ),
            ),

            const SizedBox(height: 22),

            // ========================================================
            // SEASON HERO
            // ========================================================
            _reveal(
              _heroReveal,
              GradientCard(
                gradient: AppGradients.season(result.season),
                padding: const EdgeInsets.fromLTRB(24, 26, 24, 24),
                child: SizedBox(
                  width: double.infinity,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
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
                      const SizedBox(height: 10),
                      Text(
                        result.season.toUpperCase(),
                        textAlign: TextAlign.center,
                        style: textTheme.displaySmall?.copyWith(
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'A personalised colour palette selected for you.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.92),
                          height: 1.4,
                        ),
                      ),
                      if (result.colours.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: result.colours
                              .take(5)
                              .map(
                                (colour) => Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                  ),
                                  child: ColourSwatch(name: colour, size: 34),
                                ),
                              )
                              .toList(),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // ========================================================
            // PERSONAL COLOUR ATTRIBUTES
            // ========================================================
            _reveal(
              _attributesReveal,
              Row(
                children: [
                  _attributeCard(
                    icon: Icons.thermostat_outlined,
                    label: 'Undertone',
                    value: result.undertone,
                    accent: seasonAccent,
                  ),
                  _attributeCard(
                    icon: Icons.wb_sunny_outlined,
                    label: 'Brightness',
                    value: result.brightness,
                    accent: seasonAccent,
                  ),
                  _attributeCard(
                    icon: Icons.contrast_rounded,
                    label: 'Contrast',
                    value: result.contrast,
                    accent: seasonAccent,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // ========================================================
            // RECOMMENDED COLOUR PALETTE
            // ========================================================
            _reveal(
              _paletteReveal,
              const SectionHeader(
                title: 'Your Best Colours',
                subtitle:
                    'Start with these shades when choosing your next outfit.',
              ),
            ),

            const SizedBox(height: 16),

            _reveal(
              _paletteReveal,
              result.colours.isEmpty
                  ? EmptyState(
                      icon: Icons.palette_outlined,
                      title: 'No colours yet',
                      description:
                          'This result did not include a saved colour '
                          'palette.',
                      accent: AppGradients.season(result.season),
                    )
                  : Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 18,
                      runSpacing: 18,
                      children: result.colours
                          .map(
                            (colour) => ColourSwatch(
                              name: colour,
                              size: 56,
                              showLabel: true,
                            ),
                          )
                          .toList(),
                    ),
            ),

            const SizedBox(height: 28),

            // ========================================================
            // SUPPORTING CONTENT -- styling tip + analysis photo
            // ========================================================
            _reveal(_supportingReveal, _buildTipCard()),

            if (result.imageUrl.isNotEmpty) ...[
              const SizedBox(height: 26),
              _reveal(
                _supportingReveal,
                const SectionHeader(title: 'Your Analysis Photo'),
              ),
              const SizedBox(height: 14),
              _reveal(_supportingReveal, _buildAnalysisPhoto()),
            ],

            const SizedBox(height: 26),

            // ========================================================
            // WHY THESE COLOURS SUIT YOU -- real Premium insights only.
            // Nothing is shown here for non-Premium accounts: there is no
            // real explanatory data to present without Premium, and this
            // screen never invents one.
            // ========================================================
            if (_premiumLoaded && _isPremium) ...[
              _reveal(_premiumAndActionsReveal, _buildPremiumInsights()),
              const SizedBox(height: 24),
            ],

            // ========================================================
            // ACTION
            // ========================================================
            _reveal(
              _premiumAndActionsReveal,
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Analyse Another Photo'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(double.infinity, 52),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // ATTRIBUTE CARD
  // ============================================================

  Widget _attributeCard({
    required IconData icon,
    required String label,
    required String value,
    required Color accent,
  }) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 19, color: accent),
            ),
            const SizedBox(height: 10),
            Text(
              label.toUpperCase(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // TIP CARD
  // ============================================================

  Widget _buildTipCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CircleAvatar(
            radius: 21,
            backgroundColor: AppColors.secondary,
            child: Icon(Icons.lightbulb_outline, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'A little tip for you',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 5),
                Text(
                  'Use your recommended colours as a guide, not a rule. '
                  'The best outfit is one that also feels comfortable and '
                  'like you.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(height: 1.45),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ANALYSIS PHOTO
  // ============================================================

  Widget _buildAnalysisPhoto() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: CachedNetworkImage(
        imageUrl: result.imageUrl,
        height: 240,
        width: double.infinity,
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(
          height: 240,
          color: AppColors.secondary,
          child: const Center(child: CircularProgressIndicator()),
        ),
        errorWidget: (context, url, error) => Container(
          height: 240,
          color: AppColors.secondary,
          child: const Center(
            child: Icon(Icons.image_not_supported_outlined, size: 50),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // PREMIUM INSIGHTS
  //
  // Same tip-generation logic as before -- only the visual presentation
  // changed, using the restrained Premium accent instead of the AI accent
  // (this content is deterministic guidance derived from the real saved
  // result, not Claude output, so it is deliberately NOT wrapped in the
  // AI-insight visual language).
  // ============================================================

  Widget _buildPremiumInsights() {
    final season = result.season.trim();
    final undertone = result.undertone.trim();
    final brightness = result.brightness.trim();
    final contrast = result.contrast.trim();

    String stylingDirection() {
      if (season.isEmpty) {
        return 'Build outfits around your recommended colours and keep '
            'your palette consistent across clothing and accessories.';
      }

      return 'Use your $season palette as the main colour direction, then '
          'balance it with your recorded undertone and contrast level.';
    }

    String contrastTip() {
      final value = contrast.toLowerCase();

      if (value.contains('high')) {
        return 'Your contrast level can support clearer separation between '
            'outfit colours. Try pairing a stronger colour with a lighter '
            'or darker supporting shade.';
      }

      if (value.contains('low')) {
        return 'A softer tonal outfit can work well with your contrast '
            'level. Try keeping neighbouring shades close in depth for a '
            'more blended look.';
      }

      return 'Your contrast level gives you flexibility. Start with one '
          'main colour and add a supporting shade without making the '
          'outfit feel too busy.';
    }

    String undertoneTip() {
      final value = undertone.toLowerCase();

      if (value.contains('warm')) {
        return 'For everyday styling, explore warmer versions of your '
            'recommended colours and repeat warm accents in accessories.';
      }

      if (value.contains('cool')) {
        return 'For everyday styling, explore cooler versions of your '
            'recommended colours and repeat cool accents in accessories.';
      }

      return 'Your undertone can work with a broad range of shades. '
          'Compare warmer and cooler versions of a colour to find the most '
          'flattering balance.';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.premiumAccentLight,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: AppColors.premiumAccent.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const PremiumBadge(label: 'PREMIUM INSIGHTS'),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Personalised styling guidance based on your recorded '
            'analysis.',
            style: TextStyle(
              color: AppColors.premiumAccentDark.withValues(alpha: 0.85),
              fontSize: 12.5,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          _buildPremiumInsightRow(
            Icons.palette_outlined,
            'Colour direction',
            stylingDirection(),
          ),
          _buildPremiumInsightRow(
            Icons.thermostat_outlined,
            'Undertone styling',
            undertoneTip(),
          ),
          _buildPremiumInsightRow(
            Icons.contrast_outlined,
            'Contrast styling',
            contrastTip(),
          ),
          const SizedBox(height: 4),
          Text(
            'Profile: $undertone • $brightness • $contrast',
            style: const TextStyle(
              color: AppColors.premiumAccentDark,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumInsightRow(
    IconData icon,
    String title,
    String description,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppColors.premiumAccent.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 18, color: AppColors.premiumAccentDark),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.premiumAccentDark,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  description,
                  style: TextStyle(
                    color: AppColors.premiumAccentDark.withValues(alpha: 0.85),
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
