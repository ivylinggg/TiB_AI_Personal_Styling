import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_colors.dart';
import '../admin/admin_main_screen.dart';
import '../auth/auth_service.dart';
import '../auth/login_screen.dart';
import '../main/main_screen.dart';
import '../onboarding/flash_profile_flow.dart';
import '../onboarding/onboarding_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  bool _hasRouted = false;

  late final AnimationController _controller;
  late final Animation<double> _vReveal;
  late final Animation<double> _yReveal;
  late final Animation<double> _eReveal;
  late final Animation<double> _aReveal;
  late final Animation<double> _taglineReveal;
  late final Animation<double> _subtitleReveal;
  late final Animation<double> _creditReveal;
  late final Animation<double> _lineReveal;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..forward();

    // V → Y → E → A: each letter enters separately from left to right.
    _vReveal = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.03, 0.25, curve: Curves.easeOutCubic),
    );
    _yReveal = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.16, 0.39, curve: Curves.easeOutCubic),
    );
    _eReveal = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.29, 0.52, curve: Curves.easeOutCubic),
    );
    _aReveal = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.42, 0.65, curve: Curves.easeOutCubic),
    );

    _taglineReveal = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.56, 0.77, curve: Curves.easeOutCubic),
    );
    _subtitleReveal = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.64, 0.83, curve: Curves.easeOutCubic),
    );
    _creditReveal = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.76, 0.93, curve: Curves.easeOutCubic),
    );
    _lineReveal = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.86, 1.0, curve: Curves.easeOutCubic),
    );

    Future<void>.delayed(
      const Duration(milliseconds: 3000),
      _routeFromSplash,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _routeFromSplash() async {
    if (!mounted || _hasRouted) return;

    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser != null) {
      try {
        final active = await AuthService.isCurrentUserActive();
        if (!active) {
          await AuthService.logout();
        } else {
          final role = await AuthService.getCurrentUserRole();
          if (!mounted || _hasRouted) return;

          if (role == 'admin') {
            _replace(const AdminMainScreen());
            return;
          }

          final profile = await AuthService.getCurrentUserProfile();
          if (!mounted || _hasRouted) return;

          final onboardingComplete = profile['onboardingComplete'] == true;
          _replace(
            onboardingComplete
                ? const MainScreen()
                : const FlashProfileFlow(),
          );
          return;
        }
      } catch (_) {
        if (!mounted || _hasRouted) return;
      }
    }

    final prefs = await SharedPreferences.getInstance();
    if (!mounted || _hasRouted) return;

    final hasSeenIntro = prefs.getBool('tib_intro_seen') ?? false;

    if (!hasSeenIntro) {
      await prefs.setBool('tib_intro_seen', true);
      if (!mounted || _hasRouted) return;
      _replace(const OnboardingScreen());
      return;
    }

    _replace(const LoginScreen());
  }

  void _replace(Widget destination) {
    if (!mounted || _hasRouted) return;
    _hasRouted = true;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => destination),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        fit: StackFit.expand,
        children: [
          _backgroundDecor(),
          SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    const Spacer(flex: 4),
                    _buildBrand(),
                    const SizedBox(height: 24),
                    FadeTransition(
                      opacity: _taglineReveal,
                      child: const Text(
                        'Visual · You · Expression · Aesthetic',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontFamily: 'serif',
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 2.25,
                        ),
                      ),
                    ),
                    const SizedBox(height: 48),
                    FadeTransition(
                      opacity: _subtitleReveal,
                      child: const Text(
                        'AI PERSONAL STYLING & COLOUR',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontFamily: 'serif',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 2.35,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    FadeTransition(
                      opacity: _subtitleReveal,
                      child: Text(
                        'Be your best you.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.brown,
                          fontFamily: 'serif',
                          fontSize: 17,
                          letterSpacing: 1.15,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                    const Spacer(flex: 2),
                    FadeTransition(
                      opacity: _creditReveal,
                      child: Text(
                        'Developed by TiB Consultancy',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.brown.withValues(alpha: .85),
                          fontFamily: 'serif',
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    FadeTransition(
                      opacity: _lineReveal,
                      child: Container(
                        width: 86,
                        height: 1.5,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.transparent,
                              AppColors.brown,
                              Colors.transparent,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Spacer(flex: 1),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBrand() {
    return SizedBox(
      height: 125,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _letter('V', _vReveal, fontSize: 102, width: 88),
          _letter('Y', _yReveal, fontSize: 94, width: 76),
          _letter('E', _eReveal, fontSize: 94, width: 78),
          _letter('A', _aReveal, fontSize: 94, width: 82),
        ],
      ),
    );
  }

  Widget _letter(
    String value,
    Animation<double> animation, {
    required double fontSize,
    required double width,
  }) {
    return SizedBox(
      width: width,
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, child) {
          final progress = animation.value;
          final slide = (1 - progress) * 34;

          return Opacity(
            opacity: progress,
            child: Transform.translate(
              offset: Offset(slide, (1 - progress) * 8),
              child: Transform.rotate(
                angle: -0.035,
                child: ShaderMask(
                  shaderCallback: (bounds) {
                    return LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        AppColors.brown,
                        AppColors.brown,
                        AppColors.brown.withValues(alpha: .78),
                      ],
                    ).createShader(bounds);
                  },
                  blendMode: BlendMode.srcIn,
                  child: Text(
                    value,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontFamily: 'serif',
                      fontSize: fontSize,
                      fontWeight: FontWeight.w700,
                      fontStyle: FontStyle.italic,
                      letterSpacing: -3.5,
                      height: .88,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _backgroundDecor() {
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned(
          top: -120,
          left: -100,
          child: _softShape(
            310,
            AppColors.brown.withValues(alpha: .34),
          ),
        ),
        Positioned(
          top: 40,
          left: -10,
          child: Transform.rotate(
            angle: -.22,
            child: Container(
              width: 460,
              height: 1.2,
              color: AppColors.brown.withValues(alpha: .5),
            ),
          ),
        ),
        Positioned(
          top: 260,
          left: -75,
          child: _softShape(
            170,
            AppColors.secondary.withValues(alpha: .30),
          ),
        ),
        Positioned(
          bottom: -175,
          right: -120,
          child: _softShape(
            350,
            AppColors.brown.withValues(alpha: .18),
          ),
        ),
        Positioned(
          bottom: -75,
          right: -35,
          child: Transform.rotate(
            angle: -.50,
            child: Container(
              width: 430,
              height: 1.2,
              color: AppColors.brown.withValues(alpha: .40),
            ),
          ),
        ),
        Positioned(
          bottom: -70,
          right: 100,
          child: _softShape(
            250,
            AppColors.secondary.withValues(alpha: .24),
          ),
        ),
      ],
    );
  }

  Widget _softShape(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }
}
