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
import '../../services/ai_styling_service.dart';
import '../../services/firestore_service.dart';
import '../../services/style_preference_service.dart';
import '../../widgets/ai_insight_card.dart';
import '../../widgets/colour_swatch.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/gradient_card.dart';
import '../../widgets/premium_badge.dart';
import '../../widgets/style_chip.dart';
import '../analysis/analysis_screen.dart';
import '../wardrobe/wardrobe_screen.dart';
import 'style_preferences_screen.dart';
import '../premium/premium_screen.dart';

class AIStylistScreen extends StatefulWidget {
  const AIStylistScreen({super.key});

  @override
  State<AIStylistScreen> createState() => _AIStylistScreenState();
}

class _AIStylistScreenState extends State<AIStylistScreen>
    with SingleTickerProviderStateMixin {
  static const _brown = AppColors.primary;
  static const _soft = AppColors.secondary;
  static const _cream = AppColors.background;
  static const _text = AppColors.textPrimary;
  static const _muted = AppColors.textSecondary;

  String _occasion = 'Everyday';
  List<WardrobeItem> _wardrobe = const [];
  List<String> _styles = const [];
  List<String> _preferences = const [];
  bool _loading = true;
  bool _isPremium = false;
  String? _loadError;

  // Real Claude AI styling (Premium only). The local heuristic engine
  // above always keeps working and is what free accounts see; these
  // fields only ever hold something when a real AI response arrived.
  AiStylingResult? _aiResult;
  bool _aiLoading = false;
  String? _aiSignature;
  int _aiRequestId = 0;

  // One-time entrance reveal (fade + gentle slide-up, no bounce). Plays
  // once on first mount only -- pull-to-refresh and AI state updates
  // never replay it, they just update content in place.
  late final AnimationController _revealController;
  late final Animation<double> _headerReveal;
  late final Animation<double> _profileReveal;
  late final Animation<double> _occasionReveal;
  late final Animation<double> _lookReveal;
  late final Animation<double> _helpReveal;

  @override
  void initState() {
    super.initState();
    _loadPersonalData();

    _revealController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _headerReveal = _stage(0.00, 0.35);
    _profileReveal = _stage(0.12, 0.50);
    _occasionReveal = _stage(0.24, 0.62);
    _lookReveal = _stage(0.36, 0.78);
    _helpReveal = _stage(0.55, 1.00);
    _revealController.forward();
  }

  Animation<double> _stage(double begin, double end) {
    return CurvedAnimation(
      parent: _revealController,
      curve: Interval(begin, end, curve: Curves.easeOut),
    );
  }

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
  void dispose() {
    _revealController.dispose();
    super.dispose();
  }

  Future<void> _loadPersonalData() async {
    if (_loading && _wardrobe.isNotEmpty) {
      return;
    }

    if (mounted) {
      setState(() {
        _loading = true;
      });
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
        setState(() => _loading = false);
      }
      return;
    }

    try {
      final wardrobe = await FirestoreService.getWardrobeItems(user.uid);
      final style = await StylePreferenceService.getStylePreferences(user.uid);
      final userSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final userData = userSnapshot.data();
      final isPremium = userData?['isPremium'] == true;

      if (!mounted) {
        return;
      }

      setState(() {
        _wardrobe = wardrobe;
        _styles = List<String>.from(style?['styles'] ?? const []);
        _preferences = List<String>.from(style?['preferences'] ?? const []);
        _isPremium = isPremium;
        _loadError = null;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadError = 'I couldn’t refresh your wardrobe and style profile.';
          _loading = false;
        });
      }
    }
  }

  Future<void> _openWardrobe() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const WardrobeScreen()),
    );
    await _loadPersonalData();
  }

  Future<void> _openPreferences() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const StylePreferencesScreen()),
    );
    await _loadPersonalData();
  }

  void _openAnalysis() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AnalysisScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final result = context.watch<AnalysisProvider>().result;
    final colours = result?.colours ?? const <String>[];
    final matches = _matchingItems(colours, result?.brightness, result?.contrast);
    final mainColour = colours.isEmpty ? 'a soft neutral' : colours.first;

    _syncAiStyling(result);

    return Scaffold(
      backgroundColor: _cream,
      appBar: AppBar(
        backgroundColor: _cream,
        elevation: 0,
        iconTheme: const IconThemeData(color: _text),
        title: const Text(
          'Styling Assistant',
          style: TextStyle(color: _text, fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            onPressed: _loadPersonalData,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh my style data',
          ),
          IconButton(
            onPressed: _openPreferences,
            icon: const Icon(Icons.tune_rounded),
            tooltip: 'My Style',
          ),
          IconButton(
            onPressed: _openWardrobe,
            icon: const Icon(Icons.checkroom_outlined),
            tooltip: 'My Wardrobe',
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadPersonalData,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              _reveal(_headerReveal, _header(result?.season)),
              if (_loadError != null) ...[
                const SizedBox(height: 10),
                _reveal(_headerReveal, _errorCard()),
              ],
              const SizedBox(height: 18),
              _reveal(_profileReveal, _styleProfileCard(result)),
              const SizedBox(height: 10),
              _reveal(_profileReveal, _premiumStatusCard()),
              const SizedBox(height: 10),
              _reveal(_profileReveal, _personalCard()),
              const SizedBox(height: 26),
              _reveal(
                _occasionReveal,
                _title(
                  'What are you dressing for?',
                  'Tell me the moment. I will help with the rest.',
                ),
              ),
              const SizedBox(height: 12),
              _reveal(_occasionReveal, _occasions()),
              const SizedBox(height: 18),
              _reveal(_lookReveal, _recommendation(result, mainColour, matches)),
              const SizedBox(height: 26),
              _reveal(
                _helpReveal,
                _title(
                  'A little help, when you need it',
                  'Small decisions can make getting dressed easier.',
                ),
              ),
              const SizedBox(height: 12),
              _reveal(_helpReveal, _helpGrid()),
              const SizedBox(height: 22),
              _reveal(_helpReveal, _humanNote()),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // EDITORIAL HEADER -- "YOUR AI STYLIST"
  // ============================================================

  Widget _header(String? season) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: const BoxDecoration(color: _soft, shape: BoxShape.circle),
          child: const Icon(
            Icons.auto_awesome_rounded,
            color: _brown,
            size: 27,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Your AI Stylist',
                style: TextStyle(
                  color: _text,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 5),
              const Text(
                'Let’s create a look that feels like you.',
                style: TextStyle(color: _muted, fontSize: 14, height: 1.4),
              ),
              const SizedBox(height: 3),
              Text(
                season != null
                    ? 'Styled for your $season palette.'
                    : 'Complete your colour analysis for more personalised styling.',
                style: const TextStyle(
                  color: _brown,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _errorCard() {
    return Material(
      color: AppColors.error.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: _loadPersonalData,
        borderRadius: BorderRadius.circular(16),
        child: const Padding(
          padding: EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(Icons.cloud_off_rounded, color: _brown),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Some personal styling data could not be refreshed. Tap to try again.',
                  style: TextStyle(color: _text, fontSize: 13, height: 1.35),
                ),
              ),
              Icon(Icons.refresh_rounded, color: _brown, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // YOUR STYLE PROFILE -- real Season/Undertone/Brightness/Contrast +
  // real recommended colours, or a real onboarding invitation.
  // ============================================================

  Widget _styleProfileCard(ColourAnalysisResult? result) {
    if (result == null) {
      return GradientCard(
        gradient: AppGradients.primary,
        icon: Icons.palette_outlined,
        onTap: _openAnalysis,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Discover Your Personal Style',
              style: TextStyle(
                color: _cream,
                fontSize: 19,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Complete your colour analysis first and your AI stylist can '
              'create more personalised looks.',
              style: TextStyle(color: _cream.withValues(alpha: 0.7), height: 1.5),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _openAnalysis,
                style: FilledButton.styleFrom(
                  backgroundColor: _cream,
                  foregroundColor: _brown,
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'YOUR STYLE PROFILE',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            result.season,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${result.undertone} • ${result.brightness} • ${result.contrast}',
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          if (result.colours.isNotEmpty) ...[
            const SizedBox(height: 16),
            Row(
              children: result.colours
                  .take(6)
                  .map(
                    (c) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ColourSwatch(name: c, size: 28),
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _premiumStatusCard() {
    return Material(
      color: _isPremium ? AppColors.premiumAccentLight : AppColors.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const PremiumScreen(),
            ),
          );
        },
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: _isPremium
                  ? AppColors.primary.withValues(alpha: 0.35)
                  : AppColors.border,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _isPremium ? AppColors.premiumAccentLight : _soft,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _isPremium
                      ? Icons.workspace_premium_rounded
                      : Icons.lock_outline_rounded,
                  color: _brown,
                  size: 21,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isPremium
                          ? 'Premium styling is active'
                          : 'Unlock Premium styling',
                      style: const TextStyle(
                        color: _text,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _isPremium
                          ? 'Your account can use advanced wardrobe styling.'
                          : 'Get advanced wardrobe-based styling features.',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: _muted,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _personalCard() {
    final wardrobeEmpty = !_loading && _wardrobe.isEmpty;
    final styleText = _loading
        ? 'Loading your style...'
        : _styles.isEmpty
        ? 'Tell me what feels like you'
        : _styles.take(2).join(' · ');

    return Column(
      children: [
        if (wardrobeEmpty)
          EmptyState(
            icon: Icons.checkroom_outlined,
            title: 'Build Your Wardrobe',
            description:
                'Add a few pieces and your stylist can start creating '
                'outfits from what you own.',
            ctaLabel: 'Go to Wardrobe',
            onCta: _openWardrobe,
          )
        else
          _action(
            Icons.checkroom_outlined,
            'My wardrobe',
            _loading
                ? 'Looking through your wardrobe...'
                : '${_wardrobe.length} pieces ready to style',
            _openWardrobe,
          ),
        const SizedBox(height: 8),
        _action(
          Icons.favorite_border_rounded,
          'My style',
          styleText,
          _openPreferences,
        ),
      ],
    );
  }

  Widget _action(
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap,
  ) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(17),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(17),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: _soft,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: _brown, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: _text,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: _muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: _muted),
            ],
          ),
        ),
      ),
    );
  }

  Widget _title(String title, String subtitle) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: const TextStyle(
          color: _text,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),
      const SizedBox(height: 4),
      Text(
        subtitle,
        style: const TextStyle(color: _muted, fontSize: 13, height: 1.4),
      ),
    ],
  );

  // ============================================================
  // OCCASION SELECTOR -- same 5 real values, same trigger mechanism.
  // Restyled with the shared StyleChip for a fashion-chip feel.
  // ============================================================

  static const _occasionIcons = <String, IconData>{
    'Everyday': Icons.wb_sunny_outlined,
    'Work': Icons.work_outline_rounded,
    'Date': Icons.favorite_border_rounded,
    'Event': Icons.celebration_outlined,
    'Weekend': Icons.weekend_outlined,
  };

  Widget _occasions() {
    const values = ['Everyday', 'Work', 'Date', 'Event', 'Weekend'];
    return SizedBox(
      height: 46,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: values.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, index) {
          final value = values[index];
          return StyleChip(
            label: value,
            icon: _occasionIcons[value],
            selected: value == _occasion,
            onTap: () => setState(() => _occasion = value),
          );
        },
      ),
    );
  }

  /// Fires (or clears) the real Claude AI request in response to state
  /// that actually changed -- never on every rebuild. Safe to call from
  /// build(): it only schedules work via a post-frame callback, it never
  /// calls setState synchronously here.
  void _syncAiStyling(ColourAnalysisResult? result) {
    if (_loading) {
      return;
    }

    if (!_isPremium) {
      if (_aiResult != null || _aiLoading) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          setState(() {
            _aiResult = null;
            _aiLoading = false;
          });
        });
      }
      _aiSignature = null;
      return;
    }

    final signature = _aiSignatureFor(result);
    if (signature == _aiSignature) {
      return;
    }
    _aiSignature = signature;
    WidgetsBinding.instance.addPostFrameCallback((_) => _requestAiStyling(result));
  }

  String _aiSignatureFor(ColourAnalysisResult? result) {
    final profileSignature = result == null
        ? 'none'
        : '${result.season}|${result.undertone}|${result.brightness}|${result.contrast}|${result.colours.join(',')}';
    final wardrobeSignature = _wardrobe
        .map((item) => '${item.id}:${item.colour}:${item.isFavourite}')
        .join(',');
    final styleSignature = [..._styles, ..._preferences].join(',');
    return '$profileSignature::$_occasion::$wardrobeSignature::$styleSignature';
  }

  Future<void> _requestAiStyling(ColourAnalysisResult? result) async {
    if (!mounted) {
      return;
    }

    if (!_isPremium || result == null || _wardrobe.isEmpty) {
      setState(() {
        _aiResult = null;
        _aiLoading = false;
      });
      return;
    }

    final requestId = ++_aiRequestId;
    setState(() => _aiLoading = true);

    final aiResult = await AiStylingService.getRecommendation(
      profile: result,
      wardrobe: _wardrobe,
      styles: _styles,
      preferences: _preferences,
      occasion: _occasion,
    );

    if (!mounted || requestId != _aiRequestId) {
      return;
    }

    setState(() {
      _aiResult = aiResult;
      _aiLoading = false;
    });
  }

  WardrobeItem? _findWardrobeItem(String? id) {
    if (id == null) {
      return null;
    }
    for (final item in _wardrobe) {
      if (item.id == id) {
        return item;
      }
    }
    return null;
  }

  // Colour-analysis-grounded vocabulary: a "Light" brightness profile is
  // typically recommended lighter clothing values, a "Deep" profile can
  // carry deeper values, and "High"/"Low" contrast maps to how much
  // contrast an outfit itself can carry. These word lists are matched
  // against the wardrobe item's own colour text, the same way the rest
  // of this screen already matches colour/style keywords.
  static const _lightColourWords = [
    'white',
    'ivory',
    'cream',
    'pastel',
    'light',
    'pale',
    'blush',
    'powder',
    'beige',
    'nude',
  ];
  static const _deepColourWords = [
    'black',
    'navy',
    'charcoal',
    'burgundy',
    'deep',
    'dark',
    'wine',
    'emerald',
    'plum',
    'maroon',
  ];
  static const _highContrastColourWords = [
    'black',
    'white',
    'red',
    'bold',
    'bright',
    'vivid',
  ];
  static const _lowContrastColourWords = [
    'beige',
    'cream',
    'muted',
    'soft',
    'tonal',
    'pastel',
    'neutral',
    'nude',
  ];

  int _brightnessScore(String? brightness, String itemColour) {
    if (brightness == null) {
      return 0;
    }
    final isLight = _lightColourWords.any(itemColour.contains);
    final isDeep = _deepColourWords.any(itemColour.contains);
    switch (brightness) {
      case 'Light':
        if (isLight) return 3;
        if (isDeep) return -2;
        return 0;
      case 'Deep':
        if (isDeep) return 3;
        if (isLight) return -2;
        return 0;
      case 'Medium':
        if (!isLight && !isDeep) return 2;
        return 0;
      default:
        return 0;
    }
  }

  int _contrastScore(String? contrast, String itemColour) {
    if (contrast == null) {
      return 0;
    }
    final isHigh = _highContrastColourWords.any(itemColour.contains);
    final isLow = _lowContrastColourWords.any(itemColour.contains);
    switch (contrast) {
      case 'High':
        if (isHigh) return 3;
        if (isLow) return -1;
        return 0;
      case 'Low':
        if (isLow) return 3;
        if (isHigh) return -1;
        return 0;
      case 'Medium':
        if (!isHigh && !isLow) return 2;
        return 0;
      default:
        return 0;
    }
  }

  List<WardrobeItem> _matchingItems(
    List<String> colours,
    String? brightness,
    String? contrast,
  ) {
    if (_wardrobe.isEmpty) {
      return const [];
    }

    final wanted = colours.map((e) => e.toLowerCase()).toList();

    final ranked = List<WardrobeItem>.from(_wardrobe)
      ..sort(
        (a, b) => _itemScore(
          b,
          wanted,
          brightness,
          contrast,
        ).compareTo(_itemScore(a, wanted, brightness, contrast)),
      );

    return ranked.take(_isPremium ? 6 : 2).toList();
  }

  int _itemScore(
    WardrobeItem item,
    List<String> wantedColours,
    String? brightness,
    String? contrast,
  ) {
    var score = 0;

    if (item.isFavourite) {
      score += 4;
    }

    final itemColour = item.colour.toLowerCase();
    if (wantedColours.any(
      (colour) => colour.contains(itemColour) || itemColour.contains(colour),
    )) {
      score += 6;
    }

    score += _brightnessScore(brightness, itemColour);
    score += _contrastScore(contrast, itemColour);

    final styleProfile = [
      ..._styles,
      ..._preferences,
    ].map((value) => value.toLowerCase()).join(' ');

    final itemText = '${item.name} ${item.category} $itemColour'.toLowerCase();

    for (final keyword in [
      'casual',
      'minimal',
      'classic',
      'elegant',
      'feminine',
      'street',
      'smart',
      'comfortable',
      'neutral',
    ]) {
      if (styleProfile.contains(keyword) && itemText.contains(keyword)) {
        score += 2;
      }
    }

    if (_isPremium) {
      final premiumStyleRules = <String, List<String>>{
        'minimal': ['minimal', 'basic', 'plain', 'simple', 'neutral'],
        'elegant': ['elegant', 'dress', 'blouse', 'skirt', 'heels'],
        'classic': ['classic', 'blazer', 'shirt', 'trousers', 'neutral'],
        'casual': ['casual', 'jeans', 't-shirt', 'tee', 'sneaker'],
        'feminine': ['feminine', 'dress', 'skirt', 'blouse', 'pink'],
        'street': ['street', 'oversized', 'hoodie', 'sneaker', 'denim'],
        'smart': ['smart', 'blazer', 'shirt', 'trousers', 'loafer'],
        'comfortable': ['comfortable', 'knit', 'cardigan', 'sweater', 'flat'],
      };

      for (final entry in premiumStyleRules.entries) {
        if (styleProfile.contains(entry.key) &&
            entry.value.any(itemText.contains)) {
          score += 5;
        }
      }

      if (styleProfile.contains('keep it simple') &&
          !itemText.contains('statement') &&
          !itemText.contains('bold')) {
        score += 3;
      }

      if (styleProfile.contains('i love accessories')) {
        score += item.category == 'Accessories' ? 6 : 1;
      }

      if (styleProfile.contains('comfort first') &&
          (itemText.contains('comfortable') ||
              itemText.contains('soft') ||
              itemText.contains('relaxed'))) {
        score += 5;
      }
    }

    score += _occasionScore(_occasion, item);

    return score;
  }

  // Occasion-preferred styles use the exact Style dropdown values the
  // Wardrobe screen already offers ('Everyday', 'Minimal', 'Elegant',
  // 'Casual', 'Smart Casual', 'Feminine', 'Trendy') -- no invented
  // vocabulary, just real values items can actually have.
  static const Map<String, List<String>> _occasionPreferredStyles = {
    'Everyday': ['everyday', 'casual'],
    'Work': ['smart casual', 'minimal', 'elegant'],
    'Date': ['elegant', 'feminine', 'smart casual', 'trendy'],
    'Event': ['elegant', 'trendy', 'feminine'],
    'Weekend': ['casual', 'everyday'],
  };

  /// How well [item] suits [occasion], using its real style and category
  /// fields. Only ever adjusts ranking order within a category -- it never
  /// excludes an item, so the fallback still always has something to show
  /// even if the wardrobe has nothing occasion-perfect.
  int _occasionScore(String occasion, WardrobeItem item) {
    var score = 0;
    final style = item.style.toLowerCase();
    final category = item.category;

    if ((_occasionPreferredStyles[occasion] ?? const []).any(style.contains)) {
      score += 4;
    }

    switch (occasion) {
      case 'Work':
        // Professional, polished, more structured combinations.
        if (category == 'Tops' || category == 'Bottoms' || category == 'Dresses') {
          score += 2;
        }
        break;
      case 'Date':
        // More polished/coordinated; an accessory can lift the look.
        if (category == 'Dresses') {
          score += 2;
        }
        if (category == 'Accessories') {
          score += 2;
        }
        break;
      case 'Event':
        // More elevated/statement styling where the wardrobe supports it.
        if (category == 'Dresses') {
          score += 3;
        }
        if (category == 'Accessories') {
          score += 2;
        }
        break;
      case 'Weekend':
        // Relaxed and comfortable.
        if (category == 'Tops' || category == 'Shoes') {
          score += 1;
        }
        break;
      case 'Everyday':
        // Practical, versatile basics.
        if (category == 'Tops' || category == 'Bottoms') {
          score += 1;
        }
        break;
    }

    return score;
  }

  // ============================================================
  // YOUR LOOK -- the visual centrepiece. Same selection logic as
  // before (Claude pick first, heuristic fills the rest); only the
  // presentation changed.
  // ============================================================

  Widget _recommendation(
    ColourAnalysisResult? result,
    String mainColour,
    List<WardrobeItem> items,
  ) {
    final hasProfile = result != null;
    final wanted =
        (result?.colours ?? const <String>[]).map((e) => e.toLowerCase()).toList();
    WardrobeItem? top;
    WardrobeItem? bottom;
    WardrobeItem? shoes;
    WardrobeItem? accessory;

    // Premium accounts with a real Claude pick get that pick first; the
    // heuristic below still fills in any slot Claude left null or that
    // didn't resolve to a real, current wardrobe item.
    if (_isPremium && _aiResult != null) {
      top = _findWardrobeItem(_aiResult!.topId);
      bottom = _findWardrobeItem(_aiResult!.bottomId);
      shoes = _findWardrobeItem(_aiResult!.shoesId);
      accessory = _findWardrobeItem(_aiResult!.accessoryId);
    }

    for (final item in items) {
      if (top == null &&
          (item.category == 'Tops' || item.category == 'Dresses')) {
        top = item;
      }
      if (bottom == null && item.category == 'Bottoms') {
        bottom = item;
      }
      if (shoes == null && item.category == 'Shoes') {
        shoes = item;
      }
      if (accessory == null && item.category == 'Accessories') {
        accessory = item;
      }
    }

    // An accessory row is only shown for the occasions where one is
    // actually part of the styling guidance (Date/Event) and only when a
    // real accessory was found -- never invented.
    final showAccessory =
        accessory != null && (_occasion == 'Date' || _occasion == 'Event');

    final useAiExplanation = _isPremium &&
        _aiResult != null &&
        _aiResult!.explanation.isNotEmpty;
    final showAiState = _isPremium && (_aiLoading || useAiExplanation);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.textPrimary.withValues(alpha: .04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: _soft,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _occasion,
                  style: const TextStyle(
                    color: _brown,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Spacer(),
              if (_isPremium) const PremiumBadge(compact: true),
              const SizedBox(width: 8),
              const Icon(Icons.favorite_border_rounded, color: _brown),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            items.isEmpty ? 'Your first styling idea' : 'Your Look',
            style: const TextStyle(
              color: _text,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),

          if (items.isEmpty)
            Text(
              hasProfile
                  ? 'Try $mainColour as your main colour, then add a calm neutral.'
                  : 'Complete your colour analysis and add a few wardrobe pieces so I can style what you actually own.',
              style: const TextStyle(color: _muted, fontSize: 14, height: 1.5),
            )
          else ...[
            // Real outfit pieces, with real wardrobe images.
            if (top != null)
              _outfitItemRow(
                'Main piece',
                top,
                highlightMatch: _matchesPalette(top, wanted),
              ),
            if (bottom != null) ...[
              const SizedBox(height: 12),
              _outfitItemRow(
                'Bottom',
                bottom,
                highlightMatch: _matchesPalette(bottom, wanted),
              ),
            ],
            if (shoes != null) ...[
              const SizedBox(height: 12),
              _outfitItemRow(
                'Shoes',
                shoes,
                highlightMatch: _matchesPalette(shoes, wanted),
              ),
            ],
            if (showAccessory) ...[
              const SizedBox(height: 12),
              _outfitItemRow(
                'Accessory',
                accessory,
                highlightMatch: _matchesPalette(accessory, wanted),
              ),
            ],

            const SizedBox(height: 16),

            // "Why this look works" -- clearly labelled as either real
            // Claude output or the deterministic heuristic, never blurred
            // together. The heuristic recommendation above stays visible
            // the whole time Claude is thinking; nothing is blocked.
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: showAiState
                  ? AIInsightCard(
                      key: const ValueKey('ai'),
                      loading: _aiLoading,
                      child: Text(
                        useAiExplanation ? _aiResult!.explanation : '',
                        style: TextStyle(
                          color: AppColors.aiAccentDark,
                          height: 1.5,
                          fontSize: 13.5,
                        ),
                      ),
                    )
                  : Container(
                      key: const ValueKey('heuristic'),
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: _cream,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'WHY THIS LOOK WORKS',
                            style: TextStyle(
                              color: _brown,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.6,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _pickExplanation(
                              items,
                              wanted,
                              result?.brightness,
                              result?.contrast,
                            ),
                            style: const TextStyle(
                              color: _muted,
                              fontSize: 13.5,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
            ),

            if (wanted.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                'YOUR COLOUR PALETTE',
                style: TextStyle(
                  color: _muted,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 12,
                runSpacing: 10,
                children: (result?.colours ?? const <String>[])
                    .map((c) => ColourSwatch(name: c, size: 32, showLabel: true))
                    .toList(),
              ),
            ],
          ],

          if (_styles.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              'Style direction · ${_styles.take(2).join(' · ')}',
              style: const TextStyle(
                color: _brown,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],

          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _showRecommendation(
                    items,
                    mainColour,
                    top,
                    bottom,
                    shoes,
                    showAccessory ? accessory : null,
                  ),
                  icon: const Icon(Icons.auto_awesome_rounded),
                  label: const Text('Build this look'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _brown,
                    foregroundColor: _cream,
                    minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              IconButton.filledTonal(
                onPressed: _openWardrobe,
                icon: const Icon(Icons.checkroom_outlined),
              ),
            ],
          ),
        ],
      ),
    );
  }

  bool _matchesPalette(WardrobeItem item, List<String> wantedColours) {
    final itemColour = item.colour.toLowerCase();
    return wantedColours.any(
      (colour) => colour.contains(itemColour) || itemColour.contains(colour),
    );
  }

  IconData _categoryIcon(String category) {
    switch (category) {
      case 'Bottoms':
        return Icons.layers_outlined;
      case 'Shoes':
        return Icons.directions_walk_outlined;
      case 'Accessories':
        return Icons.diamond_outlined;
      default:
        return Icons.checkroom_outlined;
    }
  }

  Widget _outfitItemRow(
    String title,
    WardrobeItem item, {
    bool highlightMatch = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          child: item.imageUrl.isEmpty
              ? Container(
                  width: 60,
                  height: 60,
                  color: _soft,
                  child: Icon(_categoryIcon(item.category), color: _brown),
                )
              : CachedNetworkImage(
                  imageUrl: item.imageUrl,
                  width: 60,
                  height: 60,
                  fit: BoxFit.cover,
                  placeholder: (context, url) =>
                      Container(width: 60, height: 60, color: _soft),
                  errorWidget: (context, url, error) => Container(
                    width: 60,
                    height: 60,
                    color: _soft,
                    child: Icon(_categoryIcon(item.category), color: _brown),
                  ),
                ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title.toUpperCase(),
                style: const TextStyle(
                  color: _muted,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                item.name,
                style: const TextStyle(color: _text, fontWeight: FontWeight.w700),
              ),
              if (item.colour.isNotEmpty)
                Text(
                  item.colour,
                  style: const TextStyle(color: _muted, fontSize: 11.5),
                ),
              if (highlightMatch) ...[
                const SizedBox(height: 3),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.check_circle_rounded,
                      size: 12,
                      color: AppColors.success,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      'Matches your palette',
                      style: TextStyle(
                        fontSize: 10.5,
                        color: AppColors.success,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  /// Real, verifiable reasons why [item] was picked -- only factors that
  /// are actually true for this item are included, nothing is assumed.
  List<String> _pickReasons(
    WardrobeItem item,
    List<String> wantedColours,
    String? brightness,
    String? contrast,
  ) {
    final reasons = <String>[];
    final itemColour = item.colour.toLowerCase();

    final colourMatch = wantedColours.any(
      (colour) => colour.contains(itemColour) || itemColour.contains(colour),
    );
    if (colourMatch) {
      reasons.add('matches your colour profile');
    }

    if (brightness != null && _brightnessScore(brightness, itemColour) > 0) {
      reasons.add('suits your ${brightness.toLowerCase()} brightness');
    }

    if (contrast != null && _contrastScore(contrast, itemColour) > 0) {
      reasons.add('works with your ${contrast.toLowerCase()} contrast level');
    }

    final styleProfile = [
      ..._styles,
      ..._preferences,
    ].map((value) => value.toLowerCase()).join(' ');
    final itemText = '${item.name} ${item.category} $itemColour'.toLowerCase();
    final styleMatch = [
      'casual',
      'minimal',
      'classic',
      'elegant',
      'feminine',
      'street',
      'smart',
      'comfortable',
      'neutral',
    ].any((keyword) => styleProfile.contains(keyword) && itemText.contains(keyword));
    if (styleMatch) {
      reasons.add('fits the style you saved');
    }

    if (_occasionScore(_occasion, item) > 0) {
      reasons.add('suits $_occasion');
    }

    if (item.isFavourite) {
      reasons.add("it's one of your favourites");
    }

    return reasons;
  }

  String _reasonSentence(List<String> reasons) {
    if (reasons.isEmpty) {
      return '';
    }
    if (reasons.length == 1) {
      return reasons.first;
    }
    if (reasons.length == 2) {
      return '${reasons[0]} and ${reasons[1]}';
    }
    return '${reasons.sublist(0, reasons.length - 1).join(', ')} and ${reasons.last}';
  }

  String _pickExplanation(
    List<WardrobeItem> items,
    List<String> wantedColours,
    String? brightness,
    String? contrast,
  ) {
    final base = _isPremium
        ? 'I prioritised pieces you already own, your colour profile and your saved Style Profile. Premium preferences have a stronger influence on the ranking.'
        : 'I prioritised pieces you already own, your colour profile and the style preferences you saved.';

    final reasons = _pickReasons(items.first, wantedColours, brightness, contrast);
    final sentence = _reasonSentence(reasons);
    if (sentence.isEmpty) {
      return base;
    }
    return '$base This top pick $sentence.';
  }

  Widget _helpGrid() => GridView.count(
    crossAxisCount: 2,
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    crossAxisSpacing: 12,
    mainAxisSpacing: 12,
    childAspectRatio: 1.12,
    children: [
      _help(
        Icons.checkroom_outlined,
        'My wardrobe',
        'Style pieces you already own.',
        _openWardrobe,
      ),
      _help(
        Icons.palette_outlined,
        'Mix & match',
        'Find colours that work together.',
        _showColourIdeas,
      ),
      _help(
        Icons.shopping_bag_outlined,
        'Shopping help',
        _isPremium
            ? 'See what your wardrobe is missing.'
            : 'Premium feature · See what your wardrobe is missing.',
        () => _runPremiumAction(_showShoppingIdeas),
      ),
      _help(
        Icons.event_outlined,
        'Dress for it',
        'Make an occasion feel effortless.',
        _showOccasionIdeas,
      ),
    ],
  );

  Widget _help(
    IconData icon,
    String title,
    String description,
    VoidCallback onTap,
  ) => Material(
    color: AppColors.surface,
    borderRadius: BorderRadius.circular(20),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: const BoxDecoration(
                color: _soft,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: _brown),
            ),
            const Spacer(),
            Text(
              title,
              style: const TextStyle(color: _text, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: _muted, fontSize: 12, height: 1.35),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _humanNote() => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: AppColors.surfaceMuted,
      borderRadius: BorderRadius.circular(20),
    ),
    child: const Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.tips_and_updates_outlined, color: _brown),
        SizedBox(width: 12),
        Expanded(
          child: Text(
            'Good style does not mean following every trend. It is about finding choices that feel comfortable, confident and right for you.',
            style: TextStyle(color: _muted, fontSize: 13, height: 1.5),
          ),
        ),
      ],
    ),
  );

  void _runPremiumAction(VoidCallback action) {
    if (_isPremium) {
      action();
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: _cream,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: const BoxDecoration(
                      color: _soft,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.workspace_premium_rounded,
                      color: _brown,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Premium feature',
                      style: TextStyle(
                        color: _text,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Text(
                'This advanced styling feature is available to Premium members.',
                style: TextStyle(
                  color: _muted,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const PremiumScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.workspace_premium_rounded),
                  label: const Text('View Premium'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _brown,
                    foregroundColor: _cream,
                    minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // BUILD THIS LOOK -- outfit detail sheet. Same real selected items
  // and real explanation as the main card, just presented as a focused
  // detail page.
  // ============================================================

  void _showRecommendation(
    List<WardrobeItem> items,
    String mainColour,
    WardrobeItem? top,
    WardrobeItem? bottom,
    WardrobeItem? shoes,
    WardrobeItem? accessory,
  ) {
    final wanted = context
        .read<AnalysisProvider>()
        .result
        ?.colours
        .map((e) => e.toLowerCase())
        .toList() ??
        const <String>[];
    final colours = context.read<AnalysisProvider>().result?.colours ?? const [];
    final useAiExplanation =
        _isPremium && _aiResult != null && _aiResult!.explanation.isNotEmpty;

    _sheet('Look for $_occasion', Icons.auto_awesome_rounded, [
      if (items.isEmpty)
        _sheetText(
          'Add a few pieces first. Then I can build outfits from what you actually own.',
        )
      else ...[
        if (_isPremium && (_aiLoading || useAiExplanation))
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: AIInsightCard(
              loading: _aiLoading,
              child: Text(
                useAiExplanation ? _aiResult!.explanation : '',
                style: TextStyle(
                  color: AppColors.aiAccentDark,
                  height: 1.5,
                  fontSize: 13.5,
                ),
              ),
            ),
          )
        else
          _sheetText(
            'I picked from your own wardrobe first, then considered your '
            'colour profile, saved preferences and $_occasion.',
          ),
        if (top != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: _outfitItemRow(
              'Main piece',
              top,
              highlightMatch: _matchesPalette(top, wanted),
            ),
          ),
        if (bottom != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: _outfitItemRow(
              'Bottom',
              bottom,
              highlightMatch: _matchesPalette(bottom, wanted),
            ),
          ),
        if (shoes != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: _outfitItemRow(
              'Shoes',
              shoes,
              highlightMatch: _matchesPalette(shoes, wanted),
            ),
          ),
        if (accessory != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: _outfitItemRow(
              'Accessory',
              accessory,
              highlightMatch: _matchesPalette(accessory, wanted),
            ),
          ),
        if (colours.isNotEmpty) ...[
          const Text(
            'YOUR COLOUR PALETTE',
            style: TextStyle(
              color: _muted,
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: colours
                .map((c) => ColourSwatch(name: c, size: 28, showLabel: true))
                .toList(),
          ),
          const SizedBox(height: 14),
        ],
      ],
      _sheetItem('Styling thought', _occasionTip()),
    ]);
  }

  String _occasionTip() {
    switch (_occasion) {
      case 'Work':
        return 'Keep the outfit polished and comfortable. Let one colour or accessory add personality.';
      case 'Date':
        return 'Choose one flattering colour near your face and keep the rest relaxed so the look still feels like you.';
      case 'Event':
        return 'Let one piece be the focus. Keep the other pieces simple enough to support it.';
      case 'Weekend':
        return 'Start with comfort, then add one detail that makes the outfit feel intentional.';
      default:
        return 'Keep one main colour, one supporting neutral and one small detail that feels like you.';
    }
  }

  void _showColourIdeas() {
    final colours =
        context.read<AnalysisProvider>().result?.colours ?? const <String>[];
    _sheet('Mix & match', Icons.palette_outlined, [
      _sheetText(
        colours.isEmpty
            ? 'Complete your colour analysis to see your personal palette.'
            : 'Use one of your best colours as the focus and pair it with a calm neutral.',
      ),
      if (colours.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Wrap(
            spacing: 14,
            runSpacing: 14,
            children: colours
                .take(6)
                .map((c) => ColourSwatch(name: c, size: 44, showLabel: true))
                .toList(),
          ),
        ),
    ]);
  }

  void _showShoppingIdeas() {
    final missing = <String>[];
    if (!_wardrobe.any((i) => i.category == 'Tops')) {
      missing.add('a versatile top');
    }
    if (!_wardrobe.any((i) => i.category == 'Bottoms')) {
      missing.add('an easy-to-match bottom');
    }
    if (!_wardrobe.any((i) => i.category == 'Shoes')) {
      missing.add('a reliable pair of shoes');
    }
    _sheet('Shopping assistant', Icons.shopping_bag_outlined, [
      _sheetText(
        missing.isEmpty
            ? 'Your basics are covered. Look for variety rather than duplicates.'
            : 'These are the wardrobe gaps I would fill first.',
      ),
      ...missing.map((m) => _sheetItem('Consider', m)),
      _sheetItem(
        'Before buying',
        'Ask yourself if the new piece works with at least three things you already own.',
      ),
    ]);
  }

  void _showOccasionIdeas() =>
      _sheet('Dress for $_occasion', Icons.event_outlined, [
    _sheetItem('Work', 'Polished, comfortable and easy to repeat.'),
    _sheetItem(
      'Date',
      'Keep a flattering colour close to your face and add one personal detail.',
    ),
    _sheetItem(
      'Event',
      'Choose one statement piece and let the rest support it.',
    ),
    _sheetItem(
      'Weekend',
      'Prioritise comfort without losing your personal style.',
    ),
  ]);

  void _sheet(String title, IconData icon, List<Widget> children) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: _cream,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 5, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(
                      color: _soft,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: _brown),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        color: _text,
                        fontSize: 21,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              ...children,
            ],
          ),
        ),
      ),
    );
  }

  Widget _sheetText(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Text(
      text,
      style: const TextStyle(color: _muted, height: 1.5, fontSize: 14),
    ),
  );
  Widget _sheetItem(String title, String description) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(
      color: AppColors.surfaceMuted,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(color: _text, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          description,
          style: const TextStyle(color: _muted, fontSize: 13, height: 1.4),
        ),
      ],
    ),
  );
}
