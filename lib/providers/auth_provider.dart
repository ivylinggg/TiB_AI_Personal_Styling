import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class AuthProvider extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  StreamSubscription<User?>? _subscription;
  User? _user;
  bool _initialized = false;
  bool _busy = false;

  AuthProvider() {
    _user = _auth.currentUser;
    _subscription = _auth.authStateChanges().listen((user) {
      final changed = _user?.uid != user?.uid;
      _user = user;
      _initialized = true;
      if (changed) notifyListeners();
    });
  }

  User? get user => _user;
  bool get isLoggedIn => _user != null;
  bool get isInitialized => _initialized;
  bool get isBusy => _busy;

  String? get uid => _user?.uid;
  String? get displayName => _user?.displayName;
  String? get email => _user?.email;
  String? get photoUrl => _user?.photoURL;

  Future<void> signOut() async {
    if (_busy) return;
    _busy = true;
    notifyListeners();
    try {
      await _auth.signOut();
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
