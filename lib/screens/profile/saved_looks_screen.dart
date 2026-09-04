import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../services/firestore_service.dart';

class SavedLooksScreen extends StatefulWidget {
  const SavedLooksScreen({super.key});

  @override
  State<SavedLooksScreen> createState() => _SavedLooksScreenState();
}

enum _SavedLookSort { recent, highestMatch }

class _SavedLooksScreenState extends State<SavedLooksScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _looks = const [];
  List<Map<String, dynamic>> _wardrobe = const [];
  String _occasionFilter = 'All';
  _SavedLookSort _sort = _SavedLookSort.recent;

  static const _filters = ['All', 'Work', 'Casual', 'Date', 'Event'];

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
          _error = 'Please sign in to view your saved looks.';
        });
      }
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final saved = await FirestoreService.getSavedOutfitLooks(uid);
      final wardrobeItems = await FirestoreService.getWardrobeItems(uid);
      final wardrobe = wardrobeItems
          .map(
            (item) => <String, dynamic>{
              'id': item.id,
              'name': item.name,
              'category': item.category,
              'colour': item.colour,
              'imageUrl': item.imageUrl,
            },
          )
          .toList();

      if (!mounted) return;
      setState(() {
        _looks = saved;
        _wardrobe = wardrobe;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'I could not load your saved looks.';
      });
    }
  }

  Map<String, dynamic>? _wardrobeItem(String id) {
    for (final item in _wardrobe) {
      if (item['id'] == id) return item;
    }
    return null;
  }

  DateTime? _createdAt(Map<String, dynamic> look) {
    final value = look['createdAt'];
    if (value is DateTime) return value;
    if (value is Timestamp) return value.toDate();
    return null;
  }

  List<Map<String, dynamic>> get _visibleLooks {
    final filtered = _occasionFilter == 'All'
        ? List<Map<String, dynamic>>.from(_looks)
        : _looks.where((look) {
            final occasion = (look['occasion'] as String? ?? '').toLowerCase();
            return _matchesOccasion(occasion, _occasionFilter);
          }).toList();

    filtered.sort((a, b) {
      if (_sort == _SavedLookSort.highestMatch) {
        final aScore = (a['matchScore'] as num?)?.toDouble() ?? 0;
        final bScore = (b['matchScore'] as num?)?.toDouble() ?? 0;
        return bScore.compareTo(aScore);
      }
      final aDate = _createdAt(a);
      final bDate = _createdAt(b);
      if (aDate == null && bDate == null) return 0;
      if (aDate == null) return 1;
      if (bDate == null) return -1;
      return bDate.compareTo(aDate);
    });

    return filtered;
  }

  bool _matchesOccasion(String occasion, String filter) {
    switch (filter) {
      case 'Work':
        return occasion.contains('work') || occasion.contains('office') || occasion.contains('business');
      case 'Casual':
        return occasion.contains('casual') || occasion.contains('weekend') || occasion.contains('cafe') || occasion.contains('coffee') || occasion.contains('everyday');
      case 'Date':
        return occasion.contains('date') || occasion.contains('dinner') || occasion.contains('romantic');
      case 'Event':
        return occasion.contains('event') || occasion.contains('party') || occasion.contains('wedding') || occasion.contains('occasion');
      default:
        return true;
    }
  }

  Future<void> _deleteLook(String lookId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove saved look?'),
        content: const Text('This saved outfit will be removed from your collection.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Keep it')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Remove')),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await FirestoreService.deleteSavedOutfitLook(uid, lookId);
      if (!mounted) return;
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved look removed.')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Unable to remove that look right now.')));
    }
  }

  void _openLook(Map<String, dynamic> look) {
    final ids = List<String>.from(look['itemIds'] ?? const <String>[]);
    final pieces = ids.map(_wardrobeItem).whereType<Map<String, dynamic>>().toList();
    final occasion = (look['occasion'] as String?)?.trim();
    final season = (look['season'] as String?)?.trim();
    final notes = (look['notes'] as String?)?.trim();
    final score = (look['matchScore'] as num?)?.toInt() ?? 0;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => SafeArea(
        child: Container(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(sheetContext).size.height * .88),
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
          decoration: const BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
          child: SingleChildScrollView(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Center(child: Container(width: 38, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(99)))),
              const SizedBox(height: 20),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('SAVED LOOK', style: TextStyle(fontSize: 9, letterSpacing: 1.3, fontWeight: FontWeight.w800, color: AppColors.textMuted)),
                  const SizedBox(height: 5),
                  Text(occasion?.isNotEmpty == true ? occasion! : 'Your saved outfit', style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w800, letterSpacing: -.5)),
                  const SizedBox(height: 4),
                  const Text('A look worth coming back to.', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                ])),
                Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), decoration: BoxDecoration(color: AppColors.sage.withValues(alpha: .20), borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.sage.withValues(alpha: .35))), child: Column(children: [Text('$score%', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.success)), const Text('MATCH', style: TextStyle(fontSize: 8, letterSpacing: .8, fontWeight: FontWeight.w800, color: AppColors.success))])),
              ]),
              const SizedBox(height: 22),
              Row(children: [const Text('YOUR OUTFIT', style: TextStyle(fontSize: 9, letterSpacing: 1.3, fontWeight: FontWeight.w800, color: AppColors.textMuted)), const Spacer(), Text('${pieces.length} ${pieces.length == 1 ? 'piece' : 'pieces'}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.textSecondary))]),
              const SizedBox(height: 10),
              if (pieces.isEmpty)
                Container(width: double.infinity, padding: const EdgeInsets.all(18), decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.border)), child: const Row(children: [Icon(Icons.checkroom_outlined, color: AppColors.primary), SizedBox(width: 10), Expanded(child: Text('Some wardrobe pieces are no longer available.', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)))]))
              else
                SizedBox(height: 205, child: ListView.separated(scrollDirection: Axis.horizontal, itemCount: pieces.length, separatorBuilder: (_, _) => const SizedBox(width: 10), itemBuilder: (_, index) {
                  final item = pieces[index];
                  final imageUrl = item['imageUrl'] as String? ?? '';
                  return SizedBox(width: 142, child: Container(decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.border)), clipBehavior: Clip.antiAlias, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(child: imageUrl.isEmpty ? Container(width: double.infinity, color: AppColors.surfaceMuted, child: const Center(child: Icon(Icons.checkroom_outlined, color: AppColors.primary, size: 30))) : CachedNetworkImage(imageUrl: imageUrl, fit: BoxFit.cover, width: double.infinity)),
                    Padding(padding: const EdgeInsets.fromLTRB(11, 9, 11, 10), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(item['name'] as String? ?? 'Wardrobe piece', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800)), const SizedBox(height: 3), Text('${item['category'] ?? ''}${item['colour'] == null ? '' : ' · ${item['colour']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 9.5, color: AppColors.textMuted))]))
                  ])));
                })),
              const SizedBox(height: 20),
              Row(children: [Expanded(child: _lookInfoTile(icon: Icons.palette_outlined, label: 'PALETTE', value: season?.isNotEmpty == true ? season! : 'Your colours')), const SizedBox(width: 10), Expanded(child: _lookInfoTile(icon: Icons.auto_awesome_outlined, label: 'MATCH', value: score >= 85 ? 'Excellent' : score >= 70 ? 'Great' : 'Good'))]),
              if (notes?.isNotEmpty == true) ...[
                const SizedBox(height: 18),
                const Text('NOTES', style: TextStyle(fontSize: 9, letterSpacing: 1.3, fontWeight: FontWeight.w800, color: AppColors.textMuted)),
                const SizedBox(height: 8),
                Container(width: double.infinity, padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.border)), child: Text(notes!, style: const TextStyle(fontSize: 12, height: 1.45, color: AppColors.textSecondary))),
              ],
              const SizedBox(height: 20),
              SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: () => Navigator.pop(sheetContext), icon: const Icon(Icons.check_rounded), label: const Text('Done'))),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _lookInfoTile({required IconData icon, required String label, required String value}) {
    return Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.border)), child: Row(children: [Container(width: 34, height: 34, decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: .10), shape: BoxShape.circle), child: Icon(icon, size: 17, color: AppColors.primary)), const SizedBox(width: 9), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(fontSize: 8, letterSpacing: .9, fontWeight: FontWeight.w800, color: AppColors.textMuted)), const SizedBox(height: 3), Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800))]))]));
  }

  @override
  Widget build(BuildContext context) {
    final visibleLooks = _visibleLooks;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Saved Looks', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)), centerTitle: true, backgroundColor: AppColors.background, elevation: 0, scrolledUnderElevation: 0, actions: [IconButton(tooltip: 'Sort saved looks', onPressed: _showSortSheet, icon: const Icon(Icons.swap_vert_rounded)), IconButton(tooltip: 'Refresh', onPressed: _load, icon: const Icon(Icons.refresh_rounded))]),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.cloud_off_rounded, color: AppColors.primary, size: 38), const SizedBox(height: 12), Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary)), const SizedBox(height: 14), FilledButton(onPressed: _load, child: const Text('Try again'))]))
              : RefreshIndicator(onRefresh: _load, child: CustomScrollView(physics: const AlwaysScrollableScrollPhysics(), slivers: [SliverToBoxAdapter(child: _buildHeader()), if (_looks.isEmpty) SliverFillRemaining(hasScrollBody: false, child: _emptyState()) else if (visibleLooks.isEmpty) SliverFillRemaining(hasScrollBody: false, child: _filteredEmptyState()) else SliverPadding(padding: const EdgeInsets.fromLTRB(20, 4, 20, 32), sliver: SliverList.separated(itemCount: visibleLooks.length, itemBuilder: (_, index) => _lookCard(visibleLooks[index]), separatorBuilder: (_, _) => const SizedBox(height: 12)))])),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 13, 20, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('VYEA  /  LOOKBOOK', style: TextStyle(fontSize: 9.5, letterSpacing: 1.45, fontWeight: FontWeight.w900, color: AppColors.primary)),
        const SizedBox(height: 8),
        const Text('Looks worth\ncoming back to.', style: TextStyle(fontSize: 30, height: 1.0, fontWeight: FontWeight.w800, letterSpacing: -1)),
        const SizedBox(height: 8),
        Text(_looks.isEmpty ? 'Save an outfit you love and it will live here.' : '${_looks.length} saved ${_looks.length == 1 ? 'look' : 'looks'} in your personal collection.', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5, height: 1.45)),
        const SizedBox(height: 16),
        SizedBox(height: 38, child: ListView.separated(scrollDirection: Axis.horizontal, itemCount: _filters.length, separatorBuilder: (_, _) => const SizedBox(width: 7), itemBuilder: (_, index) {
          final filter = _filters[index];
          final selected = filter == _occasionFilter;
          return ChoiceChip(label: Text(filter), selected: selected, onSelected: (_) => setState(() => _occasionFilter = filter), selectedColor: AppColors.primary, backgroundColor: AppColors.surface, side: BorderSide(color: selected ? AppColors.primary : AppColors.border), labelStyle: TextStyle(color: selected ? Colors.white : AppColors.textPrimary, fontSize: 11, fontWeight: FontWeight.w700), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(99)), showCheckmark: false);
        })),
        const SizedBox(height: 10),
        Row(children: [const Icon(Icons.sort_rounded, size: 15, color: AppColors.textMuted), const SizedBox(width: 5), Text(_sort == _SavedLookSort.recent ? 'Recently saved' : 'Highest match', style: const TextStyle(fontSize: 10.5, color: AppColors.textSecondary, fontWeight: FontWeight.w700)), if (_sort == _SavedLookSort.highestMatch || _occasionFilter != 'All') Padding(padding: const EdgeInsets.only(left: 8), child: TextButton(onPressed: () => setState(() { _occasionFilter = 'All'; _sort = _SavedLookSort.recent; }), style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 28), tapTargetSize: MaterialTapTargetSize.shrinkWrap), child: const Text('Reset', style: TextStyle(fontSize: 10.5)))]),
      ]),
    );
  }

  Future<void> _showSortSheet() async {
    final selected = await showModalBottomSheet<_SavedLookSort>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Padding(padding: EdgeInsets.fromLTRB(24, 0, 24, 8), child: Align(alignment: Alignment.centerLeft, child: Text('Sort your lookbook', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)))),
        RadioGroup<_SavedLookSort>(groupValue: _sort, onChanged: (value) => Navigator.pop(sheetContext, value), child: Column(mainAxisSize: MainAxisSize.min, children: [RadioListTile<_SavedLookSort>(value: _SavedLookSort.recent, title: const Text('Recently saved')), RadioListTile<_SavedLookSort>(value: _SavedLookSort.highestMatch, title: const Text('Highest match'))])),
        const SizedBox(height: 10),
      ])),
    );
    if (selected != null && mounted) setState(() => _sort = selected);
  }

  Widget _emptyState() {
    return Padding(padding: const EdgeInsets.fromLTRB(28, 54, 28, 32), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Container(width: 72, height: 72, decoration: const BoxDecoration(color: AppColors.secondary, shape: BoxShape.circle), child: const Icon(Icons.bookmark_border_rounded, color: AppColors.primary, size: 34)), const SizedBox(height: 16), const Text('Your lookbook is empty.', textAlign: TextAlign.center, style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800)), const SizedBox(height: 8), const Text('Save an outfit that feels like you and it will stay here for the next time you need it.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary, height: 1.45, fontSize: 12.5))]));
  }

  Widget _filteredEmptyState() {
    return Padding(padding: const EdgeInsets.fromLTRB(28, 54, 28, 32), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.filter_alt_off_rounded, color: AppColors.primary, size: 42), const SizedBox(height: 13), Text('No ${_occasionFilter.toLowerCase()} looks yet', textAlign: TextAlign.center, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)), const SizedBox(height: 7), const Text('Try another category or reset the filter.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5)), const SizedBox(height: 14), TextButton(onPressed: () => setState(() => _occasionFilter = 'All'), child: const Text('Show all looks'))]));
  }

  Widget _lookCard(Map<String, dynamic> look) {
    final ids = List<String>.from(look['itemIds'] ?? const <String>[]);
    final pieces = ids.map(_wardrobeItem).whereType<Map<String, dynamic>>().toList();
    final date = _createdAt(look);
    final occasion = look['occasion'] as String? ?? 'Saved look';
    final score = (look['matchScore'] as num?)?.toInt() ?? 0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openLook(look),
        borderRadius: BorderRadius.circular(26),
        child: Ink(
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(26), border: Border.all(color: AppColors.border)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(padding: const EdgeInsets.fromLTRB(16, 15, 12, 0), child: Row(children: [Expanded(child: Text(occasion, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800))), IconButton(tooltip: 'Remove saved look', onPressed: () => _deleteLook(look['id'] as String? ?? ''), icon: const Icon(Icons.more_horiz_rounded))])),
            Padding(padding: const EdgeInsets.fromLTRB(16, 2, 16, 0), child: Row(children: [Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5), decoration: BoxDecoration(color: AppColors.sage.withValues(alpha: .20), borderRadius: BorderRadius.circular(99)), child: Text('$score% match', style: const TextStyle(color: AppColors.success, fontSize: 10, fontWeight: FontWeight.w800))), const SizedBox(width: 8), if (date != null) Text(_formatDate(date), style: const TextStyle(color: AppColors.textMuted, fontSize: 10.5)), const Spacer(), Text('${pieces.length} pieces', style: const TextStyle(color: AppColors.textSecondary, fontSize: 10.5))])),
            const SizedBox(height: 13),
            SizedBox(height: 160, child: pieces.isEmpty ? Container(margin: const EdgeInsets.symmetric(horizontal: 16), decoration: BoxDecoration(color: AppColors.surfaceMuted, borderRadius: BorderRadius.circular(18)), child: const Center(child: Text('Some wardrobe pieces are unavailable', style: TextStyle(color: AppColors.textSecondary, fontSize: 11)))) : ListView.separated(padding: const EdgeInsets.symmetric(horizontal: 16), scrollDirection: Axis.horizontal, itemCount: pieces.length, separatorBuilder: (_, _) => const SizedBox(width: 9), itemBuilder: (_, index) { final url = pieces[index]['imageUrl'] as String? ?? ''; return ClipRRect(borderRadius: BorderRadius.circular(18), child: SizedBox(width: 118, child: url.isEmpty ? Container(color: AppColors.surfaceMuted, child: const Center(child: Icon(Icons.checkroom_outlined, color: AppColors.primary))) : CachedNetworkImage(imageUrl: url, fit: BoxFit.cover))); })),
            const SizedBox(height: 13),
            Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 16), child: Row(children: [const Icon(Icons.arrow_forward_rounded, color: AppColors.primary, size: 17), const SizedBox(width: 6), const Text('Open lookbook view', style: TextStyle(fontSize: 10.5, color: AppColors.primary, fontWeight: FontWeight.w800)), const Spacer(), const Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.textMuted)])),
          ]),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}
