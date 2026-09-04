import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_gradients.dart';
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

  static WardrobeItem get _emptyItem => const WardrobeItem(id: '', userId: '', name: '', category: '', colour: '', style: '', season: '', imageUrl: '', isFavourite: false, notes: '', createdAt: null);

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

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<AnalysisProvider>().result;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('AI Outfit', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)), centerTitle: true, backgroundColor: AppColors.background, elevation: 0, scrolledUnderElevation: 0, actions: [IconButton(onPressed: _loadWardrobe, icon: const Icon(Icons.refresh_rounded))]),
      body: _loading ? const Center(child: CircularProgressIndicator()) : ListView(padding: const EdgeInsets.fromLTRB(20, 10, 20, 34), children: [
        _hero(profile),
        const SizedBox(height: 22),
        _occasionSection(),
        const SizedBox(height: 22),
        _generateButton(profile),
        if (_generated) ...[const SizedBox(height: 28), _result(profile, _look)],
      ]),
    );
  }

  Widget _hero(ColourAnalysisResult? profile) {
    return Container(
      padding: const EdgeInsets.fromLTRB(21, 21, 21, 23),
      decoration: BoxDecoration(color: AppColors.primaryDark, borderRadius: BorderRadius.circular(28)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
      SizedBox(height: 88, child: ListView.separated(scrollDirection: Axis.horizontal, itemCount: _occasions.length, separatorBuilder: (_, _) => const SizedBox(width: 9), itemBuilder: (_, index) {
        final item = _occasions[index];
        final selected = _occasion == item.$1;
        return InkWell(onTap: () => setState(() { _occasion = item.$1; _generated = false; _savedLook = false; _look = const []; }), borderRadius: BorderRadius.circular(19), child: AnimatedContainer(duration: const Duration(milliseconds: 180), width: 92, padding: const EdgeInsets.all(11), decoration: BoxDecoration(color: selected ? AppColors.primaryDark : AppColors.surface, borderRadius: BorderRadius.circular(19), border: Border.all(color: selected ? AppColors.primaryDark : AppColors.border)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(item.$2, color: selected ? Colors.white : AppColors.primary, size: 19), const Spacer(), Text(item.$1, style: TextStyle(color: selected ? Colors.white : AppColors.textPrimary, fontSize: 11, fontWeight: FontWeight.w800))])));
      })));
    ],);
  }

  Widget _generateButton(ColourAnalysisResult? profile) {
    return SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: profile == null || _wardrobe.isEmpty || _styling ? null : () => _generate(profile), icon: _styling ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.auto_awesome_rounded), label: Text(_styling ? 'Putting your look together…' : _generated ? 'Create another look' : 'Create my outfit'), style: FilledButton.styleFrom(backgroundColor: AppColors.peach, foregroundColor: AppColors.charcoal, minimumSize: const Size.fromHeight(55), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17))));
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
      Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(24), border: Border.all(color: AppColors.border)), child: Column(children: [
        SizedBox(height: 225, child: ListView.separated(scrollDirection: Axis.horizontal, itemCount: look.length, separatorBuilder: (_, _) => const SizedBox(width: 10), itemBuilder: (_, index) => _itemCard(look[index]))),
        const SizedBox(height: 13),
        _whyItWorks(profile, look),
        const SizedBox(height: 12),
        _feedbackActions(),
        const SizedBox(height: 10),
        Row(children: [const Icon(Icons.event_outlined, color: AppColors.primary, size: 16), const SizedBox(width: 6), Text(_occasion, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)), const Spacer(), const Icon(Icons.checkroom_outlined, color: AppColors.textMuted, size: 16), const SizedBox(width: 6), Text('${look.length} pieces', style: const TextStyle(fontSize: 10.5, color: AppColors.textMuted))]),
      ])),
      const SizedBox(height: 10),
      SizedBox(width: double.infinity, child: OutlinedButton.icon(onPressed: _savingLook ? null : () => _saveCurrentLook(profile, look), icon: _savingLook ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : Icon(_savedLook ? Icons.bookmark_rounded : Icons.bookmark_border_rounded), label: Text(_savedLook ? 'Saved to My Looks' : 'Save this look'), style: OutlinedButton.styleFrom(foregroundColor: AppColors.primary, side: const BorderSide(color: AppColors.border), minimumSize: const Size.fromHeight(49), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))))),
    ]);
  }

  Widget _itemCard(WardrobeItem item) {
    final loved = _lovedLookIds.contains(item.id);
    final disliked = _dislikedLookIds.contains(item.id);
    return SizedBox(width: 145, child: Stack(children: [Container(width: 145, padding: const EdgeInsets.all(7), decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.border)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(14), child: item.imageUrl.isEmpty ? Container(color: AppColors.surfaceMuted, child: const Center(child: Icon(Icons.checkroom_outlined, color: AppColors.primary))) : CachedNetworkImage(imageUrl: item.imageUrl, width: double.infinity, fit: BoxFit.cover))), const SizedBox(height: 7), Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)), Text('${item.category} · ${item.colour}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.textMuted, fontSize: 10))])), Positioned(right: 11, top: 11, child: Row(children: [_feedbackIcon(Icons.favorite_rounded, loved, () => _toggleFeedback(item.id, true)), const SizedBox(width: 5), _feedbackIcon(Icons.close_rounded, disliked, () => _toggleFeedback(item.id, false))]))]));
  }

  Widget _feedbackIcon(IconData icon, bool active, VoidCallback onTap) {
    return Material(color: Colors.white.withValues(alpha: .92), shape: const CircleBorder(), child: InkWell(onTap: onTap, customBorder: const CircleBorder(), child: Padding(padding: const EdgeInsets.all(6), child: Icon(icon, size: 13, color: active ? AppColors.primary : AppColors.textMuted))));
  }

  Widget _feedbackActions() {
    return Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: AppColors.surfaceMuted, borderRadius: BorderRadius.circular(17)), child: const Row(children: [Expanded(child: Text('Tell VYEA what feels right. Your feedback shapes future matches.', style: TextStyle(fontSize: 10.5, color: AppColors.textSecondary, height: 1.35))), SizedBox(width: 8), Icon(Icons.favorite_outline_rounded, color: AppColors.primary, size: 18), SizedBox(width: 8), Icon(Icons.tune_rounded, color: AppColors.textMuted, size: 18)]));
  }

  void _toggleFeedback(String id, bool love) {
    setState(() {
      if (love) {
        _dislikedLookIds.remove(id);
        _lovedLookIds.contains(id) ? _lovedLookIds.remove(id) : _lovedLookIds.add(id);
      } else {
        _lovedLookIds.remove(id);
        _dislikedLookIds.contains(id) ? _dislikedLookIds.remove(id) : _dislikedLookIds.add(id);
      }
    });
  }

  Widget _whyItWorks(ColourAnalysisResult profile, List<WardrobeItem> look) {
    final matching = look.where((item) => profile.colours.any((c) => '${item.colour} ${item.style}'.toLowerCase().contains(c.toLowerCase()))).length;
    return Container(padding: const EdgeInsets.all(13), decoration: BoxDecoration(gradient: AppGradients.soft, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.border)), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [const Icon(Icons.auto_awesome_rounded, color: AppColors.primary, size: 18), const SizedBox(width: 8), Expanded(child: Text(matching > 0 ? '$matching pieces align with your ${profile.season} colour direction. The balance keeps the look personal without feeling overdone.' : 'The silhouette and occasion match your wardrobe profile. Try pairing the look with one of your strongest seasonal colours.', style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary, height: 1.4)))]) );
  }

  Widget _scorePill(int score) {
    return Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6), decoration: BoxDecoration(color: AppColors.secondary, borderRadius: BorderRadius.circular(10)), child: Text('$score% match', style: const TextStyle(color: AppColors.primaryDark, fontSize: 9.5, fontWeight: FontWeight.w900)));
  }

  int _matchScore(ColourAnalysisResult profile, List<WardrobeItem> look) {
    if (look.isEmpty) return 0;
    var score = 0;
    for (final item in look) {
      score += _score(item, profile);
    }
    return (score / look.length).round().clamp(0, 99);
  }

  Widget _message(String text) {
    return Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(19), border: Border.all(color: AppColors.border)), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [const Icon(Icons.info_outline_rounded, color: AppColors.primary, size: 18), const SizedBox(width: 9), Expanded(child: Text(text, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.4)))]));
  }

  void _showFeedback(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))));
  }
}
