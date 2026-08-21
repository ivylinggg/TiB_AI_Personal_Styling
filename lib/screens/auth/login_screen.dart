import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_gradients.dart';
import '../admin/admin_main_screen.dart';
import '../main/main_screen.dart';
import '../onboarding/flash_profile_flow.dart';
import 'auth_service.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  bool obscurePassword = true;
  bool isLoading = false;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> login() async {
    final email = emailController.text.trim();
    final password = passwordController.text;
    if (email.isEmpty || password.isEmpty) {
      _showMessage('Please enter your email and password.');
      return;
    }
    setState(() => isLoading = true);
    try {
      await AuthService.login(email: email, password: password);
      await _routeAuthenticatedUser();
    } on FirebaseAuthException catch (e) {
      _showMessage(_authErrorMessage(e));
    } catch (_) {
      _showMessage('Login failed. Please try again.');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> loginWithGoogle() async {
    if (isLoading) return;
    setState(() => isLoading = true);
    try {
      final credential = await AuthService.loginWithGoogle();
      if (credential == null) {
        _showMessage('Google sign-in was cancelled.');
        return;
      }
      await _routeAuthenticatedUser();
    } on FirebaseAuthException catch (e) {
      _showMessage(_authErrorMessage(e));
    } catch (_) {
      _showMessage('Google sign-in failed. Please try again.');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> loginWithApple() async {
    if (isLoading) return;
    setState(() => isLoading = true);
    try {
      final credential = await AuthService.loginWithApple();
      if (credential == null) {
        _showMessage('Apple sign-in was cancelled.');
        return;
      }
      await _routeAuthenticatedUser();
    } on FirebaseAuthException catch (e) {
      _showMessage(_authErrorMessage(e));
    } catch (_) {
      _showMessage('Apple sign-in failed. Please try again.');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _routeAuthenticatedUser() async {
    final active = await AuthService.isCurrentUserActive();
    if (!active) {
      await AuthService.logout();
      _showMessage('Your account is currently inactive.');
      return;
    }

    final role = await AuthService.getCurrentUserRole();
    if (!mounted) return;

    if (role == 'admin') {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const AdminMainScreen()),
        (_) => false,
      );
      return;
    }

    final profile = await AuthService.getCurrentUserProfile();
    if (!mounted) return;

    final onboardingComplete = profile['onboardingComplete'] == true;

    final Widget destination = onboardingComplete
        ? const MainScreen()
        : const FlashProfileFlow();

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => destination),
      (_) => false,
    );
  }

  String _authErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect email or password.';
      case 'user-not-found':
        return 'No account was found with this email.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'network-request-failed':
        return 'Network error. Check your connection.';
      case 'operation-not-allowed':
        return 'This sign-in method is not enabled yet.';
      case 'account-exists-with-different-credential':
        return 'An account already exists with a different sign-in method.';
      default:
        return e.message ?? 'Authentication failed.';
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
  }

  Future<void> _forgotPassword() async {
    final controller = TextEditingController(text: emailController.text.trim());
    final email = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reset your password'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(labelText: 'Email address'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('Send email'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (email == null || email.isEmpty) return;
    try {
      await AuthService.resetPassword(email: email);
      _showMessage('Password reset email sent. Check your inbox.');
    } catch (_) {
      _showMessage('Unable to send the reset email.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(onPressed: () {}, child: const Text('About TiB')),
              ),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(24, 26, 24, 25),
                decoration: BoxDecoration(
                  gradient: AppGradients.blush,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .82),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.auto_awesome_rounded,
                        color: AppColors.primaryDark,
                        size: 25,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'TiB',
                      style: TextStyle(
                        fontSize: 42,
                        fontWeight: FontWeight.w300,
                        letterSpacing: -2,
                      ),
                    ),
                    const SizedBox(height: 5),
                    const Text(
                      'Your personal style,\nmade simple.',
                      style: TextStyle(
                        fontSize: 24,
                        height: 1.08,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -.6,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Colours, clothes and AI styling that feel like you.',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12.5,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              const Text(
                'Welcome back',
                style: TextStyle(
                  fontSize: 27,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -.5,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Let’s continue your personal style journey.',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 21),
              _socialButton('Continue with Google', Icons.g_mobiledata, loginWithGoogle),
              const SizedBox(height: 9),
              _socialButton('Continue with Apple', Icons.apple, loginWithApple),
              const SizedBox(height: 20),
              const Row(
                children: [
                  Expanded(child: Divider()),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      'or email',
                      style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                    ),
                  ),
                  Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: 20),
              const Text('Email', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
              const SizedBox(height: 7),
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(hintText: 'you@example.com'),
              ),
              const SizedBox(height: 15),
              const Text('Password', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
              const SizedBox(height: 7),
              TextField(
                controller: passwordController,
                obscureText: obscurePassword,
                onSubmitted: (_) => login(),
                decoration: InputDecoration(
                  hintText: 'Enter your password',
                  suffixIcon: IconButton(
                    onPressed: () => setState(() => obscurePassword = !obscurePassword),
                    icon: Icon(
                      obscurePassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                    ),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: isLoading ? null : _forgotPassword,
                  child: const Text('Forgot password?'),
                ),
              ),
              const SizedBox(height: 3),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isLoading ? null : login,
                  child: Text(isLoading ? 'Signing in…' : 'Sign In'),
                ),
              ),
              const SizedBox(height: 18),
              Center(
                child: TextButton(
                  onPressed: isLoading
                      ? null
                      : () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const RegisterScreen()),
                          ),
                  child: const Text('New here? Create your style profile'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _socialButton(String label, IconData icon, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: isLoading ? null : onTap,
        icon: Icon(icon, size: 21),
        label: Text(label),
      ),
    );
  }
}
