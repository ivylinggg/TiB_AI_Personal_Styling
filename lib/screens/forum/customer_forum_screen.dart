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
  static const _categories = <String>['All', 'Outfit', 'Colour', 'Styling', 'AI Styling', 'General'];

  CollectionReference<Map<String, dynamic>> get _posts => FirebaseFirestore.instance.collection('forum_posts');

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  DateTime _date(dynamic value) => value is Timestamp ? value.toDate() : DateTime.fromMillisecondsSinceEpoch(0);

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
    return (_category == 'All' || category == _category) && (query.isEmpty || title.contains(query) || body.contains(query) || category.toLowerCase().contains(query));
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
          builder: (dialogBuildContext, setDialogState) => AlertDialog(
            title: const Text('Create a forum post'),
            content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: titleController, decoration: const InputDecoration(labelText: 'Title', hintText: 'What do you want to discuss?')),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(initialValue: category, decoration: const InputDecoration(labelText: 'Category'), items: _categories.where((item) => item != 'All').map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(), onChanged: saving ? null : (value) => setDialogState(() => category = value ?? 'General')),
              const SizedBox(height: 12),
              TextField(controller: bodyController, minLines: 4, maxLines: 7, decoration: const InputDecoration(labelText: 'Post', hintText: 'Share your styling question, idea or experience.')),
            ])),
            actions: [
              TextButton(onPressed: saving ? null : () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
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
                    final profileName = (userData['name'] as String?)?.trim();
                    final displayName = FirebaseAuth.instance.currentUser?.displayName?.trim();
                    await _posts.add({
                      'title': title,
                      'body': body,
                      'category': category,
                      'authorId': uid,
                      'authorName': profileName?.isNotEmpty == true ? profileName : (displayName?.isNotEmpty == true ? displayName : 'TiB User'),
                      'likeCount': 0,
                      'commentCount': 0,
                      'createdAt': FieldValue.serverTimestamp(),
                      'lastActivityAt': FieldValue.serverTimestamp(),
                      'isOfficial': false,
                      'source': 'customer_forum',
                    });
                    if (dialogContext.mounted) Navigator.pop(dialogContext, true);
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
      if (result == true && mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Your post is now visible to the TiB community.')));
    } finally {
      titleController.dispose();
      bodyController.dispose();
    }
  }

  Future<bool> _addComment(DocumentReference<Map<String, dynamic>> postRef, String text) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final trimmed = text.trim();
    if (uid == null || trimmed.isEmpty) return false;
    try {
      final user = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final data = user.data() ?? <String, dynamic>{};
      final profileName = (data['name'] as String?)?.trim();
      final displayName = FirebaseAuth.instance.currentUser?.displayName?.trim();
      final commentRef = postRef.collection('comments').doc();
      final batch = FirebaseFirestore.instance.batch();
      batch.set(commentRef, {
        'body': trimmed,
        'authorId': uid,
        'authorName': profileName?.isNotEmpty == true ? profileName : (displayName?.isNotEmpty == true ? displayName : 'TiB User'),
        'authorRole': data['role'] as String? ?? 'customer',
        'isOfficial': data['role'] == 'admin',
        'createdAt': FieldValue.serverTimestamp(),
      });
      batch.update(postRef, {'commentCount': FieldValue.increment(1), 'lastActivityAt': FieldValue.serverTimestamp()});
      await batch.commit();
      return true;
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not send reply: $error')));
      return false;
    }
  }

  Future<void> _toggleLike(DocumentReference<Map<String, dynamic>> postRef) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final likeRef = postRef.collection('likes').doc(uid);
      final existing = await likeRef.get();
      final postSnapshot = await postRef.get();
      final current = (postSnapshot.data()?['likeCount'] as num?)?.toInt() ?? 0;
      final batch = FirebaseFirestore.instance.batch();
      if (existing.exists) {
        batch.delete(likeRef);
        batch.update(postRef, {'likeCount': current > 0 ? current - 1 : 0});
      } else {
        batch.set(likeRef, {'createdAt': FieldValue.serverTimestamp()});
        batch.update(postRef, {'likeCount': current + 1});
      }
      await batch.commit();
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not update like: $error')));
    }
  }

  Future<void> _openPost(QueryDocumentSnapshot<Map<String, dynamic>> document) async {
    await Navigator.of(context).push<void>(MaterialPageRoute(builder: (_) => ForumPostDetailScreen(
      postReference: document.reference,
      initialData: document.data(),
      onToggleLike: () => _toggleLike(document.reference),
      onAddComment: (text) => _addComment(document.reference, text),
    )));
  }

  Widget _postCard(QueryDocumentSnapshot<Map<String, dynamic>> document) {
    final data = document.data();
    final title = data['title'] as String? ?? 'Untitled post';
    final body = data['body'] as String? ?? '';
    final category = data['category'] as String? ?? 'General';
    final author = data['authorName'] as String? ?? 'TiB User';
    final official = data['isOfficial'] == true || data['source'] == 'admin_content';
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: official ? AppColors.primarySoft : AppColors.border)),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => _openPost(document),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5), decoration: BoxDecoration(color: official ? AppColors.primarySoft : AppColors.surfaceMuted, borderRadius: BorderRadius.circular(10)), child: Text(official ? 'TiB Team' : category, style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: AppColors.primaryDark))),
              if (official) ...[const SizedBox(width: 7), const Icon(Icons.verified_rounded, size: 15, color: AppColors.primary)],
              const Spacer(),
              Text(_relativeDate(data['createdAt']), style: const TextStyle(fontSize: 10.5, color: AppColors.textMuted)),
            ]),
            const SizedBox(height: 10),
            Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            Text(body, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.textSecondary, height: 1.45, fontSize: 12.5)),
            const SizedBox(height: 11),
            Row(children: [
              CircleAvatar(radius: 14, backgroundColor: AppColors.secondary, child: Icon(official ? Icons.auto_awesome_outlined : Icons.person_outline_rounded, size: 16, color: AppColors.primary)),
              const SizedBox(width: 7),
              Expanded(child: Text(author, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700))),
              const Icon(Icons.favorite_border_rounded, size: 16, color: AppColors.textMuted), const SizedBox(width: 4), Text('${data['likeCount'] ?? 0}', style: const TextStyle(fontSize: 10.5, color: AppColors.textSecondary)),
              const SizedBox(width: 10), const Icon(Icons.chat_bubble_outline_rounded, size: 16, color: AppColors.textMuted), const SizedBox(width: 4), Text('${data['commentCount'] ?? 0}', style: const TextStyle(fontSize: 10.5, color: AppColors.textSecondary)),
            ]),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('TiB Forum'), actions: [IconButton(onPressed: _createPost, tooltip: 'Create post', icon: const Icon(Icons.add_comment_outlined))]),
      backgroundColor: AppColors.background,
      floatingActionButton: FloatingActionButton.extended(onPressed: _createPost, icon: const Icon(Icons.edit_outlined), label: const Text('Create Post')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _posts.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text('Could not load forum: ${snapshot.error}'));
          final documents = [...?snapshot.data?.docs];
          documents.sort((a, b) => _date(b.data()['lastActivityAt'] ?? b.data()['createdAt']).compareTo(_date(a.data()['lastActivityAt'] ?? a.data()['createdAt'])));
          final visible = documents.where((doc) => _matches(doc.data())).toList();
          return RefreshIndicator(
            onRefresh: () async {},
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
              children: [
                const Text('Style starts with a conversation.', style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900, height: 1.1)),
                const SizedBox(height: 6),
                const Text('Ask questions, share outfit ideas and learn from the whole TiB community.', style: TextStyle(color: AppColors.textSecondary, height: 1.4)),
                const SizedBox(height: 16),
                TextField(controller: _searchController, onChanged: (value) => setState(() => _query = value.trim()), decoration: InputDecoration(hintText: 'Search forum', prefixIcon: const Icon(Icons.search), border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)))),
                const SizedBox(height: 12),
                SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: _categories.map((item) => Padding(padding: const EdgeInsets.only(right: 8), child: ChoiceChip(label: Text(item), selected: _category == item, showCheckmark: false, onSelected: (_) => setState(() => _category = item))).toList())),
                const SizedBox(height: 20),
                Row(children: [const Text('SHARED COMMUNITY', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.3, color: AppColors.textSecondary)), const Spacer(), Text('${visible.length} posts', style: const TextStyle(fontSize: 11, color: AppColors.textMuted))]),
                const SizedBox(height: 10),
                if (snapshot.connectionState == ConnectionState.waiting && documents.isEmpty) const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))
                else if (visible.isEmpty) const Padding(padding: EdgeInsets.fromLTRB(0, 30, 0, 40), child: Center(child: Text('No posts match your search yet.')))
                else ...visible.map(_postCard),
              ],
            ),
          );
        },
      ),
    );
  }
}

class ForumPostDetailScreen extends StatefulWidget {
  const ForumPostDetailScreen({super.key, required this.postReference, required this.initialData, required this.onToggleLike, required this.onAddComment});
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
    _commentController.dispose(); _commentFocusNode.dispose(); _scrollController.dispose(); super.dispose();
  }

  DateTime _date(dynamic value) => value is Timestamp ? value.toDate() : DateTime.fromMillisecondsSinceEpoch(0);

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
        if (mounted && _scrollController.hasClients) await _scrollController.animateTo(_scrollController.position.maxScrollExtent, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Forum Discussion')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: widget.postReference.snapshots(),
        builder: (context, postSnapshot) {
          final postData = postSnapshot.data?.data() ?? widget.initialData;
          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: widget.postReference.collection('comments').snapshots(),
            builder: (context, commentsSnapshot) {
              if (postSnapshot.hasError || commentsSnapshot.hasError) {
                return Column(children: [Expanded(child: ListView(controller: _scrollController, padding: const EdgeInsets.fromLTRB(20, 16, 20, 28), children: [_originalPostCard(postData), const SizedBox(height: 22), Text('Unable to load replies: ${commentsSnapshot.error ?? postSnapshot.error}', style: const TextStyle(color: AppColors.error))])), _replyBar(theme)]);
              }
              final comments = [...?commentsSnapshot.data?.docs];
              comments.sort((a, b) => _date(a.data()['createdAt']).compareTo(_date(b.data()['createdAt'])));
              return Column(children: [
                Expanded(child: ListView(controller: _scrollController, keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag, padding: const EdgeInsets.fromLTRB(20, 16, 20, 28), children: [
                  _originalPostCard(postData),
                  const SizedBox(height: 22),
                  Row(children: [const Text('REPLIES', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.3, color: AppColors.textSecondary)), const Spacer(), Text('${comments.length}', style: const TextStyle(fontSize: 11, color: AppColors.textMuted))]),
                  const SizedBox(height: 10),
                  if (commentsSnapshot.connectionState == ConnectionState.waiting && comments.isEmpty) const Padding(padding: EdgeInsets.all(30), child: Center(child: CircularProgressIndicator()))
                  else if (comments.isEmpty) _emptyReplies()
                  else ...comments.asMap().entries.map((entry) => _replyCard(entry.value.data(), entry.key == comments.length - 1)),
                ])),
                _replyBar(theme),
              ]);
            },
          );
        },
      ),
    );
  }

  Widget _originalPostCard(Map<String, dynamic> data) {
    final official = data['isOfficial'] == true || data['source'] == 'admin_content';
    final category = data['category'] as String? ?? 'General';
    final author = data['authorName'] as String? ?? 'TiB User';
    final title = data['title'] as String? ?? 'Forum post';
    final body = data['body'] as String? ?? '';
    final likeCount = (data['likeCount'] as num?)?.toInt() ?? 0;
    final commentCount = (data['commentCount'] as num?)?.toInt() ?? 0;
    return Card(elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22), side: BorderSide(color: official ? AppColors.primarySoft : AppColors.border)), child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5), decoration: BoxDecoration(color: official ? AppColors.primarySoft : AppColors.surfaceMuted, borderRadius: BorderRadius.circular(10)), child: Text(official ? 'TiB Team' : category, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.primaryDark))), if (official) ...[const SizedBox(width: 6), const Icon(Icons.verified_rounded, size: 16, color: AppColors.primary)]]),
      const SizedBox(height: 12), Text(title, style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w900, height: 1.1)),
      const SizedBox(height: 7), Text('Posted by $author · ${_relativeDate(data['createdAt'])}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
      const SizedBox(height: 16), Text(body, style: const TextStyle(fontSize: 14, height: 1.6)),
      const SizedBox(height: 16), Row(children: [OutlinedButton.icon(onPressed: widget.onToggleLike, icon: const Icon(Icons.favorite_border_rounded), label: Text('Like $likeCount')), const SizedBox(width: 10), Text('$commentCount replies', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12))]),
    ])));
  }

  Widget _replyCard(Map<String, dynamic> data, bool last) {
    final author = data['authorName'] as String? ?? 'TiB User';
    final body = data['body'] as String? ?? '';
    final official = data['isOfficial'] == true || data['authorRole'] == 'admin';
    return Container(margin: EdgeInsets.only(bottom: last ? 0 : 10), padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: official ? AppColors.primarySoft : AppColors.border)), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      CircleAvatar(radius: 19, backgroundColor: official ? AppColors.primarySoft : AppColors.secondary, child: Icon(official ? Icons.auto_awesome_outlined : Icons.person_outline_rounded, size: 19, color: AppColors.primary)),
      const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Expanded(child: Text(author, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800))), if (official) const Padding(padding: EdgeInsets.only(right: 6), child: Text('TiB TEAM', style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w900, color: AppColors.primary))), Text(_relativeDate(data['createdAt']), style: const TextStyle(fontSize: 9.5, color: AppColors.textMuted))]), const SizedBox(height: 6), Text(body, style: const TextStyle(fontSize: 13, height: 1.45))]))
    ]));
  }

  Widget _emptyReplies() => Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: AppColors.surfaceMuted, borderRadius: BorderRadius.circular(16)), child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('No replies yet.', style: TextStyle(fontWeight: FontWeight.w700)), SizedBox(height: 4), Text('Be the first to join the conversation.', style: TextStyle(color: AppColors.textSecondary, fontSize: 12))]));

  Widget _replyBar(ThemeData theme) => Material(color: theme.colorScheme.surface, elevation: 8, child: SafeArea(top: false, child: Padding(padding: const EdgeInsets.fromLTRB(16, 10, 16, 12), child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [Expanded(child: TextField(controller: _commentController, focusNode: _commentFocusNode, minLines: 1, maxLines: 4, textInputAction: TextInputAction.send, onSubmitted: (_) => _send(), decoration: const InputDecoration(hintText: 'Write a reply...'))), const SizedBox(width: 8), IconButton.filled(onPressed: _sending ? null : _send, tooltip: 'Send reply', icon: _sending ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.send_rounded))]))));
}
