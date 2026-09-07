import 'package:cloud_firestore/cloud_firestore.dart';

class VyeaNotification {
  final String id;
  final String title;
  final String body;
  final String type;
  final bool read;
  final DateTime? createdAt;

  const VyeaNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.read,
    required this.createdAt,
  });

  factory VyeaNotification.fromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    final timestamp = data['createdAt'];
    return VyeaNotification(
      id: doc.id,
      title: data['title'] as String? ?? 'VYEA update',
      body: data['body'] as String? ?? '',
      type: data['type'] as String? ?? 'system',
      read: data['read'] == true,
      createdAt: timestamp is Timestamp ? timestamp.toDate() : null,
    );
  }
}

class NotificationService {
  NotificationService._();

  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static CollectionReference<Map<String, dynamic>> _notifications(String uid) =>
      _db.collection('users').doc(uid).collection('notifications');

  static Stream<List<VyeaNotification>> stream(String uid) {
    if (uid.trim().isEmpty) return const Stream.empty();
    return _notifications(uid).limit(50).snapshots().map((snapshot) {
      final items = snapshot.docs.map(VyeaNotification.fromDocument).toList();
      items.sort((a, b) {
        final aDate = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bDate = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bDate.compareTo(aDate);
      });
      return items;
    });
  }

  static Stream<int> unreadCountStream(String uid) {
    if (uid.trim().isEmpty) return Stream.value(0);
    return _notifications(uid)
        .where('read', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  static Future<void> ensureWelcomeNotification(String uid) async {
    if (uid.trim().isEmpty) return;
    final existing = await _notifications(uid).limit(1).get();
    if (existing.docs.isNotEmpty) return;
    await _notifications(uid).add({
      'title': 'Welcome to VYEA',
      'body': 'Your personal styling space is ready. Explore your wardrobe and discover a look that feels like you.',
      'type': 'system',
      'read': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> markRead(String uid, String notificationId) async {
    if (uid.trim().isEmpty || notificationId.trim().isEmpty) return;
    await _notifications(uid).doc(notificationId).update({'read': true});
  }

  static Future<void> markAllRead(String uid) async {
    if (uid.trim().isEmpty) return;
    final snapshot = await _notifications(uid)
        .where('read', isEqualTo: false)
        .limit(50)
        .get();
    if (snapshot.docs.isEmpty) return;
    final batch = _db.batch();
    for (final doc in snapshot.docs) {
      batch.update(doc.reference, {'read': true});
    }
    await batch.commit();
  }
}
