import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_gradients.dart';
import 'auth_service.dart';

class PasswordResetScreen extends StatefulWidget {
  const PasswordResetScreen({super.key, this.initialEmail = ''});

  final String initialEmail;

  @override
  State<PasswordResetScreen> createState() => _PasswordResetScreenState();
}

class _PasswordResetScreenState extends State<PasswordResetScreen> {
  late final TextEditingController emailController;
  bool isLoading = false;
  bool sent = false;

  @override
  void initState() {
    super.initState();
    emailController = TextEditingController(text: widget.initialEmail);
  }

  @override
  void dispose() {
    emailController.dispose();
    super.dispose();
  }

  Future<void> _sendResetEmail() async {
    final email = emailController.text.trim();
    if (email.isEmpty || !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      _message('Please enter a valid email address.');
      return;
    }

    setState(() => isLoading = true);
    try {
      await AuthService.resetPassword(email: email);
      if (mounted) setState(() => sent = true);
    } on FirebaseAuthException catch (e) {
      _message(_errorMessage(e));
    } catch (_) {
      _message('Unable to send the reset email. Please try again.');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  String _errorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'user-not-found':
        return 'No account was found with this email.';
      case 'too-many-requests':
        return 'Too many requests. Please try again later.';
      case 'network-request-failed':
        return 'Network error. Check your connection.';
      case 'operation-not-allowed':
        return 'Password reset is not enabled yet.';
      default:
        return e.message ?? 'Unable to send the reset email.';
    }
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text), behavior: SnackBarBehavior.floating));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(23, 25, 23, 25),
                decoration: BoxDecoration(
                  gradient: AppGradients.soft,
                  borderRadius: BorderRadius.circular(27),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      sent ? Icons.mark_email_read_outlined : Icons.lock_reset_rounded,
                      size: 30,
                      color: AppColors.primaryDark,
                    ),
                    const SizedBox(height: 18),
                    Text(
                      sent ? 'Check your inbox.' : 'Forgot your password?',
                      style: const TextStyle(fontSize: 27, fontWeight: FontWeight.w800, letterSpacing: -.6),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      sent
                          ? 'We sent a password reset link to ${emailController.text.trim()}. Open it to create a new password.'
                          : 'Enter the email connected to your TiB account and we’ll send you a secure reset link.',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5, height: 1.45),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 26),
              if (!sent) ...[
                const Text('EMAIL', style: TextStyle(fontSize: 9.5, letterSpacing: 1, fontWeight: FontWeight.w800, color: AppColors.textMuted)),
                const SizedBox(height: 7),
                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _sendResetEmail(),
                  decoration: const InputDecoration(
                    hintText: 'you@example.com',
                    prefixIcon: Icon(Icons.mail_outline_rounded),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: isLoading ? null : _sendResetEmail,
                    child: Text(isLoading ? 'Sending…' : 'Send Reset Link'),
                  ),
                ),
              ] else ...[
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: isLoading ? null : _sendResetEmail,
                    icon: const Icon(Icons.refresh_rounded),
                    label: Text(isLoading ? 'Sending…' : 'Resend Email'),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Back to Sign In'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
