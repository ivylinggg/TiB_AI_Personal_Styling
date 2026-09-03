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

  Stream<QuerySnapshot<Map<String, dynamic>>> _postsStream() {
    return FirebaseFirestore.instance.collection('forum_posts').snapshots();
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
          builder: (dialogBuildContext, setDialogState) {
            return AlertDialog(
              title: const Text('Create a forum post'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      textInputAction: TextInputAction.next,
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
                          .map(
                            (item) => DropdownMenuItem(
                              value: item,
                              child: Text(item),
                            ),
                          )
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
                        hintText:
                            'Share your styling question, idea or experience.',
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving
                      ? null
                      : () => Navigator.of(dialogContext).pop(false),
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
                              const SnackBar(
                                content: Text(
                                  'Please enter a title and post content.',
                                ),
                              ),
                            );
                            return;
                          }

                          setDialogState(() => saving = true);
                          try {
                            final userSnapshot = await FirebaseFirestore.instance
                                .collection('users')
                                .doc(uid)
                                .get();
                            final userData =
                                userSnapshot.data() ?? <String, dynamic>{};
                            final authUser = FirebaseAuth.instance.currentUser;
                            final profileName =
                                (userData['name'] as String?)?.trim();
                            final displayName = authUser?.displayName?.trim();

                            await FirebaseFirestore.instance
                                .collection('forum_posts')
                                .add({
                              'title': title,
                              'body': body,
                              'category': category,
                              'authorId': uid,
                              'authorName': profileName?.isNotEmpty == true
                                  ? profileName
                                  : (displayName?.isNotEmpty == true
                                      ? displayName
                                      : 'TiB User'),
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
                              SnackBar(
                                content: Text('Could not create post: $error'),
                              ),
                            );
                          }
                        },
                  child: Text(saving ? 'Posting...' : 'Post'),
                ),
              ],
            );
          },
        ),
      );

      if (created == true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Your post is now visible to the TiB community.'),
          ),
        );
      }
    } finally {
      titleController.dispose();
      bodyController.dispose();
    }
  }

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
    final date = _date(value);
    final difference = DateTime.now().difference(date);
    if (difference.inDays > 30) return '${difference.inDays ~/ 30}mo ago';
    if (difference.inDays >= 1) return '${difference.inDays}d ago';
    if (difference.inHours >= 1) return '${difference.inHours}h ago';
    if (difference.inMinutes >= 1) return '${difference.inMinutes}m ago';
    return 'Just now';
  }

  Future<void> _openPost(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) async {
    final data = document.data();
    final title = data['title'] as String? ?? 'Forum post';
    final body = data['body'] as String? ?? '';
    final category = data['category'] as String? ?? 'General';
    final author = data['authorName'] as String? ?? 'TiB User';
    final postId = document.id;
    final commentsStream = FirebaseFirestore.instance
        .collection('forum_posts')
        .doc(postId)
        .collection('comments')
        .snapshots();

    try {
      await showModalBottomSheet<void>(
        context: context,
        useSafeArea: true,
        isScrollControlled: true,
        enableDrag: true,
        backgroundColor: Colors.transparent,
        builder: (sheetContext) {
          final screenHeight = MediaQuery.sizeOf(sheetContext).height;
          final keyboardInset = MediaQuery.viewInsetsOf(sheetContext).bottom;
          final sheetHeight = (screenHeight * 0.82).clamp(420.0, 760.0);

          return AnimatedPadding(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            padding: EdgeInsets.only(bottom: keyboardInset),
            child: Material(
              color: Theme.of(sheetContext).colorScheme.surface,
              clipBehavior: Clip.antiAlias,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
              child: SizedBox(
                height: sheetHeight,
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: commentsStream,
                  builder: (sheetBuildContext, snapshot) {
                    final comments = [...?snapshot.data?.docs];
                    comments.sort(
                      (a, b) => _date(a.data()['createdAt'])
                          .compareTo(_date(b.data()['createdAt'])),
                    );

                    return Column(
                      children: [
                        const SizedBox(height: 10),
                        Container(
                          width: 42,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Theme.of(sheetBuildContext)
                                .colorScheme
                                .outlineVariant,
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                        Expanded(
                          child: CustomScrollView(
                            keyboardDismissBehavior:
                                ScrollViewKeyboardDismissBehavior.onDrag,
                            slivers: [
                              SliverPadding(
                                padding: const EdgeInsets.fromLTRB(
                                  20,
                                  18,
                                  20,
                                  12,
                                ),
                                sliver: SliverList(
                                  delegate: SliverChildListDelegate([
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 9,
                                            vertical: 5,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppColors.surfaceMuted,
                                            borderRadius:
                                                BorderRadius.circular(10),
                                          ),
                                          child: Text(
                                            category,
                                            style: const TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ),
                                        const Spacer(),
                                        Icon(
                                          Icons.forum_outlined,
                                          color: AppColors.primary,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      title,
                                      style: const TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.w900,
                                        height: 1.12,
                                      ),
                                    ),
                                    const SizedBox(height: 7),
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
                                      style: const TextStyle(
                                        fontSize: 14,
                                        height: 1.6,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    Row(
                                      children: [
                                        OutlinedButton.icon(
                                          onPressed: () => _toggleLike(
                                            document.reference,
                                          ),
                                          icon: const Icon(
                                            Icons.favorite_border_rounded,
                                          ),
                                          label: Text(
                                            'Like ${data['likeCount'] ?? 0}',
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          '${comments.length} comments',
                                          style: const TextStyle(
                                            color: AppColors.textSecondary,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 14),
                                    const Text(
                                      'COMMENTS',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 1.1,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                  ]),
                                ),
                              ),
                              if (comments.isEmpty)
                                const SliverFillRemaining(
                                  hasScrollBody: false,
                                  child: Center(
                                    child: Text(
                                      'Be the first to join the conversation.',
                                    ),
                                  ),
                                )
                              else
                                SliverPadding(
                                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
                                  sliver: SliverList.separated(
                                    itemCount: comments.length,
                                    separatorBuilder: (_, __) =>
                                        const SizedBox(height: 8),
                                    itemBuilder: (context, index) {
                                      final comment = comments[index].data();
                                      return Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: AppColors.surfaceMuted,
                                          borderRadius:
                                              BorderRadius.circular(15),
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              comment['authorName'] as String? ??
                                                  'TiB User',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w800,
                                                fontSize: 12,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              comment['body'] as String? ?? '',
                                              style: const TextStyle(
                                                fontSize: 12.5,
                                                height: 1.4,
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                          decoration: BoxDecoration(
                            color: Theme.of(sheetBuildContext)
                                .colorScheme
                                .surface,
                            border: Border(
                              top: BorderSide(
                                color: Theme.of(sheetBuildContext)
                                    .colorScheme
                                    .outlineVariant,
                              ),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _commentController,
                                  textInputAction: TextInputAction.send,
                                  minLines: 1,
                                  maxLines: 4,
                                  onSubmitted: (_) => _addComment(
                                    document,
                                    _commentController,
                                  ),
                                  decoration: const InputDecoration(
                                    hintText: 'Write a reply...',
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton.filled(
                                tooltip: 'Send reply',
                                onPressed: () => _addComment(
                                  document,
                                  _commentController,
                                ),
                                icon: const Icon(Icons.send_rounded),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          );
        },
      );
    } finally {
      _commentController.clear();
    }
  }

  final _commentController = TextEditingController();

  Future<void> _toggleLike(
    DocumentReference<Map<String, dynamic>> postReference,
  ) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      final reactionRef = postReference.collection('likes').doc(uid);
      final existing = await reactionRef.get();
      if (existing.exists) {
        await reactionRef.delete();
        await postReference.update({
          'likeCount': FieldValue.increment(-1),
        });
      } else {
        await reactionRef.set({
          'createdAt': FieldValue.serverTimestamp(),
        });
        await postReference.update({
          'likeCount': FieldValue.increment(1),
        });
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update like: $error')),
      );
    }
  }

  Future<void> _addComment(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
    TextEditingController commentController,
  ) async {
    final text = commentController.text.trim();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || text.isEmpty) return;

    try {
      final userSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      final userData = userSnapshot.data() ?? <String, dynamic>{};
      final profileName = (userData['name'] as String?)?.trim();
      final displayName = FirebaseAuth.instance.currentUser?.displayName?.trim();

      await document.reference.collection('comments').add({
        'body': text,
        'authorId': uid,
        'authorName': profileName?.isNotEmpty == true
            ? profileName
            : (displayName?.isNotEmpty == true ? displayName : 'TiB User'),
        'createdAt': FieldValue.serverTimestamp(),
      });
      await document.reference.update({
        'commentCount': FieldValue.increment(1),
      });
      commentController.clear();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not send reply: $error')),
      );
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
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
                    style: const TextStyle(
                      fontSize: 10.5,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                body,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  height: 1.45,
                  fontSize: 12.5,
                ),
              ),
              const SizedBox(height: 11),
              Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: AppColors.secondary,
                    child: const Icon(
                      Icons.person_outline_rounded,
                      size: 16,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      author,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.favorite_border_rounded,
                    size: 16,
                    color: AppColors.textMuted,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${data['likeCount'] ?? 0}',
                    style: const TextStyle(
                      fontSize: 10.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Icon(
                    Icons.chat_bubble_outline_rounded,
                    size: 16,
                    color: AppColors.textMuted,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${data['commentCount'] ?? 0}',
                    style: const TextStyle(
                      fontSize: 10.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
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
          final documents = [...?snapshot.data?.docs];
          documents.sort(
            (a, b) => _date(b.data()['createdAt'])
                .compareTo(_date(a.data()['createdAt'])),
          );
          final visible = documents
              .where((document) => _matches(document.data()))
              .toList();

          return RefreshIndicator(
            onRefresh: () async {},
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
              children: [
                const Text(
                  'Style starts with a conversation.',
                  style: TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.w900,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Ask questions, share outfit ideas and learn from the whole TiB community.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _searchController,
                  onChanged: (value) => setState(() => _query = value.trim()),
                  decoration: InputDecoration(
                    hintText: 'Search forum',
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
                    children: _categories
                        .map(
                          (category) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(category),
                              selected: _category == category,
                              showCheckmark: false,
                              onSelected: (_) =>
                                  setState(() => _category = category),
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
                      style: TextStyle(
                        fontSize: 11,
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
                if (snapshot.hasError)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 28),
                    child: Text(
                      'Could not load the forum right now.\n${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.error),
                    ),
                  )
                else if (visible.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 48),
                    child: Center(
                      child: Text('No posts match your current filters.'),
                    ),
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
