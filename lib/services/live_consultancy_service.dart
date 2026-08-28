import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LiveConsultancyService {
  LiveConsultancyService._();

  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static CollectionReference<Map<String, dynamic>> get _consultations =>
      _db.collection('consultations');

  static String get _uid => FirebaseAuth.instance.currentUser!.uid;

  static DocumentReference<Map<String, dynamic>> get _myConsultation =>
      _consultations.doc(_uid);

  static CollectionReference<Map<String, dynamic>> get _myMessages =>
      _myConsultation.collection('messages');

  static Future<void> ensureConversation() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final ref = _consultations.doc(user.uid);
    final snapshot = await ref.get();
    if (!snapshot.exists) {
      await ref.set({
        'uid': user.uid,
        'userName': user.displayName ?? 'TiB User',
        'email': user.email ?? '',
        'status': 'open',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  static Stream<QuerySnapshot<Map<String, dynamic>>> messagesStream() {
    return _myMessages.orderBy('createdAt', descending: false).snapshots();
  }

  static Stream<QuerySnapshot<Map<String, dynamic>>> consultationsStream() {
    return _consultations.orderBy('updatedAt', descending: true).snapshots();
  }

  static Future<void> sendUserMessage(String text) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || text.trim().isEmpty) return;
    await ensureConversation();
    final value = text.trim();
    await _myMessages.add({
      'senderType': 'user',
      'senderId': user.uid,
      'senderName': user.displayName ?? 'User',
      'text': value,
      'createdAt': FieldValue.serverTimestamp(),
    });
    await _myConsultation.set({
      'uid': user.uid,
      'userName': user.displayName ?? 'TiB User',
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
    final value = text.trim();
    if (value.isEmpty) return;
    await _consultations.doc(uid).collection('messages').add({
      'senderType': 'consultant',
      'senderId': FirebaseAuth.instance.currentUser?.uid ?? 'consultant',
      'senderName': consultantName,
      'text': value,
      'createdAt': FieldValue.serverTimestamp(),
    });
    await _consultations.doc(uid).set({
      'status': 'consultant_replied',
      'lastMessage': value,
      'lastSenderType': 'consultant',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static Future<void> setStatus(String uid, String status) async {
    await _consultations.doc(uid).set({
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
