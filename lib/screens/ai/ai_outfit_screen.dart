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
      final prefs = await StylePreferenceService.getStylePreferences(uid) ?? <String, dynamic>{};
      final styles = _stringList(prefs['styles']);
      final preferences = _stringList(prefs['preferences']);
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
    await StyleFeedbackService.recordRestyle(itemIds: _look.map((item) => item.id).toList(growable: false), occasion: _occasion);
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
      final prefs = await StylePreferenceService.getStylePreferences(uid) ?? <String, dynamic>{};
      final styles = _stringList(prefs['styles']);
      final preferences = _stringList(prefs['preferences']);
      final anchors = _look.where((item) => item.category != 'Shoes').toList(growable: false);
      WardrobeItem replacement = candidates.first;
      if (profile != null) {
        final ranked = AiStylingService.rankReplacementItems(candidates, profile: profile, occasion: _occasion, styles: styles, preferences: preferences, anchors: anchors);
        if (ranked.isNotEmpty) replacement = ranked.first;
      }
      final nextLook = [...anchors, replacement];
      if (!mounted || uid != _uid) return;
      setState(() {
        _look = nextLook;
        _savedLook = false;
        _generated = true;
      });
      await StyleFeedbackService.recordShoeChange(itemIds: nextLook.map((item) => item.id).toList(growable: false), occasion: _occasion);
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
    await StyleFeedbackService.recordItemFeedback(itemId: item.id, category: item.category, liked: liked, occasion: _occasion);
    if (_look.length > 1) {
      await StyleFeedbackService.recordLookFeedback(itemIds: _look.map((entry) => entry.id).toList(growable: false), liked: liked, occasion: _occasion);
    }
  }

  Future<void> _saveLook(ColourAnalysisResult profile) async {
    final uid = _uid;
    if (uid.isEmpty || _look.isEmpty || _savingLook) return;
    setState(() => _savingLook = true);
    try {
      await FirestoreService.saveOutfitLook(uid: uid, itemIds: _look.map((item) => item.id).toList(growable: false), occasion: _occasion, matchScore: _aiResult?.matchScore ?? 0, season: profile.season, title: _aiResult?.displayTitle ?? 'My ${_occasion.toLowerCase()} look', notes: _aiResult?.stylingNotes.join(' • '));
      await StyleFeedbackService.recordSavedLook(itemIds: _look.map((item) => item.id).toList(growable: false), occasion: _occasion);
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
    final notes = result?.stylingNotes ?? const <String>[];
    final title = result?.displayTitle ?? 'A look built for ${_occasion.toLowerCase()}';
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Expanded(child: Text(title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900))), if (result != null) _matchBadge(result.matchScore)]),
      const SizedBox(height: 10),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.border)),
        child: Column(children: [
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _look.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 9, mainAxisSpacing: 9, childAspectRatio: .78),
            itemBuilder: (_, index) {
              final item = _look[index];
              final loved = _lovedItemIds.contains(item.id);
              final disliked = _dislikedItemIds.contains(item.id);
              return Container(
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
                clipBehavior: Clip.antiAlias,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(child: item.imageUrl.isEmpty ? const Center(child: Icon(Icons.checkroom_outlined, color: AppColors.primary)) : CachedNetworkImage(imageUrl: item.imageUrl, width: double.infinity, fit: BoxFit.cover)),
                  Padding(padding: const EdgeInsets.fromLTRB(8, 7, 8, 3), child: Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700))),
                  Row(children: [
                    IconButton(tooltip: 'Love this', onPressed: () => _feedback(item, true), icon: Icon(loved ? Icons.thumb_up_alt_rounded : Icons.thumb_up_alt_outlined, size: 17, color: loved ? AppColors.primary : AppColors.textMuted)),
                    IconButton(tooltip: 'Not for me', onPressed: () => _feedback(item, false), icon: Icon(disliked ? Icons.thumb_down_alt_rounded : Icons.thumb_down_alt_outlined, size: 17, color: disliked ? AppColors.error : AppColors.textMuted)),
                  ]),
                ]),
              );
            },
          ),
          if (result?.explanation.isNotEmpty == true) ...[
            const SizedBox(height: 14),
            Align(alignment: Alignment.centerLeft, child: Text(result!.explanation, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.45))),
          ],
          if (notes.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Align(alignment: Alignment.centerLeft, child: Text('WHY IT WORKS', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w900, letterSpacing: 1.1, color: AppColors.textMuted))),
            const SizedBox(height: 7),
            ...notes.take(3).map((note) => Padding(padding: const EdgeInsets.only(bottom: 5), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [const Padding(padding: EdgeInsets.only(top: 5), child: Icon(Icons.circle, size: 5, color: AppColors.primary)), const SizedBox(width: 7), Expanded(child: Text(note, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)))]))),
          ],
          const SizedBox(height: 14),
          Wrap(spacing: 8, runSpacing: 8, children: [
            OutlinedButton.icon(onPressed: _styling ? null : () => _tryAnother(profile), icon: const Icon(Icons.refresh_rounded), label: const Text('Try another')),
            OutlinedButton.icon(onPressed: _styling ? null : _restyleLook, icon: const Icon(Icons.auto_awesome_rounded), label: const Text('Restyle')),
            OutlinedButton.icon(onPressed: _styling ? null : _changeShoes, icon: const Icon(Icons.directions_walk_rounded), label: const Text('Change shoes')),
            FilledButton.icon(onPressed: _savingLook ? null : () => _saveLook(profile), icon: Icon(_savedLook ? Icons.bookmark_rounded : Icons.bookmark_add_outlined), label: Text(_savedLook ? 'Saved' : 'Save look')),
          ]),
        ]),
      ),
    ]);
  }

  Widget _matchBadge(int score) => Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6), decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(20)), child: Text('$score% MATCH', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: AppColors.primaryDark)));

  Widget _message(String text) => Container(padding: const EdgeInsets.all(18), decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(19), border: Border.all(color: AppColors.border)), child: Text(text, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.45)));
}
