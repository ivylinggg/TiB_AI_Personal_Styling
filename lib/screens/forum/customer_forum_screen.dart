import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../models/app_colors.dart';
import '../../services/firestore_service.dart';

class CustomerForumScreen extends StatefulWidget {
  const CustomerForumScreen({super.key});

  @override
  State<CustomerForumScreen> createState() => _CustomerForumScreenState();
}

class _CustomerForumScreenState extends State<CustomerForumScreen>
    with WidgetsBindingObserver {
  final TextEditingController _searchController = TextEditingController();
  String _category = 'All';
  bool _showMineOnly = false;
  String _search = '';

  final List<String> _categories = const [
    'All',
    'Outfit',
    'Colour',
    'Styling',
    'AI Styling',
    'General',
  ];

  User? get _currentUser => FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _searchController.addListener(() {
      final value = _searchController.text.trim().toLowerCase();
      if (value != _search) setState(() => _search = value);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) setState(() {});
  }

  bool _isOfficial(Map<String, dynamic> data) {
    return data['isOfficial'] == true ||
        data['source'] == 'admin_content' ||
        data['source'] == 'admin_forum';
  }

  DateTime _date(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value) ?? DateTime(1970);
    return DateTime(1970);
  }

  String _relativeDate(dynamic value) {
    final date = _date(value);
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${date.day}/${date.month}/${date.year}';
  }

  Future<void> _createPost() async {
    final titleController = TextEditingController();
    final bodyController = TextEditingController();
    var category = 'General';
    final formKey = GlobalKey<FormState>();

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Create a post', style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: category,
                        decoration: const InputDecoration(labelText: 'Category'),
                        items: _categories
                            .where((item) => item != 'All')
                            .map((item) => DropdownMenuItem(value: item, child: Text(item)))
                            .toList(),
                        onChanged: (value) => setModalState(() => category = value ?? 'General'),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: titleController,
                        maxLength: 90,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(labelText: 'Title'),
                        validator: (value) {
                          final text = value?.trim() ?? '';
                          if (text.length < 3) return 'Title is too short';
                          return null;
                        },
                      ),
                      TextFormField(
                        controller: bodyController,
                        maxLength: 1500,
                        maxLines: 6,
                        decoration: const InputDecoration(labelText: 'Share your thoughts'),
                        validator: (value) {
                          final text = value?.trim() ?? '';
                          if (text.length < 3) return 'Please add a little more detail';
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () async {
                            if (!formKey.currentState!.validate()) return;
                            final user = _currentUser;
                            if (user == null) return;
                            try {
                              await FirebaseFirestore.instance.collection('forum_posts').add({
                                'authorId': user.uid,
                                'authorName': user.displayName?.trim().isNotEmpty == true
                                    ? user.displayName!.trim()
                                    : 'VYEA User',
                                'authorRole': 'customer',
                                'title': titleController.text.trim(),
                                'body': bodyController.text.trim(),
                                'category': category,
                                'status': 'published',
                                'source': 'customer_forum',
                                'isOfficial': false,
                                'createdAt': FieldValue.serverTimestamp(),
                                'updatedAt': FieldValue.serverTimestamp(),
                              });
                              if (context.mounted) Navigator.pop(context, true);
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Could not create post: $e')),
                                );
                              }
                            }
                          },
                          child: const Text('Publish'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    titleController.dispose();
    bodyController.dispose();
    if (result == true && mounted) setState(() {});
  }

  Future<void> _toggleLike(DocumentReference<Map<String, dynamic>> postRef) async {
    final user = _currentUser;
    if (user == null) return;
    final likeRef = postRef.collection('likes').doc(user.uid);
    final snapshot = await likeRef.get();
    if (snapshot.exists) {
      await likeRef.delete();
    } else {
      await likeRef.set({
        'userId': user.uid,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  void _openPost(
    DocumentReference<Map<String, dynamic>> reference,
    Map<String, dynamic> data,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ForumPostDetailScreen(
          postReference: reference,
          initialData: data,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _currentUser;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Forum'),
        actions: [
          IconButton(onPressed: _createPost, icon: const Icon(Icons.add_comment_outlined)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createPost,
        icon: const Icon(Icons.edit_outlined),
        label: const Text('Post'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('forum_posts')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Could not load forum: ${snapshot.error}'));
          }
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final posts = snapshot.data!.docs.where((doc) {
            final data = doc.data();
            if (data['status'] != 'published') return false;
            if (_showMineOnly && data['authorId'] != user?.uid) return false;
            if (_category != 'All' && data['category'] != _category) return false;
            if (_search.isEmpty) return true;
            final haystack = '${data['title'] ?? ''} ${data['body'] ?? ''} ${data['category'] ?? ''}'.toLowerCase();
            return haystack.contains(_search);
          }).toList();

          return RefreshIndicator(
            onRefresh: () async => setState(() {}),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 100),
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search discussions',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _search.isEmpty
                        ? null
                        : IconButton(
                            onPressed: _searchController.clear,
                            icon: const Icon(Icons.clear),
                          ),
                  ),
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _categories.map((category) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(category),
                          selected: _category == category,
                          onSelected: (_) => setState(() => _category = category),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 8),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('My Posts'),
                  subtitle: const Text('Show only discussions you created'),
                  value: _showMineOnly,
                  onChanged: (value) => setState(() => _showMineOnly = value),
                ),
                const SizedBox(height: 4),
                if (posts.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 80),
                    child: Center(child: Text('No discussions found.')),
                  )
                else
                  ...posts.map((doc) {
                    final data = doc.data();
                    final official = _isOfficial(data);
                    return _PostCard(
                      data: data,
                      official: official,
                      relativeDate: _relativeDate(data['createdAt']),
                      onTap: () => _openPost(doc.reference, data),
                      onLike: () => _toggleLike(doc.reference),
                    );
                  }),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _PostCard extends StatelessWidget {
  const _PostCard({
    required this.data,
    required this.official,
    required this.relativeDate,
    required this.onTap,
    required this.onLike,
  });

  final Map<String, dynamic> data;
  final bool official;
  final String relativeDate;
  final VoidCallback onTap;
  final VoidCallback onLike;

  @override
  Widget build(BuildContext context) {
    final author = data['authorName'] as String? ?? 'VYEA User';
    final category = data['category'] as String? ?? 'General';
    final title = data['title'] as String? ?? 'Untitled';
    final body = data['body'] as String? ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    child: Text(author.isEmpty ? 'V' : author[0].toUpperCase()),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(author, style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                  if (official)
                    const Row(
                      children: [
                        Icon(Icons.verified, size: 16),
                        SizedBox(width: 4),
                        Text('Official', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(category.toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700)),
              const SizedBox(height: 5),
              Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
              const SizedBox(height: 7),
              Text(body, maxLines: 3, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 12),
              Row(
                children: [
                  Text(relativeDate, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                  const Spacer(),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: onLike,
                    icon: const Icon(Icons.favorite_border, size: 18),
                  ),
                  StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: FirebaseFirestore.instance.collection('forum_posts').doc(data['id'] as String?).collection('likes').snapshots(),
                    builder: (context, snapshot) {
                      return Text('${snapshot.data?.docs.length ?? 0}', style: const TextStyle(fontSize: 11));
                    },
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.chevron_right, size: 20),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ForumPostDetailScreen extends StatefulWidget {
  const ForumPostDetailScreen({
    super.key,
    required this.postReference,
    required this.initialData,
  });

  final DocumentReference<Map<String, dynamic>> postReference;
  final Map<String, dynamic> initialData;

  @override
  State<ForumPostDetailScreen> createState() => _ForumPostDetailScreenState();
}

class _ForumPostDetailScreenState extends State<ForumPostDetailScreen> {
  final TextEditingController _replyController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _sending = false;

  User? get _currentUser => FirebaseAuth.instance.currentUser;

  DateTime _date(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value) ?? DateTime(1970);
    return DateTime(1970);
  }

  String _relativeDate(dynamic value) {
    final date = _date(value);
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${date.day}/${date.month}/${date.year}';
  }

  bool _isOfficial(Map<String, dynamic> data) {
    return data['isOfficial'] == true ||
        data['source'] == 'admin_content' ||
        data['source'] == 'admin_forum';
  }

  Future<void> _sendReply() async {
    final user = _currentUser;
    final body = _replyController.text.trim();
    if (user == null || body.length < 3 || body.length > 1500 || _sending) return;

    setState(() => _sending = true);
    try {
      final userDoc = await FirestoreService.getUser(user.uid);
      final role = (userDoc?['role'] as String?)?.trim().toLowerCase() ?? 'customer';
      final isOfficialReply = role == 'admin' || role == 'consultant';
      await widget.postReference.collection('comments').add({
        'authorId': user.uid,
        'authorName': user.displayName?.trim().isNotEmpty == true ? user.displayName!.trim() : 'VYEA User',
        'authorRole': role,
        'body': body,
        'status': 'published',
        'isOfficial': isOfficialReply,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      _replyController.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not send reply: $e')));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  void dispose() {
    _replyController.dispose();
    _scrollController.dispose();
    super.dispose();
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
            return Center(child: Text('Could not load post: ${postSnapshot.error}'));
          }
          final data = postSnapshot.data?.data() ?? widget.initialData;
          if (data['status'] == 'hidden') {
            return const Center(child: Text('This discussion is no longer available.'));
          }

          final official = _isOfficial(data);
          final title = data['title'] as String? ?? 'Forum post';
          final body = data['body'] as String? ?? '';
          final author = data['authorName'] as String? ?? 'VYEA User';
          final category = data['category'] as String? ?? 'General';

          return Column(
            children: [
              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: widget.postReference.collection('comments').snapshots(),
                  builder: (context, commentsSnapshot) {
                    if (commentsSnapshot.hasError) {
                      return Center(child: Text('Could not load replies: ${commentsSnapshot.error}'));
                    }
                    final comments = [...?commentsSnapshot.data?.docs]
                        .where((doc) => doc.data()['status'] != 'hidden')
                        .toList();
                    comments.sort((a, b) => _date(a.data()['createdAt']).compareTo(_date(b.data()['createdAt'])));

                    return ListView(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(category.toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700)),
                                  const Spacer(),
                                  Text(_relativeDate(data['createdAt']), style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  CircleAvatar(radius: 14, child: Text(author.isEmpty ? 'V' : author[0].toUpperCase())),
                                  const SizedBox(width: 8),
                                  Text(author, style: const TextStyle(fontWeight: FontWeight.w600)),
                                  if (official) ...[
                                    const SizedBox(width: 8),
                                    const Icon(Icons.verified, size: 16),
                                    const SizedBox(width: 4),
                                    const Text('Official', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 14),
                              Text(body, style: const TextStyle(fontSize: 14, height: 1.55)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text('Replies (${comments.length})', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 8),
                        if (comments.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 26),
                            child: Text('Be the first to reply.'),
                          )
                        else
                          ...comments.map((doc) => _buildComment(doc.data())),
                      ],
                    );
                  },
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _replyController,
                          maxLength: 1500,
                          maxLines: 4,
                          minLines: 1,
                          decoration: const InputDecoration(hintText: 'Write a reply...'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        onPressed: _sending ? null : _sendReply,
                        icon: _sending
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
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

  Widget _buildComment(Map<String, dynamic> comment) {
    final author = comment['authorName'] as String? ?? 'VYEA User';
    final official = _isOfficial(comment);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(radius: 13, child: Text(author.isEmpty ? 'V' : author[0].toUpperCase())),
              const SizedBox(width: 8),
              Expanded(child: Text(author, style: const TextStyle(fontWeight: FontWeight.w600))),
              if (official) ...[
                const Icon(Icons.verified, size: 15),
                const SizedBox(width: 4),
                const Text('Official', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600)),
              ],
              const SizedBox(width: 7),
              Text(_relativeDate(comment['createdAt']), style: const TextStyle(fontSize: 9.5, color: AppColors.textMuted)),
            ],
          ),
          const SizedBox(height: 10),
          Text(comment['body'] as String? ?? '', style: const TextStyle(fontSize: 13, height: 1.5)),
        ],
      ),
    );
  }
}
