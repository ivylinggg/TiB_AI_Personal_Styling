import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
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

class _AIOutfitScreenState extends State<AIOutfitScreen> with WidgetsBindingObserver {
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
  AiStylingResult? _aiResult;
  bool _loading = true;
  bool _styling = false;
  bool _generated = false;
  int _generation = 0;
  final Set<String> _lovedLookIds = <String>{};
  final Set<String> _dislikedLookIds = <String>{};
  bool _savedLook = false;
  bool _savingLook = false;
  bool _refreshingFromLifecycle = false;
  String _loadedUid = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadWardrobe();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshWhenResumed();
  }

  Future<void> _refreshWhenResumed() async {
    if (_refreshingFromLifecycle || _styling) return;
    _refreshingFromLifecycle = true;
    try {
      await _loadWardrobe(showLoading: false);
    } finally {
      _refreshingFromLifecycle = false;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _loadWardrobe({bool showLoading = true}) async {
    final uid = FirebaseAuth.instance.currentUser?.uid.trim();
    if (uid == null || uid.isEmpty) {
      if (mounted) {
        setState(() {
          _loadedUid = '';
          _loading = false;
          _wardrobe = const [];
          _look = const [];
          _aiResult = null;
          _generated = false;
        });
      }
      return;
    }

    if (_loadedUid.isNotEmpty && _loadedUid != uid && mounted) {
      setState(() {
        _wardrobe = const [];
        _look = const [];
        _aiResult = null;
        _generated = false;
        _savedLook = false;
        _lovedLookIds.clear();
        _dislikedLookIds.clear();
      });
    }

    _loadedUid = uid;
    if (showLoading && mounted) setState(() => _loading = true);

    try {
      final items = await FirestoreService.getWardrobeItems(uid);
      if (!mounted || FirebaseAuth.instance.currentUser?.uid != uid) return;
      setState(() {
        _wardrobe = items;
        _loading = false;
      });
    } catch (_) {
      if (!mounted || FirebaseAuth.instance.currentUser?.uid != uid) return;
      setState(() => _loading = false);
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
    if (item.season.toLowerCase().contains(profile.season.toLowerCase())) score += 12;
    if (occasion == 'work' && (text.contains('smart') || text.contains('elegant'))) score += 22;
    if (occasion == 'date' && (text.contains('feminine') || text.contains('elegant') || text.contains('dress'))) score += 22;
    if (occasion == 'dinner' && (text.contains('elegant') || text.contains('dress') || text.contains('smart'))) score += 18;
    if ((occasion == 'cafe' || occasion == 'weekend') && (text.contains('casual') || text.contains('everyday'))) score += 18;
    if (item.category == 'Shoes') score += 5;
    if (item.category == 'Accessories') score += 3;
    return score;
  }

  List<WardrobeItem> _fallbackLook(ColourAnalysisResult profile) {
    final sorted = [..._wardrobe]
      ..sort((a, b) => _score(b, profile).compareTo(_score(a, profile)));
    final result = <WardrobeItem>[];
    final used = <String>{};

    WardrobeItem? pick(bool Function(WardrobeItem item) test) {
      for (final item in sorted) {
        if (!used.contains(item.id) && test(item)) return item;
      }
      return null;
    }

    final onePiece = pick((item) => item.category == 'Dresses' || item.category == 'Suits');
    final hasTop = sorted.any((item) => item.category == 'Tops');
    final hasBottom = sorted.any((item) => item.category == 'Bottoms' || item.category == 'Skirts');

    if (onePiece != null && !hasTop && !hasBottom) {
      result.add(onePiece);
      used.add(onePiece.id);
    } else if (hasTop && hasBottom) {
      final top = pick((item) => item.category == 'Tops');
      final bottom = pick((item) => item.category == 'Bottoms' || item.category == 'Skirts');
      if (top != null && bottom != null) {
        result.add(top);
        used.add(top.id);
        result.add(bottom);
        used.add(bottom.id);
      }
    } else if (onePiece != null) {
      result.add(onePiece);
      used.add(onePiece.id);
    }

    final baseCategories = result.map((item) => item.category).toSet();
    for (final item in sorted) {
      if (result.length >= 4 || used.contains(item.id)) continue;
      if (item.category == 'Shoes' || item.category == 'Accessories') {
        result.add(item);
        used.add(item.id);
      } else if (item.category == 'Jackets' &&
          (baseCategories.contains('Dresses') ||
              baseCategories.contains('Tops') ||
              baseCategories.contains('Suits'))) {
        result.add(item);
        used.add(item.id);
      }
    }

    return result.take(4).toList(growable: false);
  }

  WardrobeItem? _findWardrobeItem(String? id) {
    if (id == null || id.isEmpty) return null;
    for (final item in _wardrobe) {
      if (item.id == id) return item;
    }
    return null;
  }

  Future<void> _generate(ColourAnalysisResult profile) async {
    final uid = FirebaseAuth.instance.currentUser?.uid.trim();
    if (uid == null || uid.isEmpty || uid != _loadedUid || _styling || _wardrobe.isEmpty) return;

    setState(() {
      _generation++;
      _savedLook = false;
      _styling = true;
      _generated = true;
      _look = const [];
      _aiResult = null;
    });

    try {
      final prefs = await StylePreferenceService.getStylePreferences(uid);
      if (!mounted || FirebaseAuth.instance.currentUser?.uid != uid) return;

      final styles = List<String>.from(prefs?['styles'] ?? const []);
      final preferences = List<String>.from(prefs?['preferences'] ?? const []);
      final aiResult = await AiStylingService.getRecommendation(
        profile: profile,
        wardrobe: _wardrobe,
        styles: styles,
        preferences: preferences,
        occasion: _occasion,
      );

      if (!mounted || FirebaseAuth.instance.currentUser?.uid != uid) return;

      if (aiResult != null) {
        final aiLook = [
          _findWardrobeItem(aiResult.topId),
          _findWardrobeItem(aiResult.bottomId),
          _findWardrobeItem(aiResult.shoesId),
          _findWardrobeItem(aiResult.accessoryId),
        ].whereType<WardrobeItem>().toList();
        final safeLook = AiStylingService.sanitizeLook(aiLook);
        if (safeLook.isNotEmpty || aiResult.explanation.isNotEmpty) {
          setState(() {
            _look = safeLook;
            _aiResult = aiResult;
            _styling = false;
          });
          return;
        }
      }
    } catch (_) {}

    if (!mounted || FirebaseAuth.instance.currentUser?.uid != uid) return;
    setState(() {
      _look = _fallbackLook(profile);
      _aiResult = null;
      _styling = false;
    });
    _showFeedback('AI is unavailable right now — I used a valid wardrobe combination instead.');
  }

  Future<void> _saveCurrentLook(ColourAnalysisResult profile, List<WardrobeItem> look) async {
    final uid = FirebaseAuth.instance.currentUser?.uid.trim();
    if (uid == null || uid.isEmpty || uid != _loadedUid || look.isEmpty || _savingLook) return;
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
      if (!mounted || FirebaseAuth.instance.currentUser?.uid != uid) return;
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

  int _matchScore(ColourAnalysisResult profile, List<WardrobeItem> look) {
    if (look.isEmpty) return 0;
    var total = 0;
    for (final item in look) {
      final text = '${item.category} ${item.style} ${item.colour}'.toLowerCase();
      if (profile.colours.any((c) => text.contains(c.toLowerCase()))) total += 30;
      if (item.season.toLowerCase().contains(profile.season.toLowerCase())) total += 20;
      if (item.isFavourite) total += 5;
    }
    return (total / look.length).round().clamp(0, 100);
  }

  void _toggleLove(WardrobeItem item) {
    setState(() {
      if (_lovedLookIds.contains(item.id)) {
        _lovedLookIds.remove(item.id);
      } else {
        _lovedLookIds.add(item.id);
        _dislikedLookIds.remove(item.id);
      }
    });
    _showFeedback(_lovedLookIds.contains(item.id)
        ? 'Noted — I’ll favour pieces like this.'
        : 'Preference updated.');
  }

  void _toggleDislike(WardrobeItem item) {
    setState(() {
      if (_dislikedLookIds.contains(item.id)) {
        _dislikedLookIds.remove(item.id);
      } else {
        _dislikedLookIds.add(item.id);
        _lovedLookIds.remove(item.id);
      }
    });
    _showFeedback(_dislikedLookIds.contains(item.id)
        ? 'Got it — I’ll avoid this piece in the next look.'
        : 'Preference updated.');
  }

  String _categoryLabel(String category, int index) {
    switch (category) {
      case 'Tops':
        return 'TOP';
      case 'Bottoms':
        return 'BOTTOM';
      case 'Skirts':
        return 'SKIRT';
      case 'Dresses':
        return 'DRESS';
      case 'Suits':
        return 'SUIT';
      case 'Jackets':
        return 'LAYER';
      case 'Shoes':
        return 'SHOES';
      case 'Accessories':
        return 'ACCESSORY';
      default:
        return index == 0 ? 'KEY PIECE' : 'DETAIL';
    }
  }

  void _showFeedback(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  Widget _message(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        text,
        style: const TextStyle(color: AppColors.textSecondary, height: 1.4, fontSize: 12.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<AnalysisProvider>().result;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('AI Outfit', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        centerTitle: true,
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: [
          IconButton(
            tooltip: 'Refresh wardrobe',
            onPressed: _loadWardrobe,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 34),
              children: [
                _hero(profile),
                const SizedBox(height: 22),
                if (profile == null) ...[
                  _message('Complete Colour Analysis to unlock stronger personal outfit recommendations.'),
                  const SizedBox(height: 18),
                ],
                _occasionSection(),
                const SizedBox(height: 22),
                _generateButton(profile),
                if (_generated) ...[
                  const SizedBox(height: 28),
                  _result(profile, _look),
                ],
              ],
            ),
    );
  }

  Widget _hero(ColourAnalysisResult? profile) {
    return Container(
      padding: const EdgeInsets.fromLTRB(21, 21, 21, 23),
      decoration: BoxDecoration(
        color: AppColors.primaryDark,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Expanded(
                child: Text(
                  'VYEA  /  PERSONAL OUTFIT',
                  style: TextStyle(color: AppColors.peach, fontSize: 9.5, fontWeight: FontWeight.w900, letterSpacing: 1.45),
                ),
              ),
              Text('AI STUDIO', style: TextStyle(color: Colors.white54, fontSize: 8.5, fontWeight: FontWeight.w900, letterSpacing: 1)),
            ],
          ),
          const SizedBox(height: 18),
          const Text(
            'Your next look,\nmade personal.',
            style: TextStyle(color: Colors.white, fontSize: 30, height: 1.02, fontWeight: FontWeight.w800, letterSpacing: -1),
          ),
          const SizedBox(height: 9),
          Text(
            profile == null
                ? 'Add your Colour Analysis to make recommendations more personal.'
                : 'Built around your ${profile.season} palette, face guidance and the pieces you already own.',
            style: const TextStyle(color: Colors.white70, fontSize: 12.5, height: 1.45),
          ),
          const SizedBox(height: 17),
          Row(
            children: [
              _heroStat(Icons.palette_outlined, profile?.season ?? 'Colour', 'palette'),
              const SizedBox(width: 8),
              _heroStat(Icons.checkroom_outlined, '${_wardrobe.length}', 'pieces'),
              const SizedBox(width: 8),
              _heroStat(Icons.auto_awesome_outlined, _occasion, 'occasion'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _heroStat(IconData icon, String value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 10),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: .08), borderRadius: BorderRadius.circular(15)),
        child: Row(
          children: [
            Icon(icon, color: Colors.white70, size: 15),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w800)),
                  Text(label, style: const TextStyle(color: Colors.white54, fontSize: 8.5)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _occasionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('CHOOSE THE MOMENT', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.25, color: AppColors.textMuted)),
        const SizedBox(height: 9),
        SizedBox(
          height: 88,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _occasions.length,
            separatorBuilder: (_, __) => const SizedBox(width: 9),
            itemBuilder: (_, index) {
              final item = _occasions[index];
              final selected = _occasion == item.$1;
              return InkWell(
                onTap: () => setState(() {
                  _occasion = item.$1;
                  _generated = false;
                  _savedLook = false;
                  _look = const [];
                  _aiResult = null;
                }),
                borderRadius: BorderRadius.circular(19),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 92,
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(
                    color: selected ? AppColors.primaryDark : AppColors.surface,
                    borderRadius: BorderRadius.circular(19),
                    border: Border.all(color: selected ? AppColors.primaryDark : AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(item.$2, color: selected ? Colors.white : AppColors.primary, size: 19),
                      const Spacer(),
                      Text(item.$1, style: TextStyle(color: selected ? Colors.white : AppColors.textPrimary, fontSize: 11, fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _generateButton(ColourAnalysisResult? profile) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: profile == null || _wardrobe.isEmpty || _styling ? null : () => _generate(profile),
        icon: _styling
            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.auto_awesome_rounded),
        label: Text(_styling ? 'Styling your look…' : _generated ? 'Create another look' : 'Create my outfit'),
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.peach,
          foregroundColor: AppColors.charcoal,
          minimumSize: const Size.fromHeight(55),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)),
        ),
      ),
    );
  }

  Widget _result(ColourAnalysisResult? profile, List<WardrobeItem> look) {
    if (profile == null) return _message('Complete Colour Analysis to personalise your outfit.');
    if (_styling) return _message('Looking through your wardrobe, colour profile and personal style…');
    if (_wardrobe.isEmpty) return _message('Add a few pieces to My Wardrobe first.');
    if (look.isEmpty) return _message('I could not build a valid outfit from this wardrobe yet. Add complementary pieces such as a top + bottom/skirt, or a dress with shoes.');

    final title = _aiResult?.lookTitle ?? 'A look built for ${_occasion.toLowerCase()}';
    final direction = _aiResult?.colourDirection;
    final notes = _aiResult?.stylingNotes ?? const <String>[];
    final explanation = _aiResult?.explanation ?? 'A balanced wardrobe match using compatible garment categories from your wardrobe.';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(child: Text('YOUR LOOK', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.25, color: AppColors.textMuted))),
            if (_aiResult != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(color: AppColors.peach.withValues(alpha: .38), borderRadius: BorderRadius.circular(9)),
                child: const Text('AI MATCHED', style: TextStyle(fontSize: 7.5, fontWeight: FontWeight.w900, letterSpacing: .8)),
              ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(24), border: Border.all(color: AppColors.border)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
              const SizedBox(height: 6),
              Text(explanation, style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary, height: 1.45)),
              if (direction != null) ...[
                const SizedBox(height: 13),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.palette_outlined, size: 17, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Expanded(child: Text(direction, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary, height: 1.35))),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: look.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 11, crossAxisSpacing: 11, childAspectRatio: .82),
          itemBuilder: (_, index) => _lookCard(look[index], index),
        ),
        if (notes.isNotEmpty) ...[
          const SizedBox(height: 16),
          _notesCard(notes),
        ],
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: AppColors.primaryDark, borderRadius: BorderRadius.circular(22)),
          child: const Row(
            children: [
              Icon(Icons.auto_awesome_outlined, color: Colors.white70, size: 18),
              SizedBox(width: 10),
              Expanded(child: Text('Each look keeps one-piece garments separate from bottoms: Tops pair with Bottoms or Skirts, while Dresses stay one-piece.', style: TextStyle(color: Colors.white70, fontSize: 11.5, height: 1.4))),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _savingLook ? null : () => _saveCurrentLook(profile, look),
                icon: Icon(_savedLook ? Icons.bookmark_rounded : Icons.bookmark_border_rounded),
                label: Text(_savingLook ? 'Saving…' : _savedLook ? 'Saved' : 'Save look'),
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.icon(
                onPressed: _styling ? null : () => _generate(profile),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try another'),
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50), backgroundColor: AppColors.primaryDark, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _notesCard(List<String> notes) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 13),
      decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('STYLE NOTES', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w900, letterSpacing: 1.1, color: AppColors.textMuted)),
          const SizedBox(height: 8),
          ...notes.map((note) => Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(padding: EdgeInsets.only(top: 5), child: Icon(Icons.circle, size: 5, color: AppColors.primary)),
                    const SizedBox(width: 8),
                    Expanded(child: Text(note, style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary, height: 1.35))),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _lookCard(WardrobeItem item, int index) {
    final loved = _lovedLookIds.contains(item.id);
    final disliked = _dislikedLookIds.contains(item.id);
    final caption = _categoryLabel(item.category, index);
    return Container(
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.border)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (item.imageUrl.isNotEmpty)
                  CachedNetworkImage(imageUrl: item.imageUrl, fit: BoxFit.cover)
                else
                  Container(color: AppColors.surfaceMuted, child: const Icon(Icons.checkroom_outlined, color: AppColors.primary, size: 30)),
                Positioned(
                  left: 9,
                  top: 9,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    decoration: BoxDecoration(color: Colors.black.withValues(alpha: .50), borderRadius: BorderRadius.circular(9)),
                    child: Text(caption, style: const TextStyle(color: Colors.white, fontSize: 7.5, fontWeight: FontWeight.w900, letterSpacing: .8)),
                  ),
                ),
                Positioned(
                  right: 6,
                  top: 6,
                  child: Row(
                    children: [
                      _feedbackButton(Icons.thumb_up_alt_outlined, loved, () => _toggleLove(item)),
                      const SizedBox(width: 3),
                      _feedbackButton(Icons.thumb_down_alt_outlined, disliked, () => _toggleDislike(item)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(11, 10, 11, 11),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                const SizedBox(height: 3),
                Text('${item.colour} · ${item.style}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 9.5, color: AppColors.textMuted)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _feedbackButton(IconData icon, bool selected, VoidCallback onPressed) {
    return Material(
      color: Colors.black.withValues(alpha: .46),
      borderRadius: BorderRadius.circular(9),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(9),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, color: selected ? AppColors.peach : Colors.white, size: 14),
        ),
      ),
    );
  }
}
