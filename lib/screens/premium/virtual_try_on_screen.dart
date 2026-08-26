import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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

class VirtualTryOnScreen extends StatefulWidget {
  const VirtualTryOnScreen({super.key});

  @override
  State<VirtualTryOnScreen> createState() => _VirtualTryOnScreenState();
}

enum _TryOnMode { choose, ai }

class _VirtualTryOnScreenState extends State<VirtualTryOnScreen> {
  static const _modelKey = 'tib_virtual_model_path';

  bool _loading = true;
  bool _busy = false;
  bool _saving = false;

  File? _modelPhoto;
  List<WardrobeItem> _wardrobe = const [];
  Set<String> _selectedIds = {};
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
      final stylePrefs = results[1] as Map<String, dynamic>?;

      setState(() {
        _wardrobe = results[0] as List<WardrobeItem>;
        _styles = List<String>.from(stylePrefs?['styles'] ?? const []);
        _preferences = List<String>.from(
          stylePrefs?['preferences'] ?? const [],
        );
        _analysis = results[2] as ColourAnalysisResult?;
        _modelPhoto = model;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _chooseModel({required bool camera}) async {
    if (_busy) return;

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
      setState(
        () => _status = error.toString().replaceFirst('Exception: ', ''),
      );
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
      _status = next.isEmpty ? '' : '${next.length} pieces selected.';
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
      setState(
        () => _status =
            'Complete Colour Analysis first so TiB can style you accurately.',
      );
      return;
    }

    setState(() {
      _busy = true;
      _mode = _TryOnMode.ai;
      _status = 'TiB is styling your wardrobe…';
      _selectedIds = {};
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
          _selectedIds = picks.map((item) => item.id).toSet();
          _status = 'AI look built from your real wardrobe.';
        });
      } else {
        final fallback = _buildFallback(profile);
        setState(() {
          _selectedIds = fallback.map((item) => item.id).toSet();
          _status = fallback.isEmpty
              ? 'TiB could not find a complete look from your current wardrobe.'
              : 'Here is a transparent wardrobe match while AI is unavailable.';
        });
      }
    } catch (_) {
      final fallback = _buildFallback(profile);
      setState(() {
        _selectedIds = fallback.map((item) => item.id).toSet();
        _status =
            'AI is unavailable right now, so TiB prepared a wardrobe fallback.';
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
      if (_preferences.any((item) => style.contains(item.toLowerCase())))
        value += 4;
      if (profile.colours.any((item) => _sameColourFamily(item, colour)))
        value += 12;
      if (item.season == profile.season || item.season == 'All seasons')
        value += 8;
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
      final dress = sorted
          .where((item) => item.category == 'Dresses')
          .firstOrNull;
      if (dress != null) result.add(dress);
    }

    if (result.isEmpty) {
      for (final item in sorted) {
        if (item.category == 'Tops' &&
            !result.any((x) => x.category == 'Tops')) {
          result.add(item);
        }
        if (item.category == 'Bottoms' &&
            !result.any((x) => x.category == 'Bottoms')) {
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

  List<WardrobeItem> get _selectedItems =>
      _selectedIds.map(_find).whereType<WardrobeItem>().toList();

  int _matchScore(List<WardrobeItem> items) {
    if (items.isEmpty) return 0;
    final profile = _analysis;
    if (profile == null) return 70;
    var score = 70;
    for (final item in items) {
      if (profile.colours.any((c) => _sameColourFamily(c, item.colour)))
        score += 4;
      if (item.season == profile.season || item.season == 'All seasons')
        score += 3;
      if (_styles.any(
        (s) => item.style.toLowerCase().contains(s.toLowerCase()),
      ))
        score += 2;
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
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final selected = _selectedItems;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Virtual Try-On')),
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
    final photo = _modelPhoto;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: AppGradients.soft,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: AppColors.primarySoft),
      ),
      child: Row(
        children: [
          Container(
            width: 86,
            height: 108,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
            ),
            clipBehavior: Clip.antiAlias,
            child: photo != null && photo.existsSync()
                ? Image.file(photo, fit: BoxFit.cover)
                : const Icon(
                    Icons.person_rounded,
                    size: 42,
                    color: AppColors.primary,
                  ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'MY TIΒ MODEL',
                  style: TextStyle(
                    fontSize: 9,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  photo == null
                      ? 'Add your model photo'
                      : 'Your TiB Model is ready',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                const Text(
                  'Use your own model with your wardrobe for a more personal try-on.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 10.5,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: _busy
                          ? null
                          : () => _chooseModel(camera: true),
                      icon: const Icon(Icons.camera_alt_outlined, size: 16),
                      label: Text(photo == null ? 'Scan' : 'Rescan'),
                    ),
                    const SizedBox(width: 8),
                    if (photo != null)
                      TextButton(
                        onPressed: _busy ? null : _removeModel,
                        child: const Text('Remove'),
                      ),
                  ],
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
      onSelectionChanged: (selection) {
        setState(() {
          _mode = selection.first;
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
            style: TextStyle(
              fontSize: 9,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w900,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 9),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: _occasions
                .map(
                  (value) => ChoiceChip(
                    label: Text(value),
                    selected: _occasion == value,
                    onSelected: _busy
                        ? null
                        : (_) => setState(() => _occasion = value),
                  ),
                )
                .toList(),
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
            'AI WARDROBE STYLING',
            style: TextStyle(
              fontSize: 9,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w900,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Let TiB choose the best pieces from what you already own.',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 7),
          Text(
            _selectedIds.isEmpty
                ? 'TiB will consider your colour profile, preferences and occasion.'
                : '${_selectedIds.length} pieces selected from your wardrobe.',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 10.5,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _busy ? null : _letTiBStyleMe,
              icon: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.auto_awesome_rounded),
              label: Text(_busy ? 'Styling…' : 'Style My Wardrobe'),
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
          'Your wardrobe is empty. Add some pieces first, then come back and create your virtual look.',
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
                  'SELECT FROM MY WARDROBE',
                  style: TextStyle(
                    fontSize: 11,
                    letterSpacing: 1.1,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                '${_selectedIds.length}/5',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          const Text(
            'Choose the pieces you want TiB to use.',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 10,
              height: 1.35,
            ),
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
                    color: selected
                        ? AppColors.lavenderMist
                        : AppColors.surfaceMuted,
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
                            ? const Center(
                                child: Icon(
                                  Icons.checkroom_outlined,
                                  size: 36,
                                  color: AppColors.primary,
                                ),
                              )
                            : Image.network(
                                item.imageUrl,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stack) =>
                                    const Center(
                                      child: Icon(
                                        Icons.broken_image_outlined,
                                        color: AppColors.textMuted,
                                      ),
                                    ),
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
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            if (selected)
                              const Icon(
                                Icons.check_circle_rounded,
                                size: 18,
                                color: AppColors.primary,
                              ),
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

  Widget _buildPreview(List<WardrobeItem> selected) {
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
            'SELECTED LOOK',
            style: TextStyle(
              fontSize: 10,
              letterSpacing: 1.1,
              fontWeight: FontWeight.w900,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 105,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: selected.length,
              separatorBuilder: (context, index) => const SizedBox(width: 8),
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
                              ? const Center(
                                  child: Icon(
                                    Icons.checkroom_outlined,
                                    color: AppColors.primary,
                                  ),
                                )
                              : CachedNetworkImage(
                                  imageUrl: item.imageUrl,
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                ),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        item.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 8.5,
                          fontWeight: FontWeight.w700,
                        ),
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
