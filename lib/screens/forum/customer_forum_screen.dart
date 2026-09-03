import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';

class CustomerForumScreen extends StatefulWidget {
  const CustomerForumScreen({super.key});

  @override
  State<CustomerForumScreen> createState() => _CustomerForumScreenState();
}

class _CustomerForumScreenState extends State<CustomerForumScreen> {
  final _searchController = TextEditingController();
  String _category = 'All';
  String _query = '';

  static const _categories = [
    'All',
    'Outfit',
    'Colour',
    'Styling',
    'AI Styling',
    'General',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _postsStream() =>
      FirebaseFirestore.instance.collection('forum_posts').snapshots();

  bool _matches(Map<String, dynamic> data) {
    final category = data['category'] as String? ?? 'General';
    final title = (data['title'] as String? ?? '').toLowerCase();
    final body = (data['body'] as String? ?? '').toLowerCase();
    final query = _query.toLowerCase();
    return (_category == 'All' || category == _category) &&
        (query.isEmpty ||
            title.contains(query) ||
            body.contains(query) ||
            category.toLowerCase().contains(query));
  }

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

  Future<void> _createPost() async {
    final titleController = TextEditingController();
    final bodyController = TextEditingController();
    String category = 'General';
    bool saving = false;

    try {
      final created = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (dialogBuildContext, setDialogState) => AlertDialog(
            title: const Text('Create a forum post'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: 'Title',
                      hintText: 'What do you want to discuss?',
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: category,
                    decoration: const InputDecoration(labelText: 'Category'),
                    items: _categories
                        .where((item) => item != 'All')
                        .map((item) => DropdownMenuItem(
                              value: item,
                              child: Text(item),
                            ))
                        .toList(),
                    onChanged: saving
                        ? null
                        : (value) => setDialogState(
                              () => category = value ?? 'General',
                            ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: bodyController,
                    minLines: 4,
                    maxLines: 7,
                    decoration: const InputDecoration(
                      labelText: 'Post',
                      hintText: 'Share your styling question, idea or experience.',
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: saving ? null : () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: saving
                    ? null
                    : () async {
                        final title = titleController.text.trim();
                        final body = bodyController.text.trim();
                        final uid = FirebaseAuth.instance.currentUser?.uid;
                        if (uid == null || title.isEmpty || body.isEmpty) {
                          ScaffoldMessenger.of(dialogBuildContext).showSnackBar(
                            const SnackBar(content: Text('Please enter a title and post content.')),
                          );
                          return;
                        }

                        setDialogState(() => saving = true);
                        try {
                          final userSnapshot = await FirebaseFirestore.instance
                              .collection('users')
                              .doc(uid)
                              .get();
                          final userData = userSnapshot.data() ?? <String, dynamic>{};
                          final authUser = FirebaseAuth.instance.currentUser;
                          final profileName = (userData['name'] as String?)?.trim();
                          final displayName = authUser?.displayName?.trim();

                          await FirebaseFirestore.instance.collection('forum_posts').add({
                            'title': title,
                            'body': body,
                            'category': category,
                            'authorId': uid,
                            'authorName': profileName?.isNotEmpty == true
                                ? profileName
                                : (displayName?.isNotEmpty == true ? displayName : 'TiB User'),
                            'likeCount': 0,
                            'commentCount': 0,
                            'createdAt': FieldValue.serverTimestamp(),
                          });

                          if (dialogContext.mounted) {
                            Navigator.of(dialogContext).pop(true);
                          }
                        } catch (error) {
                          if (!dialogContext.mounted) return;
                          setDialogState(() => saving = false);
                          ScaffoldMessenger.of(dialogBuildContext).showSnackBar(
                            SnackBar(content: Text('Could not create post: $error')),
                          );
                        }
                      },
                child: Text(saving ? 'Posting...' : 'Post'),
              ),
            ],
          ),
        ),
      );

      if (created == true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Your post is now visible to the TiB community.')),
        );
      }
    } finally {
      titleController.dispose();
      bodyController.dispose();
    }
  }

  Future<void> _toggleLike(DocumentReference<Map<String, dynamic>> postReference) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final reactionRef = postReference.collection('likes').doc(uid);
      final existing = await reactionRef.get();
      if (existing.exists) {
        await reactionRef.delete();
        await postReference.update({'likeCount': FieldValue.increment(-1)});
      } else {
        await reactionRef.set({'createdAt': FieldValue.serverTimestamp()});
        await postReference.update({'likeCount': FieldValue.increment(1)});
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update like: $error')),
      );
    }
  }

  Future<void> _addComment(DocumentReference<Map<String, dynamic>> postReference) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final text = _activeCommentController?.text.trim() ?? '';
    if (text.isEmpty) return;

    try {
      final userSnapshot = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final userData = userSnapshot.data() ?? <String, dynamic>{};
      final profileName = (userData['name'] as String?)?.trim();
      final displayName = FirebaseAuth.instance.currentUser?.displayName?.trim();
      await postReference.collection('comments').add({
        'body': text,
        'authorId': uid,
        'authorName': profileName?.isNotEmpty == true
            ? profileName
            : (displayName?.isNotEmpty == true ? displayName : 'TiB User'),
        'createdAt': FieldValue.serverTimestamp(),
      });
      await postReference.update({'commentCount': FieldValue.increment(1)});
      _activeCommentController?.clear();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not send reply: $error')),
      );
    }
  }

  TextEditingController? _activeCommentController;

  Future<void> _openPost(QueryDocumentSnapshot<Map<String, dynamic>> document) async {
    final data = document.data();
    final controller = TextEditingController();
    _activeCommentController = controller;

    try {
      await showModalBottomSheet<void>(
        context: context,
        useSafeArea: true,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (sheetContext) => _ForumPostSheet(
          title: data['title'] as String? ?? 'Forum post',
          body: data['body'] as String? ?? '',
          category: data['category'] as String? ?? 'General',
          author: data['authorName'] as String? ?? 'TiB User',
          relativeDate: _relativeDate(data['createdAt']),
          postReference: document.reference,
          initialLikeCount: (data['likeCount'] as num?)?.toInt() ?? 0,
          initialCommentCount: (data['commentCount'] as num?)?.toInt() ?? 0,
          commentController: controller,
          onToggleLike: () => _toggleLike(document.reference),
          onAddComment: () => _addComment(document.reference),
        ),
      );
    } finally {
      if (identical(_activeCommentController, controller)) {
        _activeCommentController = null;
      }
      controller.dispose();
    }
  }

  Widget _postCard(QueryDocumentSnapshot<Map<String, dynamic>> document) {
    final data = document.data();
    final title = data['title'] as String? ?? 'Untitled post';
    final body = data['body'] as String? ?? '';
    final category = data['category'] as String? ?? 'General';
    final author = data['authorName'] as String? ?? 'TiB User';

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColors.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => _openPost(document),
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
                      color: AppColors.surfaceMuted,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      category,
                      style: const TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primaryDark,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _relativeDate(data['createdAt']),
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
                    child: const Icon(Icons.person_outline_rounded, size: 16, color: AppColors.primary),
                  ),
                  const SizedBox(width: 7),
                  Expanded(child: Text(author, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700))),
                  const Icon(Icons.favorite_border_rounded, size: 16, color: AppColors.textMuted),
                  const SizedBox(width: 4),
                  Text('${data['likeCount'] ?? 0}', style: const TextStyle(fontSize: 10.5, color: AppColors.textSecondary)),
                  const SizedBox(width: 10),
                  const Icon(Icons.chat_bubble_outline_rounded, size: 16, color: AppColors.textMuted),
                  const SizedBox(width: 4),
                  Text('${data['commentCount'] ?? 0}', style: const TextStyle(fontSize: 10.5, color: AppColors.textSecondary)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('TiB Forum'),
        actions: [
          IconButton(
            onPressed: _createPost,
            tooltip: 'Create post',
            icon: const Icon(Icons.add_comment_outlined),
          ),
        ],
      ),
      backgroundColor: AppColors.background,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createPost,
        icon: const Icon(Icons.edit_outlined),
        label: const Text('Create Post'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _postsStream(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Could not load forum: ${snapshot.error}'));
          }

          final documents = [...?snapshot.data?.docs];
          documents.sort((a, b) => _date(b.data()['createdAt']).compareTo(_date(a.data()['createdAt'])));
          final visible = documents.where((document) => _matches(document.data())).toList();

          return RefreshIndicator(
            onRefresh: () async {},
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
              children: [
                const Text(
                  'Style starts with a conversation.',
                  style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900, height: 1.1),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Ask questions, share outfit ideas and learn from the whole TiB community.',
                  style: TextStyle(color: AppColors.textSecondary, height: 1.4),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _searchController,
                  onChanged: (value) => setState(() => _query = value.trim()),
                  decoration: InputDecoration(
                    hintText: 'Search forum',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _categories
                        .map(
                          (category) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(category),
                              selected: _category == category,
                              showCheckmark: false,
                              onSelected: (_) => setState(() => _category = category),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    const Text(
                      'COMMUNITY POSTS',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.3, color: AppColors.textSecondary),
                    ),
                    const Spacer(),
                    Text('${visible.length} posts', style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                  ],
                ),
                const SizedBox(height: 10),
                if (snapshot.connectionState == ConnectionState.waiting && documents.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (visible.isEmpty)
                  const Padding(
                    padding: EdgeInsets.fromLTRB(0, 30, 0, 40),
                    child: Center(child: Text('No posts match your search yet.')),
                  )
                else
                  ...visible.map(_postCard),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ForumPostSheet extends StatefulWidget {
  const _ForumPostSheet({
    required this.title,
    required this.body,
    required this.category,
    required this.author,
    required this.relativeDate,
    required this.postReference,
    required this.initialLikeCount,
    required this.initialCommentCount,
    required this.commentController,
    required this.onToggleLike,
    required this.onAddComment,
  });

  final String title;
  final String body;
  final String category;
  final String author;
  final String relativeDate;
  final DocumentReference<Map<String, dynamic>> postReference;
  final int initialLikeCount;
  final int initialCommentCount;
  final TextEditingController commentController;
  final Future<void> Function() onToggleLike;
  final Future<void> Function() onAddComment;

  @override
  State<_ForumPostSheet> createState() => _ForumPostSheetState();
}

class _ForumPostSheetState extends State<_ForumPostSheet> {
  bool _sending = false;

  Future<void> _send() async {
    if (_sending || widget.commentController.text.trim().isEmpty) return;
    setState(() => _sending = true);
    try {
      await widget.onAddComment();
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Align(
      alignment: Alignment.bottomCenter,
      child: Material(
        color: theme.colorScheme.surface,
        clipBehavior: Clip.antiAlias,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.82,
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: widget.postReference.collection('comments').snapshots(),
                  builder: (context, snapshot) {
                    final comments = [...?snapshot.data?.docs];
                    comments.sort(
                      (a, b) => _dateSafe(a.data()['createdAt'])
                          .compareTo(_dateSafe(b.data()['createdAt'])),
                    );

                    return CustomScrollView(
                      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                      slivers: [
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                          sliver: SliverToBoxAdapter(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                                      decoration: BoxDecoration(
                                        color: AppColors.surfaceMuted,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        widget.category,
                                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800),
                                      ),
                                    ),
                                    const Spacer(),
                                    Icon(Icons.forum_outlined, color: AppColors.primary),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  widget.title,
                                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, height: 1.12),
                                ),
                                const SizedBox(height: 7),
                                Text(
                                  'Posted by ${widget.author} · ${widget.relativeDate}',
                                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                                ),
                                const SizedBox(height: 16),
                                Text(widget.body, style: const TextStyle(fontSize: 14, height: 1.6)),
                                const SizedBox(height: 16),
                                StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                                  stream: widget.postReference.snapshots(),
                                  builder: (context, postSnapshot) {
                                    final liveData = postSnapshot.data?.data();
                                    final likeCount = (liveData?['likeCount'] as num?)?.toInt() ?? widget.initialLikeCount;
                                    final commentCount = (liveData?['commentCount'] as num?)?.toInt() ?? widget.initialCommentCount;
                                    return Row(
                                      children: [
                                        OutlinedButton.icon(
                                          onPressed: widget.onToggleLike,
                                          icon: const Icon(Icons.favorite_border_rounded),
                                          label: Text('Like $likeCount'),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          '$commentCount comments',
                                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                                const SizedBox(height: 14),
                                const Text(
                                  'COMMENTS',
                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.1, color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (snapshot.connectionState == ConnectionState.waiting && comments.isEmpty)
                          const SliverFillRemaining(
                            hasScrollBody: false,
                            child: Center(child: CircularProgressIndicator()),
                          )
                        else if (comments.isEmpty)
                          const SliverFillRemaining(
                            hasScrollBody: false,
                            child: Center(child: Text('Be the first to join the conversation.')),
                          )
                        else
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                            sliver: SliverList.builder(
                              itemCount: comments.length,
                              itemBuilder: (context, index) {
                                final comment = comments[index].data();
                                return Padding(
                                  padding: EdgeInsets.only(bottom: index == comments.length - 1 ? 0 : 8),
                                  child: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: AppColors.surfaceMuted,
                                      borderRadius: BorderRadius.circular(15),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          comment['authorName'] as String? ?? 'TiB User',
                                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          comment['body'] as String? ?? '',
                                          style: const TextStyle(fontSize: 12.5, height: 1.4),
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
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(16, 10, 16, 16 + MediaQuery.viewPaddingOf(context).bottom),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: widget.commentController,
                        minLines: 1,
                        maxLines: 4,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _send(),
                        decoration: const InputDecoration(hintText: 'Write a reply...'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      tooltip: 'Send reply',
                      onPressed: _sending ? null : _send,
                      icon: _sending
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.send_rounded),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  DateTime _dateSafe(dynamic value) => value is Timestamp
      ? value.toDate()
      : DateTime.fromMillisecondsSinceEpoch(0);
}
