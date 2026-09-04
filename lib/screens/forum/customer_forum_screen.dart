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

  static const _categories = <String>[
    'All',
    'Outfit',
    'Colour',
    'Styling',
    'AI Styling',
    'General',
  ];

  CollectionReference<Map<String, dynamic>> get _posts =>
      FirebaseFirestore.instance.collection('forum_posts');

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

  Future<void> _createPost() async {
    final titleController = TextEditingController();
    final bodyController = TextEditingController();
    String category = 'General';
    bool saving = false;

    try {
      final result = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (dialogBuildContext, setDialogState) {
            return AlertDialog(
              title: const Text('Start a discussion'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      textCapitalization: TextCapitalization.sentences,
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
                            (item) => DropdownMenuItem<String>(
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
                      textCapitalization: TextCapitalization.sentences,
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
                      : () => Navigator.pop(dialogContext, false),
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
                            return;
                          }

                          setDialogState(() => saving = true);
                          try {
                            final user = await FirebaseFirestore.instance
                                .collection('users')
                                .doc(uid)
                                .get();
                            final userData =
                                user.data() ?? <String, dynamic>{};
                            final profileName =
                                (userData['name'] as String?)?.trim();
                            final displayName = FirebaseAuth
                                .instance.currentUser?.displayName
                                ?.trim();

                            await _posts.add({
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
                              'lastActivityAt': FieldValue.serverTimestamp(),
                              'isOfficial': false,
                              'source': 'customer_forum',
                            });

                            if (dialogContext.mounted) {
                              Navigator.pop(dialogContext, true);
                            }
                          } catch (error) {
                            if (!dialogContext.mounted) return;
                            setDialogState(() => saving = false);
                            ScaffoldMessenger.of(dialogBuildContext)
                                .showSnackBar(
                              SnackBar(
                                content:
                                    Text('Could not create post: $error'),
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

      if (result == true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Your discussion is now visible to the community.'),
          ),
        );
      }
    } finally {
      titleController.dispose();
      bodyController.dispose();
    }
  }

  Future<bool> _addComment(
    DocumentReference<Map<String, dynamic>> postRef,
    String text,
  ) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final trimmed = text.trim();
    if (uid == null || trimmed.isEmpty) return false;

    try {
      final user = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      final data = user.data() ?? <String, dynamic>{};
      final profileName = (data['name'] as String?)?.trim();
      final displayName = FirebaseAuth.instance.currentUser?.displayName?.trim();
      final commentRef = postRef.collection('comments').doc();
      final batch = FirebaseFirestore.instance.batch();

      batch.set(commentRef, {
        'body': trimmed,
        'authorId': uid,
        'authorName': profileName?.isNotEmpty == true
            ? profileName
            : (displayName?.isNotEmpty == true ? displayName : 'TiB User'),
        'authorRole': data['role'] as String? ?? 'customer',
        'isOfficial': data['role'] == 'admin',
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
          SnackBar(content: Text('Could not send reply: $error')),
        );
      }
      return false;
    }
  }

  Future<void> _toggleLike(
    DocumentReference<Map<String, dynamic>> postRef,
  ) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      final likeRef = postRef.collection('likes').doc(uid);
      final existing = await likeRef.get();
      final postSnapshot = await postRef.get();
      final current =
          (postSnapshot.data()?['likeCount'] as num?)?.toInt() ?? 0;
      final batch = FirebaseFirestore.instance.batch();

      if (existing.exists) {
        batch.delete(likeRef);
        batch.update(
          postRef,
          {'likeCount': current > 0 ? current - 1 : 0},
        );
      } else {
        batch.set(likeRef, {
          'createdAt': FieldValue.serverTimestamp(),
        });
        batch.update(postRef, {'likeCount': current + 1});
      }
      await batch.commit();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update like: $error')),
        );
      }
    }
  }

  Future<void> _openPost(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => ForumPostDetailScreen(
          postReference: document.reference,
          initialData: document.data(),
          onToggleLike: () => _toggleLike(document.reference),
          onAddComment: (text) => _addComment(document.reference, text),
        ),
      ),
    );
  }

  Widget _categoryChip(String item) {
    final selected = _category == item;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(item),
        selected: selected,
        showCheckmark: false,
        side: BorderSide(
          color: selected ? AppColors.primary : AppColors.border,
        ),
        selectedColor: AppColors.primary,
        backgroundColor: AppColors.surface,
        labelStyle: TextStyle(
          color: selected ? AppColors.background : AppColors.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
        onSelected: (_) => setState(() => _category = item),
      ),
    );
  }

  Widget _postCard(QueryDocumentSnapshot<Map<String, dynamic>> document) {
    final data = document.data();
    final title = data['title'] as String? ?? 'Untitled post';
    final body = data['body'] as String? ?? '';
    final category = data['category'] as String? ?? 'General';
    final author = data['authorName'] as String? ?? 'TiB User';
    final official =
        data['isOfficial'] == true || data['source'] == 'admin_content';
    final likeCount = (data['likeCount'] as num?)?.toInt() ?? 0;
    final commentCount = (data['commentCount'] as num?)?.toInt() ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: official ? AppColors.primarySoft : AppColors.border,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () => _openPost(document),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 15, 16, 14),
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
                      color: official
                          ? AppColors.primarySoft
                          : AppColors.surfaceMuted,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      official ? 'VYEA TEAM' : category.toUpperCase(),
                      style: const TextStyle(
                        color: AppColors.primaryDark,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: .7,
                      ),
                    ),
                  ),
                  if (official) ...[
                    const SizedBox(width: 6),
                    const Icon(
                      Icons.verified_rounded,
                      size: 15,
                      color: AppColors.primary,
                    ),
                  ],
                  const Spacer(),
                  Text(
                    _relativeDate(
                      data['lastActivityAt'] ?? data['createdAt'],
                    ),
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  height: 1.15,
                ),
              ),
              if (body.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  body,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12.5,
                    height: 1.45,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  CircleAvatar(
                    radius: 15,
                    backgroundColor: official
                        ? AppColors.primarySoft
                        : AppColors.secondary,
                    child: Icon(
                      official
                          ? Icons.auto_awesome_outlined
                          : Icons.person_outline_rounded,
                      size: 17,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      author,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
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
                    '$likeCount',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 10.5,
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
                    '$commentCount',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 10.5,
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

  Widget _heroCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.surface, AppColors.primarySoft],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'STYLE IS BETTER\nWHEN IT IS SHARED.',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 23,
              height: 1.05,
              fontWeight: FontWeight.w900,
              letterSpacing: -.4,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Ask, share, inspire and learn from people who care about personal style too.',
            style: TextStyle(
              color: AppColors.textSecondary,
              height: 1.45,
              fontSize: 12.5,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        titleSpacing: 20,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'VYEA',
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 15,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.8,
              ),
            ),
            Text(
              'Community',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _createPost,
            tooltip: 'Create post',
            icon: const Icon(Icons.add_comment_outlined),
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createPost,
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.background,
        icon: const Icon(Icons.edit_outlined),
        label: const Text('Create Post'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _posts.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Could not load forum: ${snapshot.error}'),
              ),
            );
          }

          final documents = [...?snapshot.data?.docs];
          documents.sort(
            (a, b) => _date(
              b.data()['lastActivityAt'] ?? b.data()['createdAt'],
            ).compareTo(
              _date(a.data()['lastActivityAt'] ?? a.data()['createdAt']),
            ),
          );
          final visible =
              documents.where((doc) => _matches(doc.data())).toList();

          return RefreshIndicator(
            onRefresh: () async {},
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 110),
              children: [
                _heroCard(),
                const SizedBox(height: 14),
                TextField(
                  controller: _searchController,
                  onChanged: (value) => setState(() => _query = value.trim()),
                  decoration: InputDecoration(
                    hintText: 'Search discussions',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _query = '');
                            },
                            icon: const Icon(Icons.close_rounded),
                          ),
                    filled: true,
                    fillColor: AppColors.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(17),
                      borderSide:
                          const BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(17),
                      borderSide:
                          const BorderSide(color: AppColors.border),
                    ),
                  ),
                ),
                const SizedBox(height: 11),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _categories.map(_categoryChip).toList(),
                  ),
                ),
                const SizedBox(height: 19),
                Row(
                  children: [
                    const Text(
                      'DISCUSSIONS',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.3,
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
                    documents.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (visible.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceMuted,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: const Column(
                      children: [
                        Icon(
                          Icons.forum_outlined,
                          size: 30,
                          color: AppColors.primary,
                        ),
                        SizedBox(height: 9),
                        Text(
                          'No discussions found',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Try a different search or start a new conversation.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                            height: 1.4,
                          ),
                        ),
                      ],
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

class ForumPostDetailScreen extends StatefulWidget {
  const ForumPostDetailScreen({
    super.key,
    required this.postReference,
    required this.initialData,
    required this.onToggleLike,
    required this.onAddComment,
  });

  final DocumentReference<Map<String, dynamic>> postReference;
  final Map<String, dynamic> initialData;
  final Future<void> Function() onToggleLike;
  final Future<bool> Function(String text) onAddComment;

  @override
  State<ForumPostDetailScreen> createState() => _ForumPostDetailScreenState();
}

class _ForumPostDetailScreenState extends State<ForumPostDetailScreen> {
  final _commentController = TextEditingController();
  final _commentFocusNode = FocusNode();
  final _scrollController = ScrollController();
  bool _sending = false;

  @override
  void dispose() {
    _commentController.dispose();
    _commentFocusNode.dispose();
    _scrollController.dispose();
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

  Future<void> _send() async {
    final text = _commentController.text.trim();
    if (_sending || text.isEmpty) return;
    setState(() => _sending = true);
    try {
      final success = await widget.onAddComment(text);
      if (!mounted) return;
      if (success) {
        _commentController.clear();
        await Future<void>.delayed(const Duration(milliseconds: 120));
        if (mounted && _scrollController.hasClients) {
          await _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
          );
        }
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Widget _replyCard(Map<String, dynamic> comment) {
    final official =
        comment['isOfficial'] == true || comment['authorRole'] == 'admin';
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: official
            ? AppColors.primarySoft.withValues(alpha: .25)
            : AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: official ? AppColors.primarySoft : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: official
                    ? AppColors.primarySoft
                    : AppColors.secondary,
                child: Icon(
                  official
                      ? Icons.auto_awesome_outlined
                      : Icons.person_outline_rounded,
                  size: 17,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  comment['authorName'] as String? ?? 'TiB User',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (official)
                const Text(
                  'VYEA Team',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    color: AppColors.primary,
                  ),
                ),
              const SizedBox(width: 7),
              Text(
                _relativeDate(comment['createdAt']),
                style: const TextStyle(
                  fontSize: 9.5,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            comment['body'] as String? ?? '',
            style: const TextStyle(fontSize: 13, height: 1.5),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Discussion')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: widget.postReference.snapshots(),
        builder: (context, postSnapshot) {
          if (postSnapshot.hasError) {
            return Center(
              child: Text('Could not load post: ${postSnapshot.error}'),
            );
          }

          final data = postSnapshot.data?.data() ?? widget.initialData;
          final official =
              data['isOfficial'] == true || data['source'] == 'admin_content';
          final title = data['title'] as String? ?? 'Forum post';
          final body = data['body'] as String? ?? '';
          final author = data['authorName'] as String? ?? 'TiB User';
          final category = data['category'] as String? ?? 'General';

          return Column(
            children: [
              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: widget.postReference
                      .collection('comments')
                      .snapshots(),
                  builder: (context, commentsSnapshot) {
                    if (commentsSnapshot.hasError) {
                      return Center(
                        child: Text(
                          'Could not load replies: ${commentsSnapshot.error}',
                        ),
                      );
                    }

                    final comments = [...?commentsSnapshot.data?.docs];
                    comments.sort(
                      (a, b) => _date(a.data()['createdAt'])
                          .compareTo(_date(b.data()['createdAt'])),
                    );

                    return ListView(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: official
                                ? AppColors.primarySoft.withValues(alpha: .24)
                                : AppColors.surface,
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(
                              color: official
                                  ? AppColors.primarySoft
                                  : AppColors.border,
                            ),
                          ),
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
                                      color: official
                                          ? AppColors.primarySoft
                                          : AppColors.surfaceMuted,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      official
                                          ? 'VYEA TEAM'
                                          : category.toUpperCase(),
                                      style: const TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w900,
                                        color: AppColors.primaryDark,
                                      ),
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    _relativeDate(data['createdAt']),
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                title,
                                style: const TextStyle(
                                  fontSize: 25,
                                  fontWeight: FontWeight.w900,
                                  height: 1.12,
                                ),
                              ),
                              const SizedBox(height: 7),
                              Text(
                                'Posted by $author',
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 11,
                                ),
                              ),
                              const SizedBox(height: 14),
                              Text(
                                body,
                                style: const TextStyle(
                                  fontSize: 14,
                                  height: 1.6,
                                ),
                              ),
                              const SizedBox(height: 14),
                              Row(
                                children: [
                                  TextButton.icon(
                                    onPressed: widget.onToggleLike,
                                    icon: const Icon(
                                      Icons.favorite_border_rounded,
                                      size: 18,
                                    ),
                                    label: Text('${data['likeCount'] ?? 0}'),
                                  ),
                                  const SizedBox(width: 8),
                                  const Icon(
                                    Icons.forum_outlined,
                                    size: 17,
                                    color: AppColors.textMuted,
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    '${comments.length} replies',
                                    style: const TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 22),
                        const Text(
                          'REPLIES',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.3,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 10),
                        if (commentsSnapshot.connectionState ==
                                ConnectionState.waiting &&
                            comments.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(24),
                            child: Center(child: CircularProgressIndicator()),
                          )
                        else if (comments.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceMuted,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Text(
                              'No replies yet. Start the conversation below.',
                            ),
                          )
                        else
                          ...comments.map(
                            (commentDoc) => _replyCard(commentDoc.data()),
                          ),
                      ],
                    );
                  },
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _commentController,
                          focusNode: _commentFocusNode,
                          minLines: 1,
                          maxLines: 4,
                          textInputAction: TextInputAction.newline,
                          decoration: InputDecoration(
                            hintText: 'Write a reply...',
                            filled: true,
                            fillColor: AppColors.surface,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(18),
                              borderSide: const BorderSide(
                                color: AppColors.border,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(18),
                              borderSide: const BorderSide(
                                color: AppColors.border,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        onPressed: _sending ? null : _send,
                        icon: _sending
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.send_rounded),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
