import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../core/constants/app_colors.dart';
import '../../models/colour_analysis_result.dart';
import '../../models/wardrobe_item.dart';
import '../../providers/analysis_provider.dart';
import '../../services/ai_styling_service.dart';
import '../../services/firestore_service.dart';
import '../../services/style_feedback_service.dart';
import '../../services/style_preference_service.dart';

class AIOutfitScreen extends StatefulWidget {
  const AIOutfitScreen({super.key});

  @override
  State<AIOutfitScreen> createState() => _AIOutfitScreenState();
}

class _AIOutfitScreenState extends State<AIOutfitScreen> with WidgetsBindingObserver {
  static const _occasions = <(String, IconData)>[
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
  bool _savedLook = false;
  bool _savingLook = false;
  bool _refreshingFromLifecycle = false;
  String _loadedUid = '';
  final Set<String> _lovedLookIds = <String>{};
  final Set<String> _dislikedLookIds = <String>{};
  final Set<String> _excludedLookKeys = <String>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadWardrobe();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
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
          _excludedLookKeys.clear();
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
        _excludedLookKeys.clear();
      });
    }

    _loadedUid = uid;
    if (showLoading && mounted) setState(() => _loading = true);

    try {
      final items = await FirestoreService.getWardrobeItems(uid);
      if (!mounted || FirebaseAuth.instance.currentUser?.uid != uid) return;
      setState(() {
        _wardrobe = items.where((item) => item.userId.isEmpty || item.userId == uid).toList(growable: false);
        _loading = false;
      });
    } catch (_) {
      if (!mounted || FirebaseAuth.instance.currentUser?.uid != uid) return;
      setState(() => _loading = false);
    }
  }

  WardrobeItem? _findWardrobeItem(String? id) {
    if (id == null || id.isEmpty) return null;
    for (final item in _wardrobe) {
      if (item.id == id) return item;
    }
    return null;
  }

  List<WardrobeItem> _resultItems(AiStylingResult result) {
    final ids = [result.topId, result.bottomId, result.dressId, result.suitId, result.jacketId, result.shoesId, result.accessoryId];
    final output = <WardrobeItem>[];
    for (final id in ids) {
      final item = _findWardrobeItem(id);
      if (item != null) output.add(item);
    }
    return output;
  }

  String? _lookKey(List<WardrobeItem> look) {
    if (look.isEmpty) return null;
    final ids = look.map((item) => item.id).where((id) => id.isNotEmpty).toList()..sort();
    return ids.isEmpty ? null : ids.join('|');
  }

  Future<void> _generate(ColourAnalysisResult profile) async {
    final uid = FirebaseAuth.instance.currentUser?.uid.trim();
    if (uid == null || uid.isEmpty || uid != _loadedUid || _styling || _wardrobe.isEmpty) return;

    setState(() {
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
        excludedLookKeys: _excludedLookKeys,
      );
      if (!mounted || FirebaseAuth.instance.currentUser?.uid != uid) return;

      if (aiResult != null) {
        final safeLook = _resultItems(aiResult);
        final key = _lookKey(safeLook);
        if (safeLook.isNotEmpty && (key == null || !_excludedLookKeys.contains(key))) {
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
      _look = AiStylingService.sanitizeLook(_wardrobe, profile: profile, occasion: _occasion, excludedLookKeys: _excludedLookKeys);
      _aiResult = null;
      _styling = false;
    });
    _showFeedback('I built the best available look from your wardrobe.');
  }

  Future<void> _tryAnother(ColourAnalysisResult profile) async {
    final currentKey = _lookKey(_look);
    if (currentKey != null) _excludedLookKeys.add(currentKey);
    await _generate(profile);
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
      await FirestoreService.saveOutfitLook(
        uid: uid,
        occasion: _occasion,
        itemIds: look.map((item) => item.id).where((id) => id.isNotEmpty).toList(),
        matchScore: _aiResult?.matchScore ?? 0,
        season: profile.season,
        title: _aiResult?.displayTitle,
        notes: _aiResult?.explanation,
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

  Future<void> _recordFeedback(WardrobeItem item, bool liked) async {
    setState(() {
      if (liked) {
        if (_lovedLookIds.contains(item.id)) {
          _lovedLookIds.remove(item.id);
        } else {
          _lovedLookIds.add(item.id);
          _dislikedLookIds.remove(item.id);
        }
      } else {
        if (_dislikedLookIds.contains(item.id)) {
          _dislikedLookIds.remove(item.id);
        } else {
          _dislikedLookIds.add(item.id);
          _lovedLookIds.remove(item.id);
        }
      }
    });
    await StyleFeedbackService.recordItemFeedback(itemId: item.id, category: item.category, liked: liked, occasion: _occasion);
    final currentKey = _lookKey(_look);
    if (currentKey != null) {
      await StyleFeedbackService.recordLookFeedback(itemIds: _look.map((entry) => entry.id).toList(), liked: liked, occasion: _occasion);
    }
  }

  void _showFeedback(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))));
  }

  String _categoryLabel(String category) {
    switch (category) {
      case 'Tops': return 'TOP';
      case 'Bottoms': return 'BOTTOM';
      case 'Skirts': return 'SKIRT';
      case 'Dresses': return 'DRESS';
      case 'Suits': return 'SUIT';
      case 'Jackets': return 'LAYER';
      case 'Shoes': return 'SHOES';
      case 'Accessories': return 'ACCESSORY';
      default: return 'ITEM';
    }
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
        actions: [IconButton(tooltip: 'Refresh wardrobe', onPressed: _loadWardrobe, icon: const Icon(Icons.refresh_rounded))],
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
      decoration: BoxDecoration(color: AppColors.primaryDark, borderRadius: BorderRadius.circular(28)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [Expanded(child: Text('VYEA  /  PERSONAL OUTFIT', style: TextStyle(color: AppColors.peach, fontSize: 9.5, fontWeight: FontWeight.w900, letterSpacing: 1.45))), Text('AI STUDIO', style: TextStyle(color: Colors.white54, fontSize: 8.5, fontWeight: FontWeight.w900, letterSpacing: 1))]),
        const SizedBox(height: 18),
        const Text('Your next look,\nmade personal.', style: TextStyle(color: Colors.white, fontSize: 30, height: 1.02, fontWeight: FontWeight.w800, letterSpacing: -1)),
        const SizedBox(height: 9),
        Text(profile == null ? 'Add your Colour Analysis to make recommendations more personal.' : 'Built around your ${profile.undertone} · ${profile.brightness} · ${profile.chroma} · ${profile.contrast} profile and the pieces you already own.', style: const TextStyle(color: Colors.white70, fontSize: 12.5, height: 1.45)),
        const SizedBox(height: 17),
        Row(children: [_heroStat(Icons.palette_outlined, profile?.season ?? 'Colour', 'palette'), const SizedBox(width: 8), _heroStat(Icons.checkroom_outlined, '${_wardrobe.length}', 'pieces'), const SizedBox(width: 8), _heroStat(Icons.auto_awesome_outlined, _occasion, 'occasion')]),
      ]),
    );
  }

  Widget _heroStat(IconData icon, String value, String label) {
    return Expanded(child: Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 10), decoration: BoxDecoration(color: Colors.white.withValues(alpha: .08), borderRadius: BorderRadius.circular(15)), child: Row(children: [Icon(icon, color: Colors.white70, size: 15), const SizedBox(width: 6), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w800)), Text(label, style: const TextStyle(color: Colors.white54, fontSize: 8.5))]))])));
  }

  Widget _occasionSection() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('CHOOSE THE MOMENT', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.25, color: AppColors.textMuted)),
      const SizedBox(height: 9),
      SizedBox(height: 88, child: ListView.separated(scrollDirection: Axis.horizontal, itemCount: _occasions.length, separatorBuilder: (_, __) => const SizedBox(width: 9), itemBuilder: (_, index) {
        final item = _occasions[index];
        final selected = _occasion == item.$1;
        return InkWell(onTap: () => setState(() { _occasion = item.$1; _generated = false; _savedLook = false; _look = const []; _aiResult = null; _excludedLookKeys.clear(); }), borderRadius: BorderRadius.circular(19), child: AnimatedContainer(duration: const Duration(milliseconds: 180), width: 92, padding: const EdgeInsets.all(11), decoration: BoxDecoration(color: selected ? AppColors.primaryDark : AppColors.surface, borderRadius: BorderRadius.circular(19), border: Border.all(color: selected ? AppColors.primaryDark : AppColors.border)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(item.$2, color: selected ? Colors.white : AppColors.primary, size: 19), const Spacer(), Text(item.$1, style: TextStyle(color: selected ? Colors.white : AppColors.textPrimary, fontSize: 11, fontWeight: FontWeight.w800))])));
      })),
    ]);
  }

  Widget _generateButton(ColourAnalysisResult? profile) {
    return SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: profile == null || _wardrobe.isEmpty || _styling ? null : () => _generate(profile), icon: _styling ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.auto_awesome_rounded), label: Text(_styling ? 'Styling your look…' : _generated ? 'Create another look' : 'Create my outfit'), style: FilledButton.styleFrom(backgroundColor: AppColors.peach, foregroundColor: AppColors.charcoal, minimumSize: const Size.fromHeight(55), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)))));
  }

  Widget _result(ColourAnalysisResult? profile, List<WardrobeItem> look) {
    if (profile == null) return _message('Complete Colour Analysis to personalise your outfit.');
    if (_styling) return _message('Looking through your wardrobe, colour profile and personal style…');
    if (_wardrobe.isEmpty) return _message('Add a few pieces to My Wardrobe first.');
    if (look.isEmpty) return _message('I could not build a valid outfit from this wardrobe yet. Add complementary pieces and try again.');

    final title = _aiResult?.displayTitle ?? 'A look built for ${_occasion.toLowerCase()}';
    final direction = _aiResult?.colourDirection;
    final notes = _aiResult?.stylingNotes ?? const <String>[];
    final explanation = _aiResult?.explanation ?? 'A balanced wardrobe match based on your profile and the pieces you already own.';
    final score = _aiResult?.matchScore ?? 0;
    final breakdown = _aiResult?.scoreBreakdown ?? const <String, int>{};

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [const Expanded(child: Text('YOUR LOOK', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.25, color: AppColors.textMuted))), _matchBadge(score)]),
      const SizedBox(height: 10),
      Container(padding: const EdgeInsets.all(18), decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(24), border: Border.all(color: AppColors.border)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary)), const SizedBox(height: 6), Text(explanation, style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary, height: 1.45)), if (direction != null) ...[const SizedBox(height: 13), Row(crossAxisAlignment: CrossAxisAlignment.start, children: [const Icon(Icons.palette_outlined, size: 17, color: AppColors.primary), const SizedBox(width: 8), Expanded(child: Text(direction, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary, height: 1.35)))])],)),
      if (breakdown.isNotEmpty) ...[const SizedBox(height: 12), _breakdownCard(breakdown)],
      const SizedBox(height: 14),
      GridView.builder(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: look.length, gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 11, crossAxisSpacing: 11, childAspectRatio: .82), itemBuilder: (_, index) => _lookCard(look[index])),
      if (notes.isNotEmpty) ...[const SizedBox(height: 16), _notesCard(notes)],
      const SizedBox(height: 16),
      Row(children: [Expanded(child: OutlinedButton.icon(onPressed: _savingLook ? null : () => _saveCurrentLook(profile, look), icon: Icon(_savedLook ? Icons.bookmark_rounded : Icons.bookmark_border_rounded), label: Text(_savingLook ? 'Saving…' : _savedLook ? 'Saved' : 'Save look'), style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))))), const SizedBox(width: 10), Expanded(child: FilledButton.icon(onPressed: _styling ? null : () => _tryAnother(profile), icon: const Icon(Icons.auto_awesome_outlined), label: const Text('Try another'), style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50), backgroundColor: AppColors.primaryDark, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))))) ]),
    ]);
  }

  Widget _matchBadge(int score) => Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9), decoration: BoxDecoration(color: AppColors.sage.withValues(alpha: .18), borderRadius: BorderRadius.circular(17), border: Border.all(color: AppColors.sage.withValues(alpha: .35))), child: Column(children: [Text('$score%', style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: AppColors.success)), const Text('MATCH', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w800, letterSpacing: .8, color: AppColors.success))]));

  Widget _breakdownCard(Map<String, int> breakdown) {
    const labels = <String, String>{'colour': 'Colour', 'occasion': 'Occasion', 'style': 'Style', 'harmony': 'Harmony', 'personal': 'Personal'};
    return Container(padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.border)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('WHY THIS LOOK', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w900, letterSpacing: 1.1, color: AppColors.textMuted)), const SizedBox(height: 10), ...breakdown.entries.map((entry) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Row(children: [Expanded(child: Text(labels[entry.key] ?? entry.key, style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary))), Text('${entry.value}', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800))])))]));
  }

  Widget _notesCard(List<String> notes) => Container(width: double.infinity, padding: const EdgeInsets.fromLTRB(16, 15, 16, 13), decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.border)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('STYLE NOTES', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w900, letterSpacing: 1.1, color: AppColors.textMuted)), const SizedBox(height: 8), ...notes.take(4).map((note) => Padding(padding: const EdgeInsets.only(bottom: 7), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [const Padding(padding: EdgeInsets.only(top: 5), child: Icon(Icons.circle, size: 5, color: AppColors.primary)), const SizedBox(width: 8), Expanded(child: Text(note, style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary, height: 1.35)))]))]));

  Widget _lookCard(WardrobeItem item) {
    final loved = _lovedLookIds.contains(item.id);
    final disliked = _dislikedLookIds.contains(item.id);
    return Container(decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.border)), clipBehavior: Clip.antiAlias, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: Stack(fit: StackFit.expand, children: [if (item.imageUrl.isNotEmpty) CachedNetworkImage(imageUrl: item.imageUrl, fit: BoxFit.cover) else Container(color: AppColors.surfaceMuted, child: const Icon(Icons.checkroom_outlined, color: AppColors.primary, size: 36)), Positioned(top: 8, left: 8, child: Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5), decoration: BoxDecoration(color: Colors.black.withValues(alpha: .52), borderRadius: BorderRadius.circular(8)), child: Text(_categoryLabel(item.category), style: const TextStyle(color: Colors.white, fontSize: 7.5, fontWeight: FontWeight.w900, letterSpacing: .8)))), Positioned(top: 5, right: 5, child: Row(children: [_feedbackButton(Icons.thumb_up_alt_outlined, loved, () => _recordFeedback(item, true)), const SizedBox(width: 3), _feedbackButton(Icons.thumb_down_alt_outlined, disliked, () => _recordFeedback(item, false))]))])), Padding(padding: const EdgeInsets.fromLTRB(11, 9, 11, 11), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)), const SizedBox(height: 3), Text('${item.colour} · ${item.style}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 9.5, color: AppColors.textSecondary))]))]));
  }

  Widget _feedbackButton(IconData icon, bool active, VoidCallback onPressed) => Material(color: Colors.black.withValues(alpha: .48), borderRadius: BorderRadius.circular(9), child: InkWell(onTap: onPressed, borderRadius: BorderRadius.circular(9), child: Padding(padding: const EdgeInsets.all(6), child: Icon(icon, size: 13, color: active ? Colors.white : Colors.white70))));

  Widget _message(String text) => Container(width: double.infinity, padding: const EdgeInsets.all(17), decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.border)), child: Text(text, style: const TextStyle(color: AppColors.textSecondary, height: 1.4, fontSize: 12.5)));
}
