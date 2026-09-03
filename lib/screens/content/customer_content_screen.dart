import 'package:cloud_firestore/cloud_firestore.dart';
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

  final List<String> _types = const ['All', 'Learning', 'Colour Guide', 'Style Tip', 'AI Styling'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('TiB Learning')),
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
            final matchesQuery = _query.isEmpty || title.contains(_query) || description.contains(_query) || type.toLowerCase().contains(_query);
            return matchesType && matchesQuery;
          }).toList();

          return RefreshIndicator(
            onRefresh: () async => setState(() {}),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
              children: [
                const Text('Learn, discover and style better', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
                const SizedBox(height: 6),
                Text('Content published by your TiB styling team.', style: TextStyle(color: AppColors.textSecondary)),
                const SizedBox(height: 16),
                TextField(
                  onChanged: (value) => setState(() => _query = value.trim().toLowerCase()),
                  decoration: InputDecoration(
                    hintText: 'Search articles, guides and tips',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _types.map((type) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(type),
                        selected: _filter == type,
                        showCheckmark: false,
                        onSelected: (_) => setState(() => _filter = type),
                      ),
                    )).toList(),
                  ),
                ),
                const SizedBox(height: 18),
                if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData)
                  const Padding(
                    padding: EdgeInsets.only(top: 120),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (visible.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 120),
                    child: Center(
                      child: Column(
                        children: [
                          const Icon(Icons.menu_book_outlined, size: 54, color: AppColors.primary),
                          const SizedBox(height: 12),
                          const Text('No content available', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 6),
                          Text('Check another category or try a different search.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                  )
                else
                  ...visible.map((doc) => _contentCard(context, doc.data())),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _contentCard(BuildContext context, Map<String, dynamic> data) {
    final title = data['title'] as String? ?? 'Untitled';
    final description = data['description'] as String? ?? '';
    final body = data['body'] as String? ?? '';
    final type = data['type'] as String? ?? 'Learning';
    final featured = data['isFeatured'] as bool? ?? false;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColors.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => _openArticle(context, title, description, body, type),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(color: AppColors.secondary, borderRadius: BorderRadius.circular(15)),
                child: const Icon(Icons.menu_book_outlined, color: AppColors.primary),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
                        if (featured) const Icon(Icons.star_rounded, size: 18, color: AppColors.primary),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(description, maxLines: 3, overflow: TextOverflow.ellipsis, style: TextStyle(color: AppColors.textSecondary, height: 1.4, fontSize: 12)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                      decoration: BoxDecoration(color: AppColors.surfaceMuted, borderRadius: BorderRadius.circular(10)),
                      child: Text(type, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.primaryDark)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }

  void _openArticle(BuildContext context, String title, String description, String body, String type) {
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
              Text(type.toUpperCase(), style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: AppColors.primary, letterSpacing: 1.2)),
              const SizedBox(height: 8),
              Text(title, style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w900, height: 1.08)),
              const SizedBox(height: 10),
              Text(description, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.45)),
              const SizedBox(height: 22),
              Text(body, style: const TextStyle(fontSize: 14, height: 1.65)),
            ],
          ),
        ),
      ),
    );
  }
}
