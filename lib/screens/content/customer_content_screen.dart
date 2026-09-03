import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../services/content_service.dart';

class CustomerContentScreen extends StatefulWidget {
  const CustomerContentScreen({super.key});

  @override
  State<CustomerContentScreen> createState() => _CustomerContentScreenState();
}

class _CustomerContentScreenState extends State<CustomerContentScreen> {
  String _filter = 'All';
  String _query = '';
  bool _isPremium = false;

  final List<String> _types = const [
    'All',
    'Learning',
    'Colour Guide',
    'Style Tip',
    'AI Styling',
  ];

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
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('TiB Style Hub'),
        centerTitle: false,
      ),
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
                    const Text('Unable to load Style Hub', style: TextStyle(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 6),
                    Text(
                      'Please check your connection and try again.',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            );
          }

          final docs = [...?snapshot.data?.docs];
          docs.sort((a, b) {
            final aFeatured = a.data()['isFeatured'] == true;
            final bFeatured = b.data()['isFeatured'] == true;
            if (aFeatured != bFeatured) return aFeatured ? -1 : 1;
            final aValue = a.data()['createdAt'];
            final bValue = b.data()['createdAt'];
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
            final matchesQuery = _query.isEmpty ||
                title.contains(_query) ||
                description.contains(_query) ||
                type.toLowerCase().contains(_query);
            return matchesType && matchesQuery;
          }).toList();

          final featured = visible.where((doc) => doc.data()['isFeatured'] == true).take(3).toList();
          final feed = visible.where((doc) => doc.data()['isFeatured'] != true).toList();

          return RefreshIndicator(
            onRefresh: _loadMembership,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 34),
              children: [
                _heroHeader(),
                const SizedBox(height: 16),
                _searchBar(),
                const SizedBox(height: 12),
                _filterChips(),
                if (featured.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  _sectionHeader('Featured for you', 'Hand-picked by TiB'),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 190,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: featured.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (context, index) => _featuredCard(context, featured[index]),
                    ),
                  ),
                ],
                const SizedBox(height: 22),
                _sectionHeader('Community feed', 'Discover. Learn. Discuss.'),
                const SizedBox(height: 10),
                if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData)
                  const Padding(
                    padding: EdgeInsets.only(top: 120),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (visible.isEmpty)
                  _emptyState()
                else if (feed.isEmpty)
                  ...featured.map((doc) => _feedCard(context, doc))
                else
                  ...feed.map((doc) => _feedCard(context, doc)),
                const SizedBox(height: 10),
                _communityPrompt(context),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _heroHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primarySoft,
            AppColors.secondary,
          ],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'TiB STYLE HUB',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.1),
                    ),
                    if (_isPremium) ...[
                      const SizedBox(width: 8),
                      const Icon(Icons.workspace_premium_rounded, size: 18, color: AppColors.premiumAccentDark),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Find your next\nstyle inspiration.',
                  style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900, height: 1.05),
                ),
                const SizedBox(height: 7),
                Text(
                  'Tips, guides and ideas from your TiB styling team.',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5, height: 1.35),
                ),
              ],
            ),
          ),
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              color: AppColors.background,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.primarySoft),
            ),
            child: const Icon(Icons.auto_awesome_rounded, color: AppColors.primary, size: 29),
          ),
        ],
      ),
    );
  }

  Widget _searchBar() {
    return TextField(
      onChanged: (value) => setState(() => _query = value.trim().toLowerCase()),
      decoration: InputDecoration(
        hintText: 'Search styling tips, colours or guides',
        prefixIcon: const Icon(Icons.search),
        filled: true,
        fillColor: AppColors.surfaceMuted,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.primarySoft),
        ),
      ),
    );
  }

  Widget _filterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _types
            .map(
              (type) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(type),
                  selected: _filter == type,
                  showCheckmark: false,
                  onSelected: (_) => setState(() => _filter = type),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _sectionHeader(String title, String subtitle) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
              const SizedBox(height: 3),
              Text(subtitle, style: TextStyle(color: AppColors.textSecondary, fontSize: 11.5)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _featuredCard(BuildContext context, QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final title = data['title'] as String? ?? 'TiB Guide';
    final description = data['description'] as String? ?? '';
    final type = data['type'] as String? ?? 'Learning';
    final premium = data['isPremium'] == true;

    return SizedBox(
      width: 280,
      child: Material(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: () => _openArticle(context, doc),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: premium ? AppColors.premiumAccentLight : AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _typeBadge(type),
                    const Spacer(),
                    if (premium) const Icon(Icons.lock_outline_rounded, size: 17, color: AppColors.primary),
                  ],
                ),
                const SizedBox(height: 13),
                Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, height: 1.15)),
                const SizedBox(height: 7),
                Expanded(
                  child: Text(description, maxLines: 3, overflow: TextOverflow.ellipsis, style: TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.4)),
                ),
                const SizedBox(height: 8),
                const Row(
                  children: [
                    Icon(Icons.arrow_forward_rounded, size: 16, color: AppColors.primary),
                    SizedBox(width: 5),
                    Text('Read story', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.primaryDark)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _feedCard(BuildContext context, QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final title = data['title'] as String? ?? 'Untitled';
    final description = data['description'] as String? ?? '';
    final type = data['type'] as String? ?? 'Learning';
    final premium = data['isPremium'] as bool? ?? false;
    final createdAt = data['createdAt'];
    final date = createdAt is Timestamp ? createdAt.toDate() : null;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: premium ? AppColors.premiumAccentLight : AppColors.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => _openArticle(context, doc),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(15, 15, 12, 15),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: premium ? AppColors.premiumAccentLight : AppColors.secondary,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  premium ? Icons.workspace_premium_outlined : _typeIcon(type),
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w850)),
                        ),
                        const Icon(Icons.more_horiz_rounded, size: 18, color: AppColors.textMuted),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(description, maxLines: 3, overflow: TextOverflow.ellipsis, style: TextStyle(color: AppColors.textSecondary, height: 1.4, fontSize: 12)),
                    const SizedBox(height: 9),
                    Row(
                      children: [
                        _typeBadge(type),
                        const SizedBox(width: 8),
                        if (date != null)
                          Text(_relativeDate(date), style: const TextStyle(fontSize: 10.5, color: AppColors.textMuted)),
                      ],
                    ),
                    const SizedBox(height: 11),
                    Row(
                      children: [
                        _socialAction(Icons.favorite_border_rounded, 'Like'),
                        const SizedBox(width: 18),
                        _socialAction(Icons.bookmark_border_rounded, 'Save'),
                        const SizedBox(width: 18),
                        _socialAction(Icons.chat_bubble_outline_rounded, 'Discuss'),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _communityPrompt(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.primaryDark,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          const Icon(Icons.forum_outlined, color: Colors.white, size: 28),
          const SizedBox(width: 13),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Have a styling question?', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900)),
                SizedBox(height: 4),
                Text('Ask TiB and turn inspiration into your next look.', style: TextStyle(color: Colors.white70, fontSize: 11.5, height: 1.35)),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_forward_rounded, color: Colors.white),
            tooltip: 'Back to your style tools',
          ),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return Padding(
      padding: const EdgeInsets.only(top: 90),
      child: Center(
        child: Column(
          children: [
            const Icon(Icons.explore_outlined, size: 54, color: AppColors.primary),
            const SizedBox(height: 12),
            const Text('Nothing here yet', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(
              'Try another category or search for a different styling topic.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _typeBadge(String type) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(color: AppColors.surfaceMuted, borderRadius: BorderRadius.circular(10)),
      child: Text(type, style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: AppColors.primaryDark)),
    );
  }

  Widget _socialAction(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: AppColors.textMuted),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 10.5, color: AppColors.textMuted, fontWeight: FontWeight.w700)),
      ],
    );
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'Colour Guide':
        return Icons.palette_outlined;
      case 'Style Tip':
        return Icons.checkroom_outlined;
      case 'AI Styling':
        return Icons.auto_awesome_outlined;
      default:
        return Icons.menu_book_outlined;
    }
  }

  String _relativeDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    if (difference.inDays >= 1) return '${difference.inDays}d ago';
    if (difference.inHours >= 1) return '${difference.inHours}h ago';
    if (difference.inMinutes >= 1) return '${difference.inMinutes}m ago';
    return 'Just now';
  }

  void _openArticle(BuildContext context, QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final premium = data['isPremium'] as bool? ?? false;
    if (premium && !_isPremium) {
      showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Premium Content'),
          content: const Text('This article is available to Premium members. Your current account does not have Premium access.'),
          actions: [
            FilledButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Got it')),
          ],
        ),
      );
      return;
    }

    final title = data['title'] as String? ?? 'TiB Story';
    final description = data['description'] as String? ?? '';
    final body = data['body'] as String? ?? '';
    final type = data['type'] as String? ?? 'Learning';

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: AppColors.background,
      builder: (sheetContext) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(sheetContext).height * .82,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(22, 4, 22, 30),
            children: [
              _typeBadge(type),
              const SizedBox(height: 12),
              Text(title, style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w900, height: 1.08)),
              const SizedBox(height: 10),
              Text(description, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.45)),
              const SizedBox(height: 22),
              Text(body, style: const TextStyle(fontSize: 14, height: 1.65)),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(child: OutlinedButton.icon(onPressed: () {}, icon: const Icon(Icons.favorite_border_rounded), label: const Text('Like'))),
                  const SizedBox(width: 10),
                  Expanded(child: OutlinedButton.icon(onPressed: () {}, icon: const Icon(Icons.bookmark_border_rounded), label: const Text('Save'))),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => Navigator.pop(sheetContext),
                  icon: const Icon(Icons.forum_outlined),
                  label: const Text('Join discussion'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
