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
  bool _loading = true;
  bool _styling = false;
  bool _generated = false;
  int _generation = 0;
  final Set<String> _lovedLookIds = <String>{};
  final Set<String> _dislikedLookIds = <String>{};
  bool _savedLook = false;
  bool _savingLook = false;
  bool _refreshingFromLifecycle = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadWardrobe();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshWhenResumed();
    }
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
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (mounted) {
        setState(() {
          _loading = false;
          _wardrobe = const [];
        });
      }
      return;
    }
    if (showLoading && mounted) setState(() => _loading = true);
    try {
      final items = await FirestoreService.getWardrobeItems(uid);
      if (!mounted) return;
      setState(() {
        _wardrobe = items;
        _loading = false;
      });
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
    if (item.season.toLowerCase().contains(profile.season.toLowerCase())) score += 12;
    if (occasion == 'work' && (text.contains('smart') || text.contains('elegant'))) score += 22;
    if (occasion == 'date' && (text.contains('feminine') || text.contains('elegant') || text.contains('dress'))) score += 22;
    if (occasion == 'dinner' && (text.contains('elegant') || text.contains('dress') || text.contains('smart'))) score += 18;
    if ((occasion == 'cafe' || occasion == 'weekend') && (text.contains('casual') || text.contains('everyday'))) score += 18;
    if (item.category == 'Shoes') score += 5;
    if (item.category == 'Accessories') score += 3;
    return score;
  }

  List<WardrobeItem> _buildLook(ColourAnalysisResult profile) {
    final sorted = [..._wardrobe]..sort((a, b) => _score(b, profile).compareTo(_score(a, profile)));
    final categories = _occasion == 'Dinner' || _occasion == 'Date' ? ['Dresses', 'Shoes', 'Accessories'] : ['Tops', 'Bottoms', 'Shoes', 'Accessories'];
    final rotated = [...sorted];
    if (rotated.length > 1 && _generation > 1) {
      final offset = (_generation - 1) % rotated.length;
      final head = rotated.sublist(offset);
      head.addAll(rotated.sublist(0, offset));
      rotated..clear()..addAll(head);
    }
    final result = <WardrobeItem>[];
    final used = <String>{};
    for (final category in categories) {
      final match = rotated.firstWhere((item) => item.category == category && !used.contains(item.id), orElse: () => _emptyItem);
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
        id: '', userId: '', name: '', category: '', colour: '', style: '', season: '', imageUrl: '', isFavourite: false, notes: '', createdAt: null,
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
      final aiResult = await AiStylingService.getRecommendation(profile: profile, wardrobe: _wardrobe, styles: styles, preferences: preferences, occasion: _occasion);
      if (!mounted) return;
      if (aiResult != null) {
        final aiLook = [_findWardrobeItem(aiResult.topId), _findWardrobeItem(aiResult.bottomId), _findWardrobeItem(aiResult.shoesId), _findWardrobeItem(aiResult.accessoryId)].whereType<WardrobeItem>().toList();
        setState(() {
          _look = aiLook;
          _styling = false;
        });
        return;
      }
    } catch (_) {}
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
      await FirestoreService.saveOutfitLook(uid: uid, occasion: _occasion, itemIds: look.map((item) => item.id).where((id) => id.isNotEmpty).toList(), matchScore: matchScore, season: profile.season);
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
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.border)),
      child: Text(text, style: const TextStyle(color: AppColors.textSecondary, height: 1.4, fontSize: 12.5)),
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
        actions: [IconButton(onPressed: () => _loadWardrobe(), icon: const Icon(Icons.refresh_rounded))],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 34),
              children: [
                _hero(profile),
                const SizedBox(height: 22),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Expanded(child: Text('VYEA  /  AI OUTFIT', style: TextStyle(color: AppColors.peach, fontSize: 9.5, fontWeight: FontWeight.w900, letterSpacing: 1.45))),
            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5), decoration: BoxDecoration(color: Colors.white.withValues(alpha: .10), borderRadius: BorderRadius.circular(9)), child: const Text('PERSONAL LOOK', style: TextStyle(color: Colors.white70, fontSize: 7.3, fontWeight: FontWeight.w900, letterSpacing: .8))),
          ]),
          const SizedBox(height: 18),
          const Text('Your next look,\nmade personal.', style: TextStyle(color: Colors.white, fontSize: 30, height: 1.02, fontWeight: FontWeight.w800, letterSpacing: -1)),
          const SizedBox(height: 9),
          Text(profile == null ? 'Complete your colour profile first.' : 'Built around your ${profile.season} palette and the pieces you already own.', style: const TextStyle(color: Colors.white70, fontSize: 12.5, height: 1.45)),
          const SizedBox(height: 17),
          Row(children: [
            _heroStat(Icons.palette_outlined, profile?.season ?? 'Colour', 'palette'),
            const SizedBox(width: 8),
            _heroStat(Icons.checkroom_outlined, '${_wardrobe.length}', 'pieces'),
            const SizedBox(width: 8),
            _heroStat(Icons.auto_awesome_outlined, _occasion, 'occasion'),
          ]),
        ],
      ),
    );
  }

  Widget _heroStat(IconData icon, String value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 10),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: .08), borderRadius: BorderRadius.circular(15)),
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
            separatorBuilder: (_, _) => const SizedBox(width: 9),
            itemBuilder: (_, index) {
              final item = _occasions[index];
              final selected = _occasion == item.$1;
              return InkWell(
                onTap: () => setState(() {
                  _occasion = item.$1;
                  _generated = false;
                  _savedLook = false;
                  _look = const [];
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
      ],
    );
  }

  Widget _generateButton(ColourAnalysisResult? profile) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: profile == null || _wardrobe.isEmpty || _styling ? null : () => _generate(profile),
        icon: _styling ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.auto_awesome_rounded),
        label: Text(_styling ? 'Putting your look together…' : _generated ? 'Create another look' : 'Create my outfit'),
        style: FilledButton.styleFrom(backgroundColor: AppColors.peach, foregroundColor: AppColors.charcoal, minimumSize: const Size.fromHeight(55), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17))),
      ),
    );
  }

  Widget _result(ColourAnalysisResult? profile, List<WardrobeItem> look) {
    if (profile == null) return _message('Complete Colour Analysis to personalise your outfit.');
    if (_styling) return _message('Looking through your wardrobe and matching your profile…');
    if (_wardrobe.isEmpty) return _message('Add a few pieces to My Wardrobe first.');
    if (look.isEmpty) return _message('I could not find a complete combination yet. Try adding tops, bottoms and shoes.');
    final match = _matchScore(profile, look);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [const Expanded(child: Text('YOUR PERSONAL LOOK', style: TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w800, letterSpacing: 1.1))), _scorePill(match)]),
      const SizedBox(height: 11),
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(24), border: Border.all(color: AppColors.border)),
        child: Column(children: [
          SizedBox(
            height: 225,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: look.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (_, index) => _itemCard(look[index]),
            ),
          ),
          const SizedBox(height: 13),
          _whyItWorks(profile, look),
          const SizedBox(height: 12),
          _feedbackActions(look, profile),
          const SizedBox(height: 10),
          Row(children: [
            const Icon(Icons.event_outlined, color: AppColors.primary, size: 16),
            const SizedBox(width: 6),
            Expanded(child: Text('Built for $_occasion from your saved wardrobe.', style: const TextStyle(color: AppColors.textSecondary, fontSize: 10.5))),
          ]),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _savingLook ? null : () => _saveCurrentLook(profile, look),
              icon: _savingLook ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : Icon(_savedLook ? Icons.bookmark_rounded : Icons.bookmark_border_rounded),
              label: Text(_savingLook ? 'Saving…' : _savedLook ? 'Saved to Looks' : 'Save this look'),
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(46), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
            ),
          ),
        ]),
      ),
    ]);
  }

  Widget _scorePill(int score) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: AppColors.secondary, borderRadius: BorderRadius.circular(20)),
      child: Text('$score% match', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.primary)),
    );
  }

  Widget _itemCard(WardrobeItem item) {
    return SizedBox(
      width: 165,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(17),
            child: item.imageUrl.isEmpty
                ? Container(color: AppColors.surfaceMuted, child: const Center(child: Icon(Icons.checkroom_outlined, color: AppColors.primary, size: 30)))
                : CachedNetworkImage(imageUrl: item.imageUrl, fit: BoxFit.cover, width: double.infinity),
          ),
        ),
        const SizedBox(height: 8),
        Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
        Text('${item.category} · ${item.colour}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.textMuted, fontSize: 10.5)),
      ]),
    );
  }

  Widget _whyItWorks(ColourAnalysisResult profile, List<WardrobeItem> look) {
    final seasonHits = look.where((item) => item.season.toLowerCase().contains(profile.season.toLowerCase())).length;
    final colourHits = look.where((item) {
      final text = '${item.colour} ${item.style}'.toLowerCase();
      return profile.colours.any((c) => text.contains(c.toLowerCase()));
    }).length;
    final reason = seasonHits > 0 || colourHits > 0
        ? 'Chosen to work with your ${profile.season} palette and the pieces you already own.'
        : 'Balanced around the selected occasion using pieces from your wardrobe.';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.secondary.withValues(alpha: .45), borderRadius: BorderRadius.circular(17)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.auto_awesome_rounded, color: AppColors.primary, size: 18),
        const SizedBox(width: 9),
        Expanded(child: Text(reason, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11.5, height: 1.4))),
      ]),
    );
  }

  Widget _feedbackActions(List<WardrobeItem> look, ColourAnalysisResult profile) {
    return Row(children: [
      Expanded(child: OutlinedButton.icon(onPressed: () => setState(() { for (final item in look) { _lovedLookIds.add(item.id); _dislikedLookIds.remove(item.id); } }), icon: const Icon(Icons.favorite_border_rounded, size: 17), label: const Text('Love this')),
      const SizedBox(width: 9),
      Expanded(child: OutlinedButton.icon(onPressed: () { setState(() { for (final item in look) { _dislikedLookIds.add(item.id); _lovedLookIds.remove(item.id); } }); _generate(profile); }, icon: const Icon(Icons.refresh_rounded, size: 17), label: const Text('Try another')),
    ]);
  }
}
