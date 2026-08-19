import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import 'content_detail_screen.dart';

class ContentManagementScreen extends StatefulWidget {
  const ContentManagementScreen({super.key});

  @override
  State<ContentManagementScreen> createState() =>
      _ContentManagementScreenState();
}

class _ContentManagementScreenState extends State<ContentManagementScreen> {
  final TextEditingController searchController = TextEditingController();

  List<QueryDocumentSnapshot<Map<String, dynamic>>> contents = [];

  List<QueryDocumentSnapshot<Map<String, dynamic>>> filteredContents = [];

  bool isLoading = true;

  String selectedType = 'All';

  final List<String> contentTypes = const [
    'All',
    'Learning',
    'Colour Guide',
    'Style Tip',
    'AI Styling',
  ];

  @override
  void initState() {
    super.initState();

    loadContents();

    searchController.addListener(filterContents);
  }

  @override
  void dispose() {
    searchController.removeListener(filterContents);
    searchController.dispose();
    super.dispose();
  }

  // ============================================================
  // LOAD CONTENT
  // ============================================================

  Future<void> loadContents() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('content')
          .orderBy('createdAt', descending: true)
          .get();

      if (!mounted) {
        return;
      }

      setState(() {
        contents = snapshot.docs;
        filteredContents = snapshot.docs;
        isLoading = false;
      });

      filterContents();
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'We couldn’t load the content. Please try again.',
          ),
        ),
      );
    }
  }

  // ============================================================
  // FILTER CONTENT
  // ============================================================

  void filterContents() {
    final query = searchController.text.trim().toLowerCase();

    if (!mounted) {
        return;
      }

    setState(() {
      filteredContents = contents.where((document) {
        final data = document.data();

        final title = (data['title'] as String? ?? '').toLowerCase();

        final description = (data['description'] as String? ?? '')
            .toLowerCase();

        final type = data['type'] as String? ?? 'Learning';

        final matchesSearch =
            query.isEmpty ||
            title.contains(query) ||
            description.contains(query);

        final matchesType = selectedType == 'All' || type == selectedType;

        return matchesSearch && matchesType;
      }).toList();
    });
  }

  // ============================================================
  // CREATE CONTENT
  // ============================================================

  Future<void> createContent() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => const _ContentFormDialog(),
    );

    if (result == true) {
      await loadContents();
    }
  }

  // ============================================================
  // EDIT CONTENT
  // ============================================================

  Future<void> editContent(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) async {
    final data = document.data();

    final result = await showDialog<bool>(
      context: context,
      builder: (_) => _ContentFormDialog(
        documentId: document.id,
        initialTitle: data['title'] as String? ?? '',
        initialDescription: data['description'] as String? ?? '',
        initialBody: data['body'] as String? ?? '',
        initialType: data['type'] as String? ?? 'Learning',
        initialPublished: data['isPublished'] as bool? ?? false,
        initialFeatured: data['isFeatured'] as bool? ?? false,
        initialPremium: data['isPremium'] as bool? ?? false,
      ),
    );

    if (result == true) {
      await loadContents();
    }
  }

  // ============================================================
  // PUBLISH / UNPUBLISH
  // ============================================================

  Future<void> togglePublished(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) async {
    final data = document.data();

    final current = data['isPublished'] as bool? ?? false;

    final title = data['title'] as String? ?? 'this content';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(current ? 'Unpublish Content?' : 'Publish Content?'),
        content: Text(
          current
              ? '“$title” will no longer be shown to customers.'
              : '“$title” will become visible to customers.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(current ? 'Unpublish' : 'Publish'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    try {
      await FirebaseFirestore.instance
          .collection('content')
          .doc(document.id)
          .update({
            'isPublished': !current,
            'updatedAt': FieldValue.serverTimestamp(),
          });

      if (!mounted) {
        return;
      }

      await loadContents();

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            current ? 'Content unpublished.' : 'Content published.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not update this content. Please try again.',
          ),
        ),
      );
    }
  }

  // ============================================================
  // DELETE CONTENT
  // ============================================================

  Future<void> deleteContent(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) async {
    final data = document.data();

    final title = data['title'] as String? ?? 'this content';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete Content?'),
          content: Text('Are you sure you want to delete "$title"?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      await FirebaseFirestore.instance
          .collection('content')
          .doc(document.id)
          .delete();

      if (!mounted) {
        return;
      }

      await loadContents();

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Content deleted successfully.')),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not delete this content. Please try again.',
          ),
        ),
      );
    }
  }

  // ============================================================
  // OPEN CONTENT PREVIEW
  // ============================================================

  void openContentDetail(BuildContext context, Map<String, dynamic> data) {
    final createdAt = data['createdAt'] as Timestamp?;

    final updatedAt = data['updatedAt'] as Timestamp?;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ContentDetailScreen(
          title: data['title'] as String? ?? 'Untitled',

          description: data['description'] as String? ?? '',

          body: data['body'] as String? ?? '',

          type: data['type'] as String? ?? 'Learning',

          isPublished: data['isPublished'] as bool? ?? false,

          isFeatured: data['isFeatured'] as bool? ?? false,

          isPremium: data['isPremium'] as bool? ?? false,

          createdAt: createdAt?.toDate(),

          updatedAt: updatedAt?.toDate(),
        ),
      ),
    );
  }

  // ============================================================
  // STATUS CHIP
  // ============================================================

  Widget buildStatusChip(String text, bool active) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: active ? AppColors.success.withValues(alpha: 0.12) : AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: active ? AppColors.success : AppColors.textSecondary,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Content Management'),

        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: loadContents,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            onPressed: createContent,
            icon: const Icon(Icons.add),
            tooltip: 'Create Content',
          ),
        ],
      ),

      floatingActionButton: FloatingActionButton.extended(
        onPressed: createContent,
        icon: const Icon(Icons.add),
        label: const Text('Create'),
      ),

      body: RefreshIndicator(
        onRefresh: loadContents,

        child: Column(
          children: [
            // ==================================================
            // SEARCH
            // ==================================================
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),

              child: TextField(
                controller: searchController,

                decoration: InputDecoration(
                  hintText: 'Search content...',

                  prefixIcon: const Icon(Icons.search),

                  suffixIcon: searchController.text.isNotEmpty
                      ? IconButton(
                          onPressed: () {
                            searchController.clear();
                          },
                          icon: const Icon(Icons.clear),
                        )
                      : null,

                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),

            // ==================================================
            // FILTER
            // ==================================================
            SizedBox(
              height: 48,

              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 20),

                scrollDirection: Axis.horizontal,

                itemCount: contentTypes.length,

                separatorBuilder: (context, index) => const SizedBox(width: 8),

                itemBuilder: (context, index) {
                  final type = contentTypes[index];

                  return ChoiceChip(
                    label: Text(type),
                    selected: selectedType == type,
                    showCheckmark: false,

                    onSelected: (_) {
                      setState(() {
                        selectedType = type;
                      });

                      filterContents();
                    },
                  );
                },
              ),
            ),

            const SizedBox(height: 12),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${filteredContents.length} content item${filteredContents.length == 1 ? '' : 's'}',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 8),

            // ==================================================
            // CONTENT LIST
            // ==================================================
            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : filteredContents.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),

                      children: [
                        const SizedBox(height: 150),
                        Center(
                          child: Column(
                            children: [
                              const Icon(
                                Icons.library_books_outlined,
                                size: 64,
                                color: AppColors.primary,
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'No content found',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                searchController.text.trim().isEmpty &&
                                        selectedType == 'All'
                                    ? 'Create your first learning resource to show it here.'
                                    : 'Try a different search or content type.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    )
                  : ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),

                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),

                      itemCount: filteredContents.length,

                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 10),

                      itemBuilder: (context, index) {
                        final document = filteredContents[index];

                        final data = document.data();

                        final title = data['title'] as String? ?? 'Untitled';

                        final description =
                            data['description'] as String? ?? '';

                        final type = data['type'] as String? ?? 'Learning';

                        final isPublished =
                            data['isPublished'] as bool? ?? false;

                        final isFeatured = data['isFeatured'] as bool? ?? false;

                        final isPremiumContent =
                            data['isPremium'] as bool? ?? false;

                        return Card(
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                            side: const BorderSide(
                              color: AppColors.border,
                            ),
                          ),
                          child: ListTile(
                            onTap: () {
                              openContentDetail(context, data);
                            },

                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),

                            leading: CircleAvatar(
                              backgroundColor: AppColors.secondary,

                              child: const Icon(
                                Icons.library_books_outlined,
                                color: AppColors.primary,
                              ),
                            ),

                            title: Text(
                              title,

                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),

                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,

                              children: [
                                if (description.isNotEmpty) ...[
                                  const SizedBox(height: 4),

                                  Text(
                                    description,

                                    maxLines: 2,

                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],

                                const SizedBox(height: 8),

                                Wrap(
                                  spacing: 6,

                                  runSpacing: 6,

                                  children: [
                                    Chip(
                                      label: Text(type),

                                      visualDensity: VisualDensity.compact,
                                    ),

                                    buildStatusChip(
                                      isPublished ? 'PUBLISHED' : 'DRAFT',
                                      isPublished,
                                    ),

                                    if (isFeatured)
                                      buildStatusChip('FEATURED', true),

                                    if (isPremiumContent)
                                      buildStatusChip('PREMIUM', true),
                                  ],
                                ),
                              ],
                            ),

                            trailing: PopupMenuButton<String>(
                              onSelected: (value) {
                                switch (value) {
                                  case 'view':
                                    openContentDetail(context, data);
                                    break;

                                  case 'edit':
                                    editContent(document);
                                    break;

                                  case 'publish':
                                    togglePublished(document);
                                    break;

                                  case 'delete':
                                    deleteContent(document);
                                    break;
                                }
                              },

                              itemBuilder: (context) => [
                                const PopupMenuItem(
                                  value: 'view',
                                  child: Text('View'),
                                ),

                                const PopupMenuItem(
                                  value: 'edit',
                                  child: Text('Edit'),
                                ),

                                PopupMenuItem(
                                  value: 'publish',
                                  child: Text(
                                    isPublished ? 'Unpublish' : 'Publish',
                                  ),
                                ),

                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Text('Delete'),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ================================================================
// CONTENT FORM DIALOG
// ================================================================

class _ContentFormDialog extends StatefulWidget {
  final String? documentId;

  final String initialTitle;

  final String initialDescription;

  final String initialBody;

  final String initialType;

  final bool initialPublished;

  final bool initialFeatured;

  final bool initialPremium;

  const _ContentFormDialog({
    this.documentId,
    this.initialTitle = '',
    this.initialDescription = '',
    this.initialBody = '',
    this.initialType = 'Learning',
    this.initialPublished = false,
    this.initialFeatured = false,
    this.initialPremium = false,
  });

  @override
  State<_ContentFormDialog> createState() => _ContentFormDialogState();
}

class _ContentFormDialogState extends State<_ContentFormDialog> {
  late final TextEditingController titleController;

  late final TextEditingController descriptionController;

  late final TextEditingController bodyController;

  late String selectedType;

  late bool isPublished;

  late bool isFeatured;

  late bool isPremium;

  bool isSaving = false;

  final List<String> types = const [
    'Learning',
    'Colour Guide',
    'Style Tip',
    'AI Styling',
  ];

  @override
  void initState() {
    super.initState();

    titleController = TextEditingController(text: widget.initialTitle);

    descriptionController = TextEditingController(
      text: widget.initialDescription,
    );

    bodyController = TextEditingController(text: widget.initialBody);

    selectedType = widget.initialType;

    isPublished = widget.initialPublished;

    isFeatured = widget.initialFeatured;

    isPremium = widget.initialPremium;
  }

  @override
  void dispose() {
    titleController.dispose();
    descriptionController.dispose();
    bodyController.dispose();

    super.dispose();
  }

  // ============================================================
  // SAVE
  // ============================================================

  Future<void> save() async {
    final title = titleController.text.trim();

    final description = descriptionController.text.trim();

    final body = bodyController.text.trim();

    if (title.isEmpty || description.isEmpty || body.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please complete the title, description and content fields.',
          ),
        ),
      );
      return;
    }

    if (!mounted) {
      return;
    }

    setState(() {
      isSaving = true;
    });

    try {
      final collection = FirebaseFirestore.instance.collection('content');

      if (widget.documentId == null) {
        await collection.add({
          'title': title,
          'description': description,
          'body': body,
          'type': selectedType,
          'isPublished': isPublished,
          'isFeatured': isFeatured,
          'isPremium': isPremium,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        await collection.doc(widget.documentId).update({
          'title': title,
          'description': description,
          'body': body,
          'type': selectedType,
          'isPublished': isPublished,
          'isFeatured': isFeatured,
          'isPremium': isPremium,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      if (!mounted) {
        return;
      }

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        isSaving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not save this content. Please try again.',
          ),
        ),
      );
    }
  }

  // ============================================================
  // FORM UI
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.documentId != null;

    return AlertDialog(
      title: Text(isEditing ? 'Edit Content' : 'Create Content'),

      content: SizedBox(
        width: 500,

        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,

            children: [
              TextField(
                controller: titleController,

                decoration: const InputDecoration(
                  labelText: 'Title *',
                  prefixIcon: Icon(Icons.title),
                ),
              ),

              const SizedBox(height: 16),

              TextField(
                controller: descriptionController,

                maxLines: 3,

                decoration: const InputDecoration(
                  labelText: 'Short Description *',
                  alignLabelWithHint: true,
                  prefixIcon: Icon(Icons.short_text),
                ),
              ),

              const SizedBox(height: 16),

              DropdownButtonFormField<String>(
                initialValue: selectedType,

                decoration: const InputDecoration(
                  labelText: 'Content Type',
                  prefixIcon: Icon(Icons.category_outlined),
                ),

                items: types
                    .map(
                      (type) =>
                          DropdownMenuItem(value: type, child: Text(type)),
                    )
                    .toList(),

                onChanged: (value) {
                  if (value == null) {
                    return;
                  }

                  setState(() {
                    selectedType = value;
                  });
                },
              ),

              const SizedBox(height: 16),

              TextField(
                controller: bodyController,

                maxLines: 8,

                decoration: const InputDecoration(
                  labelText: 'Content *',
                  alignLabelWithHint: true,
                  prefixIcon: Icon(Icons.article_outlined),
                ),
              ),

              const SizedBox(height: 12),

              SwitchListTile(
                contentPadding: EdgeInsets.zero,

                title: const Text('Published'),

                subtitle: const Text(
                  'Published content can be shown to customers.',
                ),

                value: isPublished,

                onChanged: (value) {
                  setState(() {
                    isPublished = value;
                  });
                },
              ),

              SwitchListTile(
                contentPadding: EdgeInsets.zero,

                title: const Text('Featured'),

                subtitle: const Text(
                  'Highlight this content in the customer app.',
                ),

                value: isFeatured,

                onChanged: (value) {
                  setState(() {
                    isFeatured = value;
                  });
                },
              ),

              SwitchListTile(
                contentPadding: EdgeInsets.zero,

                title: const Text('Premium Content'),

                subtitle: const Text(
                  'Only Premium members can open this content. Free members see a Premium access message.',
                ),

                value: isPremium,

                onChanged: (value) {
                  setState(() {
                    isPremium = value;
                  });
                },
              ),
            ],
          ),
        ),
      ),

      actions: [
        TextButton(
          onPressed: isSaving
              ? null
              : () {
                  Navigator.pop(context, false);
                },
          child: const Text('Cancel'),
        ),

        FilledButton.icon(
          onPressed: isSaving ? null : save,

          icon: isSaving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.background,
                  ),
                )
              : const Icon(Icons.save),

          label: Text(isSaving ? 'Saving...' : 'Save'),
        ),
      ],
    );
  }
}
