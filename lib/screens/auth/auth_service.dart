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

  // ============================================================
  // EMAIL + PASSWORD LOGIN
  // ============================================================

  static Future<UserCredential> login({
    required String email,
    required String password,
  }) async {
    return _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  // ============================================================
  // GOOGLE SIGN-IN
  // ============================================================

  static Future<void> _initializeGoogleSignIn() async {
    if (_googleInitialized) return;

    _googleInitialization ??=
        GoogleSignIn.instance.initialize();

    await _googleInitialization;

    _googleInitialized = true;
  }

  static Future<UserCredential?> loginWithGoogle() async {
    await _initializeGoogleSignIn();

    final googleUser =
        await GoogleSignIn.instance.authenticate();

    final googleAuth = googleUser.authentication;

    final idToken = googleAuth.idToken;

    if (idToken == null || idToken.isEmpty) {
      throw FirebaseAuthException(
        code: 'google-id-token-missing',
        message: 'Google sign-in did not return an ID token.',
      );
    }

    final credential = GoogleAuthProvider.credential(
      idToken: idToken,
    );

    final userCredential =
        await _auth.signInWithCredential(credential);

    final user = userCredential.user;

    if (user == null) {
      throw FirebaseAuthException(
        code: 'google-user-missing',
        message: 'Google sign-in did not return a Firebase user.',
      );
    }

    // Create the Firestore profile automatically for a new Google user.
    final existingProfile = await FirestoreService.getUser(
      user.uid,
    );

    if (existingProfile == null) {
      final profile = UserModel(
        uid: user.uid,
        name: user.displayName?.trim().isNotEmpty == true
            ? user.displayName!.trim()
            : 'Google User',
        email: user.email ?? '',
        photoUrl: user.photoURL,
      );

      await FirestoreService.createUser(profile);
    }

    return userCredential;
  }

  // ============================================================
  // CURRENT USER PROFILE
  // ============================================================

  static Future<Map<String, dynamic>> getCurrentUserProfile() async {
    final user = _auth.currentUser;

    if (user == null) {
      throw FirebaseAuthException(
        code: 'no-current-user',
        message: 'No authenticated user found.',
      );
    }

    final document = await _firestore
        .collection('users')
        .doc(user.uid)
        .get();

    if (!document.exists) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'user-profile-not-found',
        message: 'User profile was not found.',
      );
    }

    return document.data() ?? <String, dynamic>{};
  }

  // ============================================================
  // CURRENT USER ROLE
  // ============================================================

  static Future<String> getCurrentUserRole() async {
    final data = await getCurrentUserProfile();
    final role = data['role'];

    if (role is String && role.trim().isNotEmpty) {
      return role.trim().toLowerCase();
    }

    return 'customer';
  }

  // ============================================================
  // ACCOUNT STATUS
  // ============================================================

  static Future<bool> isCurrentUserActive() async {
    final data = await getCurrentUserProfile();
    return data['isActive'] as bool? ?? true;
  }

  // ============================================================
  // REGISTER
  // ============================================================

  static Future<UserCredential> register({
    required String email,
    required String password,
  }) async {
    return _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  // ============================================================
  // PASSWORD RESET
  // ============================================================

  static Future<void> resetPassword({
    required String email,
  }) async {
    await _auth.sendPasswordResetEmail(
      email: email,
    );
  }

  // ============================================================
  // LOGOUT
  // ============================================================

  static Future<void> logout() async {
    await _auth.signOut();

    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {
      // Ignore Google sign-out errors when the user is using
      // email/password authentication.
    }
  }
}
