import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

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
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  static const Duration _readTimeout = Duration(seconds: 15);
  static const Duration _writeTimeout = Duration(seconds: 15);

  static StreamSubscription<String>? _tokenSubscription;
  static StreamSubscription<RemoteMessage>? _foregroundSubscription;
  static String? _initializedUid;
  static final Set<String> _welcomeChecks = <String>{};

  static CollectionReference<Map<String, dynamic>> _notifications(String uid) =>
      _db.collection('users').doc(uid).collection('notifications');

  static String? _normalizeUid(String uid) {
    final requested = uid.trim();
    final current = FirebaseAuth.instance.currentUser?.uid.trim();
    if (requested.isEmpty || current == null || current.isEmpty) return null;
    return requested == current ? current : null;
  }

  static Future<T> _withReadTimeout<T>(Future<T> future, String message) {
    return future.timeout(
      _readTimeout,
      onTimeout: () => throw TimeoutException(message),
    );
  }

  static Future<T> _withWriteTimeout<T>(Future<T> future, String message) {
    return future.timeout(
      _writeTimeout,
      onTimeout: () => throw TimeoutException(message),
    );
  }

  static Future<void> initializePushNotifications() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _initializedUid == user.uid) return;

    await _tokenSubscription?.cancel();
    await _foregroundSubscription?.cancel();

    try {
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      ).timeout(const Duration(seconds: 10));

      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        _initializedUid = user.uid;
        return;
      }

      await _syncToken(user.uid);

      _tokenSubscription = _messaging.onTokenRefresh.listen((token) {
        if (token.trim().isEmpty) return;
        final currentUid = FirebaseAuth.instance.currentUser?.uid;
        if (currentUid != user.uid) return;
        unawaited(_storeDeviceToken(user.uid, token));
      });

      _foregroundSubscription = FirebaseMessaging.onMessage.listen((_) {});
      _initializedUid = user.uid;
    } catch (_) {
      // Push is optional and must never block app startup.
    }
  }

  static Future<void> resetForAccountChange() async {
    await _tokenSubscription?.cancel();
    await _foregroundSubscription?.cancel();
    _tokenSubscription = null;
    _foregroundSubscription = null;
    _initializedUid = null;
  }

  static Future<void> _syncToken(String uid) async {
    try {
      final token = await _messaging.getToken().timeout(const Duration(seconds: 10));
      if (token != null && token.trim().isNotEmpty) {
        await _storeDeviceToken(uid, token);
      }
    } catch (_) {
      // Token access can temporarily fail on emulators or before APNs setup.
    }
  }

  static Future<void> _storeDeviceToken(String uid, String token) async {
    final ownerUid = _normalizeUid(uid);
    final cleanToken = token.trim();
    if (ownerUid == null || cleanToken.isEmpty) return;
    try {
      await _withWriteTimeout(
        _db.collection('users').doc(ownerUid).set({
          'fcmTokens': FieldValue.arrayUnion([cleanToken]),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true)),
        'Saving notification device settings timed out.',
      );
    } catch (_) {
      // Token persistence is non-critical.
    }
  }

  static Stream<List<VyeaNotification>> stream(String uid) {
    final ownerUid = _normalizeUid(uid);
    if (ownerUid == null) return const Stream.empty();
    return _notifications(ownerUid).limit(50).snapshots().map((snapshot) {
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
    final ownerUid = _normalizeUid(uid);
    if (ownerUid == null) return Stream.value(0);
    return _notifications(ownerUid)
        .where('read', isEqualTo: false)
        .limit(50)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  static Future<void> ensureWelcomeNotification(String uid) async {
    final ownerUid = _normalizeUid(uid);
    if (ownerUid == null || _welcomeChecks.contains(ownerUid)) return;
    _welcomeChecks.add(ownerUid);

    try {
      final existing = await _withReadTimeout(
        _notifications(ownerUid).limit(1).get(),
        'Checking welcome notification timed out.',
      );
      if (existing.docs.isNotEmpty) return;

      await _withWriteTimeout(
        _notifications(ownerUid).add({
          'title': 'Welcome to VYEA',
          'body': 'Your personal styling space is ready. Explore your wardrobe and discover a look that feels like you.',
          'type': 'system',
          'read': false,
          'createdAt': FieldValue.serverTimestamp(),
        }),
        'Creating your welcome notification timed out.',
      );
    } catch (_) {
      _welcomeChecks.remove(ownerUid);
    }
  }

  static Future<void> markRead(String uid, String notificationId) async {
    final ownerUid = _normalizeUid(uid);
    final cleanId = notificationId.trim();
    if (ownerUid == null || cleanId.isEmpty) return;
    try {
      await _withWriteTimeout(
        _notifications(ownerUid).doc(cleanId).update({'read': true}),
        'Marking the notification as read timed out.',
      );
    } catch (_) {}
  }

  static Future<void> markAllRead(String uid) async {
    final ownerUid = _normalizeUid(uid);
    if (ownerUid == null) return;
    try {
      final snapshot = await _withReadTimeout(
        _notifications(ownerUid)
            .where('read', isEqualTo: false)
            .limit(50)
            .get(),
        'Loading unread notifications timed out.',
      );
      if (snapshot.docs.isEmpty) return;
      final batch = _db.batch();
      for (final doc in snapshot.docs) {
        batch.update(doc.reference, {'read': true});
      }
      await _withWriteTimeout(
        batch.commit(),
        'Marking notifications as read timed out.',
      );
    } catch (_) {}
  }
}
