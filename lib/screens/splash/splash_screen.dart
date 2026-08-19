import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_gradients.dart';
import '../onboarding/onboarding_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Timer(const Duration(milliseconds: 2200), () {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const OnboardingScreen()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          Positioned(
            top: -100,
            right: -80,
            child: _glow(230, AppColors.peach.withValues(alpha: .25)),
          ),
          Positioned(
            bottom: -100,
            left: -80,
            child: _glow(300, AppColors.primary.withValues(alpha: .22)),
          ),
          SafeArea(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 150,
                    height: 150,
                    decoration: BoxDecoration(
                      gradient: AppGradients.blush,
                      borderRadius: BorderRadius.circular(46),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: .12),
                          blurRadius: 40,
                          offset: const Offset(0, 18),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Text(
                        'TiB',
                        style: TextStyle(
                          color: AppColors.charcoal,
                          fontSize: 52,
                          fontWeight: FontWeight.w300,
                          letterSpacing: -2,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  const Text(
                    'AI PERSONAL STYLING & COLOUR',
                    style: TextStyle(
                      fontSize: 11,
                      letterSpacing: 2.2,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Be your best you.',
                    style: TextStyle(
                      color: AppColors.brown.withValues(alpha: .75),
                      fontSize: 17,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: 70),
                  Container(
                    width: 42,
                    height: 2,
                    decoration: BoxDecoration(
                      color: AppColors.charcoal,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _glow(double size, Color color) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );
}
