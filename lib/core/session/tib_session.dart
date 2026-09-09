import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../models/user_model.dart';
import '../../services/firestore_service.dart';
import '../../services/tib_model_service.dart';

class TibSession extends ChangeNotifier {
  TibSession() {
    _user = FirebaseAuth.instance.currentUser;
    _subscription = FirebaseAuth.instance.authStateChanges().listen(_handleAuthChanged);
  }

  StreamSubscription<User?>? _subscription;
  User? _user;
  UserModel? _profile;
  TibModelProfile? _tibModel;
  bool _loadingProfile = false;
  Object? _error;

  User? get user => _user;
  UserModel? get profile => _profile;
  TibModelProfile? get tibModel => _tibModel;
  String? get uid => _user?.uid;
  bool get isSignedIn => _user != null;
  bool get isLoadingProfile => _loadingProfile;
  Object? get error => _error;

  Future<void> refresh() async {
    final current = FirebaseAuth.instance.currentUser;
    _user = current;
    if (current == null) {
      _clearPersonalState();
      notifyListeners();
      return;
    }

    final uid = current.uid;
    _loadingProfile = true;
    _error = null;
    notifyListeners();

    try {
      final results = await Future.wait<dynamic>([
        FirestoreService.getUser(uid),
        TibModelService.loadForUser(uid),
      ]);
      if (FirebaseAuth.instance.currentUser?.uid != uid) return;
      _profile = results[0] as UserModel?;
      _tibModel = results[1] as TibModelProfile;
    } catch (error) {
      if (FirebaseAuth.instance.currentUser?.uid != uid) return;
      _error = error;
    } finally {
      if (FirebaseAuth.instance.currentUser?.uid == uid) {
        _loadingProfile = false;
        notifyListeners();
      }
    }
  }

  Future<void> _handleAuthChanged(User? user) async {
    final previousUid = _user?.uid;
    final nextUid = user?.uid;
    _user = user;

    if (previousUid != nextUid) {
      _clearPersonalState();
      notifyListeners();
    }

    if (user != null) {
      await refresh();
    }
  }

  void _clearPersonalState() {
    _profile = null;
    _tibModel = null;
    _loadingProfile = false;
    _error = null;
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
