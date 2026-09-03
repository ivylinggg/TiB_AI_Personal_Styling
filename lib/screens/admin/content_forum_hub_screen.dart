import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../forum/customer_forum_screen.dart';
import 'content_detail_screen.dart';

class ContentForumHubScreen extends StatefulWidget {
  const ContentForumHubScreen({super.key});

  @override
  State<ContentForumHubScreen> createState() => _ContentForumHubScreenState();
}

class _ContentForumHubScreenState extends State<ContentForumHubScreen> {
  final _searchController = TextEditingController();
  String _filter = 'All';
  String _query = '';
  static const _filters = ['All', 'Customer Posts', 'TiB Content'];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  DateTime _date(dynamic value) => value is Timestamp
      ? value.toDate()
      : DateTime.fromMillisecondsSinceEpoch(0);

  String _relativeDate(dynamic value) {
    final date = _date(value);
    if (date.millisecondsSinceEpoch == 0) return 'Just now';
    final difference = DateTime.now().difference(date);
    if (difference.inDays > 30) return '${difference.inDays ~/ 30}mo ago';
    if (difference.inDays >= 1) return '${difference.inDays}d ago';
    if (difference.inHours >= 1) return '${difference.inHours}h ago';
    if (difference.inMinutes >= 1) return '${difference.inMinutes}m ago';
    return 'Just now';
  }

  bool _official(Map<String, dynamic> data) =>
      data['isOfficial'] == true || data['source'] == 'admin_content';

  bool _matches(Map<String, dynamic> data) {
    final official = _official(data);
    final title = (data['title'] as String? ?? '').toLowerCase();
    final body = (data['body'] as String? ?? '').toLowerCase();
    final category = (data['category'] as String? ?? 'General').toLowerCase();
    final query = _query.toLowerCase();
    final filterMatch = switch (_filter) {
      'Customer Posts' => !official,
      'TiB Content' => official,
      _ => true,
    };
    return filterMatch &&
        (query.isEmpty ||
            title.contains(query) ||
            body.contains(query) ||
            category.contains(query));
  }

  Future<void> _openPost(QueryDocumentSnapshot<Map<String, dynamic>> doc) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => ForumPostDetailScreen(
          postReference: doc.reference,
          initialData: doc.data(),
          onToggleLike: () async {
            final uid = FirebaseAuth.instance.currentUser?.uid;
            if (uid == null) return;
            final likeRef = doc.reference.collection('likes').doc(uid);
            final existing = await likeRef.get();
            final post = await doc.reference.get();
            final count = (post.data()?['likeCount'] as num?)?.toInt() ?? 0;
            final batch = FirebaseFirestore.instance.batch();
            if (existing.exists) {
              batch.delete(likeRef);
              batch.update(doc.reference, {'likeCount': count > 0 ? count - 1 : 0});
            } else {
              batch.set(likeRef, {'createdAt': FieldValue.serverTimestamp()});
              batch.update(doc.reference, {'likeCount': count + 1});
            }
            await batch.commit();
          },
          onAddComment: (text) async {
            final uid = FirebaseAuth.instance.currentUser?.uid;
            final trimmed = text.trim();
            if (uid == null || trimmed.isEmpty) return false;
            try {
              final user = await FirebaseFirestore.instance.collection('users').doc(uid).get();
              final userData = user.data() ?? <String, dynamic>{};
              final name = (userData['name'] as String?)?.trim();
              final role = userData['role'] as String? ?? 'admin';
              final commentRef = doc.reference.collection('comments').doc();
              final batch = FirebaseFirestore.instance.batch();
              batch.set(commentRef, {
                'body': trimmed,
                'authorId': uid,
                'authorName': name?.isNotEmpty == true ? name : 'TiB Admin',
                'authorRole': role,
                'isOfficial': role == 'admin',
                'createdAt': FieldValue.serverTimestamp(),
              });
              batch.update(doc.reference, {
                'commentCount': FieldValue.increment(1),
                'lastActivityAt': FieldValue.serverTimestamp(),
              });
              await batch.commit();
              return true;
            } catch (_) {
              return false;
            }
          },
        ),
      ),
    );
  }

  Future<void> _deletePost(QueryDocumentSnapshot<Map<String, dynamic>> doc) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete forum post?'),
        content: const Text('This removes the post and its discussion from the shared TiB Forum.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final comments = await doc.reference.collection('comments').get();
      final likes = await doc.reference.collection('likes').get();
      final batch = FirebaseFirestore.instance.batch();
      for (final comment in comments.docs) {
        batch.delete(comment.reference);
      }
      for (final like in likes.docs) {
        batch.delete(like.reference);
      }
      batch.delete(doc.reference);
      await batch.commit();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Forum post removed.')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not delete post: $error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Forum'),
        actions: [
          IconButton(
            tooltip: 'Create forum post',
            onPressed: _createAdminPost,
            icon: const Icon(Icons.add_comment_outlined),
          ),
        ],
      ),
      backgroundColor: AppColors.background,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createAdminPost,
        icon: const Icon(Icons.edit_outlined),
        label: const Text('Create Post'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('forum_posts').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Could not load forum: ${snapshot.error}'));
          }

          final docs = [...?snapshot.data?.docs];
          docs.sort((a, b) {
            final aOfficial = _official(a.data());
            final bOfficial = _official(b.data());
            if (aOfficial != bOfficial) return aOfficial ? -1 : 1;
            final aTime = a.data()['lastActivityAt'] ?? a.data()['createdAt'];
            final bTime = b.data()['lastActivityAt'] ?? b.data()['createdAt'];
            return _date(bTime).compareTo(_date(aTime));
          });
          final visible = docs.where((doc) => _matches(doc.data())).toList();

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Column(
                  children: [
                    TextField(
                      controller: _searchController,
                      onChanged: (value) => setState(() => _query = value.trim()),
                      decoration: InputDecoration(
                        hintText: 'Search forum',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _filters.map((item) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(item),
                            selected: _filter == item,
                            showCheckmark: false,
                            onSelected: (_) => setState(() => _filter = item),
                          ),
                        )).toList(),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: visible.isEmpty
                    ? const Center(child: Text('No forum posts found.'))
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                        itemCount: visible.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final doc = visible[index];
                          final data = doc.data();
                          final official = _official(data);
                          final title = data['title'] as String? ?? 'Untitled';
                          final author = data['authorName'] as String? ?? 'TiB User';
                          final category = data['category'] as String? ?? 'General';
                          final contentId = data['contentId'] as String?;

                          return Card(
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                              side: BorderSide(color: official ? AppColors.primarySoft : AppColors.border),
                            ),
                            child: ListTile(
                              onTap: () => _openPost(doc),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              leading: CircleAvatar(
                                backgroundColor: official ? AppColors.primarySoft : AppColors.secondary,
                                child: Icon(official ? Icons.auto_awesome_outlined : Icons.forum_outlined, color: AppColors.primary),
                              ),
                              title: Row(
                                children: [
                                  Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w800))),
                                  if (official) const Icon(Icons.verified_rounded, size: 17, color: AppColors.primary),
                                ],
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 5),
                                child: Text('$author · $category\n${data['commentCount'] ?? 0} replies · ${_relativeDate(data['lastActivityAt'] ?? data['createdAt'])}'),
                              ),
                              isThreeLine: true,
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (official && contentId != null)
                                    IconButton(
                                      tooltip: 'Open Content',
                                      icon: const Icon(Icons.open_in_new_rounded),
                                      onPressed: () async {
                                        try {
                                          final content = await FirebaseFirestore.instance.collection('content').doc(contentId).get();
                                          if (!content.exists || !context.mounted) return;
                                          final contentData = content.data()!;
                                          await Navigator.of(context).push<void>(
                                            MaterialPageRoute(
                                              builder: (_) => ContentDetailScreen(
                                                title: contentData['title'] as String? ?? title,
                                                description: contentData['description'] as String? ?? '',
                                                body: contentData['body'] as String? ?? data['body'] as String? ?? '',
                                                type: contentData['type'] as String? ?? category,
                                                isPublished: contentData['isPublished'] as bool? ?? true,
                                                isFeatured: contentData['isFeatured'] as bool? ?? false,
                                                isPremium: contentData['isPremium'] as bool? ?? false,
                                                createdAt: (contentData['createdAt'] as Timestamp?)?.toDate(),
                                                updatedAt: (contentData['updatedAt'] as Timestamp?)?.toDate(),
                                              ),
                                            ),
                                          );
                                        } catch (_) {}
                                      },
                                    ),
                                  PopupMenuButton<String>(
                                    onSelected: (value) {
                                      if (value == 'delete') _deletePost(doc);
                                    },
                                    itemBuilder: (_) => const [
                                      PopupMenuItem(value: 'delete', child: Text('Delete')),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _createAdminPost() async {
    final titleController = TextEditingController();
    final bodyController = TextEditingController();
    String category = 'General';
    bool saving = false;

    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (dialogBuildContext, setDialogState) => AlertDialog(
            title: const Text('Create Forum Post'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: 'Title',
                      hintText: 'Announcement or discussion topic',
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: category,
                    decoration: const InputDecoration(labelText: 'Category'),
                    items: const [
                      'General',
                      'Outfit',
                      'Colour',
                      'Styling',
                      'AI Styling',
                    ].map((item) => DropdownMenuItem<String>(value: item, child: Text(item))).toList(),
                    onChanged: saving ? null : (value) => setDialogState(() => category = value ?? 'General'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: bodyController,
                    minLines: 4,
                    maxLines: 7,
                    decoration: const InputDecoration(labelText: 'Post', hintText: 'Write a post for the TiB community.'),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: saving ? null : () => Navigator.pop(dialogContext), child: const Text('Cancel')),
              FilledButton(
                onPressed: saving ? null : () async {
                  final title = titleController.text.trim();
                  final body = bodyController.text.trim();
                  final uid = FirebaseAuth.instance.currentUser?.uid;
                  if (uid == null || title.isEmpty || body.isEmpty) return;
                  setDialogState(() => saving = true);
                  try {
                    final user = await FirebaseFirestore.instance.collection('users').doc(uid).get();
                    final userData = user.data() ?? <String, dynamic>{};
                    final name = (userData['name'] as String?)?.trim();
                    await FirebaseFirestore.instance.collection('forum_posts').add({
                      'title': title,
                      'body': body,
                      'category': category,
                      'authorId': uid,
                      'authorName': name?.isNotEmpty == true ? name : 'TiB Admin',
                      'authorRole': 'admin',
                      'isOfficial': true,
                      'source': 'admin_forum',
                      'likeCount': 0,
                      'commentCount': 0,
                      'createdAt': FieldValue.serverTimestamp(),
                      'lastActivityAt': FieldValue.serverTimestamp(),
                    });
                    if (dialogContext.mounted) Navigator.pop(dialogContext);
                  } catch (error) {
                    if (!dialogContext.mounted) return;
                    setDialogState(() => saving = false);
                    ScaffoldMessenger.of(dialogBuildContext).showSnackBar(SnackBar(content: Text('Could not create post: $error')));
                  }
                },
                child: Text(saving ? 'Posting...' : 'Post'),
              ),
            ],
          ),
        ),
      );
    } finally {
      titleController.dispose();
      bodyController.dispose();
    }
  }
}
