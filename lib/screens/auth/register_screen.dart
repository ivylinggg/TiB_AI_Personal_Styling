import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
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

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> register() async {
    FocusScope.of(context).unfocus();
    final name = nameController.text.trim();
    final email = emailController.text.trim();
    final password = passwordController.text;
    final confirmation = confirmPasswordController.text;

    if (name.isEmpty || email.isEmpty || password.isEmpty || confirmation.isEmpty) {
      _message('Tell us your name, email and password to get started.');
      return;
    }
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      _message('Please enter a valid email address.');
      return;
    }
    if (password != confirmation) {
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
          _message('Please choose a slightly stronger password.');
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 760;
            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(wide ? 48 : 22, 18, wide ? 48 : 22, 30),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1080),
                  child: wide
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: _visualPanel()),
                            const SizedBox(width: 42),
                            SizedBox(width: 420, child: _formPanel()),
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _visualPanel(),
                            const SizedBox(height: 28),
                            _formPanel(),
                          ],
                        ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _visualPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'VYEA',
          style: TextStyle(
            color: AppColors.primary,
            fontSize: 15,
            fontWeight: FontWeight.w900,
            letterSpacing: 4.2,
          ),
        ),
        const SizedBox(height: 9),
        const Text(
          'STYLE BUT PERSONAL',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 2.8,
          ),
        ),
        const SizedBox(height: 18),
        AspectRatio(
          aspectRatio: 0.84,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(30),
              image: const DecorationImage(
                image: AssetImage('assets/images/onboarding_hero.png'),
                fit: BoxFit.cover,
              ),
            ),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, AppColors.primaryDark],
                ),
              ),
              padding: const EdgeInsets.all(24),
              child: const Align(
                alignment: Alignment.bottomLeft,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'FIND YOUR\nSIGNATURE STYLE.',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 30,
                        height: 1.02,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -.8,
                      ),
                    ),
                    SizedBox(height: 10),
                    Text(
                      'Start with your profile.\nWe’ll take it from there.',
                      style: TextStyle(color: Colors.white70, fontSize: 12.5, height: 1.5),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          'Your style starts with you.',
          style: TextStyle(
            color: AppColors.brown,
            fontSize: 13,
            fontStyle: FontStyle.italic,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _formPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Create your profile',
          style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, letterSpacing: -.7),
        ),
        const SizedBox(height: 6),
        const Text(
          'A few details first. Your personalised styling journey comes next.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4),
        ),
        const SizedBox(height: 24),
        _fieldLabel('YOUR NAME'),
        const SizedBox(height: 7),
        TextField(
          controller: nameController,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            hintText: 'What should VYEA call you?',
            prefixIcon: Icon(Icons.person_outline_rounded),
          ),
        ),
        const SizedBox(height: 17),
        _fieldLabel('EMAIL'),
        const SizedBox(height: 7),
        TextField(
          controller: emailController,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            hintText: 'you@example.com',
            prefixIcon: Icon(Icons.mail_outline_rounded),
          ),
        ),
        const SizedBox(height: 17),
        _fieldLabel('PASSWORD'),
        const SizedBox(height: 7),
        TextField(
          controller: passwordController,
          obscureText: obscurePassword,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(
            hintText: 'Create a password',
            prefixIcon: const Icon(Icons.lock_outline_rounded),
            suffixIcon: IconButton(
              onPressed: () => setState(() => obscurePassword = !obscurePassword),
              icon: Icon(obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined),
            ),
          ),
        ),
        const SizedBox(height: 17),
        _fieldLabel('CONFIRM PASSWORD'),
        const SizedBox(height: 7),
        TextField(
          controller: confirmPasswordController,
          obscureText: obscureConfirmPassword,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) {
            if (!isLoading) register();
          },
          decoration: InputDecoration(
            hintText: 'Enter the password again',
            prefixIcon: const Icon(Icons.lock_outline_rounded),
            suffixIcon: IconButton(
              onPressed: () => setState(() => obscureConfirmPassword = !obscureConfirmPassword),
              icon: Icon(obscureConfirmPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined),
            ),
          ),
        ),
        const SizedBox(height: 25),
        SizedBox(
          width: double.infinity,
          child: PrimaryButton(
            text: isLoading ? 'Creating your profile…' : 'Create My Profile',
            icon: Icons.arrow_forward_rounded,
            onPressed: isLoading ? null : register,
          ),
        ),
        const SizedBox(height: 15),
        Center(
          child: TextButton(
            onPressed: isLoading ? null : () => Navigator.pop(context),
            child: const Text('Already have an account? Sign In'),
          ),
        ),
      ],
    );
  }

  Widget _fieldLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        color: AppColors.textSecondary,
        fontSize: 10,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.1,
      ),
    );
  }
}
