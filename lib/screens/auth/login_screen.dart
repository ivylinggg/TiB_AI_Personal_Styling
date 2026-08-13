import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../widgets/primary_button.dart';
import '../admin/admin_main_screen.dart';
import '../main/main_screen.dart';
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
      _showMessage('Please enter email and password.');
      return;
    }

    try {
      setState(() {
        isLoading = true;
      });

      await AuthService.login(
        email: email,
        password: password,
      );

      // Check the Firestore account status before routing.
      final isActive = await AuthService.isCurrentUserActive();

      if (!isActive) {
        await AuthService.logout();

        if (!mounted) return;

        _showMessage(
          'Your account is currently inactive. Please contact the administrator.',
        );
        return;
      }

      final role = await AuthService.getCurrentUserRole();

      if (!mounted) return;

      if (role == 'admin') {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) => const AdminMainScreen(),
          ),
          (route) => false,
        );
        return;
      }

      if (role == 'customer') {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) => const MainScreen(),
          ),
          (route) => false,
        );
        return;
      }

      await AuthService.logout();

      if (!mounted) return;

      _showMessage(
        'Your account has an unsupported role: $role',
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      _showMessage(
        _authErrorMessage(e),
      );
    } on FirebaseException catch (e) {
      if (!mounted) return;

      _showMessage(
        e.message ?? 'Unable to load your account profile.',
      );
    } catch (e) {
      if (!mounted) return;

      _showMessage(
        'Login failed. Please try again.',
      );
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  String _authErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect email or password.';
      case 'user-disabled':
        return 'This Firebase account has been disabled.';
      case 'too-many-requests':
        return 'Too many login attempts. Please try again later.';
      case 'network-request-failed':
        return 'Network error. Please check your internet connection.';
      case 'no-current-user':
        return 'No authenticated user was found.';
      default:
        return e.message ?? 'Login failed.';
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message)),
      );
  }

  Future<void> _showForgotPasswordDialog() async {
    final controller = TextEditingController(
      text: emailController.text.trim(),
    );

    final email = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Reset Password'),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Email',
              hintText: 'Enter your email',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  controller.text.trim(),
                );
              },
              child: const Text('Send'),
            ),
          ],
        );
      },
    );

    controller.dispose();

    if (email == null || email.isEmpty) return;

    try {
      await AuthService.resetPassword(email: email);

      if (!mounted) return;

      _showMessage(
        'Password reset email sent. Please check your inbox.',
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      _showMessage(_authErrorMessage(e));
    } catch (e) {
      if (!mounted) return;

      _showMessage(
        'Unable to send the password reset email.',
      );
    }
  }

  void _openRegister() {
    if (isLoading) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const RegisterScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 60),

              Center(
                child: Container(
                  width: 95,
                  height: 95,
                  decoration: const BoxDecoration(
                    color: Color(0xFFC58F73),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.auto_awesome,
                    color: Colors.white,
                    size: 45,
                  ),
                ),
              ),

              const SizedBox(height: 32),

              Text(
                'Welcome Back',
                style: Theme.of(context).textTheme.headlineMedium,
              ),

              const SizedBox(height: 8),

              Text(
                'Sign in to continue your AI styling journey.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),

              const SizedBox(height: 36),

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

              TextField(
                controller: passwordController,
                obscureText: obscurePassword,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) {
                  if (!isLoading) login();
                },
                decoration: InputDecoration(
                  labelText: 'Password',
                  hintText: 'Enter your password',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    onPressed: () {
                      setState(() {
                        obscurePassword = !obscurePassword;
                      });
                    },
                    icon: Icon(
                      obscurePassword
                          ? Icons.visibility_off
                          : Icons.visibility,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: isLoading
                      ? null
                      : _showForgotPasswordDialog,
                  child: const Text('Forgot Password?'),
                ),
              ),

              const SizedBox(height: 24),

              PrimaryButton(
                text: isLoading ? 'Signing In...' : 'Login',
                icon: Icons.login,
                onPressed: isLoading ? null : login,
              ),

              const SizedBox(height: 24),

              const Row(
                children: [
                  Expanded(child: Divider()),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Text('OR'),
                  ),
                  Expanded(child: Divider()),
                ],
              ),

              const SizedBox(height: 24),

              OutlinedButton.icon(
                onPressed: isLoading
                    ? null
                    : () {
                        _showMessage(
                          'Google Login is not connected yet.',
                        );
                      },
                icon: const Icon(Icons.g_mobiledata),
                label: const Text('Continue with Google'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 55),
                ),
              ),

              const SizedBox(height: 18),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Don't have an account?"),
                  TextButton(
                    onPressed: isLoading ? null : _openRegister,
                    child: const Text('Register'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
