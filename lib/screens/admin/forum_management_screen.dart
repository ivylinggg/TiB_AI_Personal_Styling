import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';

class ForumManagementScreen extends StatelessWidget {
  const ForumManagementScreen({super.key});

  DateTime _date(dynamic value) => value is Timestamp ? value.toDate() : DateTime.fromMillisecondsSinceEpoch(0);

  Future<void> _deletePost(BuildContext context, QueryDocumentSnapshot<Map<String, dynamic>> doc) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete forum post?'),
        content: const Text('This will remove the post from the shared TiB Forum for everyone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true) return;
    await doc.reference.delete();
  }

  Future<void> _openPost(BuildContext context, QueryDocumentSnapshot<Map<String, dynamic>> doc) async {
    final data = doc.data();
    final title = data['title'] as String? ?? 'Forum post';
    final body = data['body'] as String? ?? '';
    final author = data['authorName'] as String? ?? 'TiB User';
    final category = data['category'] as String? ?? 'General';

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: AppColors.background,
      builder: (sheetContext) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(sheetContext).height * .82,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(category.toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.primary, letterSpacing: 1.1)),
                const SizedBox(height: 8),
                Text(title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
                const SizedBox(height: 5),
                Text('Posted by $author', style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                const SizedBox(height: 18),
                Expanded(child: SingleChildScrollView(child: Text(body, style: const TextStyle(fontSize: 14, height: 1.6)))),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      _deletePost(context, doc);
                    },
                    icon: const Icon(Icons.delete_outline_rounded),
                    label: const Text('Remove Post'),
                  ),
                ),
              ],
            ),
          ),
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
          docs.sort((a, b) => _date(b.data()['createdAt']).compareTo(_date(a.data()['createdAt'])));

          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          if (docs.isEmpty) {
            return const Center(child: Text('No forum posts yet.'));
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
            itemCount: docs.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data();
              final official = data['isOfficial'] == true;
              return Card(
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: const BorderSide(color: AppColors.border)),
                child: ListTile(
                  onTap: () => _openPost(context, doc),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  leading: CircleAvatar(backgroundColor: official ? AppColors.primarySoft : AppColors.secondary, child: Icon(official ? Icons.verified_outlined : Icons.forum_outlined, color: AppColors.primary)),
                  title: Text(data['title'] as String? ?? 'Untitled post', style: const TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: Text('${data['authorName'] as String? ?? 'TiB User'} · ${data['category'] as String? ?? 'General'}\n${data['commentCount'] ?? 0} comments · ${data['likeCount'] ?? 0} likes'),
                  isThreeLine: true,
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'view') _openPost(context, doc);
                      if (value == 'delete') _deletePost(context, doc);
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'view', child: Text('View')),
                      PopupMenuItem(value: 'delete', child: Text('Delete')),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
