import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_gradients.dart';
import '../../models/colour_analysis_result.dart';
import '../../models/wardrobe_item.dart';
import '../../services/ai_styling_service.dart';
import '../../services/firestore_service.dart';
import '../../services/image_picker_service.dart';
import '../../services/mlkit_service.dart';
import '../../services/style_preference_service.dart';
import '../../widgets/premium_badge.dart';

class VirtualTryOnScreen extends StatefulWidget {
  const VirtualTryOnScreen({super.key});

  @override
  State<VirtualTryOnScreen> createState() => _VirtualTryOnScreenState();
}

enum _TryOnMode { choose, ai }

class _VirtualTryOnScreenState extends State<VirtualTryOnScreen> {
  static const _modelKey = 'tib_virtual_model_path';

  bool _loading = true;
  bool _isPremium = false;
  bool _busy = false;
  bool _saving = false;

  File? _modelPhoto;
  List<WardrobeItem> _wardrobe = const [];
  Set<String> _selectedIds = {};
  List<WardrobeItem> _recommended = const [];
  ColourAnalysisResult? _analysis;
  List<String> _styles = const [];
  List<String> _preferences = const [];
  String _occasion = 'Dinner';
  String _status = '';
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
      if (mounted) setState(() => _loading = false);
      return;
    }

    try {
      final results = await Future.wait<dynamic>([
        FirebaseFirestore.instance.collection('users').doc(uid).get(),
        FirestoreService.getWardrobeItems(uid),
        StylePreferenceService.getStylePreferences(uid),
        FirestoreService.getLatestColourAnalysis(uid),
      ]);

      final prefs = await SharedPreferences.getInstance();
      final storedPath = prefs.getString(_modelKey);
      final model = storedPath == null
          ? null
          : File(storedPath).existsSync()
              ? File(storedPath)
              : null;

      if (!mounted) return;
      final user = (results[0] as DocumentSnapshot<Map<String, dynamic>>).data();
      final stylePrefs = results[2] as Map<String, dynamic>?;

      setState(() {
        // Debug builds can exercise the complete Premium flow without
        // changing the production entitlement stored in Firestore.
        _isPremium = user?['isPremium'] == true || kDebugMode;
        _wardrobe = results[1] as List<WardrobeItem>;
        _styles = List<String>.from(stylePrefs?['styles'] ?? const []);
        _preferences = List<String>.from(
          stylePrefs?['preferences'] ?? const [],
        );
        _analysis = results[3] as ColourAnalysisResult?;
        _modelPhoto = model;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _chooseModel({required bool camera}) async {
    if (_busy || !_isPremium) return;

    setState(() {
      _busy = true;
      _status = 'Checking your photo…';
    });

    try {
      final image = camera
          ? await ImagePickerService.pickCamera()
          : await ImagePickerService.pickGallery();
      if (image == null) return;

      final faces = await MlKitService.detectFace(image);
      if (faces.length != 1) {
        throw Exception(
          faces.isEmpty
              ? 'No face detected. Please use a clear front-facing photo.'
              : 'Please use a photo with one clearly visible face.',
        );
      }

      final directory = await getApplicationDocumentsDirectory();
      final target = File('${directory.path}/tib_virtual_model.jpg');
      await image.copy(target.path);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_modelKey, target.path);

      if (!mounted) return;
      setState(() {
        _modelPhoto = target;
        _status = 'Your TiB Model is ready.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _status = error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _removeModel() async {
    final prefs = await SharedPreferences.getInstance();
    final path = prefs.getString(_modelKey);
    if (path != null) {
      final file = File(path);
      if (file.existsSync()) await file.delete();
    }
    await prefs.remove(_modelKey);
    if (!mounted) return;
    setState(() {
      _modelPhoto = null;
      _selectedIds = {};
      _recommended = const [];
      _status = 'Your TiB Model photo was removed.';
    });
  }

  void _toggleItem(WardrobeItem item) {
    if (_saving) return;
    final next = {..._selectedIds};
    if (next.contains(item.id)) {
      next.remove(item.id);
    } else {
      if (next.length >= 5) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Choose up to 5 pieces for one look.')),
        );
        return;
      }
      next.add(item.id);
    }
    setState(() {
      _selectedIds = next;
      _recommended = const [];
      _status = next.isEmpty ? '' : '${next.length} pieces selected.';
    });
  }

  Future<void> _letTiBStyleMe() async {
    if (_busy || !_isPremium) return;
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
      _status = 'TiB is styling your wardrobe…';
      _selectedIds = {};
      _recommended = const [];
    });

    try {
      final result = await AiStylingService.getRecommendation(
        profile: profile,
        wardrobe: _wardrobe,
        styles: _styles,
        preferences: _preferences,
        occasion: _occasion,
      );

      if (result != null) {
        final ids = <String?>[
          result.topId,
          result.bottomId,
          result.shoesId,
          result.accessoryId,
        ];
        final picks = ids
            .whereType<String>()
            .map((id) => _find(id))
            .whereType<WardrobeItem>()
            .toList();
        setState(() {
          _recommended = picks;
          _selectedIds = picks.map((item) => item.id).toSet();
          _status = 'AI look built from your real wardrobe.';
        });
      } else {
        final fallback = _buildFallback(profile);
        setState(() {
          _recommended = fallback;
          _selectedIds = fallback.map((item) => item.id).toSet();
          _status = fallback.isEmpty
              ? 'TiB could not find a complete look from your current wardrobe.'
              : 'Here is a transparent wardrobe match while AI is unavailable.';
        });
      }
    } catch (_) {
      final fallback = _buildFallback(profile);
      setState(() {
        _recommended = fallback;
        _selectedIds = fallback.map((item) => item.id).toSet();
        _status = 'AI is unavailable right now, so TiB prepared a wardrobe fallback.';
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  List<WardrobeItem> _buildFallback(ColourAnalysisResult profile) {
    int score(WardrobeItem item) {
      var value = item.isFavourite ? 8 : 0;
      final colour = item.colour.toLowerCase();
      final style = item.style.toLowerCase();
      if (_styles.any((item) => style.contains(item.toLowerCase()))) value += 8;
      if (_preferences.any((item) => style.contains(item.toLowerCase()))) value += 4;
      if (profile.colours.any((item) => _sameColourFamily(item, colour))) value += 12;
      if (item.season == profile.season || item.season == 'All seasons') value += 8;
      if (_occasion == 'Work' && style.contains('smart')) value += 10;
      if ((_occasion == 'Date' || _occasion == 'Dinner') &&
          (style.contains('elegant') || style.contains('feminine'))) {
        value += 10;
      }
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
        if (item.category == 'Tops' && !result.any((x) => x.category == 'Tops')) {
          result.add(item);
        }
        if (item.category == 'Bottoms' && !result.any((x) => x.category == 'Bottoms')) {
          result.add(item);
        }
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
    return result.take(5).toList();
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

  List<WardrobeItem> get _selectedItems => _selectedIds
      .map(_find)
      .whereType<WardrobeItem>()
      .toList();

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

  Future<void> _saveLook() async {
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
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (!_isPremium) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: const Text('Virtual Try-On')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(28),
            child: Text(
              'Virtual Try-On is part of TiB Premium. Your wardrobe and colour analysis stay available in the free experience.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    final selected = _selectedItems;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Virtual Try-On'),
        actions: const [Padding(
          padding: EdgeInsets.only(right: 14),
          child: PremiumBadge(compact: true),
        )],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 34),
        children: [
          _buildModelCard(),
          const SizedBox(height: 16),
          _buildModeSwitch(),
          const SizedBox(height: 16),
          _buildOccasions(),
          const SizedBox(height: 16),
          _mode == _TryOnMode.ai ? _buildAiPanel() : _buildWardrobePicker(),
          if (selected.isNotEmpty) ...[
            const SizedBox(height: 20),
            _buildPreview(selected),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _saving ? null : _saveLook,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.bookmark_add_outlined),
                label: Text(_saving ? 'Saving…' : 'Save Look'),
              ),
            ),
          ],
          if (_status.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              _status,
              style: const TextStyle(
                color: AppColors.textSecondary,
                height: 1.45,
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildModelCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: AppGradients.premium,
        borderRadius: BorderRadius.circular(26),
      ),
      child: Row(
        children: [
          ClipOval(
            child: SizedBox(
              width: 74,
              height: 74,
              child: _modelPhoto == null
                  ? Container(
                      color: Colors.white.withValues(alpha: .65),
                      child: const Icon(Icons.person_rounded, size: 38, color: AppColors.primary),
                    )
                  : Image.file(_modelPhoto!, fit: BoxFit.cover),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Your TiB Model',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  _modelPhoto == null
                      ? 'Add one clear front-facing photo once. TiB keeps the model on your device.'
                      : 'Ready for outfit previews using your real wardrobe.',
                  style: const TextStyle(color: AppColors.textSecondary, height: 1.35, fontSize: 11.5),
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'camera') _chooseModel(camera: true);
              if (value == 'gallery') _chooseModel(camera: false);
              if (value == 'remove') _removeModel();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'camera', child: Text('Scan face')),
              const PopupMenuItem(value: 'gallery', child: Text('Upload photo')),
              if (_modelPhoto != null)
                const PopupMenuItem(value: 'remove', child: Text('Remove model')),
            ],
            icon: const Icon(Icons.more_horiz_rounded),
          ),
        ],
      ),
    );
  }

  Widget _buildModeSwitch() {
    return SegmentedButton<_TryOnMode>(
      segments: const [
        ButtonSegment(value: _TryOnMode.choose, label: Text('Build My Look'), icon: Icon(Icons.checkroom_outlined)),
        ButtonSegment(value: _TryOnMode.ai, label: Text('Let TiB Style Me'), icon: Icon(Icons.auto_awesome_rounded)),
      ],
      selected: {_mode},
      onSelectionChanged: (selection) {
        setState(() {
          _mode = selection.first;
          _status = '';
          _recommended = const [];
          if (_mode == _TryOnMode.ai) _selectedIds = {};
        });
      },
    );
  }

  Widget _buildOccasions() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _occasions
            .map(
              (value) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(value),
                  selected: _occasion == value,
                  onSelected: (_) => setState(() => _occasion = value),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildAiPanel() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Let TiB choose for you', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 5),
          const Text(
            'TiB considers your colour analysis, style preferences and the pieces you already own.',
            style: TextStyle(color: AppColors.textSecondary, height: 1.4, fontSize: 12),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _busy ? null : _letTiBStyleMe,
              icon: _busy
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.auto_awesome_rounded),
              label: Text(_busy ? 'Building your look…' : 'Recommend a Look'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWardrobePicker() {
    if (_wardrobe.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(top: 30),
        child: Text(
          'Your wardrobe is empty. Add some pieces first.',
          textAlign: TextAlign.center,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text('Choose pieces', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            ),
            Text('${_selectedIds.length}/5', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          ],
        ),
        const SizedBox(height: 10),
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
            return InkWell(
              onTap: () => _toggleItem(item),
              borderRadius: BorderRadius.circular(18),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
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
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          item.imageUrl.isEmpty
                              ? Container(
                                  color: AppColors.surfaceMuted,
                                  child: const Icon(Icons.checkroom_outlined, size: 34, color: AppColors.primary),
                                )
                              : CachedNetworkImage(imageUrl: item.imageUrl, fit: BoxFit.cover),
                          if (selected)
                            const Align(
                              alignment: Alignment.topRight,
                              child: Padding(
                                padding: EdgeInsets.all(8),
                                child: CircleAvatar(
                                  radius: 13,
                                  backgroundColor: AppColors.primary,
                                  child: Icon(Icons.check_rounded, color: Colors.white, size: 17),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(10, 8, 10, 9),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11.5)),
                          const SizedBox(height: 2),
                          Text('${item.category} · ${item.colour}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.textMuted, fontSize: 9.5)),
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
    );
  }

  Widget _buildPreview(List<WardrobeItem> items) {
    final score = _matchScore(items);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('Virtual preview', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              ),
              Text('$score% match', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            height: 320,
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: AppGradients.soft,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                const SizedBox(height: 18),
                ClipOval(
                  child: SizedBox(
                    width: 84,
                    height: 84,
                    child: _modelPhoto == null
                        ? Container(color: AppColors.primarySoft, child: const Icon(Icons.person_rounded, size: 42, color: AppColors.primary))
                        : Image.file(_modelPhoto!, fit: BoxFit.cover),
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (final item in items.take(3))
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: SizedBox(
                            width: 78,
                            height: 145,
                            child: item.imageUrl.isEmpty
                                ? Container(
                                    decoration: BoxDecoration(color: AppColors.surfaceMuted, borderRadius: BorderRadius.circular(16)),
                                    child: const Icon(Icons.checkroom_outlined, color: AppColors.primary),
                                  )
                                : ClipRRect(
                                    borderRadius: BorderRadius.circular(16),
                                    child: CachedNetworkImage(imageUrl: item.imageUrl, fit: BoxFit.cover),
                                  ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Your face + your wardrobe',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.textMuted, letterSpacing: .8),
                ),
                const SizedBox(height: 14),
              ],
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Preview layout only — the photorealistic try-on engine can be connected as the next AI backend step.',
            style: TextStyle(color: AppColors.textMuted, fontSize: 10, height: 1.35),
          ),
        ],
      ),
    );
  }
}
