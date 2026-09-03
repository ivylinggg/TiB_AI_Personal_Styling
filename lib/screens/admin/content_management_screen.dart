import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import 'content_detail_screen.dart';

class ContentManagementScreen extends StatefulWidget {
  const ContentManagementScreen({super.key});

  @override
  State<ContentManagementScreen> createState() => _ContentManagementScreenState();
}

class _ContentManagementScreenState extends State<ContentManagementScreen> {
  final TextEditingController searchController = TextEditingController();
  List<QueryDocumentSnapshot<Map<String, dynamic>>> contents = [];
  List<QueryDocumentSnapshot<Map<String, dynamic>>> filteredContents = [];
  bool isLoading = true;
  String selectedType = 'All';
  String selectedStatus = 'All';
  bool featuredOnly = false;

  final List<String> contentTypes = const ['All', 'Learning', 'Colour Guide', 'Style Tip', 'AI Styling'];
  final List<String> contentStatuses = const ['All', 'Published', 'Draft', 'Premium'];

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

  Future<void> loadContents() async {
    if (mounted) setState(() => isLoading = true);
    try {
      final snapshot = await FirebaseFirestore.instance.collection('content').get();
      final docs = snapshot.docs.toList()
        ..sort((a, b) => _dateValue(b.data()['createdAt']).compareTo(_dateValue(a.data()['createdAt'])));
      if (!mounted) return;
      setState(() {
        contents = docs;
        isLoading = false;
      });
      filterContents();
    } on FirebaseException catch (error) {
      if (!mounted) return;
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not load content: ${error.message ?? error.code}')));
    } catch (_) {
      if (!mounted) return;
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not load content. Please try again.')));
    }
  }

  DateTime _dateValue(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  void filterContents() {
    if (!mounted) return;
    final query = searchController.text.trim().toLowerCase();
    final results = contents.where((document) {
      final data = document.data();
      final title = (data['title'] as String? ?? '').toLowerCase();
      final description = (data['description'] as String? ?? '').toLowerCase();
      final type = data['type'] as String? ?? 'Learning';
      final published = data['isPublished'] as bool? ?? false;
      final featured = data['isFeatured'] as bool? ?? false;
      final premium = data['isPremium'] as bool? ?? false;
      final matchesSearch = query.isEmpty || title.contains(query) || description.contains(query) || type.toLowerCase().contains(query);
      final matchesType = selectedType == 'All' || type == selectedType;
      final matchesStatus = switch (selectedStatus) {
        'Published' => published,
        'Draft' => !published,
        'Premium' => premium,
        _ => true,
      };
      return matchesSearch && matchesType && matchesStatus && (!featuredOnly || featured);
    }).toList();
    setState(() => filteredContents = results);
  }

  Future<void> createContent() async {
    final result = await showDialog<bool>(context: context, builder: (_) => const _ContentFormDialog());
    if (result == true) await loadContents();
  }

  Future<void> editContent(QueryDocumentSnapshot<Map<String, dynamic>> document) async {
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
    if (result == true) await loadContents();
  }

  Future<void> togglePublished(QueryDocumentSnapshot<Map<String, dynamic>> document) async {
    final data = document.data();
    final current = data['isPublished'] as bool? ?? false;
    final title = data['title'] as String? ?? 'this content';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(current ? 'Unpublish Content?' : 'Publish Content?'),
        content: Text(current ? '“$title” will no longer be shown to customers.' : '“$title” will become visible to customers.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: Text(current ? 'Unpublish' : 'Publish')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await document.reference.update({'isPublished': !current, 'updatedAt': FieldValue.serverTimestamp()});
      if (!mounted) return;
      await loadContents();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(current ? 'Content unpublished.' : 'Content published to all customers.')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not update this content. Please try again.')));
    }
  }

  Future<void> deleteContent(QueryDocumentSnapshot<Map<String, dynamic>> document) async {
    final title = document.data()['title'] as String? ?? 'this content';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Content?'),
        content: Text('Are you sure you want to delete "$title"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await document.reference.delete();
      if (!mounted) return;
      await loadContents();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Content deleted successfully.')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not delete this content. Please try again.')));
    }
  }

  void openContentDetail(BuildContext context, Map<String, dynamic> data) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ContentDetailScreen(
          title: data['title'] as String? ?? 'Untitled',
          description: data['description'] as String? ?? '',
          body: data['body'] as String? ?? '',
          type: data['type'] as String? ?? 'Learning',
          isPublished: data['isPublished'] as bool? ?? false,
          isFeatured: data['isFeatured'] as bool? ?? false,
          isPremium: data['isPremium'] as bool? ?? false,
          createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
          updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
        ),
      ),
    );
  }

  Future<void> _announcePublishedContent({required String title, required String body, required String contentId, required String type}) async {
    final users = await FirebaseFirestore.instance.collection('users').get();
    final batch = FirebaseFirestore.instance.batch();
    for (final user in users.docs) {
      final ref = user.reference.collection('notifications').doc();
      batch.set(ref, {
        'title': 'New TiB content',
        'body': body,
        'type': 'content',
        'contentId': contentId,
        'contentType': type,
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
    if (users.docs.isNotEmpty) await batch.commit();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Content Management'),
        actions: [
          IconButton(tooltip: 'Refresh', onPressed: isLoading ? null : loadContents, icon: const Icon(Icons.refresh)),
          IconButton(tooltip: 'Create Content', onPressed: createContent, icon: const Icon(Icons.add)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(onPressed: createContent, icon: const Icon(Icons.add), label: const Text('Create')),
      body: RefreshIndicator(
        onRefresh: loadContents,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
              child: TextField(
                controller: searchController,
                decoration: InputDecoration(hintText: 'Search title, description or type...', prefixIcon: const Icon(Icons.search), suffixIcon: searchController.text.isEmpty ? null : IconButton(onPressed: searchController.clear, icon: const Icon(Icons.clear)), border: OutlineInputBorder(borderRadius: BorderRadius.circular(16))),
              ),
            ),
            SizedBox(
              height: 48,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                scrollDirection: Axis.horizontal,
                itemCount: contentTypes.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (_, index) => ChoiceChip(label: Text(contentTypes[index]), selected: selectedType == contentTypes[index], showCheckmark: false, onSelected: (_) { setState(() => selectedType = contentTypes[index]); filterContents(); }),
              ),
            ),
            const SizedBox(height: 4),
            SizedBox(
              height: 48,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                scrollDirection: Axis.horizontal,
                itemCount: contentStatuses.length + 1,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (_, index) {
                  if (index == contentStatuses.length) return FilterChip(label: const Text('Featured only'), selected: featuredOnly, showCheckmark: false, onSelected: (value) { setState(() => featuredOnly = value); filterContents(); });
                  final status = contentStatuses[index];
                  return ChoiceChip(label: Text(status), selected: selectedStatus == status, showCheckmark: false, onSelected: (_) { setState(() => selectedStatus = status); filterContents(); });
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Align(alignment: Alignment.centerLeft, child: Text('${filteredContents.length} of ${contents.length} content items', style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600))),
            ),
            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : filteredContents.isEmpty
                      ? ListView(physics: const AlwaysScrollableScrollPhysics(), children: const [SizedBox(height: 150), Center(child: Column(children: [Icon(Icons.library_books_outlined, size: 64, color: AppColors.primary), SizedBox(height: 16), Text('No content found', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)), SizedBox(height: 6), Text('Use Create to add your first learning resource.', textAlign: TextAlign.center)]))])
                      : ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                          itemCount: filteredContents.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 10),
                          itemBuilder: (_, index) {
                            final document = filteredContents[index];
                            final data = document.data();
                            final title = data['title'] as String? ?? 'Untitled';
                            final description = data['description'] as String? ?? '';
                            final type = data['type'] as String? ?? 'Learning';
                            final published = data['isPublished'] as bool? ?? false;
                            final featured = data['isFeatured'] as bool? ?? false;
                            final premium = data['isPremium'] as bool? ?? false;
                            return Card(
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: const BorderSide(color: AppColors.border)),
                              child: ListTile(
                                onTap: () => openContentDetail(context, data),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                leading: CircleAvatar(backgroundColor: AppColors.secondary, child: const Icon(Icons.library_books_outlined, color: AppColors.primary)),
                                title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                                subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  if (description.isNotEmpty) ...[const SizedBox(height: 4), Text(description, maxLines: 2, overflow: TextOverflow.ellipsis)],
                                  const SizedBox(height: 8),
                                  Wrap(spacing: 6, runSpacing: 6, children: [Chip(label: Text(type), visualDensity: VisualDensity.compact), _statusChip(published ? 'PUBLISHED' : 'DRAFT', published), if (featured) _statusChip('FEATURED', true), if (premium) _statusChip('PREMIUM', true)]),
                                ]),
                                trailing: PopupMenuButton<String>(
                                  onSelected: (value) {
                                    switch (value) { case 'view': openContentDetail(context, data); break; case 'edit': editContent(document); break; case 'publish': togglePublished(document); break; case 'delete': deleteContent(document); break; }
                                  },
                                  itemBuilder: (_) => [const PopupMenuItem(value: 'view', child: Text('View')), const PopupMenuItem(value: 'edit', child: Text('Edit')), PopupMenuItem(value: 'publish', child: Text(published ? 'Unpublish' : 'Publish')), const PopupMenuItem(value: 'delete', child: Text('Delete'))],
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

class _ContentFormDialog extends StatefulWidget {
  final String? documentId;
  final String initialTitle;
  final String initialDescription;
  final String initialBody;
  final String initialType;
  final bool initialPublished;
  final bool initialFeatured;
  final bool initialPremium;

  const _ContentFormDialog({this.documentId, this.initialTitle = '', this.initialDescription = '', this.initialBody = '', this.initialType = 'Learning', this.initialPublished = false, this.initialFeatured = false, this.initialPremium = false});

  @override
  State<_ContentFormDialog> createState() => _ContentFormDialogState();
}

class _ContentFormDialogState extends State<_ContentFormDialog> {
  late final TextEditingController titleController = TextEditingController(text: widget.initialTitle);
  late final TextEditingController descriptionController = TextEditingController(text: widget.initialDescription);
  late final TextEditingController bodyController = TextEditingController(text: widget.initialBody);
  late String selectedType = widget.initialType;
  late bool isPublished = widget.initialPublished;
  late bool isFeatured = widget.initialFeatured;
  late bool isPremium = widget.initialPremium;
  bool isSaving = false;

  final types = const ['Learning', 'Colour Guide', 'Style Tip', 'AI Styling'];

  @override
  void dispose() {
    titleController.dispose();
    descriptionController.dispose();
    bodyController.dispose();
    super.dispose();
  }

  Future<void> save() async {
    final title = titleController.text.trim();
    final description = descriptionController.text.trim();
    final body = bodyController.text.trim();
    if (title.isEmpty || description.isEmpty || body.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please complete the title, description and content fields.')));
      return;
    }
    setState(() => isSaving = true);
    try {
      final collection = FirebaseFirestore.instance.collection('content');
      final payload = {'title': title, 'description': description, 'body': body, 'type': selectedType, 'isPublished': isPublished, 'isFeatured': isFeatured, 'isPremium': isPremium, 'updatedAt': FieldValue.serverTimestamp()};
      final wasPublished = widget.initialPublished;
      if (widget.documentId == null) {
        final ref = await collection.add({...payload, 'createdAt': FieldValue.serverTimestamp()});
        if (isPublished) {
          final parent = context.findAncestorStateOfType<_ContentManagementScreenState>();
          try {
            await parent?._announcePublishedContent(title: title, body: 'New TiB content is now available: $title', contentId: ref.id, type: selectedType);
          } catch (_) {}
        }
      } else {
        await collection.doc(widget.documentId).update(payload);
        if (!wasPublished && isPublished) {
          final parent = context.findAncestorStateOfType<_ContentManagementScreenState>();
          try {
            await parent?._announcePublishedContent(title: title, body: 'New TiB content is now available: $title', contentId: widget.documentId!, type: selectedType);
          } catch (_) {}
        }
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      setState(() => isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not save content: $error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.documentId != null;
    return AlertDialog(
      title: Text(editing ? 'Edit Content' : 'Create Content'),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: titleController, decoration: const InputDecoration(labelText: 'Title *', prefixIcon: Icon(Icons.title))),
            const SizedBox(height: 16),
            TextField(controller: descriptionController, maxLines: 3, decoration: const InputDecoration(labelText: 'Short Description *', prefixIcon: Icon(Icons.short_text))),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(initialValue: selectedType, decoration: const InputDecoration(labelText: 'Content Type', prefixIcon: Icon(Icons.category_outlined)), items: types.map((type) => DropdownMenuItem(value: type, child: Text(type))).toList(), onChanged: isSaving ? null : (value) { if (value != null) setState(() => selectedType = value); }),
            const SizedBox(height: 16),
            TextField(controller: bodyController, maxLines: 8, decoration: const InputDecoration(labelText: 'Content *', alignLabelWithHint: true, prefixIcon: Icon(Icons.article_outlined))),
            const SizedBox(height: 12),
            SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Published'), value: isPublished, onChanged: isSaving ? null : (value) => setState(() => isPublished = value)),
            SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Featured'), value: isFeatured, onChanged: isSaving ? null : (value) => setState(() => isFeatured = value)),
            SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Premium'), value: isPremium, onChanged: isSaving ? null : (value) => setState(() => isPremium = value)),
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: isSaving ? null : () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton.icon(onPressed: isSaving ? null : save, icon: isSaving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save_rounded), label: Text(isSaving ? 'Saving...' : 'Save')),
      ],
    );
  }
}
