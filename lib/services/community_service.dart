import 'package:cloud_firestore/cloud_firestore.dart';

class CommunityService {
  CommunityService._();

  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static Stream<QuerySnapshot<Map<String, dynamic>>> forumPostsStream() {
    return _db.collection('forum_posts').snapshots();
  }

  static Stream<QuerySnapshot<Map<String, dynamic>>> commentsStream(String postId) {
    return _db.collection('forum_posts').doc(postId).collection('comments').snapshots();
  }

  static Future<void> createAdminContentAnnouncement({
    required String title,
    required String body,
    required String type,
    required String contentId,
  }) async {
    final users = await _db.collection('users').get();
    final batch = _db.batch();

    for (final user in users.docs) {
      final ref = user.reference.collection('notifications').doc();
      batch.set(ref, {
        'title': title,
        'body': body,
        'type': 'content',
        'contentId': contentId,
        'contentType': type,
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
  }

  static Future<void> createContentForumPost({
    required String contentId,
    required String title,
    required String body,
    required String type,
  }) async {
    await _db.collection('forum_posts').add({
      'title': title,
      'body': body,
      'category': type,
      'authorId': 'tib_admin',
      'authorName': 'TiB Team',
      'source': 'admin_content',
      'contentId': contentId,
      'isOfficial': true,
      'likeCount': 0,
      'commentCount': 0,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
