import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class AuthProvider extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  StreamSubscription<User?>? _subscription;
  User? _user;
  bool _initialized = false;
  bool _busy = false;
  String? _errorMessage;

  AuthProvider() {
    _user = _auth.currentUser;
    _subscription = _auth.authStateChanges().listen((user) {
      final changed = _user?.uid != user?.uid;
      _user = user;
      _initialized = true;
      if (changed) {
        _errorMessage = null;
        notifyListeners();
      } else if (!_initialized) {
        notifyListeners();
      }
    });
  }

  User? get user => _user;
  bool get isLoggedIn => _user != null;
  bool get isInitialized => _initialized;
  bool get isBusy => _busy;
  String? get errorMessage => _errorMessage;

  String? get uid => _user?.uid;
  String? get displayName => _user?.displayName?.trim().isEmpty == true ? null : _user?.displayName?.trim();
  String? get email => _user?.email?.trim().isEmpty == true ? null : _user?.email?.trim();
  String? get photoUrl => _user?.photoURL?.trim().isEmpty == true ? null : _user?.photoURL?.trim();
  bool get isEmailVerified => _user?.emailVerified ?? false;
  bool get hasDisplayName => displayName != null;
  bool get hasPhoto => photoUrl != null;

  void clearError() {
    if (_errorMessage == null) return;
    _errorMessage = null;
    notifyListeners();
  }

  Future<bool> refreshUser() async {
    final current = _user;
    if (current == null || _busy) return false;
    _busy = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await current.reload();
      _user = _auth.currentUser;
      return true;
    } on FirebaseAuthException catch (error) {
      _errorMessage = error.message ?? 'Unable to refresh your account session.';
      return false;
    } catch (_) {
      _errorMessage = 'Unable to refresh your account session.';
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    if (_busy) return;
    _busy = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _auth.signOut();
    } on FirebaseAuthException catch (error) {
      _errorMessage = error.message ?? 'Unable to sign out right now.';
      rethrow;
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
