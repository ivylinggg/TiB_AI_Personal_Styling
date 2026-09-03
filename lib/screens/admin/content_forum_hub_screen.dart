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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Content & Forum')),
      backgroundColor: AppColors.background,
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('forum_posts').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Could not load community: ${snapshot.error}'));
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
                        hintText: 'Search content or forum',
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
                    ? const Center(child: Text('No content or forum posts found.'))
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                        itemCount: visible.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final doc = visible[index];
                          final data = doc.data();
                          final official = _official(data);
                          final title = data['title'] as String? ?? 'Untitled';
                          final body = data['body'] as String? ?? '';
                          final author = data['authorName'] as String? ?? 'TiB User';
                          final category = data['category'] as String? ?? 'General';
                          final contentId = data['contentId'] as String?;

                          return Card(
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                              side: BorderSide(
                                color: official ? AppColors.primarySoft : AppColors.border,
                              ),
                            ),
                            child: ListTile(
                              onTap: () {
                                Navigator.of(context).push<void>(
                                  MaterialPageRoute(
                                    builder: (_) => ForumPostDetailScreen(
                                      postReference: doc.reference,
                                      initialData: data,
                                      onToggleLike: () async {},
                                      onAddComment: (text) async {
                                        final uid = FirebaseAuth.instance.currentUser?.uid;
                                        final trimmed = text.trim();
                                        if (uid == null || trimmed.isEmpty) return false;
                                        try {
                                          final user = await FirebaseFirestore.instance.collection('users').doc(uid).get();
                                          final userData = user.data() ?? <String, dynamic>{};
                                          final name = (userData['name'] as String?)?.trim();
                                          final commentRef = doc.reference.collection('comments').doc();
                                          final batch = FirebaseFirestore.instance.batch();
                                          batch.set(commentRef, {
                                            'body': trimmed,
                                            'authorId': uid,
                                            'authorName': name?.isNotEmpty == true ? name : 'TiB Admin',
                                            'authorRole': userData['role'] as String? ?? 'admin',
                                            'isOfficial': userData['role'] == 'admin',
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
                              },
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              leading: CircleAvatar(
                                backgroundColor: official ? AppColors.primarySoft : AppColors.secondary,
                                child: Icon(
                                  official ? Icons.auto_awesome_outlined : Icons.forum_outlined,
                                  color: AppColors.primary,
                                ),
                              ),
                              title: Row(
                                children: [
                                  Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w800))),
                                  if (official) const Icon(Icons.verified_rounded, size: 17, color: AppColors.primary),
                                ],
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 5),
                                child: Text(
                                  '$author · $category\n${data['commentCount'] ?? 0} replies · ${_relativeDate(data['lastActivityAt'] ?? data['createdAt'])}',
                                ),
                              ),
                              isThreeLine: true,
                              trailing: official && contentId != null
                                  ? IconButton(
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
                                                body: contentData['body'] as String? ?? body,
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
                                    )
                                  : null,
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
