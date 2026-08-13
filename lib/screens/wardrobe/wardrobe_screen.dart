import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../models/wardrobe_item.dart';
import '../../services/firestore_service.dart';
import '../../services/image_picker_service.dart';
import '../../services/storage_service.dart';

class WardrobeScreen extends StatefulWidget {
  const WardrobeScreen({super.key});

  @override
  State<WardrobeScreen> createState() => _WardrobeScreenState();
}

class _WardrobeScreenState extends State<WardrobeScreen> {
  static const _brown = Color(0xFF8E5E46);
  static const _cream = Color(0xFFFFFAF7);
  static const _soft = Color(0xFFF8E3DC);
  static const _text = Color(0xFF302A27);
  static const _muted = Color(0xFF756B67);

  String _category = 'All';

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  @override
  Widget build(BuildContext context) {
    final uid = _uid;

    return Scaffold(
      backgroundColor: _cream,
      appBar: AppBar(
        backgroundColor: _cream,
        elevation: 0,
        title: const Text('My Wardrobe', style: TextStyle(color: _text, fontWeight: FontWeight.w700)),
        iconTheme: const IconThemeData(color: _text),
        actions: [
          IconButton(
            tooltip: 'Add clothing',
            onPressed: uid == null ? null : () => _showAddItem(uid),
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
      body: uid == null
          ? const Center(child: Text('Please login to use your wardrobe.'))
          : StreamBuilder<List<WardrobeItem>>(
              stream: FirestoreService.watchWardrobeItems(uid),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Could not load your wardrobe.'));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final items = snapshot.data ?? const <WardrobeItem>[];
                final filtered = _category == 'All'
                    ? items
                    : items.where((item) => item.category == _category).toList();

                return RefreshIndicator(
                  onRefresh: () async => setState(() {}),
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverToBoxAdapter(child: _buildHeader(items.length)),
                      SliverToBoxAdapter(child: _buildCategories()),
                      if (filtered.isEmpty)
                        SliverFillRemaining(hasScrollBody: false, child: _buildEmptyState())
                      else
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(18, 8, 18, 30),
                          sliver: SliverGrid(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) => _buildItemCard(filtered[index], uid),
                              childCount: filtered.length,
                            ),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 14,
                              childAspectRatio: .72,
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
      floatingActionButton: uid == null
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _showAddItem(uid),
              backgroundColor: _brown,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add Item'),
            ),
    );
  }

  Widget _buildHeader(int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFFF4D5C8), Color(0xFFF9EAE5)]),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          children: [
            Container(width: 48, height: 48, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle), child: const Icon(Icons.checkroom_rounded, color: _brown)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(count == 0 ? 'Your wardrobe is waiting.' : '$count pieces and counting.', style: const TextStyle(color: _text, fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 5),
                const Text('Add pieces you genuinely love. I’ll use them when helping you build outfits.', style: TextStyle(color: _muted, height: 1.4, fontSize: 13)),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategories() {
    const categories = ['All', 'Tops', 'Bottoms', 'Dresses', 'Shoes', 'Accessories'];
    return SizedBox(
      height: 52,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 18),
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final value = categories[index];
          return ChoiceChip(
            label: Text(value),
            selected: _category == value,
            onSelected: (_) => setState(() => _category = value),
            selectedColor: _brown,
            backgroundColor: Colors.white,
            labelStyle: TextStyle(color: _category == value ? Colors.white : _text, fontWeight: FontWeight.w600),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(35),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(width: 82, height: 82, decoration: const BoxDecoration(color: _soft, shape: BoxShape.circle), child: const Icon(Icons.checkroom_outlined, size: 40, color: _brown)),
          const SizedBox(height: 18),
          const Text('Nothing here yet', style: TextStyle(color: _text, fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          const Text('Start with a few pieces you already own. Your future outfit suggestions will feel much more like you.', textAlign: TextAlign.center, style: TextStyle(color: _muted, height: 1.5)),
          const SizedBox(height: 18),
          FilledButton.icon(onPressed: () { final uid = _uid; if (uid != null) _showAddItem(uid); }, icon: const Icon(Icons.add_rounded), label: const Text('Add your first piece'), style: FilledButton.styleFrom(backgroundColor: _brown)),
        ]),
      ),
    );
  }

  Widget _buildItemCard(WardrobeItem item, String uid) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _showItemDetails(item, uid),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Stack(children: [
              Positioned.fill(child: item.imageUrl.isEmpty ? Container(color: _soft, child: const Icon(Icons.image_outlined, size: 42, color: _brown)) : Image.network(item.imageUrl, fit: BoxFit.cover, errorBuilder: (_, _, _) => Container(color: _soft, child: const Icon(Icons.broken_image_outlined, color: _brown)))),
              Positioned(top: 8, right: 8, child: Material(color: Colors.white.withValues(alpha: .92), shape: const CircleBorder(), child: IconButton(padding: EdgeInsets.zero, constraints: const BoxConstraints.tightFor(width: 38, height: 38), onPressed: () => _toggleFavourite(item, uid), icon: Icon(item.isFavourite ? Icons.favorite : Icons.favorite_border, color: _brown, size: 20)))),
            ]),
          ),
          Padding(padding: const EdgeInsets.fromLTRB(13, 10, 13, 12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _text, fontWeight: FontWeight.w700)),
            const SizedBox(height: 3),
            Text('${item.category} · ${item.colour}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _muted, fontSize: 12)),
          ])),
        ]),
      ),
    );
  }

  Future<void> _showAddItem(String uid) async {
    final image = await showModalBottomSheet<File?>(context: context, showDragHandle: true, backgroundColor: _cream, builder: (context) => SafeArea(child: Padding(padding: const EdgeInsets.fromLTRB(20, 8, 20, 25), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Add something you love', style: TextStyle(color: _text, fontSize: 21, fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      const Text('A clear photo works best. You can add the details after choosing it.', style: TextStyle(color: _muted)),
      const SizedBox(height: 18),
      Row(children: [
        Expanded(child: OutlinedButton.icon(onPressed: () async { Navigator.pop(context, await ImagePickerService.pickCamera()); }, icon: const Icon(Icons.camera_alt_outlined), label: const Text('Camera'))),
        const SizedBox(width: 12),
        Expanded(child: OutlinedButton.icon(onPressed: () async { Navigator.pop(context, await ImagePickerService.pickGallery()); }, icon: const Icon(Icons.photo_outlined), label: const Text('Gallery'))),
      ]),
    ]))));
    if (image == null || !mounted) return;
    await _showItemForm(uid, image);
  }

  Future<void> _showItemForm(String uid, File image) async {
    final nameController = TextEditingController();
    final notesController = TextEditingController();
    var category = 'Tops';
    var colour = 'Neutral';
    var style = 'Everyday';
    var season = 'All seasons';
    var saving = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: _cream,
      builder: (sheetContext) => StatefulBuilder(builder: (context, setSheetState) {
        Future<void> save() async {
          if (nameController.text.trim().isEmpty || saving) return;
          setSheetState(() => saving = true);
          try {
            final imageUrl = await StorageService.uploadWardrobeImage(uid: uid, image: image);
            await FirestoreService.addWardrobeItem(WardrobeItem(id: '', userId: uid, imageUrl: imageUrl, name: nameController.text.trim(), category: category, colour: colour, style: style, season: season, isFavourite: false, notes: notesController.text.trim(), createdAt: null));
            if (sheetContext.mounted) Navigator.pop(sheetContext);
          } catch (_) {
            if (sheetContext.mounted) ScaffoldMessenger.of(sheetContext).showSnackBar(const SnackBar(content: Text('Could not save this piece. Please try again.')));
          } finally {
            if (sheetContext.mounted) setSheetState(() => saving = false);
          }
        }

        return SafeArea(child: Padding(padding: EdgeInsets.only(left: 20, right: 20, bottom: MediaQuery.viewInsetsOf(context).bottom + 20), child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Tell me a little about it', style: TextStyle(color: _text, fontSize: 21, fontWeight: FontWeight.w700)),
          const SizedBox(height: 15),
          ClipRRect(borderRadius: BorderRadius.circular(18), child: Image.file(image, height: 180, width: double.infinity, fit: BoxFit.cover)),
          const SizedBox(height: 15),
          TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Name', hintText: 'e.g. Cream knit cardigan', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          _dropdown('Category', category, ['Tops', 'Bottoms', 'Dresses', 'Shoes', 'Accessories'], (v) => setSheetState(() => category = v)),
          _dropdown('Colour', colour, ['Black', 'White', 'Beige', 'Brown', 'Pink', 'Red', 'Orange', 'Yellow', 'Green', 'Blue', 'Purple', 'Neutral'], (v) => setSheetState(() => colour = v)),
          _dropdown('Style', style, ['Everyday', 'Minimal', 'Elegant', 'Casual', 'Smart Casual', 'Feminine', 'Trendy'], (v) => setSheetState(() => style = v)),
          _dropdown('Season', season, ['All seasons', 'Spring', 'Summer', 'Autumn', 'Winter'], (v) => setSheetState(() => season = v)),
          const SizedBox(height: 4),
          TextField(controller: notesController, maxLines: 2, decoration: const InputDecoration(labelText: 'Notes (optional)', border: OutlineInputBorder())),
          const SizedBox(height: 16),
          SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: saving ? null : save, icon: saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.check_rounded), label: Text(saving ? 'Saving...' : 'Save to My Wardrobe'), style: FilledButton.styleFrom(backgroundColor: _brown, minimumSize: const Size.fromHeight(52)))),
        ]))));
      }),
    );
  }

  Widget _dropdown(String label, String value, List<String> values, ValueChanged<String> onChanged) {
    return Padding(padding: const EdgeInsets.only(bottom: 12), child: DropdownButtonFormField<String>(initialValue: value, decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()), items: values.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(), onChanged: (v) { if (v != null) onChanged(v); }));
  }

  Future<void> _toggleFavourite(WardrobeItem item, String uid) async {
    await FirestoreService.updateWardrobeItem(uid, item.id, {'isFavourite': !item.isFavourite});
  }

  void _showItemDetails(WardrobeItem item, String uid) {
    showModalBottomSheet<void>(context: context, showDragHandle: true, backgroundColor: _cream, builder: (context) => SafeArea(child: Padding(padding: const EdgeInsets.fromLTRB(20, 5, 20, 25), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [const Icon(Icons.checkroom_outlined, color: _brown), const SizedBox(width: 10), Expanded(child: Text(item.name, style: const TextStyle(color: _text, fontSize: 21, fontWeight: FontWeight.w700))), IconButton(onPressed: () async { await FirestoreService.deleteWardrobeItem(uid, item.id); if (context.mounted) Navigator.pop(context); }, icon: const Icon(Icons.delete_outline, color: Colors.redAccent))]),
      const SizedBox(height: 10),
      Text('${item.category} · ${item.colour} · ${item.style}', style: const TextStyle(color: _muted)),
      if (item.notes.isNotEmpty) ...[const SizedBox(height: 8), Text(item.notes, style: const TextStyle(color: _text, height: 1.4))],
      const SizedBox(height: 16),
      SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: () { Navigator.pop(context); }, icon: Icon(item.isFavourite ? Icons.favorite : Icons.favorite_border), label: Text(item.isFavourite ? 'Saved to favourites' : 'Save as favourite'), style: FilledButton.styleFrom(backgroundColor: _brown))),
    ]))));
  }
}
