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

  static StreamSubscription<String>? _tokenSubscription;
  static StreamSubscription<RemoteMessage>? _foregroundSubscription;
  static String? _initializedUid;

  static CollectionReference<Map<String, dynamic>> _notifications(String uid) =>
      _db.collection('users').doc(uid).collection('notifications');

  static Future<void> initializePushNotifications() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    if (_initializedUid == user.uid) return;

    await _tokenSubscription?.cancel();
    await _foregroundSubscription?.cancel();

    try {
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        _initializedUid = user.uid;
        return;
      }

      await _syncToken(user.uid);

      _tokenSubscription = _messaging.onTokenRefresh.listen((token) {
        if (token.trim().isNotEmpty) {
          unawaited(_storeDeviceToken(user.uid, token));
        }
      });

      _foregroundSubscription = FirebaseMessaging.onMessage.listen((message) {
        unawaited(_saveForegroundNotification(user.uid, message));
      });

      _initializedUid = user.uid;
    } catch (_) {
      // Push notifications are optional and must not block app startup.
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
      final token = await _messaging.getToken();
      if (token != null && token.trim().isNotEmpty) {
        await _storeDeviceToken(uid, token);
      }
    } catch (_) {
      // Token access can temporarily fail on emulators or before APNs setup.
    }
  }

  static Future<void> _storeDeviceToken(String uid, String token) async {
    try {
      await _db.collection('users').doc(uid).set({
        'fcmTokens': FieldValue.arrayUnion([token]),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {
      // Never block or crash the app because token persistence is unavailable.
    }
  }

  static Future<void> _saveForegroundNotification(
    String uid,
    RemoteMessage message,
  ) async {
    final title = message.notification?.title ??
        message.data['title']?.toString() ??
        'VYEA update';
    final body = message.notification?.body ?? message.data['body']?.toString() ?? '';
    if (title.trim().isEmpty && body.trim().isEmpty) return;

    try {
      await _notifications(uid).add({
        'title': title.trim().isEmpty ? 'VYEA update' : title.trim(),
        'body': body.trim(),
        'type': message.data['type']?.toString() ?? 'push',
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
        'messageId': message.messageId,
      });
    } catch (_) {
      // The foreground event should never crash the app if Firestore is offline.
    }
  }

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
    try {
      final existing = await _notifications(uid).limit(1).get();
      if (existing.docs.isNotEmpty) return;
      await _notifications(uid).add({
        'title': 'Welcome to VYEA',
        'body': 'Your personal styling space is ready. Explore your wardrobe and discover a look that feels like you.',
        'type': 'system',
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // Notifications are non-critical; keep the rest of the dashboard usable.
    }
  }

  static Future<void> markRead(String uid, String notificationId) async {
    if (uid.trim().isEmpty || notificationId.trim().isEmpty) return;
    try {
      await _notifications(uid).doc(notificationId).update({'read': true});
    } catch (_) {
      // Ignore transient notification update failures.
    }
  }

  static Future<void> markAllRead(String uid) async {
    if (uid.trim().isEmpty) return;
    try {
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
    } catch (_) {
      // Ignore transient notification update failures.
    }
  }
}
