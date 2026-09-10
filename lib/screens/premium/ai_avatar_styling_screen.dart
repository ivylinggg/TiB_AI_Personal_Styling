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
      if (!mounted || FirebaseAuth.instance.currentUser?.uid != uid) return;
      final prefs = results[2] is Map<String, dynamic> ? results[2] as Map<String, dynamic> : <String, dynamic>{};
      final items = results[1] is List<WardrobeItem> ? List<WardrobeItem>.from(results[1] as List<WardrobeItem>) : <WardrobeItem>[];
      setState(() {
        _model = results[0] as TibModelProfile?;
        _wardrobe = items.where((item) => item.userId.isEmpty || item.userId == uid).toList(growable: false);
        _styles = _stringList(prefs['styles']);
        _preferences = _stringList(prefs['preferences']);
        _analysis = results[3] as ColourAnalysisResult?;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _createAvatarLook() async {
    if (_busy) return;
    final model = _model;
    final analysis = _analysis;
    if (model == null || !model.isComplete || model.faceFile == null || model.bodyFile == null) {
      setState(() => _status = 'Complete your face scan, full-body reference and TiB Model first.');
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
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) throw StateError('Your session has ended.');
      final recommendation = await AiStylingService.getRecommendation(
        uid: uid,
        profile: analysis,
        wardrobe: _wardrobe,
        styles: _styles,
        preferences: _preferences,
        occasion: _occasion,
      );
      if (!mounted || FirebaseAuth.instance.currentUser?.uid != uid) return;
      final ids = <String?>[
        recommendation.topId,
        recommendation.bottomId,
        recommendation.dressId,
        recommendation.suitId,
        recommendation.jacketId,
        recommendation.shoesId,
        recommendation.accessoryId,
      ];
      final selected = ids.whereType<String>().map(_find).whereType<WardrobeItem>().toList(growable: false);
      if (selected.isEmpty) {
        setState(() {
          _busy = false;
          _recommendation = recommendation;
          _status = 'TiB found styling guidance, but no wardrobe match was returned.';
        });
        return;
      }
      setState(() {
        _recommendation = recommendation;
        _look = selected;
        _status = 'Your personal TiB model is trying on the recommended look…';
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
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _status = 'Could not create your virtual look right now: $error';
      });
    }
  }

  String _buildStylingBrief(AiStylingResult recommendation) {
    final model = _model!;
    final reason = recommendation.explanation.trim().isEmpty
        ? 'Choose the combination that best fits the user’s colour, body-shape and style context.'
        : recommendation.explanation.trim();
    return '''TI B PERSONAL VIRTUAL YOU — NON-NEGOTIABLE GENERATION BRIEF

PERSON IDENTITY:
- This is the real user, not a generic fashion model.
- Reference A is the user's FULL-BODY reference photo.
- Reference B is the user's FACE reference photo.
- Preserve the same person from head to toe.

MEASURED PERSONAL BODY DATA:
- Height: ${model.height.toStringAsFixed(1)} cm
- Weight: ${model.weight.toStringAsFixed(1)} kg
- Bust: ${model.bust.toStringAsFixed(1)} cm
- Waist: ${model.waist.toStringAsFixed(1)} cm
- Hips: ${model.hips.toStringAsFixed(1)} cm
- Body shape: ${model.bodyShape}
- Face shape: ${model.faceShape}

BODY FIDELITY:
- Use the full-body reference as the primary source of actual body geometry.
- Preserve shoulder width, torso length, waist placement, hip width, leg length and natural posture.
- Never slim, enlarge, lengthen, shorten, reshape or idealize the body.
- Clothing must adapt to the user's actual proportions.

FACE FIDELITY:
- Preserve the real facial structure, skin tone and hair from the face reference.
- Do not replace or beautify the person's identity.

WARDROBE FIDELITY:
- Use ONLY the selected wardrobe reference images supplied in this request.
- Preserve category, colour, pattern, material, texture and visible construction.
- Do not invent replacement clothes or accessories.

OUTPUT:
- Generate ONE photorealistic head-to-toe fashion photograph of THIS USER wearing the selected outfit.
- Use a natural standing pose, realistic fabric behaviour and clean editorial lighting.

OCCASION: $_occasion

WHY TIB SELECTED THIS LOOK:
$reason

FINAL PRIORITY:
1. Same real person.
2. Same real body proportions.
3. Exact selected wardrobe items.
4. Natural garment fit.
5. Head-to-toe composition.''';
  }

  WardrobeItem? _find(String id) {
    for (final item in _wardrobe) {
      if (item.id == id) return item;
    }
    return null;
  }

  List<String> _stringList(dynamic value) => value is List
      ? value.map((item) => item.toString().trim()).where((item) => item.isNotEmpty).toList(growable: false)
      : const [];

  Future<void> _saveLook() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || _look.isEmpty) return;
    try {
      await FirestoreService.saveOutfitLook(
        uid: uid,
        occasion: _occasion,
        itemIds: _look.map((item) => item.id).toList(growable: false),
        matchScore: _recommendation?.matchScore ?? 0,
        season: _analysis?.season ?? 'Unknown',
        title: _recommendation?.displayTitle,
        notes: _recommendation?.stylingNotes.join(' • '),
      );
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Your TiB look was saved.')));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not save this look right now.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final model = _model;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('TiB AI Avatar')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 34),
        children: [
          _buildHero(model, model?.isComplete == true),
          const SizedBox(height: 16),
          _buildOccasion(),
          const SizedBox(height: 14),
          if (_look.isNotEmpty) ...[_buildRecommendedLook(), const SizedBox(height: 14)],
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _busy ? null : _createAvatarLook,
              icon: _busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.auto_awesome_rounded),
              label: Text(_busy ? 'Creating Your Virtual Look…' : 'Find My Best Look'),
            ),
          ),
          if (_status.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(_status, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11.5, height: 1.45)),
          ],
          if (_imageUrl != null) ...[const SizedBox(height: 18), _buildResult()],
        ],
      ),
    );
  }

  Widget _buildHero(TibModelProfile? model, bool ready) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(gradient: AppGradients.premium, borderRadius: BorderRadius.circular(30)),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _referenceCard(model?.faceFile, Icons.face_retouching_natural_rounded),
                const SizedBox(width: 10),
                _referenceCard(model?.bodyFile, Icons.accessibility_new_rounded),
              ],
            ),
            const SizedBox(height: 15),
            Text(ready ? 'Meet your AI styling model' : 'Create your TiB Model first', textAlign: TextAlign.center, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, height: 1.08)),
            const SizedBox(height: 8),
            const Text('Your scanned face + full-body reference + real measurements become one persistent Personal TiB Model. TiB then dresses that same person using your own wardrobe.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary, fontSize: 11.5, height: 1.45)),
            const SizedBox(height: 14),
            Wrap(alignment: WrapAlignment.center, spacing: 7, runSpacing: 7, children: [
              _chip(Icons.face_rounded, 'Face identity'),
              _chip(Icons.accessibility_new_rounded, model?.bodyShape ?? 'Body shape'),
              _chip(Icons.straighten_rounded, model != null && model.height > 0 ? '${model.height.toStringAsFixed(0)} cm' : 'Measurements'),
              _chip(Icons.palette_outlined, _analysis?.season ?? 'Colour profile'),
              _chip(Icons.checkroom_rounded, 'Your wardrobe'),
            ]),
          ],
        ),
      );

  Widget _referenceCard(dynamic file, IconData fallback) => Container(
        width: 92,
        height: 112,
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: .58), borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.white.withValues(alpha: .7))),
        clipBehavior: Clip.antiAlias,
        child: file != null && file.existsSync() ? Image.file(file, fit: BoxFit.cover) : Icon(fallback, size: 44, color: AppColors.primary),
      );

  Widget _chip(IconData icon, String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: .65), borderRadius: BorderRadius.circular(14)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 13, color: AppColors.primaryDark), const SizedBox(width: 5), Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800))]),
      );

  Widget _buildOccasion() => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(22), border: Border.all(color: AppColors.border)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('WHAT ARE YOU DRESSING FOR?', style: TextStyle(fontSize: 9, letterSpacing: 1.2, fontWeight: FontWeight.w900, color: AppColors.textMuted)),
          const SizedBox(height: 9),
          Wrap(spacing: 7, runSpacing: 7, children: _occasions.map((value) => ChoiceChip(label: Text(value), selected: _occasion == value, onSelected: _busy ? null : (_) => setState(() { _occasion = value; _imageUrl = null; _look = const []; _recommendation = null; _status = ''; })).toList(growable: false)),
        ]),
      );

  Widget _buildRecommendedLook() => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(24), border: Border.all(color: AppColors.border)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [const Expanded(child: Text('RECOMMENDED LOOK', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.1))), if (_recommendation != null) Text('${_recommendation!.matchScore}% match', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.primaryDark))]),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: _look.map((item) => Chip(label: Text(item.name), avatar: const Icon(Icons.checkroom_outlined, size: 16))).toList(growable: false)),
          const SizedBox(height: 10),
          if (_recommendation?.stylingNotes.isNotEmpty == true) Text(_recommendation!.stylingNotes.join(' • '), style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary, height: 1.4)),
          const SizedBox(height: 8),
          Align(alignment: Alignment.centerRight, child: OutlinedButton(onPressed: _busy ? null : _saveLook, child: const Text('Save look'))),
        ]),
      );

  Widget _buildResult() => Container(
        height: 420,
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(24), border: Border.all(color: AppColors.border)),
        clipBehavior: Clip.antiAlias,
        child: CachedNetworkImage(imageUrl: _imageUrl!, fit: BoxFit.cover),
      );
}
