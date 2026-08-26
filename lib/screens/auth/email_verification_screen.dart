import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_gradients.dart';
import '../admin/admin_main_screen.dart';
import '../main/main_screen.dart';
import '../onboarding/flash_profile_flow.dart';
import 'auth_service.dart';

class EmailVerificationScreen extends StatefulWidget {
  const EmailVerificationScreen({super.key});

  @override
  State<EmailVerificationScreen> createState() => _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  bool isLoading = false;
  bool isSending = false;

  String get email => AuthService.currentUser?.email ?? '';

  Future<void> _checkVerification() async {
    if (isLoading) return;
    setState(() => isLoading = true);
    try {
      final verified = await AuthService.reloadAndCheckEmailVerified();
      if (!mounted) return;
      if (!verified) {
        _message('Your email is not verified yet. Open the link in your inbox and try again.');
        return;
      }

      final profile = await AuthService.getCurrentUserProfile();
      if (!mounted) return;

      final role = await AuthService.getCurrentUserRole();
      if (!mounted) return;

      final onboardingComplete = profile['onboardingComplete'] == true;
      final Widget destination;

      if (role == 'admin') {
        destination = const AdminMainScreen();
      } else if (onboardingComplete) {
        destination = const MainScreen();
      } else {
        destination = const FlashProfileFlow();
      }

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => destination),
        (_) => false,
      );
    } on FirebaseAuthException catch (e) {
      _message(e.message ?? 'Could not check your verification status.');
    } catch (_) {
      _message('Could not check verification status. Please try again.');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _resend() async {
    if (isSending) return;
    setState(() => isSending = true);
    try {
      await AuthService.sendEmailVerification();
      _message('Verification email sent. Check your inbox and spam folder.');
    } on FirebaseAuthException catch (e) {
      if (e.code == 'too-many-requests') {
        _message('Please wait a little before requesting another email.');
      } else {
        _message(e.message ?? 'Could not send the verification email.');
      }
    } catch (_) {
      _message('Could not send the verification email.');
    } finally {
      if (mounted) setState(() => isSending = false);
    }
  }

  Future<void> _signOut() async {
    await AuthService.logout();
    if (!mounted) return;
    Navigator.popUntil(context, (route) => route.isFirst);
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
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(24, 27, 24, 27),
                decoration: BoxDecoration(gradient: AppGradients.soft, borderRadius: BorderRadius.circular(28)),
                child: Column(
                  children: [
                    Container(
                      width: 68,
                      height: 68,
                      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                      child: const Icon(Icons.mark_email_unread_outlined, size: 31, color: AppColors.primaryDark),
                    ),
                    const SizedBox(height: 22),
                    const Text('Verify your email', textAlign: TextAlign.center, style: TextStyle(fontSize: 27, fontWeight: FontWeight.w800, letterSpacing: -.6)),
                    const SizedBox(height: 9),
                    Text('We sent a verification link to\n$email', textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.45)),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              const Text('Open the email, tap the verification link, then come back here and press “I’ve Verified”.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5, height: 1.45)),
              const Spacer(),
              SizedBox(width: double.infinity, child: ElevatedButton(onPressed: isLoading ? null : _checkVerification, child: Text(isLoading ? 'Checking…' : 'I’ve Verified'))),
              const SizedBox(height: 10),
              SizedBox(width: double.infinity, child: OutlinedButton.icon(onPressed: isSending ? null : _resend, icon: const Icon(Icons.mail_outline_rounded), label: Text(isSending ? 'Sending…' : 'Resend Verification Email'))),
              const SizedBox(height: 8),
              Center(child: TextButton(onPressed: _signOut, child: const Text('Use a different account'))),
            ],
          ),
        ),
      ),
    );
  }
}
