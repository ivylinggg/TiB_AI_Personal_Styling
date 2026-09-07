import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LiveConsultancyService {
  LiveConsultancyService._();

  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static CollectionReference<Map<String, dynamic>> get _consultations =>
      _db.collection('consultations');
  static CollectionReference<Map<String, dynamic>> get _presence =>
      _db.collection('consultant_presence');
  static String? get currentUid => FirebaseAuth.instance.currentUser?.uid;

  static DocumentReference<Map<String, dynamic>> _consultation(String uid) =>
      _consultations.doc(uid);

  static CollectionReference<Map<String, dynamic>> _messages(String uid) =>
      _consultation(uid).collection('messages');

  static bool _isValidMessage(String value) =>
      value.trim().isNotEmpty && value.trim().length <= 1500;

  static Future<Map<String, dynamic>?> _userData(String uid) async {
    final snapshot = await _db.collection('users').doc(uid).get();
    return snapshot.data();
  }

  static Future<bool> _hasConsultantRole(String uid) async {
    final data = await _userData(uid);
    final role = (data?['role'] as String? ?? '').trim().toLowerCase();
    final active = data?['isActive'] as bool? ?? true;
    return active && (role == 'consultant' || role == 'admin');
  }

  static Future<void> ensureConversation() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final ref = _consultation(user.uid);
    final existing = await ref.get();
    if (existing.exists) return;

    final displayName = user.displayName?.trim();
    await ref.set({
      'uid': user.uid,
      'userName': displayName?.isNotEmpty == true ? displayName : 'VYEA User',
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

  static Stream<DocumentSnapshot<Map<String, dynamic>>> conversationStream() {
    final uid = currentUid;
    return uid == null ? const Stream.empty() : _consultation(uid).snapshots();
  }

  static Stream<QuerySnapshot<Map<String, dynamic>>> messagesStream() {
    final uid = currentUid;
    return uid == null
        ? const Stream.empty()
        : _messages(uid).orderBy('createdAt').snapshots();
  }

  /// Fetches consultations without a composite query so no composite Firestore
  /// index is required. Consumers should sort the returned docs locally.
  static Stream<QuerySnapshot<Map<String, dynamic>>> consultationsStream({
    String? status,
  }) {
    Query<Map<String, dynamic>> query = _consultations;
    if (status != null) {
      query = query.where('status', isEqualTo: status);
    }
    return query.snapshots();
  }

  static Stream<QuerySnapshot<Map<String, dynamic>>> conversationMessages(
    String uid,
  ) =>
      _messages(uid).orderBy('createdAt').snapshots();

  static Stream<QuerySnapshot<Map<String, dynamic>>> consultantPresenceStream() =>
      _presence.orderBy('updatedAt', descending: true).snapshots();

  static Stream<QuerySnapshot<Map<String, dynamic>>> onlineConsultantsStream() =>
      _presence.where('online', isEqualTo: true).snapshots();

  static Future<void> setConsultantPresence(bool online) async {
    final consultant = FirebaseAuth.instance.currentUser;
    if (consultant == null) return;
    if (!await _hasConsultantRole(consultant.uid)) return;

    final profile = await _userData(consultant.uid);
    final profileName = (profile?['name'] as String?)?.trim();
    final authName = consultant.displayName?.trim();
    final name = profileName?.isNotEmpty == true
        ? profileName!
        : (authName?.isNotEmpty == true ? authName! : 'TiB Consultant');

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
    if (user == null || !_isValidMessage(value)) return;

    await ensureConversation();
    final ref = _consultation(user.uid);
    final existing = await ref.get();
    final data = existing.data() ?? <String, dynamic>{};
    final reopened = data['status'] == 'resolved';
    final displayName = user.displayName?.trim();
    final userName = displayName?.isNotEmpty == true ? displayName! : 'VYEA User';

    final batch = _db.batch();
    final messageRef = _messages(user.uid).doc();
    batch.set(messageRef, {
      'senderType': 'user',
      'senderId': user.uid,
      'senderName': userName,
      'text': value,
      'read': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.set(ref, {
      'uid': user.uid,
      'userName': userName,
      'email': user.email ?? '',
      'status': 'waiting_for_consultant',
      'lastMessage': value,
      'lastSenderType': 'user',
      'unreadForConsultant': reopened ? 1 : FieldValue.increment(1),
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
    await batch.commit();
  }

  static Future<bool> acceptConsultation(String uid) async {
    final consultant = FirebaseAuth.instance.currentUser;
    if (consultant == null || !await _hasConsultantRole(consultant.uid)) {
      return false;
    }

    final profile = await _userData(consultant.uid);
    final profileName = (profile?['name'] as String?)?.trim();
    final authName = consultant.displayName?.trim();
    final name = profileName?.isNotEmpty == true
        ? profileName!
        : (authName?.isNotEmpty == true ? authName! : 'TiB Consultant');
    final ref = _consultation(uid);

    return _db.runTransaction<bool>((transaction) async {
      final snapshot = await transaction.get(ref);
      if (!snapshot.exists) return false;
      final data = snapshot.data() ?? <String, dynamic>{};
      final assignedId = data['assignedConsultantId'] as String?;
      final status = data['status'] as String?;

      if (assignedId != null && assignedId != consultant.uid) return false;
      if (assignedId == consultant.uid) return true;
      if (status != 'waiting_for_consultant' && status != 'open') return false;

      transaction.set(
        ref,
        {
          'assignedConsultantId': consultant.uid,
          'assignedConsultantName': name,
          'status': 'assigned',
          'assignedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      return true;
    });
  }

  static Future<void> assignConsultant({
    required String uid,
    required String consultantId,
    required String consultantName,
  }) async {
    final actingUser = FirebaseAuth.instance.currentUser;
    if (actingUser == null || !await _hasConsultantRole(actingUser.uid)) return;

    final targetIsConsultant = await _hasConsultantRole(consultantId);
    if (!targetIsConsultant) return;

    final ref = _consultation(uid);
    await ref.set(
      {
        'assignedConsultantId': consultantId,
        'assignedConsultantName': consultantName.trim().isEmpty
            ? 'TiB Consultant'
            : consultantName.trim(),
        'status': 'assigned',
        'assignedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  static Future<bool> isAssignedToCurrentConsultant(String uid) async {
    final consultantId = currentUid;
    if (consultantId == null || !await _hasConsultantRole(consultantId)) {
      return false;
    }
    final data = (await _consultation(uid).get()).data();
    return data?['assignedConsultantId'] == consultantId;
  }

  static Future<void> sendConsultantMessage({
    required String uid,
    required String text,
    required String consultantName,
  }) async {
    final consultant = FirebaseAuth.instance.currentUser;
    final value = text.trim();
    if (consultant == null || !_isValidMessage(value)) return;
    if (!await _hasConsultantRole(consultant.uid)) return;

    final ref = _consultation(uid);
    final data = (await ref.get()).data() ?? <String, dynamic>{};
    final assignedId = data['assignedConsultantId'] as String?;
    if (assignedId != consultant.uid) return;

    final firstReplyExists = data['firstConsultantReplyAt'] != null;
    final createdAt = data['createdAt'];
    final displayName = consultantName.trim().isEmpty
        ? 'TiB Consultant'
        : consultantName.trim();

    final batch = _db.batch();
    final messageRef = _messages(uid).doc();
    batch.set(messageRef, {
      'senderType': 'consultant',
      'senderId': consultant.uid,
      'senderName': displayName,
      'text': value,
      'read': false,
      'createdAt': FieldValue.serverTimestamp(),
    });

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
        update['responseTimeSeconds'] =
            DateTime.now().difference(createdAt.toDate()).inSeconds;
      }
    }

    batch.set(ref, update, SetOptions(merge: true));
    await batch.commit();
  }

  static Future<void> setStatus(String uid, String status) async {
    final consultant = FirebaseAuth.instance.currentUser;
    if (consultant == null || !await _hasConsultantRole(consultant.uid)) return;
    if (!await isAssignedToCurrentConsultant(uid)) return;

    await _consultation(uid).set(
      {
        'status': status,
        if (status == 'resolved') 'resolvedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  static Future<void> markMessagesRead(String uid, {required String by}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || uid.isEmpty) return;

    if (by == 'customer') {
      if (uid != user.uid) return;
    } else {
      if (!await isAssignedToCurrentConsultant(uid)) return;
    }

    final senderType = by == 'customer' ? 'consultant' : 'user';
    final snapshot = await _messages(uid)
        .where('senderType', isEqualTo: senderType)
        .where('read', isEqualTo: false)
        .get();
    final batch = _db.batch();
    for (final doc in snapshot.docs) {
      batch.update(doc.reference, {'read': true});
    }
    if (snapshot.docs.isNotEmpty) {
      await batch.commit();
    }

    await _consultation(uid).set(
      {
        by == 'customer' ? 'unreadForUser' : 'unreadForConsultant': 0,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  static Future<void> rateConsultant({
    required int rating,
    String? comment,
  }) async {
    final uid = currentUid;
    if (uid == null || rating < 1 || rating > 5) return;

    final data = (await _consultation(uid).get()).data();
    if (data?['status'] != 'resolved') return;
    if (data?['rating'] != null) return;

    await _consultation(uid).set(
      {
        'rating': rating,
        'ratingComment': comment?.trim().isEmpty == true ? null : comment?.trim(),
        'ratedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }
}
