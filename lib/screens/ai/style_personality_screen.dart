import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_gradients.dart';
import '../../models/wardrobe_item.dart';
import '../../services/firestore_service.dart';
import '../../services/style_preference_service.dart';
import '../wardrobe/wardrobe_screen.dart';

/// Editorial style-discovery journey inspired by the TiB reference flow.
/// It uses real wardrobe imagery when available and writes choices back to
/// the same style-preference data used by the AI Stylist.
class StylePersonalityScreen extends StatefulWidget {
  const StylePersonalityScreen({super.key});

  @override
  State<StylePersonalityScreen> createState() => _StylePersonalityScreenState();
}

class _StylePersonalityScreenState extends State<StylePersonalityScreen> {
  static const _looks = <({String title, String subtitle, String style, IconData icon})>[
    (
      title: 'Minimal & Clean',
      subtitle: 'Simple silhouettes, quiet colours, polished details.',
      style: 'Minimal',
      icon: Icons.crop_square_rounded,
    ),
    (
      title: 'Romantic & Soft',
      subtitle: 'Feminine shapes, gentle colours, expressive details.',
      style: 'Feminine',
      icon: Icons.favorite_border_rounded,
    ),
    (
      title: 'Modern & Polished',
      subtitle: 'Smart layers, refined basics, confident structure.',
      style: 'Smart Casual',
      icon: Icons.auto_awesome_outlined,
    ),
    (
      title: 'Relaxed & Effortless',
      subtitle: 'Comfortable pieces that still look intentional.',
      style: 'Casual',
      icon: Icons.spa_outlined,
    ),
  ];

  List<WardrobeItem> _wardrobe = const [];
  List<String> _savedStyles = const [];
  bool _loading = true;
  int _question = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    try {
      final values = await Future.wait<dynamic>([
        FirestoreService.getWardrobeItems(uid),
        StylePreferenceService.getStylePreferences(uid),
      ]);
      if (!mounted) return;
      final prefs = values[1] as Map<String, dynamic>?;
      setState(() {
        _wardrobe = values[0] as List<WardrobeItem>;
        _savedStyles = List<String>.from(prefs?['styles'] ?? const []);
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _choose(String style) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final styles = {..._savedStyles, style}.toList();
    setState(() {
      _savedStyles = styles;
      _question = (_question + 1).clamp(0, 4).toInt();
    });

    try {
      final existing = await StylePreferenceService.getStylePreferences(uid);
      final preferences = List<String>.from(existing?['preferences'] ?? const []);
      await StylePreferenceService.saveStylePreferences(
        uid: uid,
        styles: styles,
        preferences: preferences,
      );
    } catch (_) {
      // Keep the journey usable if a save is temporarily unavailable.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Style Personality'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'My wardrobe',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const WardrobeScreen()),
            ),
            icon: const Icon(Icons.checkroom_outlined),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                children: [
                  _progress(),
                  const SizedBox(height: 20),
                  _intro(),
                  const SizedBox(height: 18),
                  if (_question < 4) _choiceGrid() else _finished(),
                  const SizedBox(height: 24),
                  _profileNote(),
                ],
              ),
            ),
    );
  }

  Widget _progress() {
    final value = (_question / 4).clamp(0.0, 1.0);
    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LinearProgressIndicator(
              minHeight: 5,
              value: value == 0 ? .08 : value,
              backgroundColor: AppColors.border,
              valueColor: const AlwaysStoppedAnimation(AppColors.primary),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          '${(_question == 0 ? 1 : _question).clamp(1, 4)} / 4',
          style: const TextStyle(fontSize: 10, color: AppColors.textMuted, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }

  Widget _intro() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Which look feels more like YOU?',
          style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800, height: 1.08, letterSpacing: -.5),
        ),
        const SizedBox(height: 7),
        Text(
          _question == 0
              ? 'There is no wrong answer. Choose what you would actually reach for.'
              : 'Keep going — your choices help TiB understand your style instinct.',
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5, height: 1.45),
        ),
      ],
    );
  }

  Widget _choiceGrid() {
    final pair = [
      _looks[(_question * 2) % _looks.length],
      _looks[(_question * 2 + 1) % _looks.length],
    ];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: pair.map((look) {
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: look == pair.first ? 8 : 0),
            child: _lookCard(look),
          ),
        );
      }).toList(),
    );
  }

  Widget _lookCard(({String title, String subtitle, String style, IconData icon}) look) {
    final fallback = WardrobeItem(
      id: '',
      userId: '',
      imageUrl: '',
      name: '',
      category: '',
      colour: '',
      style: '',
      season: '',
      isFavourite: false,
      notes: '',
      createdAt: null,
    );
    final image = _wardrobe.firstWhere(
      (item) => item.imageUrl.isNotEmpty && item.style.toLowerCase().contains(look.style.toLowerCase().split(' ').first),
      orElse: () => _wardrobe.isNotEmpty ? _wardrobe[_question % _wardrobe.length] : fallback,
    );

    return InkWell(
      onTap: () => _choose(look.style),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: .82,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: image.imageUrl.isNotEmpty
                    ? CachedNetworkImage(imageUrl: image.imageUrl, fit: BoxFit.cover)
                    : Container(
                        decoration: BoxDecoration(gradient: AppGradients.blush),
                        child: Icon(look.icon, size: 40, color: AppColors.primary),
                      ),
              ),
            ),
            const SizedBox(height: 9),
            Text(look.title, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(look.subtitle, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 9.5, color: AppColors.textSecondary, height: 1.35)),
            const SizedBox(height: 7),
            const Center(child: Icon(Icons.favorite_border_rounded, size: 19, color: AppColors.primary)),
            const SizedBox(height: 2),
          ],
        ),
      ),
    );
  }

  Widget _finished() {
    final primary = _savedStyles.isEmpty ? 'Your style' : _savedStyles.first;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(gradient: AppGradients.ai, borderRadius: BorderRadius.circular(25)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 28),
          const SizedBox(height: 12),
          const Text('Your style is taking shape.', style: TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text('TiB is leaning towards $primary and will use your choices when suggesting outfits.', style: const TextStyle(color: Colors.white70, fontSize: 12.5, height: 1.45)),
          const SizedBox(height: 15),
          Wrap(spacing: 7, runSpacing: 7, children: _savedStyles.take(5).map((style) => Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7), decoration: BoxDecoration(color: Colors.white.withValues(alpha: .72), borderRadius: BorderRadius.circular(20)), child: Text(style, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700)))).toList()),
          const SizedBox(height: 17),
          SizedBox(width: double.infinity, child: FilledButton(onPressed: () => Navigator.pop(context, true), style: FilledButton.styleFrom(backgroundColor: AppColors.eggYolk, foregroundColor: AppColors.primaryDark, minimumSize: const Size.fromHeight(48)), child: const Text('Done'))),
        ],
      ),
    );
  }

  Widget _profileNote() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: AppColors.secondary.withValues(alpha: .55), borderRadius: BorderRadius.circular(18)),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.favorite_border_rounded, color: AppColors.primary, size: 19),
          SizedBox(width: 9),
          Expanded(child: Text('Your style can change. Come back whenever your wardrobe or mood changes — TiB will adapt with you.', style: TextStyle(color: AppColors.textSecondary, fontSize: 11.5, height: 1.4))),
        ],
      ),
    );
  }
}
