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

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Forum post removed.')),
        );
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not delete post: $error')),
      );
    }
  }

  Future<void> _openPost(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AdminForumPostSheet(
        reference: doc.reference,
        onDelete: () async {
          Navigator.of(context).pop();
          await _deletePost(context, doc);
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
            return Center(
              child: Text('Could not load forum: ${snapshot.error}'),
            );
          }

          final docs = [...?snapshot.data?.docs];
          docs.sort(
            (a, b) => _date(b.data()['lastActivityAt'] ?? b.data()['createdAt'])
                .compareTo(_date(a.data()['lastActivityAt'] ?? a.data()['createdAt'])),
          );
          final visible = docs.where((doc) => _matches(doc.data())).toList();

          return RefreshIndicator(
            onRefresh: () async {},
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
              children: [
                const Text(
                  'Community Moderation',
                  style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 5),
                const Text(
                  'One shared forum for customer conversations and TiB Team content.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  onChanged: (value) => setState(() => _query = value.trim()),
                  decoration: InputDecoration(
                    hintText: 'Search posts',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
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
                const SizedBox(height: 20),
                Row(
                  children: [
                    const Text(
                      'SHARED COMMUNITY',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${visible.length} posts',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData)
                  const Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (visible.isEmpty)
                  const Padding(
                    padding: EdgeInsets.fromLTRB(0, 40, 0, 40),
                    child: Center(child: Text('No matching forum posts.')),
                  )
                else
                  ...visible.map((doc) => _postCard(context, doc)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _postCard(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    final official = data['isOfficial'] == true || data['source'] == 'admin_content';
    final author = data['authorName'] as String? ?? 'TiB User';
    final title = data['title'] as String? ?? 'Untitled post';
    final body = data['body'] as String? ?? '';
    final category = data['category'] as String? ?? 'General';

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: official ? AppColors.primarySoft : AppColors.border,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => _openPost(context, doc),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
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
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primaryDark,
                      ),
                    ),
                  ),
                  if (official) ...[
                    const SizedBox(width: 6),
                    const Icon(Icons.verified_rounded, size: 15, color: AppColors.primary),
                  ],
                  const Spacer(),
                  Text(
                    _relativeDate(data['lastActivityAt'] ?? data['createdAt']),
                    style: const TextStyle(fontSize: 10.5, color: AppColors.textMuted),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              Text(
                body,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.textSecondary, height: 1.45, fontSize: 12.5),
              ),
              const SizedBox(height: 11),
              Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: AppColors.secondary,
                    child: Icon(
                      official ? Icons.auto_awesome_outlined : Icons.person_outline_rounded,
                      size: 16,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(author, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                  ),
                  Text('${data['commentCount'] ?? 0} comments', style: const TextStyle(fontSize: 10.5, color: AppColors.textSecondary)),
                  const SizedBox(width: 10),
                  Text('${data['likeCount'] ?? 0} likes', style: const TextStyle(fontSize: 10.5, color: AppColors.textSecondary)),
                ],
              ),
            ],
          ),
        ),
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

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .82,
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: reference.snapshots(),
          builder: (context, postSnapshot) {
            final data = postSnapshot.data?.data() ?? const <String, dynamic>{};
            final commentsFuture = reference.collection('comments').orderBy('createdAt').get();
            final official = data['isOfficial'] == true || data['source'] == 'admin_content';

            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.outlineVariant,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Text(
                        official ? 'TIB TEAM CONTENT' : 'CUSTOMER POST',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                          color: AppColors.primary,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        tooltip: 'Delete',
                        onPressed: onDelete,
                        icon: const Icon(Icons.delete_outline_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    data['title'] as String? ?? 'Forum post',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Posted by ${data['authorName'] as String? ?? 'TiB User'}',
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            data['body'] as String? ?? '',
                            style: const TextStyle(fontSize: 14, height: 1.6),
                          ),
                          const SizedBox(height: 22),
                          const Text(
                            'COMMENTS',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.1, color: AppColors.textSecondary),
                          ),
                          const SizedBox(height: 10),
                          FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
                            future: commentsFuture,
                            builder: (context, commentsSnapshot) {
                              final comments = commentsSnapshot.data?.docs ?? const [];
                              if (comments.isEmpty) {
                                return const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 24),
                                  child: Text('No comments yet.'),
                                );
                              }
                              return Column(
                                children: comments.map((doc) {
                                  final comment = doc.data();
                                  return Container(
                                    width: double.infinity,
                                    margin: const EdgeInsets.only(bottom: 8),
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: AppColors.surfaceMuted,
                                      borderRadius: BorderRadius.circular(15),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(comment['authorName'] as String? ?? 'TiB User', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                                        const SizedBox(height: 4),
                                        Text(comment['body'] as String? ?? '', style: const TextStyle(fontSize: 12.5, height: 1.4)),
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
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Activity: ${_date(data['lastActivityAt'] ?? data['createdAt']) == DateTime.fromMillisecondsSinceEpoch(0) ? 'Just now' : 'recent'}',
                    style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
