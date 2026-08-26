import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_gradients.dart';
import '../../models/user_model.dart';
import '../../services/firestore_service.dart';
import '../../widgets/primary_button.dart';
import 'auth_service.dart';
import 'email_verification_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  bool obscurePassword = true;
  bool obscureConfirmPassword = true;
  bool isLoading = false;
  bool hasMinLength = false;
  bool hasUppercase = false;
  bool hasLowercase = false;
  bool hasNumber = false;
  bool hasSpecial = false;

  @override
  void initState() {
    super.initState();
    passwordController.addListener(_checkPassword);
  }

  @override
  void dispose() {
    passwordController.removeListener(_checkPassword);
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

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

  bool get isPasswordValid => hasMinLength && hasUppercase && hasLowercase && hasNumber && hasSpecial;

  Future<void> register() async {
    FocusScope.of(context).unfocus();
    final name = nameController.text.trim();
    final email = emailController.text.trim();
    final password = passwordController.text;

    if (name.isEmpty || email.isEmpty || password.isEmpty || confirmPasswordController.text.isEmpty) {
      _message('Tell us your name, email and password to get started.');
      return;
    }
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      _message('Please enter a valid email address.');
      return;
    }
    if (!isPasswordValid) {
      _message('Please complete the password requirements.');
      return;
    }
    if (password != confirmPasswordController.text) {
      _message('Your passwords do not match.');
      return;
    }

    setState(() => isLoading = true);
    try {
      final credential = await AuthService.register(email: email, password: password);
      final firebaseUser = credential.user;
      if (firebaseUser == null) throw Exception('User registration failed.');

      final user = UserModel(uid: firebaseUser.uid, name: name, email: email);
      try {
        await FirestoreService.createUser(user);
        await AuthService.sendEmailVerification();
      } catch (_) {
        try {
          await firebaseUser.delete();
        } catch (_) {}
        throw Exception('Could not finish creating your style profile. Please try again.');
      }

      if (!mounted) return;
      await Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const EmailVerificationScreen()),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      switch (e.code) {
        case 'email-already-in-use':
          _message('This email is already registered.');
          break;
        case 'invalid-email':
          _message('Please enter a valid email address.');
          break;
        case 'weak-password':
          _message('The password is too weak.');
          break;
        case 'operation-not-allowed':
          _message('Email/password registration is not enabled.');
          break;
        case 'network-request-failed':
          _message('Network error. Please check your connection.');
          break;
        default:
          _message(e.message ?? 'Registration failed.');
      }
    } catch (e) {
      if (mounted) _message(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _message(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message), behavior: SnackBarBehavior.floating));
  }

  Widget _requirement(bool passed, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        children: [
          Icon(passed ? Icons.check_circle : Icons.circle_outlined, color: passed ? AppColors.success : AppColors.textMuted, size: 17),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: TextStyle(color: passed ? AppColors.success : AppColors.textSecondary, fontSize: 12))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18)), const Spacer(), const Text('CREATE PROFILE', style: TextStyle(fontSize: 9, letterSpacing: 1.2, fontWeight: FontWeight.w800, color: AppColors.textMuted)), const SizedBox(width: 8)]),
              const SizedBox(height: 13),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(22, 23, 22, 22),
                decoration: BoxDecoration(gradient: AppGradients.soft, borderRadius: BorderRadius.circular(27)),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('A little about you.', style: TextStyle(fontSize: 27, fontWeight: FontWeight.w800, letterSpacing: -.6)),
                    SizedBox(height: 8),
                    Text('Create your account first. Then TiB will help you discover your colours, style personality and wardrobe.', style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5, height: 1.45)),
                  ],
                ),
              ),
              const SizedBox(height: 25),
              const Text('YOUR NAME', style: TextStyle(fontSize: 9.5, letterSpacing: 1, fontWeight: FontWeight.w800, color: AppColors.textMuted)),
              const SizedBox(height: 7),
              TextField(controller: nameController, textInputAction: TextInputAction.next, decoration: const InputDecoration(hintText: 'What should TiB call you?', prefixIcon: Icon(Icons.person_outline_rounded))),
              const SizedBox(height: 17),
              const Text('EMAIL', style: TextStyle(fontSize: 9.5, letterSpacing: 1, fontWeight: FontWeight.w800, color: AppColors.textMuted)),
              const SizedBox(height: 7),
              TextField(controller: emailController, keyboardType: TextInputType.emailAddress, textInputAction: TextInputAction.next, decoration: const InputDecoration(hintText: 'you@example.com', prefixIcon: Icon(Icons.mail_outline_rounded))),
              const SizedBox(height: 17),
              const Text('PASSWORD', style: TextStyle(fontSize: 9.5, letterSpacing: 1, fontWeight: FontWeight.w800, color: AppColors.textMuted)),
              const SizedBox(height: 7),
              TextField(controller: passwordController, obscureText: obscurePassword, textInputAction: TextInputAction.next, decoration: InputDecoration(hintText: 'Create a secure password', prefixIcon: const Icon(Icons.lock_outline_rounded), suffixIcon: IconButton(onPressed: () => setState(() => obscurePassword = !obscurePassword), icon: Icon(obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined)))),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.fromLTRB(14, 13, 14, 8),
                decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(17), border: Border.all(color: AppColors.border)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Make it secure', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)), const SizedBox(height: 10), _requirement(hasMinLength, 'At least 8 characters'), _requirement(hasUppercase, 'One uppercase letter'), _requirement(hasLowercase, 'One lowercase letter'), _requirement(hasNumber, 'One number'), _requirement(hasSpecial, 'One special character')]),
              ),
              const SizedBox(height: 17),
              TextField(controller: confirmPasswordController, obscureText: obscureConfirmPassword, textInputAction: TextInputAction.done, onSubmitted: (_) { if (!isLoading) register(); }, decoration: InputDecoration(hintText: 'Confirm your password', prefixIcon: const Icon(Icons.lock_outline_rounded), suffixIcon: IconButton(onPressed: () => setState(() => obscureConfirmPassword = !obscureConfirmPassword), icon: Icon(obscureConfirmPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined)))),
              const SizedBox(height: 25),
              SizedBox(width: double.infinity, child: PrimaryButton(text: isLoading ? 'Creating your profile…' : 'Create My Profile', icon: Icons.arrow_forward_rounded, onPressed: isLoading ? null : register)),
              const SizedBox(height: 15),
              Center(child: TextButton(onPressed: isLoading ? null : () => Navigator.pop(context), child: const Text('Already have an account? Sign In'))),
            ],
          ),
        ),
      ),
    );
  }
}
