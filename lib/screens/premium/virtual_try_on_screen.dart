import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_gradients.dart';
import '../../models/colour_analysis_result.dart';
import '../../models/wardrobe_item.dart';
import '../../services/ai_styling_service.dart';
import '../../services/firestore_service.dart';
import '../../services/style_preference_service.dart';
import '../../services/tib_model_service.dart';
import '../../services/virtual_try_on_result_service.dart';

class VirtualTryOnScreen extends StatefulWidget {
  const VirtualTryOnScreen({super.key});

  @override
  State<VirtualTryOnScreen> createState() => _VirtualTryOnScreenState();
}

enum _TryOnMode { choose, ai }

class _VirtualTryOnScreenState extends State<VirtualTryOnScreen> {
  bool _loading = true;
  bool _busy = false;
  bool _saving = false;

  TibModelProfile? _tibModel;
  List<WardrobeItem> _wardrobe = const [];
  Set<String> _selectedIds = {};
  ColourAnalysisResult? _analysis;
  List<String> _styles = const [];
  List<String> _preferences = const [];
  String _occasion = 'Dinner';
  String _status = '';
  String? _generatedImageUrl;
  String? _requestId;
  _TryOnMode _mode = _TryOnMode.choose;

  static const _occasions = [
    'Dinner',
    'Work',
    'Casual',
    'Date',
    'Travel',
    'Event',
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (mounted) {
        setState(() {
          _loading = false;
          _status = 'Please sign in again before using Virtual Try-On.';
        });
      }
      return;
    }

    try {
      final results = await Future.wait<dynamic>([
        TibModelService.load(),
        FirestoreService.getWardrobeItems(uid),
        StylePreferenceService.getStylePreferences(uid),
        FirestoreService.getLatestColourAnalysis(uid),
      ]);

      if (!mounted) return;
      final prefs = results[2] as Map<String, dynamic>?;
      setState(() {
        _tibModel = results[0] as TibModelProfile;
        _wardrobe = results[1] as List<WardrobeItem>;
        _styles = List<String>.from(prefs?['styles'] ?? const []);
        _preferences = List<String>.from(prefs?['preferences'] ?? const []);
        _analysis = results[3] as ColourAnalysisResult?;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _status = 'Could not load your TiB Model and wardrobe. Please try again.';
      });
    }
  }

  void _toggleItem(WardrobeItem item) {
    if (_busy || _saving) return;
    final next = {..._selectedIds};
    if (next.contains(item.id)) {
      next.remove(item.id);
    } else {
      if (next.length >= 6) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Choose up to 6 pieces for one virtual look.')),
        );
        return;
      }
      next.add(item.id);
    }
    setState(() {
      _selectedIds = next;
      _generatedImageUrl = null;
      _requestId = null;
      _status = next.isEmpty ? '' : '${next.length} wardrobe pieces selected.';
    });
  }

  Future<void> _letTiBStyleMe() async {
    if (_busy) return;
    if (_wardrobe.isEmpty) {
      setState(() => _status = 'Add some wardrobe pieces first.');
      return;
    }
    final profile = _analysis;
    if (profile == null) {
      setState(() => _status = 'Complete Colour Analysis first so TiB can style you accurately.');
      return;
    }

    setState(() {
      _busy = true;
      _mode = _TryOnMode.ai;
      _selectedIds = {};
      _generatedImageUrl = null;
      _requestId = null;
      _status = 'TiB is finding the best outfit from your wardrobe…';
    });

    try {
      final result = await AiStylingService.getRecommendation(
        profile: profile,
        wardrobe: _wardrobe,
        styles: _styles,
        preferences: _preferences,
        occasion: _occasion,
      );

      if (!mounted) return;
      if (result == null) {
        setState(() {
          _busy = false;
          _status = 'TiB could not find a complete outfit from your current wardrobe. Choose pieces manually or add more wardrobe items.';
        });
        return;
      }

      final ids = <String?>[
        result.topId,
        result.bottomId,
        result.shoesId,
        result.accessoryId,
      ];
      final picks = ids.whereType<String>().map(_find).whereType<WardrobeItem>().toList();

      setState(() {
        _selectedIds = picks.map((item) => item.id).toSet();
        _status = picks.isEmpty
            ? 'TiB returned a styling recommendation without matching wardrobe images.'
            : 'TiB selected ${picks.length} pieces from your real wardrobe. Generating your Virtual You…';
      });

      if (picks.isEmpty) {
        setState(() => _busy = false);
        return;
      }

      await _generateTryOn(itemsOverride: picks, autoSave: true);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _status = 'TiB could not build the look right now. You can choose your wardrobe manually.';
      });
    }
  }

  Future<void> _generateTryOn({
    List<WardrobeItem>? itemsOverride,
    bool autoSave = false,
  }) async {
    if (_busy && itemsOverride == null) return;

    final model = _tibModel;
    final selected = itemsOverride ?? _selectedItems;

    if (model == null || !model.isComplete) {
      setState(() => _status = 'Complete your TiB Model first: face scan + body measurements are required.');
      return;
    }
    if (model.faceFile == null || !model.faceFile!.existsSync()) {
      setState(() => _status = 'Your TiB face scan is missing. Please recreate your TiB Model.');
      return;
    }
    if (selected.isEmpty) {
      setState(() => _status = 'Select at least one wardrobe piece first.');
      return;
    }

    if (!_busy) {
      setState(() {
        _busy = true;
        _generatedImageUrl = null;
        _requestId = null;
        _status = 'Creating your Virtual You…\nTiB is matching your face, body and selected wardrobe.';
      });
    } else {
      setState(() {
        _generatedImageUrl = null;
        _requestId = null;
        _status = 'Creating your Virtual You…\nTiB is matching your face, body and selected wardrobe.';
      });
    }

    try {
      final result = await VirtualTryOnResultService.generate(
        VirtualTryOnRequest(
          model: model,
          items: selected,
          occasion: _occasion,
          stylingBrief: _buildStylingBrief(),
        ),
      );

      if (!mounted) return;
      setState(() {
        _busy = false;
        _generatedImageUrl = result.imageUrl;
        _requestId = result.requestId;
        _status = result.isGenerated
            ? 'Your Virtual You is ready — wearing your selected wardrobe.'
            : result.status;
      });

      if (result.isGenerated || autoSave) {
        await _saveGeneratedLook(selected);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _status = 'Virtual Try-On failed. Please try again.';
      });
    }
  }

  String _buildStylingBrief() {
    final model = _tibModel!;
    final profile = _analysis;
    final selected = _selectedItems;
    final items = selected.map((item) {
      return '${item.name} | category=${item.category} | colour=${item.colour} | style=${item.style}';
    }).join('\n');

    return '''Create the user's Virtual You for a $_occasion look.

IDENTITY:
Use the supplied TiB face reference as the user's identity. Preserve recognizable facial features, natural skin tone, hair and overall appearance.

BODY:
Use the supplied TiB body reference when available. Preserve the user's natural silhouette and proportions. Do not create a generic fashion model and do not idealize, slim, lengthen or reshape the body.

TIB BODY PROFILE:
Body shape: ${model.bodyShape}
Face shape: ${model.faceShape}
Height: ${model.height} cm
Weight: ${model.weight} kg
Bust: ${model.bust} cm
Waist: ${model.waist} cm
Hips: ${model.hips} cm

COLOUR PROFILE:
Season: ${profile?.season ?? 'unknown'}
Recommended colours: ${profile?.colours.join(', ') ?? 'unknown'}

SELECTED REAL WARDROBE:
$items

WARDROBE RULE:
Use the selected wardrobe reference images as the exact clothing sources. Preserve their real colours, silhouettes, textures, patterns and important details. Do not replace them with invented garments.

RESULT:
Generate one realistic full-body fashion image of the same user wearing the selected wardrobe. Keep the person clearly recognizable as the user's Virtual You. Show the complete outfit, including shoes when selected, with natural proportions, realistic garment fit, folds and lighting.''';
  }

  Future<void> _saveGeneratedLook(List<WardrobeItem> items) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || items.isEmpty) return;
    try {
      await FirestoreService.saveOutfitLook(
        uid: uid,
        occasion: _occasion,
        itemIds: items.map((item) => item.id).toList(),
        matchScore: _matchScore(items),
        season: _analysis?.season ?? 'Unknown',
      );
    } catch (_) {}
  }

  WardrobeItem? _find(String id) {
    for (final item in _wardrobe) {
      if (item.id == id) return item;
    }
    return null;
  }

  List<WardrobeItem> get _selectedItems => _selectedIds.map(_find).whereType<WardrobeItem>().toList();

  int _matchScore(List<WardrobeItem> items) {
    if (items.isEmpty) return 0;
    final profile = _analysis;
    if (profile == null) return 70;
    var score = 70;
    for (final item in items) {
      if (profile.colours.any((c) => _sameColourFamily(c, item.colour))) score += 4;
      if (item.season == profile.season || item.season == 'All seasons') score += 3;
      if (_styles.any((s) => item.style.toLowerCase().contains(s.toLowerCase()))) score += 2;
    }
    return score.clamp(0, 100);
  }

  bool _sameColourFamily(String preferred, String wardrobeColour) {
    final a = preferred.toLowerCase();
    final b = wardrobeColour.toLowerCase();
    if (a == b || a.contains(b) || b.contains(a)) return true;
    const families = <String, List<String>>{
      'pink': ['pink', 'rose', 'coral', 'peach'],
      'brown': ['brown', 'camel', 'tan', 'chocolate'],
      'beige': ['beige', 'cream', 'ivory', 'taupe'],
      'green': ['green', 'olive', 'sage', 'mint', 'emerald'],
      'blue': ['blue', 'navy', 'cobalt', 'sapphire'],
      'purple': ['purple', 'lavender', 'lilac', 'mauve', 'plum'],
      'red': ['red', 'ruby', 'burgundy', 'wine'],
      'yellow': ['yellow', 'gold', 'mustard'],
    };
    for (final family in families.values) {
      if (family.any(a.contains) && family.any(b.contains)) return true;
    }
    return false;
  }

  Future<void> _saveManualLook() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final items = _selectedItems;
    if (uid == null || items.isEmpty || _saving) return;
    setState(() => _saving = true);
    try {
      await FirestoreService.saveOutfitLook(
        uid: uid,
        occasion: _occasion,
        itemIds: items.map((item) => item.id).toList(),
        matchScore: _matchScore(items),
        season: _analysis?.season ?? 'Unknown',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Look saved to Saved Looks.')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not save this look right now.')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final selected = _selectedItems;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('AI Virtual Try-On')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 34),
        children: [
          if (_generatedImageUrl != null) ...[_buildGeneratedResult(), const SizedBox(height: 16)],
          _buildModelCard(_tibModel),
          const SizedBox(height: 16),
          _buildModeSwitch(),
          const SizedBox(height: 16),
          _buildOccasions(),
          const SizedBox(height: 16),
          _mode == _TryOnMode.ai ? _buildAiPanel() : _buildWardrobePicker(),
          if (selected.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildSelectedLook(selected),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _busy ? null : _generateTryOn,
                icon: _busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.auto_awesome_rounded),
                label: Text(_busy ? 'Creating Your Virtual You…' : 'Generate My Try-On'),
              ),
            ),
            const SizedBox(height: 8),
            if (_mode == _TryOnMode.choose)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _saving ? null : _saveManualLook,
                  icon: const Icon(Icons.bookmark_add_outlined),
                  label: const Text('Save Look Without Generating'),
                ),
              ),
          ],
          if (_status.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _generatedImageUrl != null ? AppColors.primarySoft : AppColors.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.border),
              ),
              child: Text(_status, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary, height: 1.45, fontSize: 11.5)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGeneratedResult() => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(gradient: AppGradients.soft, borderRadius: BorderRadius.circular(26), border: Border.all(color: AppColors.primarySoft)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(6, 4, 6, 10),
              child: Row(children: [Icon(Icons.person_rounded, size: 18, color: AppColors.primaryDark), SizedBox(width: 7), Text('Your Virtual You', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900))]),
            ),
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: CachedNetworkImage(
                imageUrl: _generatedImageUrl!,
                width: double.infinity,
                fit: BoxFit.cover,
                placeholder: (_, __) => const AspectRatio(aspectRatio: .75, child: Center(child: CircularProgressIndicator())),
                errorWidget: (_, __, ___) => const Padding(padding: EdgeInsets.all(24), child: Text('The generated image could not be displayed.')),
              ),
            ),
            if (_requestId != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text('Generation ID: $_requestId', style: const TextStyle(color: AppColors.textMuted, fontSize: 9))),
          ],
        ),
      );

  Widget _buildModelCard(TibModelProfile? model) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(22), border: Border.all(color: AppColors.border)),
        child: Row(
          children: [
            Container(
              width: 58,
              height: 70,
              decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(17)),
              clipBehavior: Clip.antiAlias,
              child: model?.faceFile != null && model!.faceFile!.existsSync() ? Image.file(model.faceFile!, fit: BoxFit.cover) : const Icon(Icons.face_retouching_natural_rounded, color: AppColors.primaryDark, size: 28),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('YOUR AI VIRTUAL YOU', style: TextStyle(fontSize: 9, letterSpacing: 1.2, fontWeight: FontWeight.w900, color: AppColors.textMuted)),
                  const SizedBox(height: 5),
                  Text(model?.bodyShape ?? 'TiB Model', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 4),
                  Text('Face + body profile + proportions + wardrobe', style: const TextStyle(color: AppColors.textSecondary, fontSize: 10.5, height: 1.35)),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _buildModeSwitch() => Container(
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(color: AppColors.surfaceMuted, borderRadius: BorderRadius.circular(16)),
        child: Row(
          children: [
            Expanded(child: _modeButton(_TryOnMode.choose, 'Choose My Outfit', Icons.checkroom_rounded)),
            Expanded(child: _modeButton(_TryOnMode.ai, 'Let TiB Style Me', Icons.auto_awesome_rounded)),
          ],
        ),
      );

  Widget _modeButton(_TryOnMode mode, String label, IconData icon) => GestureDetector(
        onTap: _busy ? null : () => setState(() {
          _mode = mode;
          _generatedImageUrl = null;
          _requestId = null;
          _status = '';
        }),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 8),
          decoration: BoxDecoration(color: _mode == mode ? AppColors.surface : Colors.transparent, borderRadius: BorderRadius.circular(12)),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon, size: 16, color: AppColors.primaryDark), const SizedBox(width: 6), Flexible(child: Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800)))]),
        ),
      );

  Widget _buildOccasions() => Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.border)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('WHAT ARE YOU DRESSING FOR?', style: TextStyle(fontSize: 9, letterSpacing: 1.2, fontWeight: FontWeight.w900, color: AppColors.textMuted)),
          const SizedBox(height: 8),
          Wrap(spacing: 7, runSpacing: 7, children: _occasions.map((value) => ChoiceChip(label: Text(value), selected: _occasion == value, onSelected: _busy ? null : (_) => setState(() { _occasion = value; _generatedImageUrl = null; _requestId = null; _status = ''; })).toList()),
        ]),
      );

  Widget _buildAiPanel() => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(gradient: AppGradients.ai, borderRadius: BorderRadius.circular(22), border: Border.all(color: AppColors.border)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [Icon(Icons.auto_awesome_rounded, color: AppColors.primaryDark), SizedBox(width: 8), Text('Let TiB Style Me', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900))]),
          const SizedBox(height: 7),
          const Text('TiB will choose the most suitable clothes and shoes from your wardrobe using your Colour Analysis, body shape and personal style, then create your Virtual You.', style: TextStyle(color: AppColors.textSecondary, fontSize: 11, height: 1.45)),
          const SizedBox(height: 13),
          SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: _busy ? null : _letTiBStyleMe, icon: const Icon(Icons.auto_awesome), label: const Text('Find My Best Look'))),
        ]),
      );

  Widget _buildWardrobePicker() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('YOUR WARDROBE', style: TextStyle(fontSize: 10, letterSpacing: 1.3, fontWeight: FontWeight.w900, color: AppColors.textMuted)),
        const SizedBox(height: 9),
        if (_wardrobe.isEmpty)
          Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.border)), child: const Center(child: Text('Your wardrobe is empty. Add clothes first.')))
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _wardrobe.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: .77),
            itemBuilder: (_, index) {
              final item = _wardrobe[index];
              final selected = _selectedIds.contains(item.id);
              return GestureDetector(
                onTap: () => _toggleItem(item),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: selected ? AppColors.primaryDark : AppColors.border, width: selected ? 2 : 1)),
                  clipBehavior: Clip.antiAlias,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(child: Stack(children: [Positioned.fill(child: CachedNetworkImage(imageUrl: item.imageUrl, fit: BoxFit.cover, errorWidget: (_, __, ___) => const Icon(Icons.image_not_supported_outlined)),), if (selected) Positioned(top: 9, right: 9, child: Container(width: 27, height: 27, decoration: const BoxDecoration(color: AppColors.primaryDark, shape: BoxShape.circle), child: const Icon(Icons.check, color: Colors.white, size: 16))),]),
                    Padding(padding: const EdgeInsets.fromLTRB(11, 8, 11, 11), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800)), const SizedBox(height: 3), Text('${item.category} • ${item.colour}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.textSecondary, fontSize: 9.5))]),
                  ]),
                ),
              );
            },
          ),
      ]);

  Widget _buildSelectedLook(List<WardrobeItem> items) => Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.border)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('SELECTED LOOK', style: TextStyle(fontSize: 9, letterSpacing: 1.2, fontWeight: FontWeight.w900, color: AppColors.textMuted)),
          const SizedBox(height: 10),
          SizedBox(height: 92, child: ListView.separated(scrollDirection: Axis.horizontal, itemCount: items.length, separatorBuilder: (_, __) => const SizedBox(width: 9), itemBuilder: (_, index) {
            final item = items[index];
            return SizedBox(width: 72, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(13), child: CachedNetworkImage(imageUrl: item.imageUrl, width: double.infinity, fit: BoxFit.cover, errorWidget: (_, __, ___) => const Icon(Icons.image_not_supported_outlined)))), const SizedBox(height: 4), Text(item.category, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.w800))]);
          })),
        ]),
      );
}
