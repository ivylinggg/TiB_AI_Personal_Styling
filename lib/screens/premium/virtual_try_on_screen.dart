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
    } catch (error) {
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
      final picks = ids
          .whereType<String>()
          .map(_find)
          .whereType<WardrobeItem>()
          .toList();

      setState(() {
        _selectedIds = picks.map((item) => item.id).toSet();
        _status = picks.isEmpty
            ? 'TiB returned a styling recommendation without matching wardrobe images.'
            : 'TiB selected ${picks.length} pieces from your real wardrobe. Tap Generate My Try-On to see them on you.';
        _busy = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _status = 'TiB could not build the look right now. You can choose your wardrobe manually.';
      });
    }
  }

  Future<void> _generateTryOn() async {
    if (_busy) return;

    final model = _tibModel;
    final selected = _selectedItems;

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

    setState(() {
      _busy = true;
      _generatedImageUrl = null;
      _requestId = null;
      _status = 'Creating your Virtual You…\nTiB is matching your face, body and selected wardrobe.';
    });

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

      if (result.isGenerated) {
        await _saveGeneratedLook(selected);
      }
    } catch (error) {
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
    } catch (_) {
      // Generation succeeded; saving is only a convenience and must not
      // turn a successful Virtual Try-On into an error state.
    }
  }

  List<WardrobeItem> _buildFallback(ColourAnalysisResult profile) {
    int score(WardrobeItem item) {
      var value = item.isFavourite ? 8 : 0;
      final colour = item.colour.toLowerCase();
      final style = item.style.toLowerCase();
      if (_styles.any((s) => style.contains(s.toLowerCase()))) value += 8;
      if (_preferences.any((p) => style.contains(p.toLowerCase()))) value += 4;
      if (profile.colours.any((c) => _sameColourFamily(c, colour))) value += 12;
      if (item.season == profile.season || item.season == 'All seasons') value += 8;
      return value;
    }

    final sorted = [..._wardrobe]..sort((a, b) => score(b).compareTo(score(a)));
    final result = <WardrobeItem>[];

    if (_occasion == 'Date' || _occasion == 'Dinner' || _occasion == 'Event') {
      final dress = sorted.where((item) => item.category == 'Dresses').firstOrNull;
      if (dress != null) result.add(dress);
    }

    if (result.isEmpty) {
      for (final item in sorted) {
        if (item.category == 'Tops' && !result.any((x) => x.category == 'Tops')) result.add(item);
        if (item.category == 'Bottoms' && !result.any((x) => x.category == 'Bottoms')) result.add(item);
      }
    }

    for (final item in sorted) {
      if (item.category == 'Shoes' && !result.contains(item)) {
        result.add(item);
        break;
      }
    }

    for (final item in sorted) {
      if (item.category == 'Accessories' && !result.contains(item)) {
        result.add(item);
        break;
      }
    }

    return result.take(6).toList();
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

  WardrobeItem? _find(String id) {
    for (final item in _wardrobe) {
      if (item.id == id) return item;
    }
    return null;
  }

  List<WardrobeItem> get _selectedItems =>
      _selectedIds.map(_find).whereType<WardrobeItem>().toList();

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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Look saved to Saved Looks.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save this look right now.')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final selected = _selectedItems;
    final model = _tibModel;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('AI Virtual Try-On')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 34),
        children: [
          if (_generatedImageUrl != null) ...[
            _buildGeneratedResult(),
            const SizedBox(height: 16),
          ],
          _buildModelCard(model),
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
                icon: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.auto_awesome_rounded),
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
                color: _generatedImageUrl != null
                    ? AppColors.primarySoft
                    : AppColors.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.border),
              ),
              child: Text(
                _status,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  height: 1.45,
                  fontSize: 11.5,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGeneratedResult() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: AppGradients.soft,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: AppColors.primarySoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(6, 4, 6, 10),
            child: Row(
              children: [
                Icon(Icons.person_rounded, color: AppColors.primaryDark, size: 20),
                SizedBox(width: 7),
                Expanded(
                  child: Text(
                    'YOUR VIRTUAL YOU',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: .5),
                  ),
                ),
                Icon(Icons.auto_awesome_rounded, color: AppColors.primary, size: 18),
              ],
            ),
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: CachedNetworkImage(
              imageUrl: _generatedImageUrl!,
              width: double.infinity,
              fit: BoxFit.cover,
              placeholder: (_, __) => const AspectRatio(
                aspectRatio: .72,
                child: Center(child: CircularProgressIndicator()),
              ),
              errorWidget: (_, __, ___) => const Padding(
                padding: EdgeInsets.all(28),
                child: Center(child: Text('The generated Virtual You could not be displayed.')),
              ),
            ),
          ),
          if (_requestId != null) ...[
            const SizedBox(height: 7),
            Text(
              'Try-On ready • ${_requestId!}',
              style: const TextStyle(color: AppColors.textMuted, fontSize: 9),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildModelCard(TibModelProfile? model) {
    final face = model?.faceFile;
    final body = model?.bodyFile;
    final complete = model?.isComplete == true;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: AppGradients.soft,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: AppColors.primarySoft),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 92,
            height: 116,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: face != null && face.existsSync()
                      ? Image.file(face, fit: BoxFit.cover)
                      : Container(
                          color: AppColors.surface,
                          child: const Icon(Icons.face_retouching_natural_rounded, size: 40, color: AppColors.primary),
                        ),
                ),
                if (body != null && body.existsSync())
                  Positioned(
                    right: 6,
                    bottom: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.accessibility_new_rounded, size: 12, color: AppColors.primaryDark),
                          SizedBox(width: 3),
                          Text('BODY', style: TextStyle(fontSize: 7, fontWeight: FontWeight.w900)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'YOUR AI MODEL',
                  style: TextStyle(fontSize: 9, letterSpacing: 1.2, fontWeight: FontWeight.w900, color: AppColors.textMuted),
                ),
                const SizedBox(height: 7),
                Text(
                  complete ? 'Ready to become Virtual You' : 'Complete your TiB Model first',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 6),
                Text(
                  complete
                      ? '${model!.bodyShape} • ${model.height.toStringAsFixed(0)} cm • Face + body reference ready'
                      : 'Face scan and body measurements are required so the AI can keep your identity and proportions.',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 10.5, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeSwitch() {
    return SegmentedButton<_TryOnMode>(
      segments: const [
        ButtonSegment(
          value: _TryOnMode.choose,
          icon: Icon(Icons.checkroom_rounded),
          label: Text('Choose Clothes'),
        ),
        ButtonSegment(
          value: _TryOnMode.ai,
          icon: Icon(Icons.auto_awesome_rounded),
          label: Text('Let TiB Style Me'),
        ),
      ],
      selected: {_mode},
      onSelectionChanged: _busy
          ? null
          : (selection) {
              setState(() {
                _mode = selection.first;
                _generatedImageUrl = null;
                _requestId = null;
                _status = '';
              });
              if (_mode == _TryOnMode.ai) _letTiBStyleMe();
            },
    );
  }

  Widget _buildOccasions() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'WHAT ARE YOU DRESSING FOR?',
            style: TextStyle(fontSize: 9, letterSpacing: 1.2, fontWeight: FontWeight.w900, color: AppColors.textMuted),
          ),
          const SizedBox(height: 9),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: _occasions.map((value) {
              return ChoiceChip(
                label: Text(value),
                selected: _occasion == value,
                onSelected: _busy
                    ? null
                    : (_) => setState(() {
                        _occasion = value;
                        _generatedImageUrl = null;
                        _requestId = null;
                        _status = '';
                      }),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildAiPanel() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.primarySoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'AI PERSONAL STYLIST',
            style: TextStyle(fontSize: 9, letterSpacing: 1.2, fontWeight: FontWeight.w900, color: AppColors.textMuted),
          ),
          const SizedBox(height: 8),
          const Text(
            'Find the look that suits your Virtual You.',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 7),
          Text(
            _selectedIds.isEmpty
                ? 'TiB will use your colour profile, style preferences, occasion and real wardrobe.'
                : '${_selectedIds.length} pieces selected from your real wardrobe.',
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 10.5, height: 1.4),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _busy ? null : _letTiBStyleMe,
              icon: _busy
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.auto_awesome_rounded),
              label: Text(_busy ? 'Finding Your Look…' : 'Find My Best Look'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWardrobePicker() {
    if (_wardrobe.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.border),
        ),
        child: const Text(
          'Your wardrobe is empty. Add clothes and shoes first, then come back to create your Virtual You look.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textSecondary, height: 1.45),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'MY REAL WARDROBE',
                  style: TextStyle(fontSize: 11, letterSpacing: 1.1, fontWeight: FontWeight.w900),
                ),
              ),
              Text(
                '${_selectedIds.length}/6',
                style: const TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 5),
          const Text(
            'Select the exact clothes and shoes you want your Virtual You to wear.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 10, height: 1.35),
          ),
          const SizedBox(height: 11),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _wardrobe.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: .78,
            ),
            itemBuilder: (context, index) {
              final item = _wardrobe[index];
              final selected = _selectedIds.contains(item.id);
              return GestureDetector(
                onTap: () => _toggleItem(item),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  decoration: BoxDecoration(
                    color: selected ? AppColors.lavenderMist : AppColors.surfaceMuted,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: selected ? AppColors.primary : AppColors.border,
                      width: selected ? 2 : 1,
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: item.imageUrl.isEmpty
                            ? const Center(child: Icon(Icons.checkroom_outlined, size: 36, color: AppColors.primary))
                            : CachedNetworkImage(
                                imageUrl: item.imageUrl,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                errorWidget: (_, __, ___) => const Center(child: Icon(Icons.broken_image_outlined, color: AppColors.textMuted)),
                              ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                item.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
                              ),
                            ),
                            if (selected) const Icon(Icons.check_circle_rounded, size: 18, color: AppColors.primary),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedLook(List<WardrobeItem> selected) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.primarySoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'YOUR SELECTED LOOK',
            style: TextStyle(fontSize: 10, letterSpacing: 1.1, fontWeight: FontWeight.w900, color: AppColors.textMuted),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 105,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: selected.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final item = selected[index];
                return SizedBox(
                  width: 86,
                  child: Column(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: item.imageUrl.isEmpty
                              ? const Center(child: Icon(Icons.checkroom_outlined, color: AppColors.primary))
                              : CachedNetworkImage(imageUrl: item.imageUrl, fit: BoxFit.cover, width: double.infinity),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        item.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
