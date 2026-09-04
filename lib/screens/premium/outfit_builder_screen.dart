import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../models/wardrobe_item.dart';
import '../../services/firestore_service.dart';
import '../../services/tib_model_service.dart';

class OutfitBuilderScreen extends StatefulWidget {
  const OutfitBuilderScreen({super.key});

  @override
  State<OutfitBuilderScreen> createState() => _OutfitBuilderScreenState();
}

class _OutfitBuilderScreenState extends State<OutfitBuilderScreen> {
  final List<String> _slots = const ['Top', 'Bottom', 'Dress', 'Outerwear', 'Shoes', 'Accessories'];
  List<WardrobeItem> _wardrobe = const [];
  final Map<String, WardrobeItem?> _selected = {};
  TibModelProfile? _model;
  String _activeSlot = 'Top';
  bool _loading = true;
  bool _saving = false;

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
        TibModelService.load(),
      ]);
      if (!mounted) return;
      setState(() {
        _wardrobe = results[0] as List<WardrobeItem>;
        _model = results[1] as TibModelProfile;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _categoryForSlot(String slot) {
    switch (slot) {
      case 'Top': return 'Tops';
      case 'Bottom': return 'Bottoms';
      case 'Dress': return 'Dresses';
      case 'Outerwear': return 'Outerwear';
      case 'Shoes': return 'Shoes';
      case 'Accessories': return 'Accessories';
      default: return slot;
    }
  }

  List<WardrobeItem> get _visibleItems => _wardrobe.where((item) => item.category.toLowerCase() == _categoryForSlot(_activeSlot).toLowerCase()).toList();
  List<WardrobeItem> get _selectedItems => _selected.values.whereType<WardrobeItem>().toList();
  int get _filledSlots => _selectedItems.length;

  void _select(WardrobeItem item) {
    setState(() {
      _selected[_activeSlot] = _selected[_activeSlot]?.id == item.id ? null : item;
    });
  }

  void _clearSlot() => setState(() => _selected[_activeSlot] = null);

  Future<void> _saveLook() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || _selectedItems.isEmpty || _saving) return;
    setState(() => _saving = true);
    try {
      await FirestoreService.saveOutfitLook(
        uid: uid,
        occasion: 'Personal Look',
        itemIds: _selectedItems.map((item) => item.id).toList(),
        matchScore: 85,
        season: 'Personal',
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
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Build My Look')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 36),
        children: [
          _buildHero(),
          const SizedBox(height: 18),
          _buildPreview(),
          const SizedBox(height: 20),
          _buildSlotSelector(),
          const SizedBox(height: 15),
          _buildWardrobePicker(),
          if (_selectedItems.isNotEmpty) ...[
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _saving ? null : _saveLook,
              icon: const Icon(Icons.bookmark_add_outlined),
              label: Text(_saving ? 'Saving…' : 'Save This Look'),
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHero() {
    return Container(
      padding: const EdgeInsets.fromLTRB(21, 21, 21, 22),
      decoration: BoxDecoration(color: AppColors.primaryDark, borderRadius: BorderRadius.circular(28)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('VYEA  /  OUTFIT BUILDER', style: TextStyle(color: AppColors.peach, fontSize: 9.5, fontWeight: FontWeight.w900, letterSpacing: 1.45)),
        const SizedBox(height: 16),
        const Text('Build the look.\nPiece by piece.', style: TextStyle(color: Colors.white, fontSize: 30, height: 1.02, fontWeight: FontWeight.w800, letterSpacing: -1)),
        const SizedBox(height: 9),
        Text(
          _model?.isComplete == true ? 'Choose from your real wardrobe and see your personal combination come together.' : 'Choose your wardrobe pieces first. Your VYEA Model can be used as your visual reference.',
          style: const TextStyle(color: Colors.white70, fontSize: 12.5, height: 1.45),
        ),
      ]),
    );
  }

  Widget _buildPreview() {
    final photo = _model?.faceFile;
    return Container(
      height: 350,
      decoration: BoxDecoration(
        gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFF7F1EC), Color(0xFFE7D9D0)]),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.border),
      ),
      child: Stack(alignment: Alignment.center, children: [
        Positioned(top: 20, child: ClipOval(child: SizedBox(width: 88, height: 88, child: photo != null && photo.existsSync() ? Image.file(photo, fit: BoxFit.cover) : const ColoredBox(color: AppColors.primarySoft, child: Icon(Icons.person_rounded, size: 42, color: AppColors.primary))))),
        Positioned(top: 118, child: Container(width: 170, height: 188, decoration: BoxDecoration(color: Colors.white.withValues(alpha: .72), borderRadius: const BorderRadius.vertical(top: Radius.circular(82), bottom: Radius.circular(30))), child: _selectedItems.isEmpty ? const Center(child: Icon(Icons.checkroom_outlined, size: 44, color: AppColors.primary)) : Padding(padding: const EdgeInsets.all(13), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: _selectedItems.take(4).map((item) => Padding(padding: const EdgeInsets.symmetric(vertical: 2.5), child: SizedBox(width: 125, height: 36, child: item.imageUrl.isEmpty ? const Icon(Icons.checkroom_outlined, color: AppColors.primary) : ClipRRect(borderRadius: BorderRadius.circular(9), child: CachedNetworkImage(imageUrl: item.imageUrl, fit: BoxFit.cover)))).toList())))),
        Positioned(left: 16, bottom: 14, child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)), child: Text('$_filledSlots pieces selected', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800)))),
        const Positioned(right: 16, bottom: 17, child: Text('LIVE PREVIEW', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 1, color: AppColors.textMuted))),
      ]),
    );
  }

  Widget _buildSlotSelector() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('CHOOSE A LAYER', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.25, color: AppColors.textMuted)),
      const SizedBox(height: 9),
      SizedBox(height: 42, child: ListView.separated(scrollDirection: Axis.horizontal, itemCount: _slots.length, separatorBuilder: (_, _) => const SizedBox(width: 7), itemBuilder: (_, index) {
        final slot = _slots[index];
        final selected = _activeSlot == slot;
        final filled = _selected[slot] != null;
        return ChoiceChip(label: Text(filled ? '✓ $slot' : slot), selected: selected, onSelected: (_) => setState(() => _activeSlot = slot));
      })),
    ]);
  }

  Widget _buildWardrobePicker() {
    final items = _visibleItems;
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(24), border: Border.all(color: AppColors.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Expanded(child: Text(_activeSlot, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800))), if (_selected[_activeSlot] != null) TextButton(onPressed: _clearSlot, child: const Text('Clear'))]),
        const SizedBox(height: 4),
        Text('Select one ${_categoryForSlot(_activeSlot).toLowerCase()} piece from your wardrobe.', style: const TextStyle(color: AppColors.textSecondary, fontSize: 10.5, height: 1.4)),
        const SizedBox(height: 12),
        if (items.isEmpty)
          Container(width: double.infinity, padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: AppColors.surfaceMuted, borderRadius: BorderRadius.circular(18)), child: Text('No ${_categoryForSlot(_activeSlot).toLowerCase()} in your wardrobe yet.', textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)))
        else
          GridView.builder(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: items.length, gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: .82), itemBuilder: (_, index) => _wardrobeItem(items[index])),
      ]),
    );
  }

  Widget _wardrobeItem(WardrobeItem item) {
    final selected = _selected[_activeSlot]?.id == item.id;
    return InkWell(
      onTap: () => _select(item),
      borderRadius: BorderRadius.circular(19),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(19), border: Border.all(color: selected ? AppColors.primary : AppColors.border, width: selected ? 2 : 1)),
        child: Stack(children: [
          Positioned.fill(child: item.imageUrl.isEmpty ? const ColoredBox(color: AppColors.surfaceMuted, child: Icon(Icons.checkroom_outlined, color: AppColors.primary, size: 36)) : CachedNetworkImage(imageUrl: item.imageUrl, fit: BoxFit.cover)),
          Positioned(left: 8, right: 8, bottom: 8, child: Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8), decoration: BoxDecoration(color: Colors.white.withValues(alpha: .92), borderRadius: BorderRadius.circular(12)), child: Row(children: [Expanded(child: Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w900))), if (selected) const Icon(Icons.check_circle_rounded, size: 17, color: AppColors.primary)]))),
        ]),
      ),
    );
  }
}
