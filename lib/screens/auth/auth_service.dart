import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  AuthService._();

  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static User? get currentUser => _auth.currentUser;

  static Future<UserCredential> login({
    required String email,
    required String password,
  }) async {
    return _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

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

  static Future<void> resetPassword({required String email}) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  static Future<void> logout() async {
    await _auth.signOut();
  }
}
