import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
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

class _VirtualTryOnScreenState extends State<VirtualTryOnScreen> {
  static const _occasions = ['Dinner', 'Work', 'Casual', 'Date', 'Travel', 'Event'];
  bool _loading = true;
  bool _busy = false;
  TibModelProfile? _model;
  ColourAnalysisResult? _analysis;
  List<WardrobeItem> _wardrobe = const [];
  List<String> _styles = const [];
  List<String> _preferences = const [];
  final Set<String> _selectedIds = <String>{};
  String _occasion = 'Dinner';
  String _status = '';
  String? _generatedImageUrl;

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
      if (!mounted || FirebaseAuth.instance.currentUser?.uid != uid) {
        return;
      }
      final prefs = results[2] is Map
          ? Map<String, dynamic>.from(results[2] as Map)
          : <String, dynamic>{};
      final items = results[1] is List<WardrobeItem>
          ? List<WardrobeItem>.from(results[1] as List<WardrobeItem>)
          : <WardrobeItem>[];
      setState(() {
        _model = results[0] as TibModelProfile?;
        _wardrobe = items
            .where((item) => item.userId.isEmpty || item.userId == uid)
            .toList(growable: false);
        _styles = _stringList(prefs['styles']);
        _preferences = _stringList(prefs['preferences']);
        _analysis = results[3] as ColourAnalysisResult?;
        _loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _status = 'Could not load your Personal TiB Model. Please try again.';
        });
      }
    }
  }

  List<WardrobeItem> get _selectedItems => _selectedIds
      .map(_find)
      .whereType<WardrobeItem>()
      .take(6)
      .toList(growable: false);

  WardrobeItem? _find(String id) {
    for (final item in _wardrobe) {
      if (item.id == id) {
        return item;
      }
    }
    return null;
  }

  void _toggle(WardrobeItem item) {
    if (_busy) {
      return;
    }
    setState(() {
      if (_selectedIds.contains(item.id)) {
        _selectedIds.remove(item.id);
      } else if (_selectedIds.length < 6) {
        _selectedIds.add(item.id);
      } else {
        _status = 'Choose up to 6 pieces for one look.';
        return;
      }
      _generatedImageUrl = null;
      _status = _selectedIds.isEmpty
          ? ''
          : '${_selectedIds.length} piece${_selectedIds.length == 1 ? '' : 's'} selected.';
    });
  }

  Future<void> _letTiBStyleMe() async {
    if (_busy) {
      return;
    }
    final analysis = _analysis;
    if (analysis == null) {
      setState(() {
        _status = 'Complete Colour Analysis first so TiB can style your real wardrobe.';
      });
      return;
    }
    if (_wardrobe.isEmpty) {
      setState(() {
        _status = 'Add your real clothes to My Wardrobe first.';
      });
      return;
    }
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      setState(() {
        _status = 'Please sign in again.';
      });
      return;
    }
    setState(() {
      _busy = true;
      _generatedImageUrl = null;
      _status = 'TiB is choosing your look from clothes you already own…';
    });
    try {
      final recommendation = await AiStylingService.getRecommendation(
        uid: uid,
        profile: analysis,
        wardrobe: _wardrobe,
        styles: _styles,
        preferences: _preferences,
        occasion: _occasion,
      );
      if (!mounted || FirebaseAuth.instance.currentUser?.uid != uid) {
        return;
      }
      final ids = <String?>[
        recommendation.topId,
        recommendation.bottomId,
        recommendation.dressId,
        recommendation.suitId,
        recommendation.jacketId,
        recommendation.shoesId,
        recommendation.accessoryId,
      ];
      final picks = ids
          .whereType<String>()
          .map(_find)
          .whereType<WardrobeItem>()
          .toList(growable: false);
      setState(() {
        _selectedIds
          ..clear()
          ..addAll(picks.map((item) => item.id));
        _status = picks.isEmpty
            ? 'No matching wardrobe pieces were found.'
            : 'Great — I found ${picks.length} pieces. Now building your Virtual You…';
      });
      if (picks.isNotEmpty) {
        await _generate(items: picks);
      } else if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _status = 'TiB could not build the look right now: $error';
        });
      }
    }
  }

  Future<void> _generate({List<WardrobeItem>? items}) async {
    final model = _model;
    final selected = items ?? _selectedItems;
    if (_busy && items == null) {
      return;
    }
    if (model == null || !model.isComplete) {
      setState(() {
        _status = 'Complete your Personal TiB Model first: face + full-body reference + real measurements.';
      });
      return;
    }
    if (model.bodyFile == null || !model.bodyFile!.existsSync()) {
      setState(() {
        _status = 'Your full-body reference is missing. Rebuild your Personal TiB Model.';
      });
      return;
    }
    if (selected.isEmpty) {
      setState(() {
        _status = 'Select at least one real wardrobe piece first.';
      });
      return;
    }
    setState(() {
      _busy = true;
      _generatedImageUrl = null;
      _status = 'Creating your Virtual You…\nUsing your face, full-body reference and real measurements.';
    });
    try {
      final result = await VirtualTryOnResultService.generate(
        VirtualTryOnRequest(
          model: model,
          items: selected,
          occasion: _occasion,
          stylingBrief: _stylingBrief(selected),
        ),
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _busy = false;
        _generatedImageUrl = result.imageUrl;
        _status = result.isGenerated
            ? 'Your Virtual You is ready — this look is built around your real proportions.'
            : result.status;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _status = 'Virtual Try-On failed: $error';
        });
      }
    }
  }

  String _stylingBrief(List<WardrobeItem> items) {
    final model = _model!;
    return '''TiB Personal Virtual You fitting room.

IDENTITY MASTER:
This is a real user, not a fashion-model template. Use the user's full-body reference as the primary body reference and the user's face reference as the identity anchor.

REAL BODY DATA:
Height ${model.height} cm; weight ${model.weight} kg; bust ${model.bust} cm; waist ${model.waist} cm; hips ${model.hips} cm; body shape ${model.bodyShape}.

NON-NEGOTIABLE:
Keep the same person and natural body proportions. Do not slim, lengthen, enlarge, shrink, reshape or idealize any body area. Clothing must adapt to the user's actual proportions.

WARDROBE:
${items.map((item) => '${item.name} | ${item.category} | ${item.colour} | ${item.style}').join('\n')}

OUTPUT:
Create one photorealistic head-to-toe image of this same user wearing only the selected real wardrobe pieces. Preserve garment construction, colour, texture and details. Use a natural standing pose and realistic fabric fit.''';
  }

  List<String> _stringList(dynamic value) => value is List
      ? value
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList(growable: false)
      : const [];

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final model = _model;
    final selected = _selectedItems;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('AI Virtual Try-On'),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: _busy ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 34),
        children: [
          _identityHero(model),
          const SizedBox(height: 14),
          if (_generatedImageUrl != null) ...[
            _generatedCard(),
            const SizedBox(height: 16),
          ],
          _modelCard(model),
          const SizedBox(height: 18),
          _occasionSection(),
          const SizedBox(height: 18),
          _modeActions(),
          const SizedBox(height: 18),
          _wardrobeSection(selected),
          if (selected.isNotEmpty) ...[
            const SizedBox(height: 14),
            _selectedBar(selected),
          ],
          if (_status.isNotEmpty) ...[
            const SizedBox(height: 14),
            _statusCard(),
          ],
        ],
      ),
    );
  }

  Widget _identityHero(TibModelProfile? model) {
    final complete = model?.isComplete == true;
    final bodyFile = model?.bodyFile;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.primary.withValues(alpha: .18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 66,
            height: 82,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              color: AppColors.lavenderMist,
            ),
            clipBehavior: Clip.antiAlias,
            child: bodyFile != null && bodyFile.existsSync()
                ? Image.file(bodyFile, fit: BoxFit.cover)
                : const Icon(Icons.person_rounded, size: 38, color: AppColors.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'YOUR VIRTUAL YOU',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.2, color: AppColors.primary),
                ),
                const SizedBox(height: 5),
                const Text(
                  'Not a generic model.',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, height: 1.05),
                ),
                const SizedBox(height: 6),
                Text(
                  complete
                      ? 'TiB uses your real body data + your face + your full-body reference.'
                      : 'Finish your Personal TiB Model to make the fitting room truly yours.',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _modelCard(TibModelProfile? model) {
    final complete = model?.isComplete == true;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.straighten_rounded, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'REAL BODY PROFILE',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1),
                ),
              ),
              _pill(complete ? 'READY' : 'INCOMPLETE', complete),
            ],
          ),
          const SizedBox(height: 12),
          if (model == null || !complete)
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Face + full-body reference + height + weight + bust + waist + hips are required.',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.4),
              ),
            )
          else ...[
            _metrics(model),
            const SizedBox(height: 10),
            Row(
              children: [
                _tag(Icons.person_outline_rounded, model.bodyShape),
                const SizedBox(width: 7),
                _tag(Icons.face_retouching_natural_rounded, model.faceShape),
                const Spacer(),
                Text(
                  '${model.weight.toStringAsFixed(1)} kg',
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _metrics(TibModelProfile model) => Row(
        children: [
          _metric('HEIGHT', '${model.height.toStringAsFixed(0)} cm'),
          _metric('BUST', '${model.bust.toStringAsFixed(1)} cm'),
          _metric('WAIST', '${model.waist.toStringAsFixed(1)} cm'),
          _metric('HIPS', '${model.hips.toStringAsFixed(1)} cm'),
        ],
      );

  Widget _metric(String label, String value) => Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 8.5, color: AppColors.textMuted, fontWeight: FontWeight.w800)),
            const SizedBox(height: 3),
            Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
          ],
        ),
      );

  Widget _tag(IconData icon, String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: AppColors.primary),
            const SizedBox(width: 5),
            Text(text, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800)),
          ],
        ),
      );

  Widget _pill(String text, bool ok) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: ok ? AppColors.lavenderMist : Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(text, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900)),
      );

  Widget _occasionSection() => Container(
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
              children: [
                for (final value in _occasions)
                  ChoiceChip(
                    label: Text(value),
                    selected: _occasion == value,
                    onSelected: _busy
                        ? null
                        : (_) {
                            setState(() {
                              _occasion = value;
                              _generatedImageUrl = null;
                              _selectedIds.clear();
                              _status = '';
                            });
                          },
                  ),
              ],
            ),
          ],
        ),
      );

  Widget _modeActions() => SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: _busy ? null : _letTiBStyleMe,
          icon: _busy
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.auto_awesome_rounded),
          label: Text(_busy ? 'Working…' : 'Let TiB Style Me'),
        ),
      );

  Widget _wardrobeSection(List<WardrobeItem> selected) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'YOUR WARDROBE',
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.2, color: AppColors.textMuted),
          ),
          const SizedBox(height: 10),
          if (_wardrobe.isEmpty)
            const Text('No wardrobe pieces yet.', style: TextStyle(color: AppColors.textSecondary))
          else
            SizedBox(
              height: 210,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _wardrobe.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (_, index) {
                  final item = _wardrobe[index];
                  final chosen = selected.any((entry) => entry.id == item.id);
                  return SizedBox(
                    width: 145,
                    child: InkWell(
                      onTap: () => _toggle(item),
                      borderRadius: BorderRadius.circular(18),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: chosen ? AppColors.primary : AppColors.border,
                            width: chosen ? 2 : 1,
                          ),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: item.imageUrl.isEmpty
                                  ? const Center(child: Icon(Icons.checkroom_outlined, size: 36, color: AppColors.textMuted))
                                  : CachedNetworkImage(
                                      imageUrl: item.imageUrl,
                                      fit: BoxFit.cover,
                                      width: double.infinity,
                                    ),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    item.category,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 9.5, color: AppColors.textMuted),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      );

  Widget _selectedBar(List<WardrobeItem> selected) => Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
        ),
        child: Wrap(
          spacing: 7,
          runSpacing: 7,
          children: [
            for (final item in selected)
              Chip(
                label: Text(item.name),
                onDeleted: _busy ? null : () => _toggle(item),
              ),
          ],
        ),
      );

  Widget _statusCard() => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
        ),
        child: Text(
          _status,
          style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary, height: 1.45),
        ),
      );

  Widget _generatedCard() => Container(
        height: 420,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: CachedNetworkImage(imageUrl: _generatedImageUrl!, fit: BoxFit.cover),
      );
}
