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
    final difference = DateTime.now().difference(_date(value));
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

    return filterMatches &&
        (query.isEmpty ||
            title.contains(query) ||
            body.contains(query) ||
            category.contains(query));
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
    final rootContext = context;
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AdminForumPostSheet(
        reference: doc.reference,
        onDelete: () {
          Navigator.of(context).pop();
          return _deletePost(rootContext, doc);
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

          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
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
                        children: _filters.map((filter) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(filter),
                              selected: _filter == filter,
                              showCheckmark: false,
                              onSelected: (_) => setState(() => _filter = filter),
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
                          final body = data['body'] as String? ?? '';
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
                                    child: Text('View discussion'),
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
      borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .86,
          child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: reference.snapshots(),
            builder: (context, postSnapshot) {
              final data = postSnapshot.data?.data() ?? const <String, dynamic>{};
              final official = data['isOfficial'] == true || data['source'] == 'admin_content';
              final title = data['title'] as String? ?? 'Forum post';
              final body = data['body'] as String? ?? '';
              final author = data['authorName'] as String? ?? 'TiB User';
              final category = data['category'] as String? ?? 'General';

              return Column(
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.textMuted,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                  Expanded(
                    child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: reference.collection('comments').snapshots(),
                      builder: (context, commentsSnapshot) {
                        final comments = [...?commentsSnapshot.data?.docs];
                        comments.sort(
                          (a, b) => _date(a.data()['createdAt'])
                              .compareTo(_date(b.data()['createdAt'])),
                        );

                        return ListView(
                          padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: official ? AppColors.primarySoft : AppColors.surfaceMuted,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    official ? 'TiB Team' : category,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.primaryDark,
                                    ),
                                  ),
                                ),
                                if (official) ...[
                                  const SizedBox(width: 6),
                                  const Icon(Icons.verified_rounded, size: 16, color: AppColors.primary),
                                ],
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              title,
                              style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w900),
                            ),
                            const SizedBox(height: 7),
                            Text(
                              'Posted by $author · ${_relativeDate(data['createdAt'])}',
                              style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                            ),
                            const SizedBox(height: 14),
                            Text(body, style: const TextStyle(fontSize: 14, height: 1.6)),
                            const SizedBox(height: 22),
                            Row(
                              children: [
                                const Text(
                                  'REPLIES',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.3,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                const Spacer(),
                                Text('${comments.length}'),
                              ],
                            ),
                            const SizedBox(height: 10),
                            if (commentsSnapshot.hasError)
                              Text('Could not load replies: ${commentsSnapshot.error}')
                            else if (comments.isEmpty)
                              const Padding(
                                padding: EdgeInsets.all(24),
                                child: Center(child: Text('No replies yet.')),
                              )
                            else
                              ...comments.map((doc) {
                                final comment = doc.data();
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: AppColors.surface,
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(color: AppColors.border),
                                  ),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      CircleAvatar(
                                        radius: 18,
                                        backgroundColor: AppColors.secondary,
                                        child: const Icon(
                                          Icons.person_outline_rounded,
                                          size: 18,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              comment['authorName'] as String? ?? 'TiB User',
                                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                                            ),
                                            const SizedBox(height: 5),
                                            Text(
                                              comment['body'] as String? ?? '',
                                              style: const TextStyle(fontSize: 13, height: 1.45),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              _relativeDate(comment['createdAt']),
                                              style: const TextStyle(fontSize: 9.5, color: AppColors.textMuted),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                            const SizedBox(height: 14),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                onPressed: onDelete,
                                icon: const Icon(Icons.delete_outline_rounded),
                                label: const Text('Remove Post'),
                              ),
                            ),
                          ],
                        );
                      },
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
