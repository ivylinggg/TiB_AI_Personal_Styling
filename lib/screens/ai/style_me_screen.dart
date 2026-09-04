import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_radius.dart';
import '../../models/colour_analysis_result.dart';
import '../../models/wardrobe_item.dart';
import '../../providers/analysis_provider.dart';
import '../../services/ai_styling_service.dart';
import '../../services/firestore_service.dart';
import '../../services/style_preference_service.dart';
import '../../widgets/empty_state.dart';
import 'ai_stylist_screen.dart';

/// Human-first outfit planner using the user's real wardrobe.
/// Premium users get the existing AI service; everyone else gets a
/// transparent local wardrobe match.
class StyleMeScreen extends StatefulWidget {
  const StyleMeScreen({super.key});

  @override
  State<StyleMeScreen> createState() => _StyleMeScreenState();
}

class _StyleMeScreenState extends State<StyleMeScreen> {
  final TextEditingController _occasionController = TextEditingController();

  bool _loading = true;
  bool _styling = false;
  bool _isPremium = false;
  String _status = '';

  List<WardrobeItem> _wardrobe = const [];
  List<String> _styles = const [];
  List<String> _preferences = const [];

  AiStylingResult? _aiResult;
  List<WardrobeItem> _localLook = const [];

  static const _ideas = [
    'Dinner date tonight',
    'Cafe hopping with friends',
    'Airport outfit',
    'Weekend shopping',
    'Smart casual work day',
    'Birthday dinner',
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _occasionController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    try {
      final results = await Future.wait<dynamic>([
        FirestoreService.getWardrobeItems(uid),
        StylePreferenceService.getStylePreferences(uid),
        FirebaseFirestore.instance.collection('users').doc(uid).get(),
      ]);

      if (!mounted) return;

      final prefs = results[1] as Map<String, dynamic>?;
      final user = (results[2] as DocumentSnapshot<Map<String, dynamic>>).data();

      setState(() {
        _wardrobe = results[0] as List<WardrobeItem>;
        _styles = List<String>.from(prefs?['styles'] ?? const []);
        _preferences = List<String>.from(prefs?['preferences'] ?? const []);
        _isPremium = user?['isPremium'] == true;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _styleMe() async {
    final prompt = _occasionController.text.trim();
    if (prompt.isEmpty || _styling || _wardrobe.isEmpty) return;

    final profile = context.read<AnalysisProvider>().result;
    if (profile == null) {
      setState(() {
        _status = 'Complete Colour Analysis first so your look can be colour-aware.';
        _aiResult = null;
        _localLook = const [];
      });
      return;
    }

    setState(() {
      _styling = true;
      _status = 'Checking your wardrobe, palette and preferences…';
      _aiResult = null;
      _localLook = const [];
    });

    final result = _isPremium
        ? await AiStylingService.getRecommendation(
            profile: profile,
            wardrobe: _wardrobe,
            styles: _styles,
            preferences: _preferences,
            occasion: prompt,
          )
        : null;

    if (!mounted) return;

    if (result != null) {
      setState(() {
        _aiResult = result;
        _styling = false;
        _status = 'AI look built from pieces you already own.';
      });
      return;
    }

    setState(() {
      _localLook = _buildLocalLook(prompt, profile);
      _styling = false;
      _status = _isPremium
          ? 'AI is unavailable right now, so here is a transparent wardrobe fallback.'
          : 'Here is a wardrobe match based on your saved palette and preferences.';
    });
  }

  List<WardrobeItem> _buildLocalLook(String prompt, ColourAnalysisResult profile) {
    final text = prompt.toLowerCase();
    final wantsDress = text.contains('dress') || text.contains('date') || text.contains('birthday') || text.contains('dinner');
    final wantsSmart = text.contains('work') || text.contains('office') || text.contains('meeting') || text.contains('smart');
    final wantsCasual = text.contains('cafe') || text.contains('shopping') || text.contains('weekend') || text.contains('airport');

    int score(WardrobeItem item) {
      var value = 0;
      final colour = item.colour.toLowerCase();
      final style = item.style.toLowerCase();
      final category = item.category.toLowerCase();

      if (item.isFavourite) value += 8;
      if (_styles.any((s) => style.contains(s.toLowerCase()))) value += 9;
      if (_preferences.any((p) => style.contains(p.toLowerCase()))) value += 4;
      if (profile.colours.any((c) => c.toLowerCase().contains(colour) || colour.contains(c.toLowerCase()))) value += 12;
      if (wantsDress && category == 'dresses') value += 20;
      if (wantsSmart && (style.contains('smart') || style.contains('elegant'))) value += 16;
      if (wantsCasual && (style.contains('casual') || style.contains('everyday'))) value += 14;
      if (!wantsDress && category == 'tops') value += 7;
      if (!wantsDress && category == 'bottoms') value += 7;
      if (category == 'shoes') value += 3;
      if (category == 'accessories') value += 2;
      return value;
    }

    final sorted = [..._wardrobe]..sort((a, b) => score(b).compareTo(score(a)));
    final look = <WardrobeItem>[];

    if (wantsDress) {
      for (final item in sorted) {
        if (item.category == 'Dresses') {
          look.add(item);
          break;
        }
      }
    } else {
      WardrobeItem? top;
      WardrobeItem? bottom;
      for (final item in sorted) {
        if (top == null && item.category == 'Tops') top = item;
        if (bottom == null && item.category == 'Bottoms') bottom = item;
        if (top != null && bottom != null) break;
      }
      if (top != null) look.add(top);
      if (bottom != null && bottom.id != top?.id) look.add(bottom);
    }

    WardrobeItem? shoes;
    WardrobeItem? accessory;
    for (final item in sorted) {
      if (shoes == null && item.category == 'Shoes') shoes = item;
      if (accessory == null && item.category == 'Accessories') accessory = item;
      if (shoes != null && accessory != null) break;
    }

    if (shoes != null && !look.any((i) => i.id == shoes!.id)) look.add(shoes);
    if (accessory != null && !look.any((i) => i.id == accessory!.id)) look.add(accessory);
    return look.take(4).toList();
  }

  WardrobeItem? _find(String? id) {
    if (id == null) return null;
    for (final item in _wardrobe) {
      if (item.id == id) return item;
    }
    return null;
  }

  List<WardrobeItem> get _aiLook {
    final ids = [_aiResult?.topId, _aiResult?.bottomId, _aiResult?.shoesId, _aiResult?.accessoryId];
    return ids.map(_find).whereType<WardrobeItem>().toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18), onPressed: () => Navigator.pop(context)),
        title: const Text('Style Me', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        actions: [
          IconButton(
            tooltip: 'Open AI Stylist chat',
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AIStylistScreen())),
            icon: const Icon(Icons.chat_bubble_outline_rounded),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _wardrobe.isEmpty
              ? EmptyState(
                  icon: Icons.checkroom_outlined,
                  title: 'Add a few wardrobe pieces first',
                  description: 'Style Me only recommends pieces you actually own.',
                  ctaLabel: 'Open Wardrobe',
                  onCta: () => Navigator.pop(context),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 34),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildEditorialHero(),
                      const SizedBox(height: 18),
                      _buildPlanSection(),
                      const SizedBox(height: 20),
                      _buildWardrobeContext(),
                      if (_status.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Text(_status, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11.5, height: 1.4)),
                      ],
                      if (_aiResult != null || _localLook.isNotEmpty) ...[
                        const SizedBox(height: 22),
                        _buildResult(_aiResult == null ? _localLook : _aiLook),
                      ],
                    ],
                  ),
                ),
    );
  }

  Widget _buildEditorialHero() {
    return Container(
      padding: const EdgeInsets.fromLTRB(21, 20, 21, 22),
      decoration: BoxDecoration(
        color: AppColors.primaryDark,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(child: Text('VYEA  /  STYLE ME', style: TextStyle(color: AppColors.peach, fontSize: 9.5, fontWeight: FontWeight.w900, letterSpacing: 1.45))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: .10), borderRadius: BorderRadius.circular(9)),
                child: Text(_isPremium ? 'AI STYLIST' : 'PERSONAL MATCH', style: const TextStyle(color: Colors.white70, fontSize: 7.5, fontWeight: FontWeight.w900, letterSpacing: .8)),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Text('Dress for the moment.\nUse what you own.', style: TextStyle(color: Colors.white, fontSize: 30, height: 1.02, fontWeight: FontWeight.w800, letterSpacing: -1)),
          const SizedBox(height: 9),
          const Text('Tell VYEA where you are going and the feeling you want. Your wardrobe, palette and preferences do the rest.', style: TextStyle(color: Colors.white70, fontSize: 12.5, height: 1.45)),
        ],
      ),
    );
  }

  Widget _buildPlanSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('WHAT ARE YOU DRESSING FOR?', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.25, color: AppColors.textMuted)),
        const SizedBox(height: 9),
        Container(
          padding: const EdgeInsets.fromLTRB(15, 4, 10, 4),
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(22), border: Border.all(color: AppColors.border)),
          child: Row(
            children: [
              const Icon(Icons.edit_note_rounded, color: AppColors.primary, size: 22),
              const SizedBox(width: 7),
              Expanded(
                child: TextField(
                  controller: _occasionController,
                  minLines: 1,
                  maxLines: 3,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _styleMe(),
                  decoration: const InputDecoration(hintText: 'Dinner, work, holiday, date night…', border: InputBorder.none, isDense: true),
                ),
              ),
              const SizedBox(width: 6),
              Material(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  onTap: _styling ? null : _styleMe,
                  borderRadius: BorderRadius.circular(16),
                  child: SizedBox(width: 48, height: 48, child: Icon(_styling ? Icons.hourglass_top_rounded : Icons.arrow_upward_rounded, color: Colors.white, size: 20)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 35,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _ideas.length,
            separatorBuilder: (_, _) => const SizedBox(width: 7),
            itemBuilder: (_, index) => ActionChip(
              label: Text(_ideas[index]),
              onPressed: _styling ? null : () => setState(() => _occasionController.text = _ideas[index]),
              backgroundColor: AppColors.surface,
              side: const BorderSide(color: AppColors.border),
              visualDensity: VisualDensity.compact,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWardrobeContext() {
    final styleText = _styles.isEmpty ? 'preferences' : _styles.take(2).join(' · ');
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.border)),
      child: Row(
        children: [
          Container(width: 40, height: 40, decoration: const BoxDecoration(color: AppColors.secondary, shape: BoxShape.circle), child: const Icon(Icons.checkroom_outlined, color: AppColors.primary, size: 20)),
          const SizedBox(width: 11),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('YOUR STYLE CONTEXT', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1.1)),
              const SizedBox(height: 4),
              Text('${_wardrobe.length} pieces · $styleText', style: const TextStyle(color: AppColors.textSecondary, fontSize: 11.5, height: 1.35)),
            ]),
          ),
          IconButton(icon: const Icon(Icons.chat_bubble_outline_rounded, size: 19), color: AppColors.primary, tooltip: 'Talk to VYEA', onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AIStylistScreen()))),
        ],
      ),
    );
  }

  Widget _buildResult(List<WardrobeItem> look) {
    if (look.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(17),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(21), border: Border.all(color: AppColors.border)),
        child: const Text('I could not build a complete look from the pieces currently in your wardrobe. Add more basics or accessories and try again.', style: TextStyle(color: AppColors.textSecondary, height: 1.4, fontSize: 12)),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [const Expanded(child: Text('YOUR LOOK', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w900, letterSpacing: 1.2, color: AppColors.textMuted))), if (_aiResult != null) const Text('AI MATCH', style: TextStyle(color: AppColors.premiumAccentDark, fontSize: 9.5, fontWeight: FontWeight.w900, letterSpacing: .9))]),
        const SizedBox(height: 9),
        if (_aiResult?.explanation.isNotEmpty == true)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [AppColors.blush, AppColors.surface]), borderRadius: BorderRadius.circular(21), border: Border.all(color: AppColors.border)),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [const Icon(Icons.auto_awesome_rounded, color: AppColors.primary, size: 18), const SizedBox(width: 9), Expanded(child: Text(_aiResult!.explanation, style: const TextStyle(color: AppColors.textSecondary, height: 1.45, fontSize: 12.5)))]),
          ),
        Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(23), border: Border.all(color: AppColors.border)),
          child: SizedBox(
            height: 205,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: look.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (_, index) => _resultItemCard(look[index]),
            ),
          ),
        ),
        const SizedBox(height: 11),
        Row(
          children: [
            const Icon(Icons.check_circle_outline_rounded, color: AppColors.primary, size: 16),
            const SizedBox(width: 6),
            const Expanded(child: Text('Built from pieces you already own', style: TextStyle(fontSize: 10.5, color: AppColors.textSecondary, fontWeight: FontWeight.w700))),
            TextButton(onPressed: _styling ? null : _styleMe, child: const Text('Refresh')),
          ],
        ),
      ],
    );
  }

  Widget _resultItemCard(WardrobeItem item) {
    return SizedBox(
      width: 150,
      child: Container(
        decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.border.withValues(alpha: .75))),
        padding: const EdgeInsets.all(7),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: item.imageUrl.isEmpty
                  ? Container(color: AppColors.surfaceMuted, child: const Center(child: Icon(Icons.checkroom_outlined, color: AppColors.primary, size: 28)))
                  : CachedNetworkImage(imageUrl: item.imageUrl, fit: BoxFit.cover, width: double.infinity),
            ),
          ),
          const SizedBox(height: 7),
          Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text('${item.category} · ${item.colour}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 9.5, color: AppColors.textMuted)),
        ]),
      ),
    );
  }
}
