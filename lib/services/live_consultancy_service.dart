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

  static bool _isValidUid(String value) => RegExp(r'^[A-Za-z0-9:_-]{1,128}$').hasMatch(value.trim());

  static bool _isValidMessage(String value) =>
      value.trim().isNotEmpty && value.trim().length <= 1500;

  static String? _normaliseUid(String value) {
    final uid = value.trim();
    return _isValidUid(uid) ? uid : null;
  }

  static String _normaliseDisplayName(String? value, {String fallback = 'TiB Consultant'}) {
    final name = value?.trim() ?? '';
    return name.isEmpty ? fallback : name;
  }

  static String? _normaliseStatus(String? value) {
    final status = value?.trim();
    if (status == null || status.isEmpty || status.length > 64) return null;
    return status;
  }

  static Future<Map<String, dynamic>?> _userData(String uid) async {
    final safeUid = _normaliseUid(uid);
    if (safeUid == null) return null;
    final snapshot = await _db.collection('users').doc(safeUid).get();
    return snapshot.data();
  }

  static Future<bool> _hasConsultantRole(String uid) async {
    final safeUid = _normaliseUid(uid);
    if (safeUid == null) return false;
    final data = await _userData(safeUid);
    final roleValue = data?['role'];
    final role = roleValue is String ? roleValue.trim().toLowerCase() : '';
    final activeValue = data?['isActive'];
    final active = activeValue is bool ? activeValue : true;
    return active && (role == 'consultant' || role == 'admin');
  }

  static Future<bool> _isAdmin(String uid) async {
    final safeUid = _normaliseUid(uid);
    if (safeUid == null) return false;
    final data = await _userData(safeUid);
    final roleValue = data?['role'];
    final role = roleValue is String ? roleValue.trim().toLowerCase() : '';
    return role == 'admin';
  }

  static Future<void> ensureConversation() async {
    final user = FirebaseAuth.instance.currentUser;
    final uid = user == null ? null : _normaliseUid(user.uid);
    if (user == null || uid == null) return;

    final ref = _consultation(uid);
    final existing = await ref.get();
    if (existing.exists) return;

    final userName = _normaliseDisplayName(
      user.displayName,
      fallback: 'VYEA User',
    );
    await ref.set({
      'uid': uid,
      'userName': userName,
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
    return uid == null || !_isValidUid(uid)
        ? const Stream.empty()
        : _consultation(uid).snapshots();
  }

  static Stream<QuerySnapshot<Map<String, dynamic>>> messagesStream() {
    final uid = currentUid;
    return uid == null || !_isValidUid(uid)
        ? const Stream.empty()
        : _messages(uid).orderBy('createdAt').snapshots();
  }

  /// Returns only consultations the signed-in staff member is permitted to
  /// list. Admins can see the full queue. Consultants can see consultations
  /// assigned to them plus unassigned open/waiting requests that they may accept.
  static Stream<QuerySnapshot<Map<String, dynamic>>> consultationsStream({
    String? status,
  }) async* {
    final uid = currentUid;
    if (uid == null || !_isValidUid(uid)) return;

    final profile = await _userData(uid);
    final roleValue = profile?['role'];
    final role = roleValue is String ? roleValue.trim().toLowerCase() : '';
    final activeValue = profile?['isActive'];
    final active = activeValue is bool ? activeValue : true;
    final safeStatus = status == null ? null : _normaliseStatus(status);
    if (status != null && safeStatus == null) return;

    Query<Map<String, dynamic>> query = _consultations;

    if (role == 'admin') {
      if (safeStatus != null) {
        query = query.where('status', isEqualTo: safeStatus);
      }
    } else if (role == 'consultant' && active) {
      query = query.where(
        Filter.or(
          Filter('assignedConsultantId', isEqualTo: uid),
          Filter.and(
            Filter('assignedConsultantId', isNull: true),
            Filter('status', whereIn: const ['open', 'waiting_for_consultant']),
          ),
        ),
      );
      if (safeStatus != null) {
        query = query.where('status', isEqualTo: safeStatus);
      }
    } else {
      return;
    }

    yield* query.snapshots();
  }

  /// Message bodies are private to the customer, admin, or assigned consultant.
  /// An unassigned consultant may inspect the consultation metadata needed to
  /// accept it, but cannot stream its private messages before acceptance.
  static Stream<QuerySnapshot<Map<String, dynamic>>> conversationMessages(
    String uid,
  ) async* {
    final targetUid = _normaliseUid(uid);
    final viewer = currentUid;
    if (viewer == null || !_isValidUid(viewer) || targetUid == null) return;

    if (viewer == targetUid || await _isAdmin(viewer)) {
      yield* _messages(targetUid).orderBy('createdAt').snapshots();
      return;
    }

    final profile = await _userData(viewer);
    final roleValue = profile?['role'];
    final role = roleValue is String ? roleValue.trim().toLowerCase() : '';
    final activeValue = profile?['isActive'];
    final active = activeValue is bool ? activeValue : true;
    if (role != 'consultant' || !active) return;

    final consultation = (await _consultation(targetUid).get()).data();
    if (consultation?['assignedConsultantId'] != viewer) return;

    yield* _messages(targetUid).orderBy('createdAt').snapshots();
  }

  static Stream<QuerySnapshot<Map<String, dynamic>>> consultantPresenceStream() =>
      _presence.orderBy('updatedAt', descending: true).snapshots();

  static Stream<QuerySnapshot<Map<String, dynamic>>> onlineConsultantsStream() =>
      _presence.where('online', isEqualTo: true).snapshots();

  static Future<void> setConsultantPresence(bool online) async {
    final consultant = FirebaseAuth.instance.currentUser;
    final uid = consultant == null ? null : _normaliseUid(consultant.uid);
    if (consultant == null || uid == null) return;
    if (!await _hasConsultantRole(uid)) return;

    final profile = await _userData(uid);
    final profileNameValue = profile?['name'];
    final profileName = profileNameValue is String ? profileNameValue : null;
    final name = _normaliseDisplayName(
      profileName?.trim().isNotEmpty == true
          ? profileName
          : consultant.displayName,
    );

    await _presence.doc(uid).set({
      'consultantId': uid,
      'consultantName': name,
      'online': online,
      'updatedAt': FieldValue.serverTimestamp(),
      'lastSeenAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static Future<void> sendUserMessage(String text) async {
    final user = FirebaseAuth.instance.currentUser;
    final uid = user == null ? null : _normaliseUid(user.uid);
    final value = text.trim();
    if (user == null || uid == null || !_isValidMessage(value)) return;

    await ensureConversation();
    final ref = _consultation(uid);
    final existing = await ref.get();
    final data = existing.data() ?? <String, dynamic>{};
    final reopened = data['status'] == 'resolved';
    final userName = _normaliseDisplayName(
      user.displayName,
      fallback: 'VYEA User',
    );

    final batch = _db.batch();
    final messageRef = _messages(uid).doc();
    batch.set(messageRef, {
      'senderType': 'user',
      'senderId': uid,
      'senderName': userName,
      'text': value,
      'read': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.set(ref, {
      'uid': uid,
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
    final targetUid = _normaliseUid(uid);
    final consultant = FirebaseAuth.instance.currentUser;
    final consultantUid = consultant == null ? null : _normaliseUid(consultant.uid);
    if (consultant == null || consultantUid == null || targetUid == null ||
        !await _hasConsultantRole(consultantUid)) {
      return false;
    }

    final profile = await _userData(consultantUid);
    final profileNameValue = profile?['name'];
    final profileName = profileNameValue is String ? profileNameValue : null;
    final name = _normaliseDisplayName(
      profileName?.trim().isNotEmpty == true
          ? profileName
          : consultant.displayName,
    );
    final ref = _consultation(targetUid);

    return _db.runTransaction<bool>((transaction) async {
      final snapshot = await transaction.get(ref);
      if (!snapshot.exists) return false;
      final data = snapshot.data() ?? <String, dynamic>{};
      final assignedValue = data['assignedConsultantId'];
      final assignedId = assignedValue is String && _isValidUid(assignedValue)
          ? assignedValue
          : null;
      final statusValue = data['status'];
      final status = statusValue is String ? statusValue.trim() : null;

      if (assignedId != null && assignedId != consultantUid) return false;
      if (assignedId == consultantUid) return true;
      if (status != 'waiting_for_consultant' && status != 'open') return false;

      transaction.set(
        ref,
        {
          'assignedConsultantId': consultantUid,
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

  /// Explicit reassignment is an administrative action. Consultants can only
  /// claim an unassigned request through [acceptConsultation].
  static Future<void> assignConsultant({
    required String uid,
    required String consultantId,
    required String consultantName,
  }) async {
    final targetUid = _normaliseUid(uid);
    final targetConsultantId = _normaliseUid(consultantId);
    final actingUser = FirebaseAuth.instance.currentUser;
    final actingUid = actingUser == null ? null : _normaliseUid(actingUser.uid);
    final trimmedName = consultantName.trim();
    if (actingUser == null || actingUid == null || targetUid == null ||
        targetConsultantId == null ||
        trimmedName.length > 120 ||
        !await _isAdmin(actingUid)) {
      return;
    }

    final targetIsConsultant = await _hasConsultantRole(targetConsultantId);
    if (!targetIsConsultant) return;

    final ref = _consultation(targetUid);
    await ref.set(
      {
        'assignedConsultantId': targetConsultantId,
        'assignedConsultantName': _normaliseDisplayName(trimmedName),
        'status': 'assigned',
        'assignedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  static Future<bool> isAssignedToCurrentConsultant(String uid) async {
    final targetUid = _normaliseUid(uid);
    final consultantId = currentUid;
    if (targetUid == null || consultantId == null ||
        !_isValidUid(consultantId) ||
        !await _hasConsultantRole(consultantId)) {
      return false;
    }
    final data = (await _consultation(targetUid).get()).data();
    return data?['assignedConsultantId'] == consultantId;
  }

  static Future<void> sendConsultantMessage({
    required String uid,
    required String text,
    required String consultantName,
  }) async {
    final targetUid = _normaliseUid(uid);
    final consultant = FirebaseAuth.instance.currentUser;
    final consultantUid = consultant == null ? null : _normaliseUid(consultant.uid);
    final value = text.trim();
    final displayName = consultantName.trim();
    if (consultant == null || consultantUid == null || targetUid == null ||
        !_isValidMessage(value) || displayName.length > 120) {
      return;
    }
    if (!await _hasConsultantRole(consultantUid)) return;

    final ref = _consultation(targetUid);
    final data = (await ref.get()).data() ?? <String, dynamic>{};
    final assignedValue = data['assignedConsultantId'];
    final assignedId = assignedValue is String && _isValidUid(assignedValue)
        ? assignedValue
        : null;
    if (assignedId != consultantUid) return;

    final firstReplyExists = data['firstConsultantReplyAt'] != null;
    final createdAt = data['createdAt'];
    final safeDisplayName = _normaliseDisplayName(displayName);

    final batch = _db.batch();
    final messageRef = _messages(targetUid).doc();
    batch.set(messageRef, {
      'senderType': 'consultant',
      'senderId': consultantUid,
      'senderName': safeDisplayName,
      'text': value,
      'read': false,
      'createdAt': FieldValue.serverTimestamp(),
    });

    final update = <String, dynamic>{
      'status': 'consultant_replied',
      'assignedConsultantId': consultantUid,
      'assignedConsultantName': safeDisplayName,
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
    final targetUid = _normaliseUid(uid);
    final safeStatus = _normaliseStatus(status);
    final consultant = FirebaseAuth.instance.currentUser;
    final consultantUid = consultant == null ? null : _normaliseUid(consultant.uid);
    if (consultant == null || consultantUid == null || targetUid == null ||
        safeStatus == null || !await _hasConsultantRole(consultantUid)) {
      return;
    }
    if (!await isAssignedToCurrentConsultant(targetUid)) return;

    await _consultation(targetUid).set(
      {
        'status': safeStatus,
        if (safeStatus == 'resolved') 'resolvedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  static Future<void> markMessagesRead(String uid, {required String by}) async {
    final targetUid = _normaliseUid(uid);
    final viewer = FirebaseAuth.instance.currentUser;
    final viewerUid = viewer == null ? null : _normaliseUid(viewer.uid);
    final readerType = by.trim().toLowerCase();
    if (viewer == null || viewerUid == null || targetUid == null ||
        (readerType != 'customer' && readerType != 'consultant')) {
      return;
    }

    if (readerType == 'customer') {
      if (targetUid != viewerUid) return;
    } else {
      if (!await isAssignedToCurrentConsultant(targetUid)) return;
    }

    final senderType = readerType == 'customer' ? 'consultant' : 'user';
    final snapshot = await _messages(targetUid)
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

    await _consultation(targetUid).set(
      {
        readerType == 'customer' ? 'unreadForUser' : 'unreadForConsultant': 0,
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
    if (uid == null || !_isValidUid(uid) || rating < 1 || rating > 5) return;

    final data = (await _consultation(uid).get()).data();
    if (data?['status'] != 'resolved') return;
    if (data?['rating'] != null) return;

    final trimmedComment = comment?.trim();
    if (trimmedComment != null && trimmedComment.length > 1000) return;

    await _consultation(uid).set(
      {
        'rating': rating,
        'ratingComment': trimmedComment?.isEmpty == true ? null : trimmedComment,
        'ratedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }
}
