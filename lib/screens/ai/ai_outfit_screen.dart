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
import '../../services/firestore_service.dart';

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
  bool _generated = false;
  int _generation = 0;

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
          _generated = false;
          _look = const [];
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  int _score(WardrobeItem item, ColourAnalysisResult profile) {
    var score = 30;
    final text = '${item.category} ${item.style} ${item.colour}'.toLowerCase();
    final occasion = _occasion.toLowerCase();

    if (item.isFavourite) score += 8;
    if (profile.colours.any((c) => text.contains(c.toLowerCase()))) score += 28;

    switch (occasion) {
      case 'work':
        if (text.contains('smart') || text.contains('formal')) score += 24;
        if (text.contains('elegant') || text.contains('classic')) score += 12;
        if (text.contains('casual')) score -= 8;
        break;
      case 'date':
        if (text.contains('feminine') || text.contains('elegant')) score += 22;
        if (text.contains('dress')) score += 16;
        if (text.contains('casual')) score += 4;
        break;
      case 'dinner':
        if (text.contains('elegant') || text.contains('dress')) score += 22;
        if (text.contains('smart') || text.contains('classic')) score += 14;
        break;
      case 'cafe':
        if (text.contains('casual') || text.contains('everyday')) score += 20;
        if (text.contains('minimal') || text.contains('relaxed')) score += 10;
        break;
      case 'weekend':
        if (text.contains('casual') || text.contains('everyday')) score += 22;
        if (text.contains('relaxed') || text.contains('street')) score += 10;
        break;
    }

    if (item.category == 'Shoes') score += 6;
    if (item.category == 'Accessories') score += 4;
    return score.clamp(0, 100);
  }

  List<WardrobeItem> _buildLook(ColourAnalysisResult profile) {
    final ranked = [..._wardrobe]
      ..sort((a, b) => _score(b, profile).compareTo(_score(a, profile)));

    // Rotate equally strong candidates when the user regenerates so the
    // recommendation feels useful rather than returning the exact same look.
    final offset = ranked.isEmpty ? 0 : _generation % ranked.length;
    final rotated = [
      ...ranked.skip(offset),
      ...ranked.take(offset),
    ];

    final result = <WardrobeItem>[];
    final used = <String>{};
    const categories = ['Dresses', 'Tops', 'Bottoms', 'Shoes', 'Accessories'];

    final hasDress = rotated.any((item) => item.category == 'Dresses');
    final targetCategories = hasDress
        ? ['Dresses', 'Shoes', 'Accessories']
        : categories.where((category) => category != 'Dresses').toList();

    for (final category in targetCategories) {
      final match = rotated.firstWhere(
        (item) => item.category == category && !used.contains(item.id),
        orElse: () => _emptyItem,
      );
      if (match.id.isNotEmpty) {
        result.add(match);
        used.add(match.id);
      }
    }

    return result.take(4).toList();
  }

  static WardrobeItem get _emptyItem => WardrobeItem(
        id: '',
        name: '',
        category: '',
        colour: '',
        style: '',
        imageUrl: '',
        isFavourite: false,
      );

  void _generate(ColourAnalysisResult profile) {
    setState(() {
      _generation++;
      _look = _buildLook(profile);
      _generated = true;
    });
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
            onPressed: _loading ? null : _loadWardrobe,
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
                          _look = const [];
                        }),
                        selectedColor: AppColors.primarySoft,
                        backgroundColor: AppColors.surface,
                        side: BorderSide(
                          color: selected ? AppColors.primary : AppColors.border,
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
                child: const Icon(Icons.auto_awesome_rounded, color: AppColors.primary),
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
            style: const TextStyle(color: Colors.white70, fontSize: 12.5, height: 1.45),
          ),
        ],
      ),
    );
  }

  Widget _generateButton(ColourAnalysisResult? profile) {
    final disabled = profile == null || _wardrobe.isEmpty;
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: disabled ? null : () => _generate(profile),
        icon: const Icon(Icons.auto_awesome_rounded),
        label: Text(_generated ? 'Try another look' : 'Create my outfit'),
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.peach,
          foregroundColor: AppColors.charcoal,
          disabledBackgroundColor: AppColors.surfaceMuted,
          disabledForegroundColor: AppColors.textMuted,
          minimumSize: const Size.fromHeight(54),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)),
        ),
      ),
    );
  }

  Widget _result(ColourAnalysisResult? profile, List<WardrobeItem> look) {
    if (profile == null) {
      return _message('Complete Colour Analysis to personalise your outfit.');
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
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.event_outlined, color: AppColors.primary, size: 16),
                  const SizedBox(width: 6),
                  Text(_occasion, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                  const Spacer(),
                  const Icon(Icons.checkroom_outlined, color: AppColors.textMuted, size: 16),
                  const SizedBox(width: 5),
                  Text('${look.length} pieces', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  int _matchScore(ColourAnalysisResult profile, List<WardrobeItem> look) {
    final colourMatches = look.where(
      (item) => profile.colours.any((c) => item.colour.toLowerCase().contains(c.toLowerCase())),
    ).length;
    final favourites = look.where((item) => item.isFavourite).length;
    final occasionMatches = look.where((item) {
      final text = '${item.style} ${item.category}'.toLowerCase();
      return switch (_occasion.toLowerCase()) {
        'work' => text.contains('smart') || text.contains('formal') || text.contains('elegant'),
        'date' => text.contains('feminine') || text.contains('elegant') || text.contains('dress'),
        'dinner' => text.contains('elegant') || text.contains('dress') || text.contains('smart'),
        'cafe' || 'weekend' => text.contains('casual') || text.contains('everyday') || text.contains('relaxed'),
        _ => false,
      };
    }).length;
    return (62 + colourMatches * 7 + favourites * 3 + occasionMatches * 5).clamp(68, 97);
  }

  Widget _whyItWorks(ColourAnalysisResult profile, List<WardrobeItem> look) {
    final matchedColours = look.where(
      (item) => profile.colours.any((c) => item.colour.toLowerCase().contains(c.toLowerCase())),
    ).length;
    final favouriteCount = look.where((item) => item.isFavourite).length;
    final reason = matchedColours > 0
        ? 'I kept $matchedColours ${matchedColours == 1 ? 'piece' : 'pieces'} close to your ${profile.season} palette, then balanced the look for a ${_occasion.toLowerCase()} setting.'
        : 'I balanced the pieces for a ${_occasion.toLowerCase()} setting while keeping the recommendation grounded in what you already own.';

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
              Icon(Icons.auto_awesome_rounded, color: AppColors.primary, size: 18),
              SizedBox(width: 7),
              Text('Why this works', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5)),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            reason,
            style: const TextStyle(fontSize: 11.5, height: 1.45, color: AppColors.textSecondary),
          ),
          if (favouriteCount > 0) ...[
            const SizedBox(height: 8),
            Text(
              '$favouriteCount favourite ${favouriteCount == 1 ? 'piece' : 'pieces'} included',
              style: const TextStyle(color: AppColors.primary, fontSize: 10.5, fontWeight: FontWeight.w700),
            ),
          ],
        ],
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
      child: Text(
        '$score% match',
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.success),
      ),
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
                      child: const Center(child: Icon(Icons.checkroom_outlined, color: AppColors.primary)),
                    )
                  : CachedNetworkImage(imageUrl: item.imageUrl, fit: BoxFit.cover, width: double.infinity),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            item.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
          ),
          const SizedBox(height: 2),
          Text(
            '${item.category} · ${item.colour}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 10.5),
          ),
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
      child: Text(
        text,
        style: const TextStyle(color: AppColors.textSecondary, height: 1.45, fontSize: 12.5),
      ),
    );
  }
}
