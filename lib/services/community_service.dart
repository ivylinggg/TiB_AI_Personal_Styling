import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CommunityService {
  CommunityService._();

  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static const _maxTitleLength = 120;
  static const _maxBodyLength = 5000;
  static const _maxNameLength = 80;
  static const _maxCategoryLength = 40;
  static const _maxContentIdLength = 200;
  static const _maxTypeLength = 40;
  static const _maxLimit = 100;

  static CollectionReference<Map<String, dynamic>> get posts =>
      _db.collection('forum_posts');

  static Stream<QuerySnapshot<Map<String, dynamic>>> forumPostsStream() =>
      posts.snapshots();

  static Stream<QuerySnapshot<Map<String, dynamic>>> commentsStream(
    String postId,
  ) =>
      _isValidId(postId) && postId.length <= _maxContentIdLength
          ? posts.doc(postId).collection('comments').snapshots()
          : const Stream.empty();

  static bool _isValidId(String value) => value.trim().isNotEmpty;

  static String? _boundedText(String value, int maxLength) {
    final trimmed = value.trim();
    if (trimmed.isEmpty || trimmed.length > maxLength) return null;
    return trimmed;
  }

  static String _displayName(String value, {String fallback = 'TiB User'}) {
    final trimmed = value.trim();
    if (trimmed.isEmpty || trimmed.length > _maxNameLength) return fallback;
    return trimmed;
  }

  static Future<DocumentReference<Map<String, dynamic>>> createPost({
    required String title,
    required String body,
    required String category,
    required String authorId,
    required String authorName,
    String? contentId,
    String? contentTitle,
  }) async {
    final cleanTitle = _boundedText(title, _maxTitleLength);
    final cleanBody = _boundedText(body, _maxBodyLength);
    final cleanCategory = _boundedText(category, _maxCategoryLength);
    final cleanAuthorId = _boundedText(authorId, _maxContentIdLength);
    if (cleanTitle == null ||
        cleanBody == null ||
        cleanCategory == null ||
        cleanAuthorId == null) {
      throw ArgumentError('Invalid community post data.');
    }

    final cleanContentId = contentId?.trim();
    final cleanContentTitle = contentTitle?.trim();
    if (cleanContentId != null &&
        (cleanContentId.isEmpty ||
            cleanContentId.length > _maxContentIdLength)) {
      throw ArgumentError('Invalid content ID.');
    }
    if (cleanContentTitle != null && cleanContentTitle.length > _maxTitleLength) {
      throw ArgumentError('Invalid content title.');
    }

    final data = <String, dynamic>{
      'title': cleanTitle,
      'body': cleanBody,
      'category': cleanCategory,
      'authorId': cleanAuthorId,
      'authorName': _displayName(authorName),
      'likeCount': 0,
      'commentCount': 0,
      'createdAt': FieldValue.serverTimestamp(),
      'lastActivityAt': FieldValue.serverTimestamp(),
    };
    if (cleanContentId != null) {
      data['source'] = 'admin_content';
      data['contentId'] = cleanContentId;
      data['contentTitle'] =
          cleanContentTitle?.isNotEmpty == true ? cleanContentTitle : cleanTitle;
      data['isOfficial'] = true;
    } else {
      data['source'] = 'customer_forum';
      data['isOfficial'] = false;
    }
    return posts.add(data);
  }

  static Future<void> addComment({
    required String postId,
    required String authorId,
    required String authorName,
    required String body,
  }) async {
    final cleanPostId = postId.trim();
    final cleanAuthorId = _boundedText(authorId, _maxContentIdLength);
    final trimmed = _boundedText(body, _maxBodyLength);
    if (!_isValidId(cleanPostId) ||
        cleanPostId.length > _maxContentIdLength ||
        cleanAuthorId == null ||
        trimmed == null) {
      return;
    }

    final batch = _db.batch();
    final postRef = posts.doc(cleanPostId);
    final commentRef = postRef.collection('comments').doc();
    batch.set(commentRef, {
      'body': trimmed,
      'authorId': cleanAuthorId,
      'authorName': _displayName(authorName),
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.update(postRef, {
      'commentCount': FieldValue.increment(1),
      'lastActivityAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }

  static Future<void> toggleLike({
    required String postId,
    required String userId,
  }) async {
    final cleanPostId = postId.trim();
    final cleanUserId = userId.trim();
    if (!_isValidId(cleanPostId) ||
        cleanPostId.length > _maxContentIdLength ||
        !_isValidId(cleanUserId) ||
        cleanUserId.length > _maxContentIdLength) {
      return;
    }

    final postRef = posts.doc(cleanPostId);
    final likeRef = postRef.collection('likes').doc(cleanUserId);
    final postSnapshot = await postRef.get();
    if (!postSnapshot.exists) return;

    final currentRaw = postSnapshot.data()?['likeCount'];
    final currentCount = currentRaw is num && currentRaw.isFinite
        ? currentRaw.toInt().clamp(0, 1000000)
        : 0;
    final existing = await likeRef.get();
    final batch = _db.batch();
    if (existing.exists) {
      batch.delete(likeRef);
      batch.update(postRef, {'likeCount': currentCount > 0 ? currentCount - 1 : 0});
    } else {
      batch.set(likeRef, {'createdAt': FieldValue.serverTimestamp()});
      batch.update(postRef, {'likeCount': currentCount + 1});
    }
    await batch.commit();
  }

  static Future<void> createAdminContentAnnouncement({
    required String title,
    required String body,
    required String type,
    required String contentId,
  }) async {
    final cleanTitle = _boundedText(title, _maxTitleLength);
    final cleanBody = _boundedText(body, _maxBodyLength);
    final cleanType = _boundedText(type, _maxTypeLength);
    final cleanContentId = _boundedText(contentId, _maxContentIdLength);
    if (cleanTitle == null ||
        cleanBody == null ||
        cleanType == null ||
        cleanContentId == null) {
      return;
    }

    final users = await _db.collection('users').get();
    WriteBatch batch = _db.batch();
    var operations = 0;
    for (final user in users.docs) {
      batch.set(user.reference.collection('notifications').doc(), {
        'title': cleanTitle,
        'body': cleanBody,
        'type': 'content',
        'contentId': cleanContentId,
        'contentType': cleanType,
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
      operations++;
      if (operations == 450) {
        await batch.commit();
        batch = _db.batch();
        operations = 0;
      }
    }
    if (operations > 0) await batch.commit();
  }

  static Future<DocumentReference<Map<String, dynamic>>> createContentForumPost({
    required String contentId,
    required String title,
    required String body,
    required String type,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      throw StateError('You must be signed in to publish community content.');
    }

    final cleanContentId = _boundedText(contentId, _maxContentIdLength);
    final cleanTitle = _boundedText(title, _maxTitleLength);
    final cleanBody = _boundedText(body, _maxBodyLength);
    final cleanType = _boundedText(type, _maxTypeLength);
    if (cleanContentId == null ||
        cleanTitle == null ||
        cleanBody == null ||
        cleanType == null ||
        uid.trim().length > _maxContentIdLength) {
      throw ArgumentError('Invalid community content data.');
    }

    final userSnapshot = await _db.collection('users').doc(uid).get();
    final userData = userSnapshot.data() ?? <String, dynamic>{};
    final profileName = (userData['name'] as String?)?.trim();
    final authName = FirebaseAuth.instance.currentUser?.displayName?.trim();
    final authorName = profileName?.isNotEmpty == true &&
            profileName!.length <= _maxNameLength
        ? profileName
        : (authName?.isNotEmpty == true && authName!.length <= _maxNameLength
            ? authName
            : 'TiB Team');

    return posts.add({
      'title': cleanTitle,
      'body': cleanBody,
      'category': cleanType,
      'authorId': uid,
      'authorName': authorName,
      'source': 'admin_content',
      'contentId': cleanContentId,
      'contentTitle': cleanTitle,
      'isOfficial': true,
      'likeCount': 0,
      'commentCount': 0,
      'createdAt': FieldValue.serverTimestamp(),
      'lastActivityAt': FieldValue.serverTimestamp(),
    });
  }
}
