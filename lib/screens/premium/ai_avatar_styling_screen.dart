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

/// AI-first TiB Avatar experience.
///
/// The scanned face is used as the identity reference. TiB first finds a
/// complete wardrobe match (including shoes), then sends that selected look
/// with the TiB Model profile to the existing Virtual Try-On service. The
/// result is a realistic virtual-person image rather than the old GLB avatar.
class AiAvatarStylingScreen extends StatefulWidget {
  const AiAvatarStylingScreen({super.key});

  @override
  State<AiAvatarStylingScreen> createState() => _AiAvatarStylingScreenState();
}

class _AiAvatarStylingScreenState extends State<AiAvatarStylingScreen> {
  static const _occasions = ['Dinner', 'Work', 'Casual', 'Date', 'Travel', 'Event'];

  bool _loading = true;
  bool _busy = false;
  TibModelProfile? _model;
  ColourAnalysisResult? _analysis;
  List<WardrobeItem> _wardrobe = const [];
  List<String> _styles = const [];
  List<String> _preferences = const [];
  List<WardrobeItem> _look = const [];
  AiStylingResult? _recommendation;
  String _occasion = 'Dinner';
  String _status = '';
  String? _imageUrl;

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
        TibModelService.load(),
        FirestoreService.getWardrobeItems(uid),
        StylePreferenceService.getStylePreferences(uid),
        FirestoreService.getLatestColourAnalysis(uid),
      ]);

      if (!mounted) return;
      final prefs = results[2] as Map<String, dynamic>?;
      setState(() {
        _model = results[0] as TibModelProfile;
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
        _status = 'Could not load your styling profile. Please try again.';
      });
    }
  }

  Future<void> _createAvatarLook() async {
    if (_busy) return;

    final model = _model;
    final analysis = _analysis;

    if (model == null || !model.isComplete || model.faceFile == null) {
      setState(() => _status = 'Complete your face scan and TiB Model first.');
      return;
    }
    if (_wardrobe.isEmpty) {
      setState(() => _status = 'Add some clothes and shoes to your wardrobe first.');
      return;
    }
    if (analysis == null) {
      setState(() => _status = 'Complete Colour Analysis first so TiB can choose your best colours.');
      return;
    }

    setState(() {
      _busy = true;
      _imageUrl = null;
      _recommendation = null;
      _look = const [];
      _status = 'TiB is finding the best outfit for you…';
    });

    try {
      final recommendation = await AiStylingService.getRecommendation(
        profile: analysis,
        wardrobe: _wardrobe,
        styles: _styles,
        preferences: _preferences,
        occasion: _occasion,
      );

      if (!mounted) return;
      if (recommendation == null) {
        setState(() {
          _busy = false;
          _status = 'TiB could not find a complete match. Try adding more wardrobe pieces.';
        });
        return;
      }

      final ids = [
        recommendation.topId,
        recommendation.bottomId,
        recommendation.shoesId,
        recommendation.accessoryId,
      ].whereType<String>();
      final selected = ids.map(_find).whereType<WardrobeItem>().toList();

      if (selected.isEmpty) {
        setState(() {
          _busy = false;
          _recommendation = recommendation;
          _status = 'TiB found styling guidance, but no complete wardrobe match was returned.';
        });
        return;
      }

      setState(() {
        _recommendation = recommendation;
        _look = selected;
        _status = 'Your virtual TiB person is trying on the recommended look…';
      });

      final tryOn = await VirtualTryOnResultService.generate(
        VirtualTryOnRequest(
          model: model,
          items: selected,
          occasion: _occasion,
          stylingBrief: _buildStylingBrief(recommendation),
        ),
      );

      if (!mounted) return;
      setState(() {
        _imageUrl = tryOn.imageUrl;
        _status = tryOn.status;
        _busy = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _status = 'Could not create your virtual look right now. Please try again.';
      });
    }
  }

  String _buildStylingBrief(AiStylingResult recommendation) {
    final explanation = recommendation.explanation.trim();
    return '''Create a realistic full-body virtual fashion model based on the user's scanned face and TiB Model profile.

Identity and fit:
- Preserve the user's recognizable facial identity from the reference image.
- Preserve natural proportions and use the supplied TiB body shape and measurements as fit context.
- Do not beautify, reshape, slim, enlarge, age, or otherwise alter the person's body or face.

Wardrobe:
- Use ONLY the selected wardrobe pieces as the clothing source.
- Include the selected shoes when a shoes item is supplied.
- Keep garment colour, silhouette, material, pattern and major details faithful to the wardrobe references.
- Do not invent replacement garments.

Presentation:
- Show one complete, polished, full-body fashion look for $_occasion.
- Make the person look like a clean, friendly virtual styling model rather than a generic mannequin.
- Keep the face naturally integrated with the body and clothing.
- Use a simple editorial background and clear lighting so the outfit is easy to evaluate.

Why TiB selected this look:
${explanation.isEmpty ? 'Choose the combination that best fits the user's colour, body-shape and style context.' : explanation}''';
  }

  WardrobeItem? _find(String id) {
    for (final item in _wardrobe) {
      if (item.id == id) return item;
    }
    return null;
  }

  Future<void> _saveLook() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || _look.isEmpty) return;
    try {
      await FirestoreService.saveOutfitLook(
        uid: uid,
        occasion: _occasion,
        itemIds: _look.map((item) => item.id).toList(),
        matchScore: 92,
        season: _analysis?.season ?? 'Unknown',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Your TiB look was saved.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save this look right now.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final model = _model;
    final ready = model?.isComplete == true;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('TiB AI Avatar'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 34),
        children: [
          _buildHero(model, ready),
          const SizedBox(height: 16),
          _buildOccasion(),
          const SizedBox(height: 14),
          _buildHowItWorks(),
          const SizedBox(height: 16),
          if (_look.isNotEmpty) ...[
            _buildRecommendedLook(),
            const SizedBox(height: 14),
          ],
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _busy ? null : _createAvatarLook,
              icon: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.auto_awesome_rounded),
              label: Text(_busy ? 'Creating Your Virtual Look…' : 'Find My Best Look'),
            ),
          ),
          if (_status.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              _status,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11.5,
                height: 1.45,
              ),
            ),
          ],
          if (_imageUrl != null) ...[
            const SizedBox(height: 18),
            _buildResult(),
          ],
        ],
      ),
    );
  }

  Widget _buildHero(TibModelProfile? model, bool ready) {
    final face = model?.faceFile;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppGradients.premium,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Column(
        children: [
          Container(
            width: 112,
            height: 132,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .58),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: Colors.white.withValues(alpha: .7)),
            ),
            clipBehavior: Clip.antiAlias,
            child: face != null && face.existsSync()
                ? Image.file(face, fit: BoxFit.cover)
                : const Icon(Icons.face_retouching_natural_rounded, size: 52, color: AppColors.primary),
          ),
          const SizedBox(height: 15),
          Text(
            ready ? 'Meet your AI styling model' : 'Create your TiB Model first',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, height: 1.08),
          ),
          const SizedBox(height: 8),
          const Text(
            'Scan your face once. TiB uses your identity, body profile, colour direction and wardrobe to create a virtual person wearing the look that suits you best.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 11.5, height: 1.45),
          ),
          const SizedBox(height: 14),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 7,
            runSpacing: 7,
            children: [
              _chip(Icons.face_rounded, 'Face scan'),
              _chip(Icons.accessibility_new_rounded, model?.bodyShape ?? 'Body shape'),
              _chip(Icons.palette_outlined, _analysis?.season ?? 'Colour profile'),
              _chip(Icons.checkroom_rounded, 'Your wardrobe'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .65),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppColors.primaryDark),
          const SizedBox(width: 5),
          Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }

  Widget _buildOccasion() {
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
                onSelected: _busy ? null : (_) => setState(() {
                  _occasion = value;
                  _imageUrl = null;
                  _look = const [];
                  _recommendation = null;
                  _status = '';
                }),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildHowItWorks() {
    const steps = [
      ('01', 'Scan & understand you', 'Your face scan and TiB measurements become the identity and fit context.'),
      ('02', 'Find your best outfit', 'TiB considers your colour profile, body shape, style preferences and wardrobe.'),
      ('03', 'Create your virtual person', 'The selected clothes and shoes are rendered onto a realistic full-body version of you.'),
    ];

    return Column(
      children: steps.map((step) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 9),
          child: Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(color: AppColors.primarySoft, shape: BoxShape.circle),
                  child: Text(step.$1, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: AppColors.primaryDark)),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(step.$2, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      Text(step.$3, style: const TextStyle(color: AppColors.textSecondary, fontSize: 10.5, height: 1.4)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildRecommendedLook() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppGradients.soft,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.primarySoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.auto_awesome_rounded, size: 18, color: AppColors.primaryDark),
              SizedBox(width: 7),
              Expanded(child: Text('TiB selected this look for you', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900))),
            ],
          ),
          const SizedBox(height: 11),
          SizedBox(
            height: 118,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _look.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final item = _look[index];
                return SizedBox(
                  width: 96,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: item.imageUrl.isEmpty
                              ? const ColoredBox(color: AppColors.surfaceMuted, child: Center(child: Icon(Icons.checkroom_outlined, color: AppColors.primary)))
                              : CachedNetworkImage(imageUrl: item.imageUrl, width: 96, fit: BoxFit.cover),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700)),
                    ],
                  ),
                );
              },
            ),
          ),
          if (_recommendation?.explanation.trim().isNotEmpty == true) ...[
            const SizedBox(height: 11),
            Text(
              _recommendation!.explanation,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 10.5, height: 1.4),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildResult() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: .76,
            child: CachedNetworkImage(
              imageUrl: _imageUrl!,
              fit: BoxFit.cover,
              placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
              errorWidget: (context, url, error) => const Center(child: Icon(Icons.broken_image_outlined, size: 42, color: AppColors.textMuted)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('YOUR VIRTUAL LOOK', style: TextStyle(fontSize: 10, letterSpacing: 1.2, fontWeight: FontWeight.w900, color: AppColors.textMuted)),
                const SizedBox(height: 5),
                const Text('This is your TiB styling model in the recommended outfit.', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                const SizedBox(height: 13),
                Row(
                  children: [
                    Expanded(child: OutlinedButton.icon(onPressed: _busy ? null : _createAvatarLook, icon: const Icon(Icons.refresh_rounded), label: const Text('Try Another'))),
                    const SizedBox(width: 9),
                    Expanded(child: FilledButton.icon(onPressed: _look.isEmpty ? null : _saveLook, icon: const Icon(Icons.bookmark_add_outlined), label: const Text('Save Look'))),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
