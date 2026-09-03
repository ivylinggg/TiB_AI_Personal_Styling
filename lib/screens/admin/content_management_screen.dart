import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../services/community_service.dart';
import 'content_detail_screen.dart';
import '../forum/customer_forum_screen.dart';

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

  DateTime _dateValue(dynamic value) => value is Timestamp ? value.toDate() : DateTime.fromMillisecondsSinceEpoch(0);

  Future<void> loadContents() async {
    if (mounted) setState(() => isLoading = true);
    try {
      final snapshot = await FirebaseFirestore.instance.collection('content').get();
      final docs = snapshot.docs.toList()..sort((a, b) => _dateValue(b.data()['createdAt']).compareTo(_dateValue(a.data()['createdAt'])));
      if (!mounted) return;
      setState(() {
        contents = docs;
        isLoading = false;
      });
      filterContents();
    } catch (error) {
      if (!mounted) return;
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not load content: $error')));
    }
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
      final searchMatch = query.isEmpty || title.contains(query) || description.contains(query) || type.toLowerCase().contains(query);
      final typeMatch = selectedType == 'All' || type == selectedType;
      final statusMatch = switch (selectedStatus) {
        'Published' => published,
        'Draft' => !published,
        'Premium' => premium,
        _ => true,
      };
      return searchMatch && typeMatch && statusMatch && (!featuredOnly || featured);
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
        content: Text(current ? '“$title” will no longer be shown to customers.' : '“$title” will become visible to customers and connected to the shared TiB Forum.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: Text(current ? 'Unpublish' : 'Publish')),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final willPublish = !current;
      await document.reference.update({'isPublished': willPublish, 'updatedAt': FieldValue.serverTimestamp()});
      if (willPublish) {
        await _publishToCommunity(document.id, data);
      } else {
        await _removeCommunityPostsForContent(document.id);
      }
      if (!mounted) return;
      await loadContents();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(willPublish ? 'Published to customers and shared TiB Forum.' : 'Unpublished and removed from shared TiB Forum.')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not update this content: $error')));
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
      await _removeCommunityPostsForContent(document.id);
      await document.reference.delete();
      if (!mounted) return;
      await loadContents();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Content deleted successfully.')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not delete this content: $error')));
    }
  }

  Future<void> _publishToCommunity(String contentId, Map<String, dynamic> data) async {
    final title = data['title'] as String? ?? 'New TiB content';
    final body = data['body'] as String? ?? data['description'] as String? ?? '';
    final type = data['type'] as String? ?? 'Learning';
    final existing = await FirebaseFirestore.instance.collection('forum_posts').where('contentId', isEqualTo: contentId).limit(1).get();
    if (existing.docs.isEmpty) {
      await CommunityService.createContentForumPost(contentId: contentId, title: title, body: body, type: type);
    }
    await _notifyUsers(title, data['description'] as String? ?? '', contentId, type);
  }

  Future<void> _notifyUsers(String title, String body, String contentId, String type) async {
    final users = await FirebaseFirestore.instance.collection('users').get();
    if (users.docs.isEmpty) return;
    WriteBatch batch = FirebaseFirestore.instance.batch();
    var operations = 0;
    for (final user in users.docs) {
      batch.set(user.reference.collection('notifications').doc(), {
        'title': 'New TiB content: $title',
        'body': body.isEmpty ? 'New content is now available in TiB Style Hub.' : body,
        'type': 'content',
        'contentId': contentId,
        'contentType': type,
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
      operations++;
      if (operations == 450) {
        await batch.commit();
        batch = FirebaseFirestore.instance.batch();
        operations = 0;
      }
    }
    if (operations > 0) await batch.commit();
  }

  Future<void> _removeCommunityPostsForContent(String contentId) async {
    final snapshot = await FirebaseFirestore.instance.collection('forum_posts').where('contentId', isEqualTo: contentId).get();
    for (final post in snapshot.docs) {
      final comments = await post.reference.collection('comments').get();
      final likes = await post.reference.collection('likes').get();
      final batch = FirebaseFirestore.instance.batch();
      for (final comment in comments.docs) batch.delete(comment.reference);
      for (final like in likes.docs) batch.delete(like.reference);
      batch.delete(post.reference);
      await batch.commit();
    }
  }

  void openContentDetail(BuildContext context, Map<String, dynamic> data) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => ContentDetailScreen(
      title: data['title'] as String? ?? 'Untitled',
      description: data['description'] as String? ?? '',
      body: data['body'] as String? ?? '',
      type: data['type'] as String? ?? 'Learning',
      isPublished: data['isPublished'] as bool? ?? false,
      isFeatured: data['isFeatured'] as bool? ?? false,
      isPremium: data['isPremium'] as bool? ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    )));
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
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
            child: TextField(controller: searchController, decoration: InputDecoration(hintText: 'Search title, description or type...', prefixIcon: const Icon(Icons.search), border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)))),
          ),
          SizedBox(height: 48, child: ListView.separated(padding: const EdgeInsets.symmetric(horizontal: 20), scrollDirection: Axis.horizontal, itemCount: contentTypes.length, separatorBuilder: (_, __) => const SizedBox(width: 8), itemBuilder: (_, index) => ChoiceChip(label: Text(contentTypes[index]), selected: selectedType == contentTypes[index], showCheckmark: false, onSelected: (_) { setState(() => selectedType = contentTypes[index]); filterContents(); }))),
          SizedBox(height: 48, child: ListView.separated(padding: const EdgeInsets.symmetric(horizontal: 20), scrollDirection: Axis.horizontal, itemCount: contentStatuses.length, separatorBuilder: (_, __) => const SizedBox(width: 8), itemBuilder: (_, index) { final status = contentStatuses[index]; return ChoiceChip(label: Text(status), selected: selectedStatus == status, showCheckmark: false, onSelected: (_) { setState(() => selectedStatus = status); filterContents(); }); })),
          Padding(padding: const EdgeInsets.fromLTRB(20, 4, 20, 8), child: Align(alignment: Alignment.centerLeft, child: Text('${filteredContents.length} of ${contents.length} content items', style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)))),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : filteredContents.isEmpty
                    ? const Center(child: Text('No content found'))
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                        itemCount: filteredContents.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, index) {
                          final document = filteredContents[index];
                          final data = document.data();
                          final published = data['isPublished'] as bool? ?? false;
                          return Card(
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: const BorderSide(color: AppColors.border)),
                            child: ListTile(
                              onTap: () => openContentDetail(context, data),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              leading: CircleAvatar(backgroundColor: AppColors.secondary, child: const Icon(Icons.library_books_outlined, color: AppColors.primary)),
                              title: Text(data['title'] as String? ?? 'Untitled', style: const TextStyle(fontWeight: FontWeight.w700)),
                              subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                if ((data['description'] as String? ?? '').isNotEmpty) ...[const SizedBox(height: 4), Text(data['description'] as String, maxLines: 2, overflow: TextOverflow.ellipsis)],
                                const SizedBox(height: 8),
                                Wrap(spacing: 6, runSpacing: 6, children: [Chip(label: Text(data['type'] as String? ?? 'Learning'), visualDensity: VisualDensity.compact), _statusChip(published ? 'PUBLISHED' : 'DRAFT', published)]),
                              ]),
                              trailing: PopupMenuButton<String>(
                                onSelected: (value) {
                                  if (value == 'view') openContentDetail(context, data);
                                  if (value == 'edit') editContent(document);
                                  if (value == 'publish') togglePublished(document);
                                  if (value == 'delete') deleteContent(document);
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
    );
  }

  Widget _statusChip(String text, bool active) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(color: active ? AppColors.success.withValues(alpha: .12) : AppColors.surfaceMuted, borderRadius: BorderRadius.circular(20)),
    child: Text(text, style: TextStyle(color: active ? AppColors.success : AppColors.textSecondary, fontSize: 10.5, fontWeight: FontWeight.w800)),
  );
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
      final payload = {
        'title': title,
        'description': description,
        'body': body,
        'type': selectedType,
        'isPublished': isPublished,
        'isFeatured': isFeatured,
        'isPremium': isPremium,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (widget.documentId == null) {
        final document = await collection.add({...payload, 'createdAt': FieldValue.serverTimestamp()});
        if (isPublished) await _publishNewContent(document.id, title, description, body, selectedType);
      } else {
        final wasPublished = widget.initialPublished;
        await collection.doc(widget.documentId).update(payload);
        if (isPublished && !wasPublished) {
          await _publishNewContent(widget.documentId!, title, description, body, selectedType);
        } else if (!isPublished && wasPublished) {
          await _removeForumPost(widget.documentId!);
        } else if (isPublished && wasPublished) {
          await _syncExistingForumPost(widget.documentId!, title, body, selectedType);
        }
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      setState(() => isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not save this content: $error')));
    }
  }

  Future<void> _publishNewContent(String contentId, String title, String description, String body, String type) async {
    final existing = await FirebaseFirestore.instance.collection('forum_posts').where('contentId', isEqualTo: contentId).limit(1).get();
    if (existing.docs.isEmpty) {
      await CommunityService.createContentForumPost(contentId: contentId, title: title, body: body, type: type);
    }
    await _notifyUsers(title, description, contentId, type);
  }

  Future<void> _notifyUsers(String title, String description, String contentId, String type) async {
    final users = await FirebaseFirestore.instance.collection('users').get();
    WriteBatch batch = FirebaseFirestore.instance.batch();
    var operations = 0;
    for (final user in users.docs) {
      batch.set(user.reference.collection('notifications').doc(), {
        'title': 'New TiB content: $title',
        'body': description,
        'type': 'content',
        'contentId': contentId,
        'contentType': type,
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
      operations++;
      if (operations == 450) {
        await batch.commit();
        batch = FirebaseFirestore.instance.batch();
        operations = 0;
      }
    }
    if (operations > 0) await batch.commit();
  }

  Future<void> _syncExistingForumPost(String contentId, String title, String body, String type) async {
    final snapshot = await FirebaseFirestore.instance.collection('forum_posts').where('contentId', isEqualTo: contentId).limit(1).get();
    if (snapshot.docs.isEmpty) {
      await CommunityService.createContentForumPost(contentId: contentId, title: title, body: body, type: type);
      return;
    }
    await snapshot.docs.first.reference.update({'title': title, 'body': body, 'category': type, 'contentTitle': title, 'updatedAt': FieldValue.serverTimestamp()});
  }

  Future<void> _removeForumPost(String contentId) async {
    final snapshot = await FirebaseFirestore.instance.collection('forum_posts').where('contentId', isEqualTo: contentId).get();
    for (final post in snapshot.docs) {
      final comments = await post.reference.collection('comments').get();
      final likes = await post.reference.collection('likes').get();
      final batch = FirebaseFirestore.instance.batch();
      for (final comment in comments.docs) batch.delete(comment.reference);
      for (final like in likes.docs) batch.delete(like.reference);
      batch.delete(post.reference);
      await batch.commit();
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
            DropdownButtonFormField<String>(initialValue: selectedType, decoration: const InputDecoration(labelText: 'Content Type', prefixIcon: Icon(Icons.category_outlined)), items: types.map((type) => DropdownMenuItem(value: type, child: Text(type))).toList(), onChanged: (value) { if (value != null) setState(() => selectedType = value); }),
            const SizedBox(height: 16),
            TextField(controller: bodyController, maxLines: 8, decoration: const InputDecoration(labelText: 'Content *', alignLabelWithHint: true, prefixIcon: Icon(Icons.article_outlined))),
            const SizedBox(height: 12),
            SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Published'), value: isPublished, onChanged: (value) => setState(() => isPublished = value)),
            SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Featured'), value: isFeatured, onChanged: (value) => setState(() => isFeatured = value)),
            SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Premium'), value: isPremium, onChanged: (value) => setState(() => isPremium = value)),
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
