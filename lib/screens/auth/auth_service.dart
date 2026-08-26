import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../models/user_model.dart';
import '../../services/firestore_service.dart';

class AuthService {
  AuthService._();

  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static bool _googleInitialized = false;
  static Future<void>? _googleInitialization;

  static User? get currentUser => _auth.currentUser;

  static Future<UserCredential> login({
    required String email,
    required String password,
  }) async {
    return _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  static Future<void> _initializeGoogleSignIn() async {
    if (_googleInitialized) return;
    _googleInitialization ??= GoogleSignIn.instance.initialize(
      serverClientId:
          '494434706372-jdg9h3re1bdc6idecjumdavdmbh3eai8.apps.googleusercontent.com',
    );
    await _googleInitialization;
    _googleInitialized = true;
  }

  static Future<UserCredential?> loginWithGoogle() async {
    await _initializeGoogleSignIn();

    final googleUser = await GoogleSignIn.instance.authenticate();
    final googleAuth = googleUser.authentication;
    final idToken = googleAuth.idToken;

    if (idToken == null || idToken.isEmpty) {
      throw FirebaseAuthException(
        code: 'google-id-token-missing',
        message: 'Google sign-in did not return an ID token.',
      );
    }

    final credential = GoogleAuthProvider.credential(idToken: idToken);
    final userCredential = await _auth.signInWithCredential(credential);
    await _ensureFirestoreProfile(userCredential.user);
    return userCredential;
  }

  static Future<void> _ensureFirestoreProfile(User? user) async {
    if (user == null) {
      throw FirebaseAuthException(
        code: 'social-user-missing',
        message: 'Sign-in did not return a Firebase user.',
      );
    }

    final existingProfile = await FirestoreService.getUser(user.uid);
    if (existingProfile != null) return;

    final profile = UserModel(
      uid: user.uid,
      name: user.displayName?.trim().isNotEmpty == true
          ? user.displayName!.trim()
          : 'TiB User',
      email: user.email?.trim() ?? '',
      photoUrl: user.photoURL,
    );

    await FirestoreService.createUser(profile);
  }

  static Future<Map<String, dynamic>> getCurrentUserProfile() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'no-current-user',
        message: 'No authenticated user found.',
      );
    }

    final document = await _firestore.collection('users').doc(user.uid).get();
    if (!document.exists) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'user-profile-not-found',
        message: 'User profile was not found.',
      );
    }

    return document.data() ?? <String, dynamic>{};
  }

  static Future<String> getCurrentUserRole() async {
    final data = await getCurrentUserProfile();
    final role = data['role'];
    if (role is String && role.trim().isNotEmpty) {
      return role.trim().toLowerCase();
    }
    return 'customer';
  }

  static Future<bool> isCurrentUserActive() async {
    final data = await getCurrentUserProfile();
    return data['isActive'] as bool? ?? true;
  }

  static Future<UserCredential> register({
    required String email,
    required String password,
  }) async {
    return _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  /// Sends the verification email with a bounded timeout so the registration
  /// screen can never remain stuck on "Creating your profile..." forever.
  static Future<void> sendEmailVerification() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'no-current-user',
        message: 'No authenticated user found.',
      );
    }

    await user.sendEmailVerification().timeout(
      const Duration(seconds: 15),
      onTimeout: () => throw TimeoutException(
        'Sending the verification email timed out. Please try again.',
      ),
    );
  }

  static Future<bool> reloadAndCheckEmailVerified() async {
    await _auth.currentUser?.reload();
    return _auth.currentUser?.emailVerified ?? false;
  }

  static Future<void> resetPassword({required String email}) async {
    final normalizedEmail = email.trim();
    if (normalizedEmail.isEmpty || !normalizedEmail.contains('@')) {
      throw FirebaseAuthException(
        code: 'invalid-email',
        message: 'Please enter a valid email address.',
      );
    }

    await _auth.sendPasswordResetEmail(email: normalizedEmail);
  }

  static Future<void> logout() async {
    await _auth.signOut();

    if (!_googleInitialized) return;

    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {
      // Google sign-out can fail after email/password authentication.
    }
  }
}
