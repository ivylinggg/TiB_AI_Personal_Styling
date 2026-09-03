import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CommunityService {
  CommunityService._();

  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static CollectionReference<Map<String, dynamic>> get posts => _db.collection('forum_posts');

  static Stream<QuerySnapshot<Map<String, dynamic>>> forumPostsStream() => posts.snapshots();

  static Stream<QuerySnapshot<Map<String, dynamic>>> commentsStream(String postId) => posts.doc(postId).collection('comments').snapshots();

  static Future<DocumentReference<Map<String, dynamic>>> createPost({
    required String title,
    required String body,
    required String category,
    required String authorId,
    required String authorName,
    String? contentId,
    String? contentTitle,
  }) async {
    final data = <String, dynamic>{
      'title': title.trim(),
      'body': body.trim(),
      'category': category,
      'authorId': authorId,
      'authorName': authorName.trim().isEmpty ? 'TiB User' : authorName.trim(),
      'likeCount': 0,
      'commentCount': 0,
      'createdAt': FieldValue.serverTimestamp(),
      'lastActivityAt': FieldValue.serverTimestamp(),
    };
    if (contentId != null && contentId.isNotEmpty) {
      data['source'] = 'admin_content';
      data['contentId'] = contentId;
      data['contentTitle'] = contentTitle ?? title;
      data['isOfficial'] = false;
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
    final trimmed = body.trim();
    if (trimmed.isEmpty) return;
    final batch = _db.batch();
    final postRef = posts.doc(postId);
    final commentRef = postRef.collection('comments').doc();
    batch.set(commentRef, {
      'body': trimmed,
      'authorId': authorId,
      'authorName': authorName.trim().isEmpty ? 'TiB User' : authorName.trim(),
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.update(postRef, {
      'commentCount': FieldValue.increment(1),
      'lastActivityAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }

  static Future<void> toggleLike({required String postId, required String userId}) async {
    final postRef = posts.doc(postId);
    final likeRef = postRef.collection('likes').doc(userId);
    final postSnapshot = await postRef.get();
    final currentCount = (postSnapshot.data()?['likeCount'] as num?)?.toInt() ?? 0;
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
    final users = await _db.collection('users').get();
    WriteBatch batch = _db.batch();
    var operations = 0;
    for (final user in users.docs) {
      batch.set(user.reference.collection('notifications').doc(), {
        'title': title,
        'body': body,
        'type': 'content',
        'contentId': contentId,
        'contentType': type,
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
    return posts.add({
      'title': title.trim(),
      'body': body.trim(),
      'category': type,
      'authorId': uid,
      'authorName': 'TiB Team',
      'source': 'admin_content',
      'contentId': contentId,
      'contentTitle': title.trim(),
      'isOfficial': true,
      'likeCount': 0,
      'commentCount': 0,
      'createdAt': FieldValue.serverTimestamp(),
      'lastActivityAt': FieldValue.serverTimestamp(),
    });
  }
}
