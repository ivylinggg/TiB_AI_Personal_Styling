import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  AuthService._();

  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ============================================================
  // CURRENT USER
  // ============================================================

  static User? get currentUser => _auth.currentUser;

  // ============================================================
  // LOGIN
  // ============================================================

  static Future<UserCredential> login({
    required String email,
    required String password,
  }) async {
    return await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  // ============================================================
  // GET CURRENT USER ROLE
  // ============================================================

  static Future<String> getCurrentUserRole() async {
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

    final data = document.data();

    final role = data?['role'];

    if (role is String && role.trim().isNotEmpty) {
      return role.trim().toLowerCase();
    }

    // Existing accounts without a role are treated
    // as customer until an administrator assigns a role.
    return 'customer';
  }

  // ============================================================
  // REGISTER
  // ============================================================

  static Future<UserCredential> register({
    required String email,
    required String password,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    return credential;
  }

  // ============================================================
  // PASSWORD RESET
  // ============================================================

  static Future<void> resetPassword({required String email}) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  // ============================================================
  // LOGOUT
  // ============================================================

  static Future<void> logout() async {
    await _auth.signOut();
  }
}
