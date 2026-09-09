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
import '../../services/style_feedback_service.dart';
import '../../services/style_preference_service.dart';

class AIOutfitScreen extends StatefulWidget {
  const AIOutfitScreen({super.key});

  @override
  State<AIOutfitScreen> createState() => _AIOutfitScreenState();
}

class _AIOutfitScreenState extends State<AIOutfitScreen> {
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
  final Set<String> _excludedLookKeys = <String>{};
  final Set<String> _lovedItemIds = <String>{};
  final Set<String> _dislikedItemIds = <String>{};

  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    _loadWardrobe();
  }

  Future<void> _loadWardrobe() async {
    final uid = _uid;
    if (uid.isEmpty) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      final items = await FirestoreService.getWardrobeItems(uid);
      if (!mounted || uid != _uid) return;
      setState(() {
        _wardrobe = items.where((item) => item.userId.isEmpty || item.userId == uid).toList(growable: false);
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<String> _stringList(dynamic value) {
    if (value is! List) return const [];
    return value.map((item) => item.toString().trim()).where((item) => item.isNotEmpty).toList(growable: false);
  }

  Future<void> _generate(ColourAnalysisResult profile) async {
    final uid = _uid;
    if (uid.isEmpty || _styling) return;
    setState(() => _styling = true);
    try {
      final prefs = await StylePreferenceService.getStylePreferences(uid);
      final styles = prefs == null ? const <String>[] : _stringList(prefs['styles']);
      final preferences = prefs == null ? const <String>[] : _stringList(prefs['preferences']);
      if (!mounted || uid != _uid) return;
      final result = await AiStylingService.getRecommendation(
        uid: uid,
        wardrobe: _wardrobe,
        occasion: _occasion,
        profile: profile,
        styles: styles,
        preferences: preferences,
        excludedLookKeys: _excludedLookKeys,
      );
      if (!mounted || uid != _uid) return;
      final resolved = result == null ? const <WardrobeItem>[] : _resolveLook(result);
      setState(() {
        _aiResult = result;
        _look = resolved;
        _generated = resolved.isNotEmpty;
        _savedLook = false;
      });
      if (resolved.isNotEmpty && result != null) {
        await StyleFeedbackService.recordGeneratedLook(
          itemIds: resolved.map((item) => item.id).toList(growable: false),
          occasion: _occasion,
          matchScore: result.matchScore,
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _aiResult = null;
          _look = const [];
          _generated = false;
        });
      }
    } finally {
      if (mounted && uid == _uid) setState(() => _styling = false);
    }
  }

  List<WardrobeItem> _resolveLook(AiStylingResult result) {
    final ids = <String?>[
      result.topId,
      result.bottomId,
      result.dressId,
      result.suitId,
      result.jacketId,
      result.shoesId,
      result.accessoryId,
    ];
    final byId = <String, WardrobeItem>{for (final item in _wardrobe) item.id: item};
    return [
      for (final id in ids)
        if (id != null && id.isNotEmpty && byId[id] != null) byId[id]!,
    ];
  }

  String _lookKey(List<WardrobeItem> items) {
    final ids = items.map((item) => item.id).where((id) => id.isNotEmpty).toList()..sort();
    return ids.join('|');
  }

  Future<void> _tryAnother(ColourAnalysisResult profile) async {
    final key = _lookKey(_look);
    if (key.isNotEmpty) _excludedLookKeys.add(key);
    await _generate(profile);
  }

  Future<void> _restyleLook() async {
    final profile = context.read<AnalysisProvider>().result;
    if (profile == null) return;
    final key = _lookKey(_look);
    if (key.isNotEmpty) _excludedLookKeys.add(key);
    await StyleFeedbackService.recordRestyle(
      itemIds: _look.map((item) => item.id).toList(growable: false),
      occasion: _occasion,
    );
    await _generate(profile);
  }

  Future<void> _changeShoes() async {
    final uid = _uid;
    if (uid.isEmpty || _look.isEmpty || _styling) return;
    final currentShoes = _look.where((item) => item.category == 'Shoes').toList(growable: false);
    final candidates = _wardrobe
        .where((item) => item.category == 'Shoes' && (item.userId.isEmpty || item.userId == uid))
        .where((item) => !currentShoes.any((shoe) => shoe.id == item.id))
        .toList(growable: false);
    if (candidates.isEmpty) return;

    setState(() => _styling = true);
    try {
      final profile = context.read<AnalysisProvider>().result;
      final prefs = await StylePreferenceService.getStylePreferences(uid);
      final styles = prefs == null ? const <String>[] : _stringList(prefs['styles']);
      final preferences = prefs == null ? const <String>[] : _stringList(prefs['preferences']);
      final anchors = _look.where((item) => item.category != 'Shoes').toList(growable: false);
      WardrobeItem replacement = candidates.first;
      if (profile != null) {
        final ranked = AiStylingService.rankReplacementItems(
          candidates,
          profile: profile,
          occasion: _occasion,
          styles: styles,
          preferences: preferences,
          anchors: anchors,
        );
        if (ranked.isNotEmpty) replacement = ranked.first;
      }
      final nextLook = [...anchors, replacement];
      if (!mounted || uid != _uid) return;
      setState(() {
        _look = nextLook;
        _savedLook = false;
        _generated = true;
      });
      await StyleFeedbackService.recordShoeChange(
        itemIds: nextLook.map((item) => item.id).toList(growable: false),
        occasion: _occasion,
      );
    } finally {
      if (mounted && uid == _uid) setState(() => _styling = false);
    }
  }

  Future<void> _feedback(WardrobeItem item, bool liked) async {
    final uid = _uid;
    if (uid.isEmpty) return;
    setState(() {
      if (liked) {
        _lovedItemIds.add(item.id);
        _dislikedItemIds.remove(item.id);
      } else {
        _dislikedItemIds.add(item.id);
        _lovedItemIds.remove(item.id);
      }
    });
    await StyleFeedbackService.recordItemFeedback(
      itemId: item.id,
      category: item.category,
      liked: liked,
      occasion: _occasion,
    );
    if (_look.length > 1) {
      await StyleFeedbackService.recordLookFeedback(
        itemIds: _look.map((entry) => entry.id).toList(growable: false),
        liked: liked,
        occasion: _occasion,
      );
    }
  }

  Future<void> _saveLook(ColourAnalysisResult profile) async {
    final uid = _uid;
    if (uid.isEmpty || _look.isEmpty || _savingLook) return;
    setState(() => _savingLook = true);
    try {
      await FirestoreService.saveOutfitLook(
        uid: uid,
        itemIds: _look.map((item) => item.id).toList(growable: false),
        occasion: _occasion,
        matchScore: _aiResult?.matchScore ?? 0,
        season: profile.season,
        title: _aiResult?.displayTitle ?? 'My ${_occasion.toLowerCase()} look',
        notes: _aiResult?.stylingNotes.join(' • '),
      );
      await StyleFeedbackService.recordSavedLook(
        itemIds: _look.map((item) => item.id).toList(growable: false),
        occasion: _occasion,
      );
      if (mounted) setState(() => _savedLook = true);
    } finally {
      if (mounted) setState(() => _savingLook = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<AnalysisProvider>().result;
    return Scaffold(
      appBar: AppBar(title: const Text('AI Outfit')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadWardrobe,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 32),
                children: [
                  _hero(profile),
                  const SizedBox(height: 18),
                  _occasionSection(),
                  const SizedBox(height: 14),
                  _generateButton(profile),
                  const SizedBox(height: 18),
                  _result(profile),
                ],
              ),
            ),
    );
  }

  Widget _hero(ColourAnalysisResult? profile) => Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
        decoration: BoxDecoration(color: AppColors.primaryDark, borderRadius: BorderRadius.circular(24)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('PERSONAL AI STYLIST', style: TextStyle(color: Colors.white70, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
          const SizedBox(height: 7),
          const Text('One wardrobe. One right look.', style: TextStyle(color: Colors.white, fontSize: 23, fontWeight: FontWeight.w900, height: 1.08)),
          const SizedBox(height: 7),
          Text(profile == null ? 'Complete Colour Analysis for a more personal recommendation.' : 'Built around your colours, preferences and the pieces you already own.', style: const TextStyle(color: Colors.white70, fontSize: 11.5, height: 1.35)),
          const SizedBox(height: 15),
          Row(children: [
            _heroStat(Icons.checkroom_outlined, '${_wardrobe.length}', 'WARDROBE PIECES'),
            const SizedBox(width: 8),
            _heroStat(Icons.palette_outlined, profile?.season ?? '—', 'COLOUR PROFILE'),
            const SizedBox(width: 8),
            _heroStat(Icons.event_outlined, _occasion, 'MOMENT'),
          ]),
        ]),
      );

  Widget _heroStat(IconData icon, String value, String label) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 10),
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(15)),
          child: Row(children: [
            Icon(icon, color: Colors.white70, size: 15),
            const SizedBox(width: 6),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w800)),
              Text(label, style: const TextStyle(color: Colors.white54, fontSize: 8.5)),
            ])),
          ]),
        ),
      );

  Widget _occasionSection() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
                  _excludedLookKeys.clear();
                }),
                borderRadius: BorderRadius.circular(19),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 92,
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(color: selected ? AppColors.primaryDark : AppColors.surface, borderRadius: BorderRadius.circular(19), border: Border.all(color: selected ? AppColors.primaryDark : AppColors.border)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Icon(item.$2, color: selected ? Colors.white : AppColors.primary, size: 19),
                    const Spacer(),
                    Text(item.$1, style: TextStyle(color: selected ? Colors.white : AppColors.textPrimary, fontSize: 11, fontWeight: FontWeight.w800)),
                  ]),
                ),
              );
            },
          ),
        ),
      ]);

  Widget _generateButton(ColourAnalysisResult? profile) => SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: profile == null || _wardrobe.isEmpty || _styling ? null : () => _generate(profile),
          icon: _styling ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.auto_awesome_rounded),
          label: Text(_styling ? 'Styling your look…' : _generated ? 'Create another look' : 'Create my outfit'),
          style: FilledButton.styleFrom(backgroundColor: AppColors.peach, foregroundColor: AppColors.charcoal, minimumSize: const Size.fromHeight(55), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17))),
        ),
      );

  Widget _result(ColourAnalysisResult? profile) {
    if (profile == null) return _message('Complete Colour Analysis to personalise your outfit.');
    if (_styling) return _message('Looking through your wardrobe and personal style…');
    if (_wardrobe.isEmpty) return _message('Add a few pieces to My Wardrobe first.');
    if (_look.isEmpty) return _message('I could not build a valid outfit from this wardrobe yet.');
    final result = _aiResult;
    final breakdown = result?.scoreBreakdown ?? const <String, int>{};
    final notes = result?.stylingNotes ?? const <String>[];
    final title = result?.displayTitle ?? 'A look built for ${_occasion.toLowerCase()}';
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: Text(title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900))),
        if (result != null) _matchBadge(result.matchScore),
      ]),
      const SizedBox(height: 12),
      SizedBox(
        height: 360,
        child: GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _look.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 0.77),
          itemBuilder: (_, index) => _lookCard(_look[index]),
        ),
      ),
      if (result?.colourDirection != null && result!.colourDirection!.isNotEmpty) ...[
        const SizedBox(height: 16),
        _message(result.colourDirection!),
      ],
      if (breakdown.isNotEmpty) ...[
        const SizedBox(height: 16),
        _breakdownCard(breakdown),
      ],
      if (notes.isNotEmpty) ...[
        const SizedBox(height: 16),
        _notesCard(notes),
      ],
      const SizedBox(height: 16),
      _actionGrid(profile),
    ]);
  }

  Widget _actionGrid(ColourAnalysisResult profile) {
    final actions = <({String label, IconData icon, VoidCallback? onTap})>[
      (label: _savedLook ? 'Saved' : 'Save look', icon: _savedLook ? Icons.bookmark_rounded : Icons.bookmark_border_rounded, onTap: _savingLook ? null : () => _saveLook(profile)),
      (label: 'Try another', icon: Icons.auto_awesome_outlined, onTap: _styling ? null : () => _tryAnother(profile)),
      (label: 'Restyle', icon: Icons.refresh_rounded, onTap: _styling ? null : _restyleLook),
      (label: 'Change shoes', icon: Icons.sports_rounded, onTap: _styling ? null : _changeShoes),
    ];
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: actions.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 2.5),
      itemBuilder: (_, index) {
        final action = actions[index];
        return OutlinedButton.icon(
          onPressed: action.onTap,
          icon: Icon(action.icon, size: 17),
          label: Text(action.label, maxLines: 1, overflow: TextOverflow.ellipsis),
          style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
        );
      },
    );
  }

  Widget _matchBadge(int score) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(color: AppColors.sage.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(17), border: Border.all(color: AppColors.sage.withValues(alpha: 0.35))),
        child: Column(children: [
          Text('$score%', style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: AppColors.success)),
          const Text('MATCH', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w800, letterSpacing: 0.8, color: AppColors.success)),
        ]),
      );

  Widget _breakdownCard(Map<String, int> breakdown) {
    const labels = {'colour': 'Colour', 'occasion': 'Occasion', 'style': 'Style', 'harmony': 'Harmony', 'personal': 'Personal'};
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('WHY THIS LOOK', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w900, letterSpacing: 1.1, color: AppColors.textMuted)),
        const SizedBox(height: 10),
        ...breakdown.entries.map((entry) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(children: [
                Expanded(child: Text(labels[entry.key] ?? entry.key, style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary))),
                Text('${entry.value}', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800)),
              ]),
            )),
      ]),
    );
  }

  Widget _notesCard(List<String> notes) => Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 15, 16, 13),
        decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.border)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('STYLE NOTES', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w900, letterSpacing: 1.1, color: AppColors.textMuted)),
          const SizedBox(height: 8),
          ...notes.take(4).map((note) => Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Padding(padding: EdgeInsets.only(top: 5), child: Icon(Icons.circle, size: 5, color: AppColors.primary)),
                  const SizedBox(width: 8),
                  Expanded(child: Text(note, style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary, height: 1.35))),
                ]),
              )),
        ]),
      );

  Widget _lookCard(WardrobeItem item) {
    final loved = _lovedItemIds.contains(item.id);
    final disliked = _dislikedItemIds.contains(item.id);
    return Container(
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.border)),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          child: Stack(fit: StackFit.expand, children: [
            if (item.imageUrl.isNotEmpty) CachedNetworkImage(imageUrl: item.imageUrl, fit: BoxFit.cover) else Container(color: AppColors.surfaceMuted, child: const Icon(Icons.checkroom_outlined, color: AppColors.primary, size: 36)),
            Positioned(top: 8, left: 8, child: Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5), decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.52), borderRadius: BorderRadius.circular(8)), child: Text(_categoryLabel(item.category), style: const TextStyle(color: Colors.white, fontSize: 7.5, fontWeight: FontWeight.w900, letterSpacing: 0.8)))),
            Positioned(top: 5, right: 5, child: Row(children: [_feedbackButton(Icons.thumb_up_alt_outlined, loved, () => _feedback(item, true)), const SizedBox(width: 3), _feedbackButton(Icons.thumb_down_alt_outlined, disliked, () => _feedback(item, false))])),
          ]),
        ),
        Padding(padding: const EdgeInsets.fromLTRB(11, 9, 11, 11), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)), const SizedBox(height: 3), Text('${item.colour} · ${item.style}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 9.5, color: AppColors.textSecondary))])),
      ]),
    );
  }

  String _categoryLabel(String category) {
    switch (category) {
      case 'Tops':
        return 'TOP';
      case 'Bottoms':
        return 'BOTTOM';
      case 'Dresses':
        return 'DRESS';
      case 'Suits':
        return 'SUIT';
      case 'Jackets':
        return 'JACKET';
      case 'Skirts':
        return 'SKIRT';
      case 'Shoes':
        return 'SHOES';
      case 'Accessories':
        return 'ACCESSORY';
      default:
        return category.toUpperCase();
    }
  }

  Widget _feedbackButton(IconData icon, bool active, VoidCallback onPressed) => Material(
        color: Colors.black.withValues(alpha: 0.48),
        borderRadius: BorderRadius.circular(9),
        child: InkWell(onTap: onPressed, borderRadius: BorderRadius.circular(9), child: Padding(padding: const EdgeInsets.all(6), child: Icon(icon, size: 13, color: active ? Colors.white : Colors.white70))),
      );

  Widget _message(String text) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(17),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.border)),
        child: Text(text, style: const TextStyle(color: AppColors.textSecondary, height: 1.4, fontSize: 12.5)),
      );
}
