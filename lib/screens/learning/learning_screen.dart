import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class LearningScreen extends StatefulWidget {
  const LearningScreen({super.key});

  @override
  State<LearningScreen> createState() => _LearningScreenState();
}

class _LearningScreenState extends State<LearningScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String selectedCategory = 'All';

  final List<String> categories = const [
    'All',
    'Learning',
    'Colour Guide',
    'Style Tip',
    'AI Styling',
  ];

  Query<Map<String, dynamic>> get contentQuery {
    return _firestore
        .collection('content')
        .where('isPublished', isEqualTo: true)
        .orderBy('createdAt', descending: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDF9F6),
      appBar: AppBar(
        title: const Text('Learning'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () => setState(() {}),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          _buildCategoryFilter(),
          const SizedBox(height: 8),
          Expanded(child: _buildContentList()),
        ],
      ),
    );
  }

  // ============================================================
  // HEADER
  // ============================================================

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Learn & Discover',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            'Explore colour, styling and personal fashion tips.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade700),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // CATEGORY FILTER
  // ============================================================

  Widget _buildCategoryFilter() {
    return SizedBox(
      height: 54,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (_, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final category = categories[index];

          return ChoiceChip(
            label: Text(category),
            selected: selectedCategory == category,
            onSelected: (_) {
              setState(() {
                selectedCategory = category;
              });
            },
          );
        },
      ),
    );
  }

  // ============================================================
  // FIRESTORE CONTENT
  // ============================================================

  Widget _buildContentList() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: contentQuery.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return _buildErrorState(snapshot.error.toString());
        }

        final documents = snapshot.data?.docs ?? [];

        final filteredDocuments = documents.where((document) {
          if (selectedCategory == 'All') {
            return true;
          }

          final data = document.data();

          final type = data['type'] as String? ?? '';

          return type == selectedCategory;
        }).toList();

        if (filteredDocuments.isEmpty) {
          return _buildEmptyState();
        }

        return RefreshIndicator(
          onRefresh: () async {
            setState(() {});
          },
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
            itemCount: filteredDocuments.length,
            separatorBuilder: (_, index) => const SizedBox(height: 14),
            itemBuilder: (context, index) {
              return _buildContentCard(filteredDocuments[index]);
            },
          ),
        );
      },
    );
  }

  // ============================================================
  // CONTENT CARD
  // ============================================================

  Widget _buildContentCard(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();

    final title = data['title'] as String? ?? 'Untitled';

    final description = data['description'] as String? ?? '';

    final body = data['body'] as String? ?? '';

    final type = data['type'] as String? ?? 'Learning';

    final imageUrl = data['imageUrl'] as String? ?? '';

    final isFeatured = data['isFeatured'] as bool? ?? false;

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: Colors.white,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(
          color: Color(0xFFF0DDD2),
        ),
      ),
      child: InkWell(
        onTap: () {
          _openContent(
            title: title,
            description: description,
            body: body,
            type: type,
            imageUrl: imageUrl,
            isFeatured: isFeatured,
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (imageUrl.isNotEmpty) _buildImage(imageUrl),

            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (isFeatured)
                        const Icon(Icons.star, color: Colors.amber, size: 20),
                    ],
                  ),

                  const SizedBox(height: 8),

                  _buildCategoryLabel(type),

                  if (description.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      description,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],

                  const SizedBox(height: 14),

                  const Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        'Explore this guide',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      SizedBox(width: 6),
                      Icon(Icons.arrow_forward_ios, size: 13),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // IMAGE
  // ============================================================

  Widget _buildImage(String imageUrl) {
    return SizedBox(
      width: double.infinity,
      height: 180,
      child: Image.network(
        imageUrl,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            color: const Color(0xFFF5D8C7),
            child: const Center(
              child: Icon(Icons.image_not_supported_outlined, size: 45),
            ),
          );
        },
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) {
            return child;
          }

          return Container(
            color: const Color(0xFFF5D8C7),
            child: const Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
              ),
            ),
          );
        },
      ),
    );
  }

  // ============================================================
  // CATEGORY LABEL
  // ============================================================

  Widget _buildCategoryLabel(String type) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFF5D8C7),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        type,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Color(0xFF8B5E4B),
        ),
      ),
    );
  }

  // ============================================================
  // OPEN CONTENT
  // ============================================================

  void _openContent({
    required String title,
    required String description,
    required String body,
    required String type,
    required String imageUrl,
    required bool isFeatured,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _ContentDetailScreen(
          title: title,
          description: description,
          body: body,
          type: type,
          imageUrl: imageUrl,
          isFeatured: isFeatured,
        ),
      ),
    );
  }

  // ============================================================
  // EMPTY STATE
  // ============================================================

  Widget _buildEmptyState() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 130),
        Center(
          child: Column(
            children: [
              Icon(
                Icons.menu_book_outlined,
                size: 70,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 16),
              Text(
                'Nothing to learn here yet',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  'New colour guides, styling tips and fashion lessons will appear here when they’re published.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ============================================================
  // ERROR STATE
  // ============================================================

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 60),
            const SizedBox(height: 16),
            const Text(
              'We couldn’t load the learning content.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Please check your connection and try again.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () {
                setState(() {});
              },
              child: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }
}

// ================================================================
// CONTENT DETAIL SCREEN
// ================================================================

class _ContentDetailScreen extends StatelessWidget {
  final String title;
  final String description;
  final String body;
  final String type;
  final String imageUrl;
  final bool isFeatured;

  const _ContentDetailScreen({
    required this.title,
    required this.description,
    required this.body,
    required this.type,
    required this.imageUrl,
    required this.isFeatured,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Learn & Discover'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (imageUrl.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Image.network(
                  imageUrl,
                  width: double.infinity,
                  height: 220,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return const SizedBox.shrink();
                  },
                ),
              ),

            if (imageUrl.isNotEmpty) const SizedBox(height: 20),

            Row(
              children: [
                _buildDetailCategory(context, type),
                if (isFeatured) ...[
                  const SizedBox(width: 8),
                  const Icon(Icons.star, color: Colors.amber),
                ],
              ],
            ),

            const SizedBox(height: 18),

            if (isFeatured)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    const Icon(
                      Icons.auto_awesome,
                      size: 16,
                      color: Color(0xFFC58F73),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Featured guide',
                      style: TextStyle(
                        color: Colors.brown.shade600,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),

            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),

            if (description.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(description, style: Theme.of(context).textTheme.titleMedium),
            ],

            const SizedBox(height: 24),

            const Divider(),

            const SizedBox(height: 24),

            Text(
              body.isNotEmpty
                  ? body
                  : 'This guide does not have additional details yet.',
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(height: 1.6),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailCategory(BuildContext context, String type) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFF5D8C7),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        type,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Color(0xFF8B5E4B),
        ),
      ),
    );
  }
}
