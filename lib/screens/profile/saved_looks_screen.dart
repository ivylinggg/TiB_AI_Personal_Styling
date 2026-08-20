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

class _SavedLooksScreenState extends State<SavedLooksScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _looks = const [];
  List<Map<String, dynamic>> _wardrobe = const [];

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
          .map((item) => <String, dynamic>{
                'id': item.id,
                'name': item.name,
                'category': item.category,
                'colour': item.colour,
                'imageUrl': item.imageUrl,
              })
          .toList();

      if (!mounted) return;
      setState(() {
        _looks = saved;
        _wardrobe = wardrobe;
        _loading = false;
      });
    } catch (e) {
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

  Future<void> _deleteLook(String lookId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove saved look?'),
        content: const Text('This saved outfit will be removed from your collection.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep it'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await FirestoreService.deleteSavedOutfitLook(uid, lookId);
      if (!mounted) return;
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saved look removed.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to remove that look right now.')),
      );
    }
  }

  void _openLook(Map<String, dynamic> look) {
    final ids = List<String>.from(look['itemIds'] ?? const <String>[]);
    final pieces = ids.map(_wardrobeItem).whereType<Map<String, dynamic>>().toList();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return SafeArea(
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 22),
            decoration: const BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  '${look['occasion'] ?? 'Saved look'}',
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  'A look you saved with TiB',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
                const SizedBox(height: 16),
                if (pieces.isEmpty)
                  const Text(
                    'Some wardrobe pieces are no longer available.',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  )
                else
                  SizedBox(
                    height: 190,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: pieces.length,
                      separatorBuilder: (_, index) => const SizedBox(width: 10),
                      itemBuilder: (_, index) {
                        final item = pieces[index];
                        final imageUrl = item['imageUrl'] as String? ?? '';
                        return SizedBox(
                          width: 132,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: imageUrl.isEmpty
                                      ? Container(
                                          color: AppColors.surfaceMuted,
                                          child: const Center(
                                            child: Icon(Icons.checkroom_outlined, color: AppColors.primary),
                                          ),
                                        )
                                      : CachedNetworkImage(
                                          imageUrl: imageUrl,
                                          fit: BoxFit.cover,
                                          width: double.infinity,
                                        ),
                                ),
                              ),
                              const SizedBox(height: 7),
                              Text(
                                item['name'] as String? ?? 'Wardrobe piece',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800),
                              ),
                              Text(
                                '${item['category'] ?? ''} · ${item['colour'] ?? ''}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 9.5, color: AppColors.textMuted),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    const Icon(Icons.palette_outlined, size: 16, color: AppColors.primary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Built around ${look['season'] ?? 'your'} colours',
                        style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.sage.withValues(alpha: .22),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        '${look['matchScore'] ?? 0}% match',
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.success),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Saved Looks'),
        centerTitle: true,
        backgroundColor: AppColors.background,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.cloud_off_rounded, color: AppColors.primary, size: 38),
                        const SizedBox(height: 12),
                        Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary)),
                        const SizedBox(height: 14),
                        FilledButton(onPressed: _load, child: const Text('Try again')),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: _looksEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(20, 60, 20, 32),
                          children: [
                            const Icon(Icons.bookmark_border_rounded, color: AppColors.primary, size: 48),
                            const SizedBox(height: 14),
                            const Text(
                              'No saved looks yet',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'When an AI outfit feels like you, save it here and come back to it later.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: AppColors.textSecondary, height: 1.45, fontSize: 12.5),
                            ),
                          ],
                        )
                      : ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                          itemCount: _looks.length,
                          separatorBuilder: (_, index) => const SizedBox(height: 12),
                          itemBuilder: (_, index) => _lookCard(_looks[index]),
                        ),
                ),
    );
  }

  bool get _looksEmpty => _looks.isEmpty;

  Widget _lookCard(Map<String, dynamic> look) {
    final ids = List<String>.from(look['itemIds'] ?? const <String>[]);
    final pieces = ids.map(_wardrobeItem).whereType<Map<String, dynamic>>().toList();
    final date = _createdAt(look);
    final occasion = look['occasion'] as String? ?? 'Saved look';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openLook(look),
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          padding: const EdgeInsets.all(13),
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
                  Expanded(
                    child: Text(
                      occasion,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Remove saved look',
                    onPressed: () => _deleteLook(look['id'] as String? ?? ''),
                    icon: const Icon(Icons.more_horiz_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(
                    '${look['matchScore'] ?? 0}% match',
                    style: const TextStyle(color: AppColors.success, fontSize: 10.5, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(width: 8),
                  if (date != null)
                    Text(
                      _formatDate(date),
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 10.5),
                    ),
                  const Spacer(),
                  Text(
                    '${pieces.length} pieces',
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 10.5),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 118,
                child: pieces.isEmpty
                    ? Container(
                        decoration: BoxDecoration(
                          color: AppColors.surfaceMuted,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Center(
                          child: Text('Some wardrobe pieces are unavailable', style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                        ),
                      )
                    : ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: pieces.length,
                        separatorBuilder: (_, index) => const SizedBox(width: 9),
                        itemBuilder: (_, index) {
                          final url = pieces[index]['imageUrl'] as String? ?? '';
                          return ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: SizedBox(
                              width: 92,
                              child: url.isEmpty
                                  ? Container(
                                      color: AppColors.surfaceMuted,
                                      child: const Icon(Icons.checkroom_outlined, color: AppColors.primary),
                                    )
                                  : CachedNetworkImage(imageUrl: url, fit: BoxFit.cover),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final months = const [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}
