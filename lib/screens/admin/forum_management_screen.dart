import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';

class ForumManagementScreen extends StatefulWidget {
  const ForumManagementScreen({super.key});

  @override
  State<ForumManagementScreen> createState() => _ForumManagementScreenState();
}

class _ForumManagementScreenState extends State<ForumManagementScreen> {
  String _filter = 'All';
  String _query = '';

  static const _filters = ['All', 'Customer Posts', 'TiB Content'];

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

  bool _matches(Map<String, dynamic> data) {
    final official = data['isOfficial'] == true || data['source'] == 'admin_content';
    final title = (data['title'] as String? ?? '').toLowerCase();
    final body = (data['body'] as String? ?? '').toLowerCase();
    final category = (data['category'] as String? ?? 'General').toLowerCase();
    final query = _query.toLowerCase();

    final filterMatches = switch (_filter) {
      'Customer Posts' => !official,
      'TiB Content' => official,
      _ => true,
    };

    final searchMatches = query.isEmpty ||
        title.contains(query) ||
        body.contains(query) ||
        category.contains(query);

    return filterMatches && searchMatches;
  }

  Future<void> _deletePost(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete forum post?'),
        content: const Text(
          'This removes the post and its discussion from the shared TiB Forum.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
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

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Forum post removed.')),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not delete post: $error')),
      );
    }
  }

  Future<void> _openPost(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final parentContext = context;
    await showModalBottomSheet<void>(
      context: parentContext,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AdminForumPostSheet(
        reference: doc.reference,
        onDelete: () async {
          Navigator.of(parentContext).pop();
          await _deletePost(parentContext, doc);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Forum Management')),
      backgroundColor: AppColors.background,
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('forum_posts').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Could not load forum: ${snapshot.error}'));
          }

          final docs = [...?snapshot.data?.docs];
          docs.sort((a, b) {
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
                      onChanged: (value) => setState(() => _query = value.trim()),
                      decoration: InputDecoration(
                        hintText: 'Search forum',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _filters.map((item) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(item),
                              selected: _filter == item,
                              showCheckmark: false,
                              onSelected: (_) => setState(() => _filter = item),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: visible.isEmpty
                    ? const Center(child: Text('No forum posts found.'))
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 30),
                        itemCount: visible.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final doc = visible[index];
                          final data = doc.data();
                          final official = data['isOfficial'] == true ||
                              data['source'] == 'admin_content';
                          final title = data['title'] as String? ?? 'Untitled post';
                          final author = data['authorName'] as String? ?? 'TiB User';
                          final category = data['category'] as String? ?? 'General';

                          return Card(
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                              side: BorderSide(
                                color: official
                                    ? AppColors.primarySoft
                                    : AppColors.border,
                              ),
                            ),
                            child: ListTile(
                              onTap: () => _openPost(context, doc),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                              leading: CircleAvatar(
                                backgroundColor: official
                                    ? AppColors.primarySoft
                                    : AppColors.secondary,
                                child: Icon(
                                  official
                                      ? Icons.auto_awesome_outlined
                                      : Icons.forum_outlined,
                                  color: AppColors.primary,
                                ),
                              ),
                              title: Text(
                                title,
                                style: const TextStyle(fontWeight: FontWeight.w800),
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 5),
                                child: Text(
                                  '$author · $category\n${data['commentCount'] ?? 0} replies · ${_relativeDate(data['lastActivityAt'] ?? data['createdAt'])}',
                                ),
                              ),
                              isThreeLine: true,
                              trailing: PopupMenuButton<String>(
                                onSelected: (value) {
                                  if (value == 'view') _openPost(context, doc);
                                  if (value == 'delete') _deletePost(context, doc);
                                },
                                itemBuilder: (_) => const [
                                  PopupMenuItem(
                                    value: 'view',
                                    child: Text('View'),
                                  ),
                                  PopupMenuItem(
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
          );
        },
      ),
    );
  }
}

class _AdminForumPostSheet extends StatelessWidget {
  const _AdminForumPostSheet({
    required this.reference,
    required this.onDelete,
  });

  final DocumentReference<Map<String, dynamic>> reference;
  final Future<void> Function() onDelete;

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

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.background,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .82,
          child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: reference.snapshots(),
            builder: (context, postSnapshot) {
              if (postSnapshot.hasError) {
                return Center(child: Text('Could not load post: ${postSnapshot.error}'));
              }

              final data = postSnapshot.data?.data() ?? <String, dynamic>{};
              final official = data['isOfficial'] == true || data['source'] == 'admin_content';
              final title = data['title'] as String? ?? 'Forum post';
              final body = data['body'] as String? ?? '';
              final author = data['authorName'] as String? ?? 'TiB User';
              final category = data['category'] as String? ?? 'General';

              return Column(
                children: [
                  const SizedBox(height: 10),
                  Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
                      children: [
                        Text(
                          official ? 'TiB CONTENT' : category.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 25,
                            fontWeight: FontWeight.w900,
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Posted by $author · ${_relativeDate(data['createdAt'])}',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          body,
                          style: const TextStyle(fontSize: 14, height: 1.6),
                        ),
                        const SizedBox(height: 22),
                        const Text(
                          'REPLIES',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 10),
                        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                          stream: reference.collection('comments').snapshots(),
                          builder: (context, commentsSnapshot) {
                            if (commentsSnapshot.hasError) {
                              return Text(
                                'Could not load replies: ${commentsSnapshot.error}',
                                style: const TextStyle(color: AppColors.error),
                              );
                            }

                            final comments = [...?commentsSnapshot.data?.docs];
                            comments.sort(
                              (a, b) => _date(a.data()['createdAt'])
                                  .compareTo(_date(b.data()['createdAt'])),
                            );

                            if (commentsSnapshot.connectionState == ConnectionState.waiting && comments.isEmpty) {
                              return const Padding(
                                padding: EdgeInsets.all(24),
                                child: Center(child: CircularProgressIndicator()),
                              );
                            }

                            if (comments.isEmpty) {
                              return Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceMuted,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: const Text('No replies yet.'),
                              );
                            }

                            return Column(
                              children: comments.map((commentDoc) {
                                final comment = commentDoc.data();
                                return Container(
                                  width: double.infinity,
                                  margin: const EdgeInsets.only(bottom: 9),
                                  padding: const EdgeInsets.all(13),
                                  decoration: BoxDecoration(
                                    color: AppColors.surface,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: AppColors.border),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        comment['authorName'] as String? ?? 'TiB User',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      const SizedBox(height: 5),
                                      Text(
                                        comment['body'] as String? ?? '',
                                        style: const TextStyle(
                                          fontSize: 13,
                                          height: 1.45,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: onDelete,
                        icon: const Icon(Icons.delete_outline_rounded),
                        label: const Text('Remove Post'),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
