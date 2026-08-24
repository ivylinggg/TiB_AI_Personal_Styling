import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../models/colour_analysis_result.dart';
import '../../models/wardrobe_item.dart';
import '../../services/ai_styling_service.dart';
import '../../services/firestore_service.dart';
import '../../services/style_preference_service.dart';

class AiStyleMeScreen extends StatefulWidget {
  const AiStyleMeScreen({super.key});

  @override
  State<AiStyleMeScreen> createState() => _AiStyleMeScreenState();
}

class _AiStyleMeScreenState extends State<AiStyleMeScreen> {
  static const occasions = ['Dinner', 'Work', 'Casual', 'Date', 'Travel', 'Event'];

  bool _loading = true;
  bool _busy = false;
  String _occasion = 'Dinner';
  List<WardrobeItem> _wardrobe = const [];
  List<String> _styles = const [];
  List<String> _preferences = const [];
  ColourAnalysisResult? _analysis;
  AiStylingResult? _result;
  List<WardrobeItem> _look = const [];

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
      final results = await Future.wait<dynamic>([
        FirestoreService.getWardrobeItems(uid),
        StylePreferenceService.getStylePreferences(uid),
        FirestoreService.getLatestColourAnalysis(uid),
      ]);

      final prefs = results[1] as Map<String, dynamic>?;
      if (!mounted) return;

      setState(() {
        _wardrobe = results[0] as List<WardrobeItem>;
        _styles = List<String>.from(prefs?['styles'] ?? const []);
        _preferences = List<String>.from(prefs?['preferences'] ?? const []);
        _analysis = results[2] as ColourAnalysisResult?;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _styleMe() async {
    if (_busy) return;
    if (_wardrobe.isEmpty) {
      _show('Add wardrobe pieces before asking TiB to style you.');
      return;
    }
    if (_analysis == null) {
      _show('Complete Colour Analysis first so TiB can personalise the look.');
      return;
    }

    setState(() {
      _busy = true;
      _result = null;
      _look = const [];
    });

    final result = await AiStylingService.getRecommendation(
      profile: _analysis!,
      wardrobe: _wardrobe,
      styles: _styles,
      preferences: _preferences,
      occasion: _occasion,
    );

    if (!mounted) return;
    if (result == null) {
      setState(() => _busy = false);
      _show('TiB could not reach the AI stylist right now. Try again in a moment.');
      return;
    }

    final ids = [result.topId, result.bottomId, result.shoesId, result.accessoryId].whereType<String>();
    final picked = ids.map(_find).whereType<WardrobeItem>().toList();

    setState(() {
      _result = result;
      _look = picked;
      _busy = false;
    });
  }

  WardrobeItem? _find(String id) {
    for (final item in _wardrobe) {
      if (item.id == id) return item;
    }
    return null;
  }

  void _show(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _save() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || _look.isEmpty) return;
    try {
      await FirestoreService.saveOutfitLook(
        uid: uid,
        occasion: _occasion,
        itemIds: _look.map((e) => e.id).toList(),
        matchScore: 92,
        season: _analysis?.season ?? 'Unknown',
      );
      _show('Look saved to Saved Looks.');
    } catch (_) {
      _show('Could not save this look right now.');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Let TiB Style Me')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 34),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(26), border: Border.all(color: AppColors.border)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Your AI Personal Stylist', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                const SizedBox(height: 7),
                const Text('TiB styles only from pieces you already own, using your colour profile and saved preferences.', style: TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.45)),
                const SizedBox(height: 18),
                const Text('WHAT ARE YOU DRESSING FOR?', style: TextStyle(fontSize: 9, letterSpacing: 1.2, fontWeight: FontWeight.w900, color: AppColors.textMuted)),
                const SizedBox(height: 9),
                Wrap(spacing: 7, runSpacing: 7, children: occasions.map((value) => ChoiceChip(label: Text(value), selected: _occasion == value, onSelected: (_) => setState(() => _occasion = value))).toList()),
                const SizedBox(height: 16),
                SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: _busy ? null : _styleMe, icon: _busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.auto_awesome_rounded), label: Text(_busy ? 'Styling you…' : 'Create My Look')),
              ],
            ),
          ),
          if (_result != null) ...[
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(26), border: Border.all(color: AppColors.border)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [const Expanded(child: Text('YOUR AI LOOK', style: TextStyle(fontSize: 11, letterSpacing: 1.2, fontWeight: FontWeight.w900))), Text('PERSONALISED', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: AppColors.primary))]),
                  const SizedBox(height: 13),
                  if (_look.isEmpty)
                    const Text('TiB returned an explanation but no complete wardrobe match was available.')
                  else
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _look.length,
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: .9),
                      itemBuilder: (_, index) {
                        final item = _look[index];
                        return Container(
                          decoration: BoxDecoration(borderRadius: BorderRadius.circular(17), border: Border.all(color: AppColors.border)),
                          clipBehavior: Clip.antiAlias,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: item.imageUrl.isEmpty ? const Center(child: Icon(Icons.checkroom_outlined, color: AppColors.primary)) : CachedNetworkImage(imageUrl: item.imageUrl, fit: BoxFit.cover, width: double.infinity)),
                              Padding(padding: const EdgeInsets.all(9), child: Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700))),
                            ],
                          ),
                        );
                      },
                    ),
                  if (_result!.explanation.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Text('WHY THIS LOOK WORKS', style: TextStyle(fontSize: 9, letterSpacing: 1.1, fontWeight: FontWeight.w900, color: AppColors.textMuted)),
                    const SizedBox(height: 7),
                    Text(_result!.explanation, style: const TextStyle(fontSize: 12, height: 1.5)),
                  ],
                  const SizedBox(height: 16),
                  Row(children: [Expanded(child: OutlinedButton.icon(onPressed: _busy ? null : _styleMe, icon: const Icon(Icons.refresh_rounded), label: const Text('Try Another Look'))), const SizedBox(width: 9), Expanded(child: FilledButton.icon(onPressed: _look.isEmpty ? null : _save, icon: const Icon(Icons.bookmark_add_outlined), label: const Text('Save Look')))]),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
