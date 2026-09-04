import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../admin/admin_main_screen.dart';
import '../main/main_screen.dart';
import '../onboarding/flash_profile_flow.dart';
import '../staff/staff_console_screen.dart';
import 'auth_service.dart';
import 'password_reset_screen.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

enum _LoginStage { idle, signingIn }

class _LoginScreenState extends State<LoginScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  bool obscurePassword = true;
  _LoginStage _stage = _LoginStage.idle;

  bool get isLoading => _stage != _LoginStage.idle;

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
    setState(() => _stage = _LoginStage.signingIn);
    try {
      await AuthService.login(email: email, password: password);
      await _routeAuthenticatedUser();
    } on FirebaseAuthException catch (error) {
      _showMessage(_authErrorMessage(error));
    } catch (_) {
      _showMessage('Login failed. Please try again.');
    } finally {
      if (mounted) setState(() => _stage = _LoginStage.idle);
    }
  }

  Future<void> loginWithGoogle() async {
    if (isLoading) return;
    setState(() => _stage = _LoginStage.signingIn);
    try {
      final credential = await AuthService.loginWithGoogle();
      if (credential == null) {
        _showMessage('Google sign-in was cancelled.');
        return;
      }
      await _routeAuthenticatedUser();
    } on FirebaseAuthException catch (error) {
      _showMessage(_authErrorMessage(error));
    } catch (error) {
      _showMessage('Google sign-in failed — ${error.toString()}');
    } finally {
      if (mounted) setState(() => _stage = _LoginStage.idle);
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
    if (role == 'consultant' || role == 'staff') {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const StaffConsoleScreen()),
        (_) => false,
      );
      return;
    }
    final profile = await AuthService.getCurrentUserProfile();
    if (!mounted) return;
    final onboardingComplete = profile['onboardingComplete'] == true;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => onboardingComplete
            ? const MainScreen()
            : const FlashProfileFlow(),
      ),
      (_) => false,
    );
  }

  String _authErrorMessage(FirebaseAuthException error) {
    switch (error.code) {
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
      case 'google-id-token-missing':
        return 'Google did not return a valid sign-in token.';
      default:
        return error.message ?? 'Authentication failed.';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 760;
            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                wide ? 48 : 22,
                18,
                wide ? 48 : 22,
                30,
              ),
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
                gradient: const LinearGradient(
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
                      'A MORE\nCONFIDENT YOU.',
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
                      'Your colours. Your wardrobe.\nYour way of expressing yourself.',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12.5,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          'Colour shapes confidence.',
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
          'Welcome Back',
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w800,
            letterSpacing: -.7,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Continue your personal style journey.',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 24),
        _socialButton(
          'Continue with Google',
          Icons.g_mobiledata,
          loginWithGoogle,
        ),
        const SizedBox(height: 18),
        const Row(
          children: [
            Expanded(child: Divider()),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                'or sign in with email',
                style: TextStyle(color: AppColors.textMuted, fontSize: 10.5),
              ),
            ),
            Expanded(child: Divider()),
          ],
        ),
        const SizedBox(height: 20),
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
        const SizedBox(height: 15),
        _fieldLabel('PASSWORD'),
        const SizedBox(height: 7),
        TextField(
          controller: passwordController,
          obscureText: obscurePassword,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => login(),
          decoration: InputDecoration(
            hintText: 'Enter your password',
            prefixIcon: const Icon(Icons.lock_outline_rounded),
            suffixIcon: IconButton(
              onPressed: () =>
                  setState(() => obscurePassword = !obscurePassword),
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
            onPressed: isLoading
                ? null
                : () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PasswordResetScreen(
                          initialEmail: emailController.text.trim(),
                        ),
                      ),
                    ),
            child: const Text('Forgot Password?'),
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
                      MaterialPageRoute(
                        builder: (_) => const RegisterScreen(),
                      ),
                    ),
            child: const Text('New here? Create your style profile'),
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
