import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../widgets/primary_button.dart';
import '../admin/admin_main_screen.dart';
import '../main/main_screen.dart';
import 'auth_service.dart';

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

  // ============================================================
  // LOGIN + ROLE ROUTING
  // ============================================================

  Future<void> login() async {
    final email = emailController.text.trim();
    final password = passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter email and password.")),
      );
      return;
    }

    try {
      setState(() {
        isLoading = true;
      });

      // ----------------------------------------------------------
      // 1. Firebase Authentication
      // ----------------------------------------------------------

      await AuthService.login(email: email, password: password);

      // ----------------------------------------------------------
      // 2. Read role from Firestore
      // ----------------------------------------------------------

      final role = await AuthService.getCurrentUserRole();

      if (!mounted) return;

      // ----------------------------------------------------------
      // 3. Route based on role
      // ----------------------------------------------------------

      if (role == 'admin') {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const AdminMainScreen()),
          (route) => false,
        );

        return;
      }

      if (role == 'customer') {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const MainScreen()),
          (route) => false,
        );

        return;
      }

      // ----------------------------------------------------------
      // 4. Unknown role
      // ----------------------------------------------------------

      await AuthService.logout();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Your account has an unsupported role: $role')),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message ?? "Login failed.")));
    } on FirebaseException catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message ?? "Unable to load your account profile."),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Login failed: $e")));
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  // ============================================================
  // BUILD
  // ============================================================

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

              // ==================================================
              // LOGO
              // ==================================================
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

              // ==================================================
              // TITLE
              // ==================================================
              Text(
                "Welcome Back",
                style: Theme.of(context).textTheme.headlineMedium,
              ),

              const SizedBox(height: 8),

              Text(
                "Sign in to continue your AI styling journey.",
                style: Theme.of(context).textTheme.bodyMedium,
              ),

              const SizedBox(height: 36),

              // ==================================================
              // EMAIL
              // ==================================================
              TextField(
                controller: emailController,

                keyboardType: TextInputType.emailAddress,

                textInputAction: TextInputAction.next,

                decoration: const InputDecoration(
                  labelText: "Email",
                  hintText: "example@email.com",
                  prefixIcon: Icon(Icons.email_outlined),
                ),
              ),

              const SizedBox(height: 20),

              // ==================================================
              // PASSWORD
              // ==================================================
              TextField(
                controller: passwordController,

                obscureText: obscurePassword,

                textInputAction: TextInputAction.done,

                onSubmitted: (_) {
                  if (!isLoading) {
                    login();
                  }
                },

                decoration: InputDecoration(
                  labelText: "Password",

                  hintText: "Enter your password",

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

              const SizedBox(height: 12),

              // ==================================================
              // FORGOT PASSWORD
              // ==================================================
              Align(
                alignment: Alignment.centerRight,

                child: TextButton(
                  onPressed: _showForgotPasswordDialog,

                  child: const Text("Forgot Password?"),
                ),
              ),

              const SizedBox(height: 24),

              // ==================================================
              // LOGIN BUTTON
              // ==================================================
              PrimaryButton(
                text: isLoading ? "Signing In..." : "Login",

                icon: Icons.login,

                onPressed: () {
                  if (!isLoading) {
                    login();
                  }
                },
              ),

              const SizedBox(height: 24),

              const Row(
                children: [
                  Expanded(child: Divider()),

                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),

                    child: Text("OR"),
                  ),

                  Expanded(child: Divider()),
                ],
              ),

              const SizedBox(height: 24),

              // ==================================================
              // GOOGLE LOGIN
              // ==================================================
              OutlinedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Google Login will be connected next."),
                    ),
                  );
                },

                icon: const Icon(Icons.g_mobiledata),

                label: const Text("Continue with Google"),

                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 55),
                ),
              ),

              const SizedBox(height: 18),

              // ==================================================
              // REGISTER
              // ==================================================
              Row(
                mainAxisAlignment: MainAxisAlignment.center,

                children: [
                  const Text("Don't have an account?"),

                  TextButton(
                    onPressed: () {
                      // Keep your existing
                      // Register navigation here.
                    },

                    child: const Text("Register"),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // FORGOT PASSWORD
  // ============================================================

  Future<void> _showForgotPasswordDialog() async {
    final controller = TextEditingController(text: emailController.text.trim());

    final email = await showDialog<String>(
      context: context,

      builder: (dialogContext) {
        return AlertDialog(
          title: const Text("Reset Password"),

          content: TextField(
            controller: controller,

            keyboardType: TextInputType.emailAddress,

            decoration: const InputDecoration(
              labelText: "Email",
              hintText: "Enter your email",
            ),
          ),

          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },

              child: const Text("Cancel"),
            ),

            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext, controller.text.trim());
              },

              child: const Text("Send"),
            ),
          ],
        );
      },
    );

    controller.dispose();

    if (email == null || email.isEmpty) {
      return;
    }

    try {
      await AuthService.resetPassword(email: email);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Password reset email sent.")),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? "Unable to send reset email.")),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Unable to send reset email: $e")));
    }
  }
}
