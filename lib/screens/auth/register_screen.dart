import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../models/user_model.dart';
import '../../services/firestore_service.dart';
import '../../widgets/primary_button.dart';
import 'auth_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  // ============================================================
  // Controllers
  // ============================================================

  final TextEditingController nameController = TextEditingController();

  final TextEditingController emailController = TextEditingController();

  final TextEditingController passwordController = TextEditingController();

  final TextEditingController confirmPasswordController =
      TextEditingController();

  // ============================================================
  // UI States
  // ============================================================

  bool obscurePassword = true;
  bool obscureConfirmPassword = true;
  bool isLoading = false;

  // ============================================================
  // Password Requirements
  // ============================================================

  bool hasMinLength = false;
  bool hasUppercase = false;
  bool hasLowercase = false;
  bool hasNumber = false;
  bool hasSpecial = false;

  // ============================================================
  // Init
  // ============================================================

  @override
  void initState() {
    super.initState();

    passwordController.addListener(_checkPassword);
  }

  // ============================================================
  // Dispose
  // ============================================================

  @override
  void dispose() {
    passwordController.removeListener(_checkPassword);

    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();

    super.dispose();
  }

  // ============================================================
  // Password Validation
  // ============================================================

  void _checkPassword() {
    final password = passwordController.text;

    if (!mounted) return;

    setState(() {
      hasMinLength = password.length >= 8;

      hasUppercase = RegExp(r'[A-Z]').hasMatch(password);

      hasLowercase = RegExp(r'[a-z]').hasMatch(password);

      hasNumber = RegExp(r'[0-9]').hasMatch(password);

      hasSpecial = RegExp(r'[!@#\$%^&*(),.?":{}|<>]').hasMatch(password);
    });
  }

  bool get isPasswordValid {
    return hasMinLength &&
        hasUppercase &&
        hasLowercase &&
        hasNumber &&
        hasSpecial;
  }

  // ============================================================
  // Register
  // ============================================================

  Future<void> register() async {
    FocusScope.of(context).unfocus();

    // ----------------------------------------------------------
    // Check empty fields
    // ----------------------------------------------------------

    if (nameController.text.trim().isEmpty ||
        emailController.text.trim().isEmpty ||
        passwordController.text.isEmpty ||
        confirmPasswordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields.')),
      );

      return;
    }

    // ----------------------------------------------------------
    // Check password requirements
    // ----------------------------------------------------------

    if (!isPasswordValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please make sure your password meets all requirements.',
          ),
        ),
      );

      return;
    }

    // ----------------------------------------------------------
    // Check confirm password
    // ----------------------------------------------------------

    if (passwordController.text != confirmPasswordController.text) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Passwords do not match.')));

      return;
    }

    // ----------------------------------------------------------
    // Start loading
    // ----------------------------------------------------------

    setState(() {
      isLoading = true;
    });

    try {
      // --------------------------------------------------------
      // Firebase Authentication
      // --------------------------------------------------------

      final credential = await AuthService.register(
        email: emailController.text.trim(),
        password: passwordController.text,
      );

      // --------------------------------------------------------
      // Make sure Firebase user exists
      // --------------------------------------------------------

      final firebaseUser = credential.user;

      if (firebaseUser == null) {
        throw Exception('User registration failed.');
      }

      // --------------------------------------------------------
      // Create Firestore User Model
      //
      // UserModel.toMap() will automatically
      // assign:
      //
      // role = customer
      // isActive = true
      //
      // --------------------------------------------------------

      final user = UserModel(
        uid: firebaseUser.uid,
        name: nameController.text.trim(),
        email: emailController.text.trim(),
      );

      // --------------------------------------------------------
      // Save user to Firestore
      // --------------------------------------------------------

      await FirestoreService.createUser(user);

      if (!mounted) return;

      // --------------------------------------------------------
      // Success
      // --------------------------------------------------------

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Account created successfully.')),
      );

      // --------------------------------------------------------
      // Return to Login
      // --------------------------------------------------------

      Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      String message;

      switch (e.code) {
        case 'email-already-in-use':
          message = 'This email is already registered.';
          break;

        case 'invalid-email':
          message = 'Please enter a valid email address.';
          break;

        case 'weak-password':
          message = 'The password is too weak.';
          break;

        case 'operation-not-allowed':
          message = 'Email/password registration is not enabled in Firebase.';
          break;

        case 'network-request-failed':
          message = 'Network error. Please check your internet connection.';
          break;

        default:
          message = e.message ?? 'Registration failed.';
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Registration failed: $e')));
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  // ============================================================
  // Password Requirement Widget
  // ============================================================

  Widget _buildRequirement(bool passed, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        children: [
          Icon(
            passed ? Icons.check_circle : Icons.cancel_outlined,
            color: passed ? Colors.green : Colors.grey,
            size: 18,
          ),

          const SizedBox(width: 8),

          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: passed ? Colors.green : Colors.grey.shade700,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // Build
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,

      appBar: AppBar(title: const Text('Create Account')),

      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),

          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,

            children: [
              // ==================================================
              // Header
              // ==================================================
              Center(
                child: Container(
                  width: 85,
                  height: 85,
                  decoration: const BoxDecoration(
                    color: Color(0xFFC58F73),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.person_add_alt_1,
                    color: Colors.white,
                    size: 40,
                  ),
                ),
              ),

              const SizedBox(height: 28),

              Text(
                'Create Your Account',
                style: Theme.of(context).textTheme.headlineMedium,
              ),

              const SizedBox(height: 8),

              Text(
                'Join TiB AI and start your personal styling journey.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),

              const SizedBox(height: 32),

              // ==================================================
              // Full Name
              // ==================================================
              TextField(
                controller: nameController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Full Name',
                  hintText: 'Enter your full name',
                  prefixIcon: Icon(Icons.person_outline),
                ),
              ),

              const SizedBox(height: 20),

              // ==================================================
              // Email
              // ==================================================
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  hintText: 'example@email.com',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
              ),

              const SizedBox(height: 20),

              // ==================================================
              // Password
              // ==================================================
              TextField(
                controller: passwordController,
                obscureText: obscurePassword,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: 'Password',
                  hintText: 'Create a strong password',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    onPressed: () {
                      setState(() {
                        obscurePassword = !obscurePassword;
                      });
                    },
                    icon: Icon(
                      obscurePassword ? Icons.visibility_off : Icons.visibility,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // ==================================================
              // Password Requirements
              // ==================================================
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade300),
                ),

                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [
                    const Text(
                      'Password Requirements',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),

                    const SizedBox(height: 12),

                    _buildRequirement(hasMinLength, 'At least 8 characters'),

                    _buildRequirement(
                      hasUppercase,
                      'At least 1 uppercase letter (A-Z)',
                    ),

                    _buildRequirement(
                      hasLowercase,
                      'At least 1 lowercase letter (a-z)',
                    ),

                    _buildRequirement(hasNumber, 'At least 1 number (0-9)'),

                    _buildRequirement(
                      hasSpecial,
                      'At least 1 special character (!@#\$%^&*)',
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ==================================================
              // Confirm Password
              // ==================================================
              TextField(
                controller: confirmPasswordController,
                obscureText: obscureConfirmPassword,
                textInputAction: TextInputAction.done,

                onSubmitted: (_) {
                  if (!isLoading) {
                    register();
                  }
                },

                decoration: InputDecoration(
                  labelText: 'Confirm Password',
                  hintText: 'Re-enter your password',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    onPressed: () {
                      setState(() {
                        obscureConfirmPassword = !obscureConfirmPassword;
                      });
                    },
                    icon: Icon(
                      obscureConfirmPassword
                          ? Icons.visibility_off
                          : Icons.visibility,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 30),

              // ==================================================
              // Register Button
              // ==================================================
              SizedBox(
                width: double.infinity,

                child: PrimaryButton(
                  text: isLoading ? 'Creating Account...' : 'Create Account',

                  icon: Icons.person_add,

                  onPressed: isLoading ? null : register,
                ),
              ),

              const SizedBox(height: 24),

              // ==================================================
              // Login Link
              // ==================================================
              Row(
                mainAxisAlignment: MainAxisAlignment.center,

                children: [
                  const Text('Already have an account?'),

                  TextButton(
                    onPressed: isLoading
                        ? null
                        : () {
                            Navigator.pop(context);
                          },
                    child: const Text('Sign In'),
                  ),
                ],
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
