import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LiveConsultancyService {
  LiveConsultancyService._();

  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static CollectionReference<Map<String, dynamic>> get _consultations => _db.collection('consultations');
  static CollectionReference<Map<String, dynamic>> get _presence => _db.collection('consultant_presence');
  static String? get currentUid => FirebaseAuth.instance.currentUser?.uid;
  static DocumentReference<Map<String, dynamic>> _consultation(String uid) => _consultations.doc(uid);
  static CollectionReference<Map<String, dynamic>> _messages(String uid) => _consultation(uid).collection('messages');

  static Future<void> ensureConversation() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final ref = _consultation(user.uid);
    if (!(await ref.get()).exists) {
      await ref.set({
        'uid': user.uid,
        'userName': user.displayName?.trim().isNotEmpty == true ? user.displayName!.trim() : 'TiB User',
        'email': user.email ?? '',
        'status': 'open',
        'assignedConsultantId': null,
        'assignedConsultantName': null,
        'lastMessage': null,
        'lastSenderType': null,
        'unreadForUser': 0,
        'unreadForConsultant': 0,
        'firstConsultantReplyAt': null,
        'responseTimeSeconds': null,
        'rating': null,
        'ratingComment': null,
        'ratedAt': null,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  static Stream<DocumentSnapshot<Map<String, dynamic>>> conversationStream() {
    final uid = currentUid;
    return uid == null ? const Stream.empty() : _consultation(uid).snapshots();
  }

  static Stream<QuerySnapshot<Map<String, dynamic>>> messagesStream() {
    final uid = currentUid;
    return uid == null ? const Stream.empty() : _messages(uid).orderBy('createdAt').snapshots();
  }

  static Stream<QuerySnapshot<Map<String, dynamic>>> consultationsStream({String? status}) {
    Query<Map<String, dynamic>> query = _consultations.orderBy('updatedAt', descending: true);
    if (status != null) query = query.where('status', isEqualTo: status);
    return query.snapshots();
  }

  static Stream<QuerySnapshot<Map<String, dynamic>>> conversationMessages(String uid) => _messages(uid).orderBy('createdAt').snapshots();
  static Stream<QuerySnapshot<Map<String, dynamic>>> consultantPresenceStream() => _presence.orderBy('updatedAt', descending: true).snapshots();
  static Stream<QuerySnapshot<Map<String, dynamic>>> onlineConsultantsStream() => _presence.where('online', isEqualTo: true).snapshots();

  static Future<void> setConsultantPresence(bool online) async {
    final consultant = FirebaseAuth.instance.currentUser;
    if (consultant == null) return;
    final name = consultant.displayName?.trim().isNotEmpty == true ? consultant.displayName!.trim() : 'TiB Consultant';
    await _presence.doc(consultant.uid).set({
      'consultantId': consultant.uid,
      'consultantName': name,
      'online': online,
      'updatedAt': FieldValue.serverTimestamp(),
      'lastSeenAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static Future<void> sendUserMessage(String text) async {
    final user = FirebaseAuth.instance.currentUser;
    final value = text.trim();
    if (user == null || value.isEmpty) return;
    await ensureConversation();
    final ref = _consultation(user.uid);
    final existing = await ref.get();
    await _messages(user.uid).add({
      'senderType': 'user',
      'senderId': user.uid,
      'senderName': user.displayName?.trim().isNotEmpty == true ? user.displayName!.trim() : 'User',
      'text': value,
      'read': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
    final reopened = existing.data()?['status'] == 'resolved';
    await ref.set({
      'uid': user.uid,
      'userName': user.displayName?.trim().isNotEmpty == true ? user.displayName!.trim() : 'TiB User',
      'email': user.email ?? '',
      'status': 'waiting_for_consultant',
      'lastMessage': value,
      'lastSenderType': 'user',
      'unreadForConsultant': FieldValue.increment(1),
      'updatedAt': FieldValue.serverTimestamp(),
      if (reopened) ...{
        'resolvedAt': null,
        'assignedConsultantId': null,
        'assignedConsultantName': null,
        'firstConsultantReplyAt': null,
        'responseTimeSeconds': null,
        'rating': null,
        'ratingComment': null,
        'ratedAt': null,
      },
    }, SetOptions(merge: true));
  }

  static Future<void> acceptConsultation(String uid) async {
    final consultant = FirebaseAuth.instance.currentUser;
    if (consultant == null) return;
    final name = consultant.displayName?.trim().isNotEmpty == true ? consultant.displayName!.trim() : 'TiB Consultant';
    final ref = _consultation(uid);
    final data = (await ref.get()).data() ?? <String, dynamic>{};
    final assignedId = data['assignedConsultantId'] as String?;
    if (assignedId != null && assignedId != consultant.uid) return;
    await ref.set({
      'assignedConsultantId': consultant.uid,
      'assignedConsultantName': name,
      'status': 'assigned',
      'assignedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static Future<void> sendConsultantMessage({required String uid, required String text, required String consultantName}) async {
    final consultant = FirebaseAuth.instance.currentUser;
    final value = text.trim();
    if (consultant == null || value.isEmpty) return;
    final ref = _consultation(uid);
    final data = (await ref.get()).data() ?? <String, dynamic>{};
    final assignedId = data['assignedConsultantId'] as String?;
    if (assignedId != null && assignedId != consultant.uid) return;
    final firstReplyExists = data['firstConsultantReplyAt'] != null;
    final createdAt = data['createdAt'];
    final displayName = consultantName.trim().isEmpty ? 'TiB Consultant' : consultantName.trim();
    await _messages(uid).add({'senderType': 'consultant', 'senderId': consultant.uid, 'senderName': displayName, 'text': value, 'read': false, 'createdAt': FieldValue.serverTimestamp()});
    final update = <String, dynamic>{
      'status': 'consultant_replied',
      'assignedConsultantId': consultant.uid,
      'assignedConsultantName': displayName,
      'lastMessage': value,
      'lastSenderType': 'consultant',
      'unreadForUser': FieldValue.increment(1),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (!firstReplyExists) {
      update['firstConsultantReplyAt'] = FieldValue.serverTimestamp();
      if (createdAt is Timestamp) {
        update['responseTimeSeconds'] = DateTime.now().difference(createdAt.toDate()).inSeconds;
      }
    }
    await ref.set(update, SetOptions(merge: true));
  }

  static Future<void> assignToCurrentConsultant(String uid) => acceptConsultation(uid);

  static Future<void> setStatus(String uid, String status) async {
    await _consultation(uid).set({'status': status, if (status == 'resolved') 'resolvedAt': FieldValue.serverTimestamp(), 'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
  }

  static Future<void> markMessagesRead(String uid, {required String by}) async {
    if (uid.isEmpty) return;
    final senderType = by == 'customer' ? 'consultant' : 'user';
    final snapshot = await _messages(uid).where('senderType', isEqualTo: senderType).where('read', isEqualTo: false).get();
    final batch = _db.batch();
    for (final doc in snapshot.docs) {
      batch.update(doc.reference, {'read': true});
    }
    if (snapshot.docs.isNotEmpty) await batch.commit();
    await _consultation(uid).set({by == 'customer' ? 'unreadForUser' : 'unreadForConsultant': 0, 'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
  }

  static Future<void> rateConsultant({required int rating, String? comment}) async {
    final uid = currentUid;
    if (uid == null || rating < 1 || rating > 5) return;
    await _consultation(uid).set({'rating': rating, 'ratingComment': comment?.trim().isEmpty == true ? null : comment?.trim(), 'ratedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
  }
}
