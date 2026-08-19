import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';

class LearningScreen extends StatefulWidget {
  const LearningScreen({super.key});

  @override
  State<LearningScreen> createState() => _LearningScreenState();
}

class _LearningScreenState extends State<LearningScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String selectedCategory = 'All';
  bool _isPremium = false;
  bool _premiumLoaded = false;

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
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid != null && !_premiumLoaded) {
      _loadPremiumStatus(uid);
    }

    return Scaffold(
      backgroundColor: AppColors.background,
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
            ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          _buildPremiumStatusBanner(),
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


  Future<void> _loadPremiumStatus(String uid) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(uid)
          .get();

      if (!mounted ||
          FirebaseAuth.instance.currentUser?.uid != uid) {
        return;
      }

      setState(() {
        _isPremium = snapshot.data()?['isPremium'] == true;
        _premiumLoaded = true;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isPremium = false;
        _premiumLoaded = true;
      });
    }
  }

  Widget _buildPremiumStatusBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 11,
      ),
      decoration: BoxDecoration(
        color: _isPremium ? AppColors.secondary : AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: AppColors.border,
        ),
      ),
      child: Row(
        children: [
          Icon(
            _isPremium
                ? Icons.workspace_premium
                : Icons.menu_book_outlined,
            size: 20,
            color: AppColors.primary,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              _isPremium
                  ? 'Premium access is active — enjoy all learning content.'
                  : 'Free access — Premium guides are marked with a lock.',
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showPremiumRequiredDialog() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Row(
          children: [
            Icon(
              Icons.workspace_premium_outlined,
              color: AppColors.primary,
            ),
            SizedBox(width: 8),
            Expanded(
              child: Text('Premium Guide'),
            ),
          ],
        ),
        content: const Text(
          'This learning guide is available to Premium members. '
          'Premium access is managed by your administrator.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

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
    final isPremiumContent =
        data['isPremium'] as bool? ??
        data['premiumOnly'] as bool? ??
        false;

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: AppColors.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(
          color: AppColors.border,
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
            isPremiumContent: isPremiumContent,
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
                        const Icon(
                          Icons.star,
                          color: AppColors.primary,
                          size: 20,
                        ),
                      if (isPremiumContent) ...[
                        const SizedBox(width: 7),
                        const Icon(
                          Icons.workspace_premium_outlined,
                          color: AppColors.primary,
                          size: 19,
                        ),
                      ],
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

                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        isPremiumContent
                            ? (_isPremium
                                ? 'Read Premium guide'
                                : 'Premium guide')
                            : 'Explore this guide',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(
                        isPremiumContent && !_isPremium
                            ? Icons.lock_outline
                            : Icons.arrow_forward_ios,
                        size: 15,
                      ),
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
            color: AppColors.secondary,
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
            color: AppColors.secondary,
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
        color: AppColors.secondary,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        type,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppColors.primaryDark,
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
    required bool isPremiumContent,
  }) {
    if (isPremiumContent && !_isPremium) {
      _showPremiumRequiredDialog();
      return;
    }

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
          isPremiumContent: isPremiumContent,
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
              const Icon(
                Icons.menu_book_outlined,
                size: 70,
                color: AppColors.textMuted,
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
                  style: const TextStyle(color: AppColors.textSecondary),
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
            const Text(
              'Please check your connection and try again.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary),
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
  final bool isPremiumContent;

  const _ContentDetailScreen({
    required this.title,
    required this.description,
    required this.body,
    required this.type,
    required this.imageUrl,
    required this.isFeatured,
    required this.isPremiumContent,
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
                  const Icon(
                    Icons.star,
                    color: AppColors.primary,
                  ),
                ],
                if (isPremiumContent) ...[
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.workspace_premium_outlined,
                    color: AppColors.primary,
                  ),
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
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Featured guide',
                      style: TextStyle(
                        color: AppColors.primaryDark,
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
        color: AppColors.secondary,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        type,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.primaryDark,
        ),
      ),
    );
  }
}
