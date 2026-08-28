import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LiveConsultancyService {
  LiveConsultancyService._();

  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static CollectionReference<Map<String, dynamic>> get _consultations =>
      _db.collection('consultations');

  static String? get currentUid => FirebaseAuth.instance.currentUser?.uid;

  static DocumentReference<Map<String, dynamic>> _consultation(String uid) =>
      _consultations.doc(uid);

  static CollectionReference<Map<String, dynamic>> _messages(String uid) =>
      _consultation(uid).collection('messages');

  static Future<void> ensureConversation() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final ref = _consultation(user.uid);
    final snapshot = await ref.get();
    if (!snapshot.exists) {
      await ref.set({
        'uid': user.uid,
        'userName': user.displayName?.trim().isNotEmpty == true
            ? user.displayName!.trim()
            : 'TiB User',
        'email': user.email ?? '',
        'status': 'open',
        'assignedConsultantId': null,
        'assignedConsultantName': null,
        'lastMessage': null,
        'lastSenderType': null,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  static Stream<DocumentSnapshot<Map<String, dynamic>>> conversationStream() {
    final uid = currentUid;
    if (uid == null) return const Stream.empty();
    return _consultation(uid).snapshots();
  }

  static Stream<QuerySnapshot<Map<String, dynamic>>> messagesStream() {
    final uid = currentUid;
    if (uid == null) return const Stream.empty();
    return _messages(uid).orderBy('createdAt').snapshots();
  }

  static Stream<QuerySnapshot<Map<String, dynamic>>> consultationsStream({
    String? status,
  }) {
    Query<Map<String, dynamic>> query = _consultations.orderBy(
      'updatedAt',
      descending: true,
    );
    if (status != null) query = query.where('status', isEqualTo: status);
    return query.snapshots();
  }

  static Stream<QuerySnapshot<Map<String, dynamic>>> conversationMessages(
    String uid,
  ) {
    return _messages(uid).orderBy('createdAt').snapshots();
  }

  static Future<void> sendUserMessage(String text) async {
    final user = FirebaseAuth.instance.currentUser;
    final value = text.trim();
    if (user == null || value.isEmpty) return;

    await ensureConversation();
    final ref = _consultation(user.uid);

    await _messages(user.uid).add({
      'senderType': 'user',
      'senderId': user.uid,
      'senderName': user.displayName?.trim().isNotEmpty == true
          ? user.displayName!.trim()
          : 'User',
      'text': value,
      'read': false,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await ref.set({
      'uid': user.uid,
      'userName': user.displayName?.trim().isNotEmpty == true
          ? user.displayName!.trim()
          : 'TiB User',
      'email': user.email ?? '',
      'status': 'waiting_for_consultant',
      'lastMessage': value,
      'lastSenderType': 'user',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static Future<void> sendConsultantMessage({
    required String uid,
    required String text,
    required String consultantName,
  }) async {
    final consultant = FirebaseAuth.instance.currentUser;
    final value = text.trim();
    if (consultant == null || value.isEmpty) return;

    await _messages(uid).add({
      'senderType': 'consultant',
      'senderId': consultant.uid,
      'senderName': consultantName.trim().isEmpty
          ? 'TiB Consultant'
          : consultantName.trim(),
      'text': value,
      'read': false,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await _consultation(uid).set({
      'status': 'consultant_replied',
      'assignedConsultantId': consultant.uid,
      'assignedConsultantName': consultantName.trim().isEmpty
          ? 'TiB Consultant'
          : consultantName.trim(),
      'lastMessage': value,
      'lastSenderType': 'consultant',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static Future<void> assignToCurrentConsultant(String uid) async {
    final consultant = FirebaseAuth.instance.currentUser;
    if (consultant == null) return;
    final name = consultant.displayName?.trim().isNotEmpty == true
        ? consultant.displayName!.trim()
        : 'TiB Consultant';

    await _consultation(uid).set({
      'assignedConsultantId': consultant.uid,
      'assignedConsultantName': name,
      'status': 'assigned',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static Future<void> setStatus(String uid, String status) async {
    await _consultation(uid).set({
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static Future<void> markMessagesRead(String uid, {required String by}) async {
    final snapshot = await _messages(uid)
        .where('senderType', isEqualTo: by == 'customer' ? 'consultant' : 'user')
        .where('read', isEqualTo: false)
        .get();
    if (snapshot.docs.isEmpty) return;

    final batch = _db.batch();
    for (final doc in snapshot.docs) {
      batch.update(doc.reference, {'read': true});
    }
    await batch.commit();
  }
}
