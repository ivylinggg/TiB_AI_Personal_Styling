import 'package:cached_network_image/cached_network_image.dart';
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

class AIOutfitScreen extends StatefulWidget {
  const AIOutfitScreen({super.key});

  @override
  State<AIOutfitScreen> createState() => _AIOutfitScreenState();
}

class _AIOutfitScreenState extends State<AIOutfitScreen> {
  static const _occasions = [
    ('Dinner', Icons.restaurant_outlined),
    ('Work', Icons.business_center_outlined),
    ('Cafe', Icons.local_cafe_outlined),
    ('Weekend', Icons.weekend_outlined),
    ('Date', Icons.favorite_border_rounded),
  ];

  String _occasion = 'Dinner';
  List<WardrobeItem> _wardrobe = const [];
  List<WardrobeItem> _look = const [];
  bool _loading = true;
  bool _styling = false;
  bool _generated = false;
  int _generation = 0;
  final Set<String> _lovedLookIds = <String>{};
  final Set<String> _dislikedLookIds = <String>{};
  bool _savedLook = false;
  bool _savingLook = false;

  @override
  void initState() {
    super.initState();
    _loadWardrobe();
  }

  Future<void> _loadWardrobe() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      final items = await FirestoreService.getWardrobeItems(uid);
      if (mounted) {
        setState(() {
          _wardrobe = items;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  int _score(WardrobeItem item, ColourAnalysisResult profile) {
    var score = 0;
    final text = '${item.category} ${item.style} ${item.colour}'.toLowerCase();
    final occasion = _occasion.toLowerCase();
    if (item.isFavourite) score += 10;
    if (_lovedLookIds.contains(item.id)) score += 16;
    if (_dislikedLookIds.contains(item.id)) score -= 20;
    if (profile.colours.any((c) => text.contains(c.toLowerCase()))) score += 25;
    if (item.season.toLowerCase().contains(profile.season.toLowerCase())) {
      score += 12;
    }
    if (occasion == 'work' &&
        (text.contains('smart') || text.contains('elegant'))) {
      score += 22;
    }
    if (occasion == 'date' &&
        (text.contains('feminine') ||
            text.contains('elegant') ||
            text.contains('dress'))) {
      score += 22;
    }
    if (occasion == 'dinner' &&
        (text.contains('elegant') ||
            text.contains('dress') ||
            text.contains('smart'))) {
      score += 18;
    }
    if ((occasion == 'cafe' || occasion == 'weekend') &&
        (text.contains('casual') || text.contains('everyday'))) {
      score += 18;
    }
    if (item.category == 'Shoes') score += 5;
    if (item.category == 'Accessories') score += 3;
    return score;
  }

  List<WardrobeItem> _buildLook(ColourAnalysisResult profile) {
    final sorted = [..._wardrobe]
      ..sort((a, b) => _score(b, profile).compareTo(_score(a, profile)));

    final categories = _occasion == 'Dinner' || _occasion == 'Date'
        ? ['Dresses', 'Shoes', 'Accessories']
        : ['Tops', 'Bottoms', 'Shoes', 'Accessories'];

    final rotated = [...sorted];
    if (rotated.length > 1 && _generation > 1) {
      final offset = (_generation - 1) % rotated.length;
      final head = rotated.sublist(offset);
      head.addAll(rotated.sublist(0, offset));
      rotated
        ..clear()
        ..addAll(head);
    }

    final result = <WardrobeItem>[];
    final used = <String>{};

    for (final category in categories) {
      final match = rotated.firstWhere(
        (item) => item.category == category && !used.contains(item.id),
        orElse: () => _emptyItem,
      );
      if (match.id.isNotEmpty) {
        result.add(match);
        used.add(match.id);
      }
    }

    if (result.length < 2) {
      for (final item in rotated) {
        if (!used.contains(item.id)) {
          result.add(item);
          used.add(item.id);
        }
        if (result.length == 4) break;
      }
    }

    return result.take(4).toList();
  }

  static WardrobeItem get _emptyItem => const WardrobeItem(
        id: '',
        userId: '',
        name: '',
        category: '',
        colour: '',
        style: '',
        season: '',
        imageUrl: '',
        isFavourite: false,
        notes: '',
        createdAt: null,
      );

  WardrobeItem? _findWardrobeItem(String? id) {
    if (id == null || id.isEmpty) return null;
    for (final item in _wardrobe) {
      if (item.id == id) return item;
    }
    return null;
  }

  Future<void> _generate(ColourAnalysisResult profile) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || _styling || _wardrobe.isEmpty) return;

    setState(() {
      _generation++;
      _savedLook = false;
      _styling = true;
      _generated = true;
      _look = const [];
    });

    try {
      final prefs = await StylePreferenceService.getStylePreferences(uid);
      final styles = List<String>.from(prefs?['styles'] ?? const []);
      final preferences = List<String>.from(prefs?['preferences'] ?? const []);

      final aiResult = await AiStylingService.getRecommendation(
        profile: profile,
        wardrobe: _wardrobe,
        styles: styles,
        preferences: preferences,
        occasion: _occasion,
      );

      if (!mounted) return;

      if (aiResult != null) {
        final aiLook = [
          _findWardrobeItem(aiResult.topId),
          _findWardrobeItem(aiResult.bottomId),
          _findWardrobeItem(aiResult.shoesId),
          _findWardrobeItem(aiResult.accessoryId),
        ].whereType<WardrobeItem>().toList();

        setState(() {
          _look = aiLook;
          _styling = false;
        });
        return;
      }
    } catch (_) {
      // Fall back to the transparent local matcher below.
    }

    if (!mounted) return;
    setState(() {
      _look = _buildLook(profile);
      _styling = false;
    });
    _showFeedback('AI is unavailable right now — I used your wardrobe match instead.');
  }

  Future<void> _saveCurrentLook(ColourAnalysisResult profile, List<WardrobeItem> look) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || look.isEmpty || _savingLook) return;

    if (_savedLook) {
      _showFeedback('This look is already saved.');
      return;
    }

    setState(() => _savingLook = true);

    try {
      final matchScore = _matchScore(profile, look);
      await FirestoreService.saveOutfitLook(
        uid: uid,
        occasion: _occasion,
        itemIds: look.map((item) => item.id).where((id) => id.isNotEmpty).toList(),
        matchScore: matchScore,
        season: profile.season,
      );

      if (!mounted) return;
      setState(() {
        _savedLook = true;
        _savingLook = false;
      });
      _showFeedback('Saved. You can come back to this look anytime.');
    } catch (_) {
      if (!mounted) return;
      setState(() => _savingLook = false);
      _showFeedback('I couldn’t save that look right now. Please try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<AnalysisProvider>().result;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('AI Outfit'),
        centerTitle: true,
        backgroundColor: AppColors.background,
        actions: [
          IconButton(
            onPressed: _loadWardrobe,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                _hero(profile),
                const SizedBox(height: 20),
                const Text(
                  'What are you dressing for?',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 45,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _occasions.length,
                    separatorBuilder: (_, index) => const SizedBox(width: 8),
                    itemBuilder: (_, index) {
                      final item = _occasions[index];
                      final selected = _occasion == item.$1;
                      return ChoiceChip(
                        selected: selected,
                        label: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(item.$2, size: 16),
                            const SizedBox(width: 6),
                            Text(item.$1),
                          ],
                        ),
                        onSelected: (_) => setState(() {
                          _occasion = item.$1;
                          _generated = false;
                          _savedLook = false;
                          _look = const [];
                        }),
                        selectedColor: AppColors.primarySoft,
                        backgroundColor: AppColors.surface,
                        side: BorderSide(
                          color: selected
                              ? AppColors.primary
                              : AppColors.border,
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 20),
                _generateButton(profile),
                if (_generated) ...[
                  const SizedBox(height: 27),
                  _result(profile, _look),
                ],
              ],
            ),
    );
  }

  Widget _hero(ColourAnalysisResult? profile) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: AppGradients.ai,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'AI OUTFIT',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          const Text(
            'Your next look,\nmade personal.',
            style: TextStyle(
              color: Colors.white,
              fontSize: 29,
              height: 1.05,
              fontWeight: FontWeight.w800,
              letterSpacing: -.8,
            ),
          ),
          const SizedBox(height: 9),
          Text(
            profile == null
                ? 'Complete your colour profile first.'
                : 'Built around your ${profile.season} palette and the pieces you already own.',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12.5,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _generateButton(ColourAnalysisResult? profile) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: profile == null || _wardrobe.isEmpty || _styling
            ? null
            : () => _generate(profile),
        icon: _styling
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.auto_awesome_rounded),
        label: Text(
          _styling
              ? 'Putting your look together…'
              : _generated
                  ? 'Try another look'
                  : 'Create my outfit',
        ),
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.peach,
          foregroundColor: AppColors.charcoal,
          minimumSize: const Size.fromHeight(54),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(17),
          ),
        ),
      ),
    );
  }

  Widget _result(ColourAnalysisResult? profile, List<WardrobeItem> look) {
    if (profile == null) {
      return _message('Complete Colour Analysis to personalise your outfit.');
    }
    if (_styling) {
      return _message('Looking through your wardrobe and matching your profile…');
    }
    if (_wardrobe.isEmpty) {
      return _message('Add a few pieces to My Wardrobe first.');
    }
    if (look.isEmpty) {
      return _message(
        'I could not find a complete combination yet. Try adding tops, bottoms and shoes.',
      );
    }

    final match = _matchScore(profile, look);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'YOUR PERSONAL LOOK',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.primary,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                ),
              ),
            ),
            _scorePill(match),
          ],
        ),
        const SizedBox(height: 11),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              SizedBox(
                height: 225,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: look.length,
                  separatorBuilder: (_, index) => const SizedBox(width: 10),
                  itemBuilder: (_, index) => _itemCard(look[index]),
                ),
              ),
              const SizedBox(height: 13),
              _whyItWorks(profile, look),
              const SizedBox(height: 12),
              _feedbackActions(look, profile),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.event_outlined,
                      color: AppColors.primary, size: 16),
                  const SizedBox(width: 6),
                  Text(_occasion,
                      style: const TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w700)),
                  const Spacer(),
                  const Icon(Icons.checkroom_outlined,
                      color: AppColors.textMuted, size: 16),
                  const SizedBox(width: 5),
                  Text('${look.length} pieces',
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textSecondary)),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  int _matchScore(ColourAnalysisResult profile, List<WardrobeItem> look) {
    var total = 0;
    for (final item in look) {
      total += _score(item, profile);
    }
    final maximum = look.length * 75;
    if (maximum == 0) return 0;
    return ((total / maximum) * 100).round().clamp(45, 98);
  }

  Widget _whyItWorks(ColourAnalysisResult profile, List<WardrobeItem> look) {
    final matchedColours = look
        .where((item) => profile.colours.any(
              (c) => item.colour.toLowerCase().contains(c.toLowerCase()),
            ))
        .length;
    final favouriteCount = look.where((item) => item.isFavourite).length;
    final reason = matchedColours > 0
        ? 'I chose these pieces because $matchedColours of them connect with your ${profile.season} colour palette. The combination keeps the ${_occasion.toLowerCase()} look intentional without feeling overdone.'
        : 'I kept the look balanced for a ${_occasion.toLowerCase()} setting and prioritised pieces you already wear and save.';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.lavenderMist,
        borderRadius: BorderRadius.circular(17),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.auto_awesome_rounded,
                  color: AppColors.primary, size: 18),
              SizedBox(width: 7),
              Text('Why this works',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5)),
            ],
          ),
          const SizedBox(height: 7),
          Text(reason,
              style: const TextStyle(
                  fontSize: 11.5,
                  height: 1.45,
                  color: AppColors.textSecondary)),
          if (favouriteCount > 0) ...[
            const SizedBox(height: 8),
            Text(
              '$favouriteCount favourite ${favouriteCount == 1 ? 'piece' : 'pieces'} included',
              style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700),
            ),
          ],
        ],
      ),
    );
  }

  Widget _feedbackActions(List<WardrobeItem> look, ColourAnalysisResult profile) {
    final loved = look.any((item) => _lovedLookIds.contains(item.id));
    final disliked = look.any((item) => _dislikedLookIds.contains(item.id));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _feedbackButton(
                icon: loved ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                label: loved ? 'Loved' : 'Love this',
                selected: loved,
                onPressed: () {
                  setState(() {
                    for (final item in look) {
                      _lovedLookIds.add(item.id);
                      _dislikedLookIds.remove(item.id);
                    }
                  });
                  _showFeedback('Got it — I’ll lean into this style.');
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _feedbackButton(
                icon: disliked ? Icons.thumb_down_rounded : Icons.thumb_down_outlined,
                label: disliked ? 'Noted' : 'Not my style',
                selected: disliked,
                onPressed: () {
                  setState(() {
                    for (final item in look) {
                      _dislikedLookIds.add(item.id);
                      _lovedLookIds.remove(item.id);
                    }
                  });
                  _showFeedback('Okay — I’ll move away from these pieces.');
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _savingLook ? null : () => _saveCurrentLook(profile, look),
            icon: _savingLook
                ? const SizedBox(
                    width: 17,
                    height: 17,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    _savedLook ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                    size: 18,
                  ),
            label: Text(
              _savingLook
                  ? 'Saving…'
                  : _savedLook
                      ? 'Saved look'
                      : 'Save this look',
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: BorderSide(color: AppColors.border),
              minimumSize: const Size.fromHeight(44),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _feedbackButton({
    required IconData icon,
    required String label,
    required bool selected,
    required VoidCallback onPressed,
  }) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 17),
      label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      style: OutlinedButton.styleFrom(
        foregroundColor: selected ? AppColors.primary : AppColors.textSecondary,
        backgroundColor: selected ? AppColors.primarySoft : AppColors.surface,
        side: BorderSide(
          color: selected ? AppColors.primary : AppColors.border,
        ),
        minimumSize: const Size.fromHeight(44),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
  }

  void _showFeedback(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
  }

  Widget _scorePill(int score) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.sage.withValues(alpha: .25),
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Text('$score% match',
          style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: AppColors.success)),
    );
  }

  Widget _itemCard(WardrobeItem item) {
    return SizedBox(
      width: 150,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(17),
              child: item.imageUrl.isEmpty
                  ? Container(
                      color: AppColors.surfaceMuted,
                      width: double.infinity,
                      child: const Center(
                        child: Icon(Icons.checkroom_outlined,
                            color: AppColors.primary),
                      ),
                    )
                  : CachedNetworkImage(
                      imageUrl: item.imageUrl,
                      fit: BoxFit.cover,
                      width: double.infinity,
                    ),
            ),
          ),
          const SizedBox(height: 8),
          Text(item.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
          const SizedBox(height: 2),
          Text('${item.category} · ${item.colour}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 10.5)),
        ],
      ),
    );
  }

  Widget _message(String text) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(text,
          style: const TextStyle(
              color: AppColors.textSecondary,
              height: 1.45,
              fontSize: 12.5)),
    );
  }
}
