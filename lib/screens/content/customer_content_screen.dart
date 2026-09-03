import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../services/content_service.dart';
import '../forum/customer_forum_screen.dart';

class CustomerContentScreen extends StatefulWidget {
  const CustomerContentScreen({super.key});

  @override
  State<CustomerContentScreen> createState() => _CustomerContentScreenState();
}

class _CustomerContentScreenState extends State<CustomerContentScreen> {
  String _filter = 'All';
  String _query = '';
  bool _isPremium = false;

  final List<String> _types = const ['All', 'Learning', 'Colour Guide', 'Style Tip', 'AI Styling'];

  @override
  void initState() {
    super.initState();
    _loadMembership();
  }

  Future<void> _loadMembership() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final snapshot = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (!mounted) return;
      setState(() => _isPremium = snapshot.data()?['isPremium'] as bool? ?? false);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('TiB Style Hub'),
        actions: [
          IconButton(
            tooltip: 'Forum',
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CustomerForumScreen())),
            icon: const Icon(Icons.forum_outlined),
          ),
        ],
      ),
      backgroundColor: AppColors.background,
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: ContentService.publishedContentStream(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.cloud_off_outlined, size: 46),
                    const SizedBox(height: 12),
                    const Text('Unable to load TiB content', style: TextStyle(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 6),
                    Text('Please check your connection and try again.', style: TextStyle(color: AppColors.textSecondary)),
                  ],
                ),
              ),
            );
          }

          final docs = [...?snapshot.data?.docs];
          docs.sort((a, b) {
            final aData = a.data();
            final bData = b.data();
            final aFeatured = aData['isFeatured'] == true;
            final bFeatured = bData['isFeatured'] == true;
            if (aFeatured != bFeatured) return aFeatured ? -1 : 1;
            final aValue = aData['createdAt'];
            final bValue = bData['createdAt'];
            final aDate = aValue is Timestamp ? aValue.toDate() : DateTime.fromMillisecondsSinceEpoch(0);
            final bDate = bValue is Timestamp ? bValue.toDate() : DateTime.fromMillisecondsSinceEpoch(0);
            return bDate.compareTo(aDate);
          });

          final visible = docs.where((doc) {
            final data = doc.data();
            final title = (data['title'] as String? ?? '').toLowerCase();
            final description = (data['description'] as String? ?? '').toLowerCase();
            final type = data['type'] as String? ?? 'Learning';
            final matchesType = _filter == 'All' || type == _filter;
            final matchesQuery = _query.isEmpty || title.contains(_query) || description.contains(_query) || type.toLowerCase().contains(_query);
            return matchesType && matchesQuery;
          }).toList();
          final featured = visible.where((doc) => doc.data()['isFeatured'] == true).take(3).toList();
          final feed = visible.where((doc) => doc.data()['isFeatured'] != true).toList();

          return RefreshIndicator(
            onRefresh: _loadMembership,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
              children: [
                Row(
                  children: [
                    const Expanded(child: Text('TiB Style Hub', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900))),
                    if (_isPremium) const Chip(label: Text('PREMIUM'), avatar: Icon(Icons.workspace_premium_outlined, size: 15)),
                  ],
                ),
                const SizedBox(height: 5),
                Text('Discover styling ideas and content from the TiB team.', style: TextStyle(color: AppColors.textSecondary, height: 1.35)),
                const SizedBox(height: 16),
                Card(
                  elevation: 0,
                  color: AppColors.secondary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CustomerForumScreen())),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 15, 14, 15),
                      child: Row(
                        children: [
                          Container(width: 46, height: 46, decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(14)), child: const Icon(Icons.forum_outlined, color: AppColors.primary)),
                          const SizedBox(width: 12),
                          const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('TiB Forum', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14.5)), SizedBox(height: 3), Text('Ask, share and discuss styling with the whole TiB community.', style: TextStyle(fontSize: 11.5, height: 1.35))])),
                          const Icon(Icons.chevron_right_rounded, color: AppColors.primary),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  onChanged: (value) => setState(() => _query = value.trim().toLowerCase()),
                  decoration: InputDecoration(hintText: 'Search content', prefixIcon: const Icon(Icons.search), border: OutlineInputBorder(borderRadius: BorderRadius.circular(16))),
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _types.map((type) => Padding(padding: const EdgeInsets.only(right: 8), child: ChoiceChip(label: Text(type), selected: _filter == type, showCheckmark: false, onSelected: (_) => setState(() => _filter = type)))).toList(),
                  ),
                ),
                const SizedBox(height: 20),
                if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData)
                  const Padding(padding: EdgeInsets.only(top: 100), child: Center(child: CircularProgressIndicator()))
                else if (visible.isEmpty)
                  Padding(padding: const EdgeInsets.only(top: 100), child: Center(child: Column(children: [const Icon(Icons.menu_book_outlined, size: 54, color: AppColors.primary), const SizedBox(height: 12), const Text('No content available', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)), const SizedBox(height: 6), Text('Try another category or search term.', style: TextStyle(color: AppColors.textSecondary))])))
                else ...[
                  if (featured.isNotEmpty) ...[
                    const Text('FEATURED', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.2, color: AppColors.textSecondary)),
                    const SizedBox(height: 9),
                    SizedBox(height: 176, child: ListView.separated(scrollDirection: Axis.horizontal, itemCount: featured.length, separatorBuilder: (_, __) => const SizedBox(width: 10), itemBuilder: (context, index) => _featuredCard(context, featured[index].data()))),
                    const SizedBox(height: 24),
                  ],
                  Row(children: [const Expanded(child: Text('STYLE FEED', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.2, color: AppColors.textSecondary))), Text('${feed.length} posts', style: TextStyle(fontSize: 10.5, color: AppColors.textMuted))]),
                  const SizedBox(height: 9),
                  if (feed.isEmpty) const Text('Featured content is available above.', style: TextStyle(color: AppColors.textSecondary)) else ...feed.map((doc) => _contentCard(context, doc.data())),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _featuredCard(BuildContext context, Map<String, dynamic> data) {
    final title = data['title'] as String? ?? 'TiB Guide';
    final description = data['description'] as String? ?? '';
    final type = data['type'] as String? ?? 'Learning';
    final premium = data['isPremium'] as bool? ?? false;
    return SizedBox(
      width: 270,
      child: Card(
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: AppColors.primarySoft)),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _openArticle(context, title, description, data['body'] as String? ?? '', type, premium),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [_typeBadge(type), const Spacer(), const Icon(Icons.star_rounded, size: 18, color: AppColors.primary)]),
              const SizedBox(height: 14),
              Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, height: 1.15)),
              const SizedBox(height: 7),
              Expanded(child: Text(description, maxLines: 3, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11.5, height: 1.35, color: AppColors.textSecondary))),
              const SizedBox(height: 6),
              Row(children: [const Icon(Icons.arrow_forward_rounded, size: 16, color: AppColors.primary), const SizedBox(width: 5), const Text('Read', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: AppColors.primaryDark)), if (premium) ...[const Spacer(), const Icon(Icons.lock_outline_rounded, size: 15, color: AppColors.primary)]]),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _contentCard(BuildContext context, Map<String, dynamic> data) {
    final title = data['title'] as String? ?? 'Untitled';
    final description = data['description'] as String? ?? '';
    final body = data['body'] as String? ?? '';
    final type = data['type'] as String? ?? 'Learning';
    final featured = data['isFeatured'] as bool? ?? false;
    final premium = data['isPremium'] as bool? ?? false;
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: premium ? AppColors.premiumAccentLight : AppColors.border)),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => _openArticle(context, title, description, body, type, premium),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(width: 54, height: 54, decoration: BoxDecoration(color: premium ? AppColors.premiumAccentLight : AppColors.secondary, borderRadius: BorderRadius.circular(16)), child: Icon(premium ? Icons.workspace_premium_outlined : _typeIcon(type), color: AppColors.primary)),
            const SizedBox(width: 13),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              const SizedBox(height: 5),
              Text(description, maxLines: 3, overflow: TextOverflow.ellipsis, style: TextStyle(color: AppColors.textSecondary, height: 1.4, fontSize: 12)),
              const SizedBox(height: 9),
              Row(children: [_typeBadge(type), if (featured) ...[const SizedBox(width: 8), const Icon(Icons.star_rounded, size: 17, color: AppColors.primary)]]),
              const SizedBox(height: 11),
              SizedBox(width: double.infinity, child: OutlinedButton.icon(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CustomerForumScreen())), icon: const Icon(Icons.forum_outlined, size: 16), label: const Text('Discuss in Forum')),
            ])),
            const SizedBox(width: 5),
            const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
          ]),
        ),
      ),
    );
  }

  Widget _typeBadge(String type) => Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5), decoration: BoxDecoration(color: AppColors.surfaceMuted, borderRadius: BorderRadius.circular(10)), child: Text(type, style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: AppColors.primaryDark)));

  IconData _typeIcon(String type) {
    switch (type) {
      case 'Colour Guide': return Icons.palette_outlined;
      case 'Style Tip': return Icons.tips_and_updates_outlined;
      case 'AI Styling': return Icons.auto_awesome_outlined;
      default: return Icons.menu_book_outlined;
    }
  }

  void _openArticle(BuildContext context, String title, String description, String body, String type, bool premium) {
    if (premium && !_isPremium) {
      showDialog<void>(context: context, builder: (dialogContext) => AlertDialog(title: const Text('Premium Content'), content: const Text('This article is available to Premium members. Your current account does not have Premium access.'), actions: [FilledButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Got it'))]));
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(sheetContext).height * .82,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(22, 4, 22, 30),
            children: [
              Row(children: [Expanded(child: Text(type.toUpperCase(), style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: AppColors.primary, letterSpacing: 1.2))), if (premium) const Icon(Icons.workspace_premium_outlined, color: AppColors.primary, size: 20)]),
              const SizedBox(height: 8),
              Text(title, style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w900, height: 1.08)),
              const SizedBox(height: 10),
              Text(description, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.45)),
              const SizedBox(height: 22),
              Text(body, style: const TextStyle(fontSize: 14, height: 1.65)),
              const SizedBox(height: 22),
              SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: () { Navigator.pop(sheetContext); Navigator.push(context, MaterialPageRoute(builder: (_) => const CustomerForumScreen())); }, icon: const Icon(Icons.forum_outlined), label: const Text('Discuss in TiB Forum'))),
            ],
          ),
        ),
      ),
    );
  }
}
