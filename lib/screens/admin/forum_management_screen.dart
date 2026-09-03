import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../forum/customer_forum_screen.dart';

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
    return filterMatches &&
        (query.isEmpty ||
            title.contains(query) ||
            body.contains(query) ||
            category.contains(query));
  }

  Future<bool> _addAdminReply(
    DocumentReference<Map<String, dynamic>> postRef,
    String text,
  ) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final trimmed = text.trim();
    if (uid == null || trimmed.isEmpty) return false;
    try {
      final snapshot =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final data = snapshot.data() ?? <String, dynamic>{};
      final name = (data['name'] as String?)?.trim();
      final commentRef = postRef.collection('comments').doc();
      final batch = FirebaseFirestore.instance.batch();
      batch.set(commentRef, {
        'body': trimmed,
        'authorId': uid,
        'authorName': name?.isNotEmpty == true ? name : 'TiB Team',
        'authorRole': 'admin',
        'isOfficial': true,
        'createdAt': FieldValue.serverTimestamp(),
      });
      batch.update(postRef, {
        'commentCount': FieldValue.increment(1),
        'lastActivityAt': FieldValue.serverTimestamp(),
      });
      await batch.commit();
      return true;
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not send admin reply: $error')),
        );
      }
      return false;
    }
  }

  Future<void> _toggleLike(DocumentReference<Map<String, dynamic>> postRef) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final likeRef = postRef.collection('likes').doc(uid);
      final existing = await likeRef.get();
      final snapshot = await postRef.get();
      final current = (snapshot.data()?['likeCount'] as num?)?.toInt() ?? 0;
      final batch = FirebaseFirestore.instance.batch();
      if (existing.exists) {
        batch.delete(likeRef);
        batch.update(postRef, {'likeCount': current > 0 ? current - 1 : 0});
      } else {
        batch.set(likeRef, {'createdAt': FieldValue.serverTimestamp()});
        batch.update(postRef, {'likeCount': current + 1});
      }
      await batch.commit();
    } catch (_) {}
  }

  Future<void> _deletePost(
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
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
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
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Forum post removed.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not delete post: $error')),
      );
    }
  }

  Future<void> _openPost(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => ForumPostDetailScreen(
          postReference: doc.reference,
          initialData: doc.data(),
          onToggleLike: () => _toggleLike(doc.reference),
          onAddComment: (text) => _addAdminReply(doc.reference, text),
        ),
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
          docs.sort(
            (a, b) => _date(
              b.data()['lastActivityAt'] ?? b.data()['createdAt'],
            ).compareTo(
              _date(a.data()['lastActivityAt'] ?? a.data()['createdAt']),
            ),
          );
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
                        hintText: 'Search shared forum',
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
                        children: _filters
                            .map(
                              (item) => Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: ChoiceChip(
                                  label: Text(item),
                                  selected: _filter == item,
                                  showCheckmark: false,
                                  onSelected: (_) =>
                                      setState(() => _filter = item),
                                ),
                              ),
                            )
                            .toList(),
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
                          final official =
                              data['isOfficial'] == true ||
                                  data['source'] == 'admin_content';
                          final title =
                              data['title'] as String? ?? 'Untitled post';
                          final author =
                              data['authorName'] as String? ?? 'TiB User';
                          final category =
                              data['category'] as String? ?? 'General';
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
                              onTap: () => _openPost(doc),
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
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
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
                                  if (value == 'view') _openPost(doc);
                                  if (value == 'delete') _deletePost(doc);
                                },
                                itemBuilder: (_) => const [
                                  PopupMenuItem(
                                    value: 'view',
                                    child: Text('View / Reply'),
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
