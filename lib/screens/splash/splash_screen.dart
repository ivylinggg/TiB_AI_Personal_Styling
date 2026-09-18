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
  late final Animation<double> _brandV;
  late final Animation<double> _brandY;
  late final Animation<double> _brandE;
  late final Animation<double> _brandA;
  late final Animation<double> _taglineReveal;
  late final Animation<double> _subtitleReveal;
  late final Animation<double> _creditReveal;
  late final Animation<double> _lineReveal;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..forward();

    _brandV = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.04, 0.28, curve: Curves.easeOutCubic),
    );
    _brandY = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.14, 0.40, curve: Curves.easeOutCubic),
    );
    _brandE = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.24, 0.52, curve: Curves.easeOutCubic),
    );
    _brandA = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.34, 0.62, curve: Curves.easeOutCubic),
    );
    _taglineReveal = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.52, 0.76, curve: Curves.easeOutCubic),
    );
    _subtitleReveal = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.60, 0.82, curve: Curves.easeOutCubic),
    );
    _creditReveal = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.72, 0.94, curve: Curves.easeOutCubic),
    );
    _lineReveal = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.82, 1.0, curve: Curves.easeOutCubic),
    );

    Future<void>.delayed(
      const Duration(milliseconds: 2700),
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
    final size = MediaQuery.sizeOf(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        fit: StackFit.expand,
        children: [
          _backgroundDecor(size),
          SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  children: [
                    const Spacer(flex: 4),
                    _brandMark(),
                    const SizedBox(height: 22),
                    FadeTransition(
                      opacity: _taglineReveal,
                      child: const Text(
                        'Visual · You · Expression · Aesthetic',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontFamily: 'serif',
                          fontSize: 12.5,
                          letterSpacing: 2.2,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(height: 46),
                    FadeTransition(
                      opacity: _subtitleReveal,
                      child: const Text(
                        'AI PERSONAL STYLING & COLOUR',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontFamily: 'serif',
                          fontSize: 14,
                          letterSpacing: 2.15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    FadeTransition(
                      opacity: _subtitleReveal,
                      child: const Text(
                        'Be your best you.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.brown,
                          fontFamily: 'serif',
                          fontSize: 17,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                    const Spacer(flex: 2),
                    FadeTransition(
                      opacity: _creditReveal,
                      child: const Text(
                        'Developed by TiB Consultancy',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontFamily: 'serif',
                          fontSize: 11,
                          letterSpacing: 1.15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    FadeTransition(
                      opacity: _lineReveal,
                      child: Container(
                        width: 82,
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

  Widget _brandMark() {
    return SizedBox(
      height: 108,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _letter(
            'V',
            _brandV,
            fontSize: 92,
            xOffset: 18,
          ),
          const SizedBox(width: 2),
          _letter(
            'Y',
            _brandY,
            fontSize: 88,
            xOffset: 18,
          ),
          const SizedBox(width: 2),
          _letter(
            'E',
            _brandE,
            fontSize: 88,
            xOffset: 18,
          ),
          const SizedBox(width: 2),
          _letter(
            'A',
            _brandA,
            fontSize: 88,
            xOffset: 18,
          ),
        ],
      ),
    );
  }

  Widget _letter(
    String value,
    Animation<double> animation, {
    required double fontSize,
    required double xOffset,
  }) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final progress = animation.value;
        return Opacity(
          opacity: progress,
          child: Transform.translate(
            offset: Offset((1 - progress) * xOffset, (1 - progress) * 4),
            child: Transform.rotate(
              angle: -0.035,
              child: ShaderMask(
                shaderCallback: (bounds) {
                  return const LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Color(0xFF73562A),
                      Color(0xFFB28A45),
                      Color(0xFFE1C47B),
                      Color(0xFF9C7538),
                      Color(0xFF63481F),
                    ],
                  ).createShader(bounds);
                },
                blendMode: BlendMode.srcIn,
                child: Text(
                  value,
                  style: TextStyle(
                    color: Colors.white,
                    fontFamily: 'serif',
                    fontSize: fontSize,
                    fontWeight: FontWeight.w700,
                    fontStyle: FontStyle.italic,
                    letterSpacing: -4.5,
                    height: .9,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _backgroundDecor(Size size) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned(
          top: -110,
          left: -95,
          child: _shape(
            300,
            AppColors.peach.withValues(alpha: .22),
          ),
        ),
        Positioned(
          top: -25,
          left: -25,
          child: Transform.rotate(
            angle: -.25,
            child: Container(
              width: 390,
              height: 1,
              color: AppColors.brown.withValues(alpha: .18),
            ),
          ),
        ),
        Positioned(
          bottom: -140,
          right: -110,
          child: _shape(
            330,
            AppColors.primarySoft.withValues(alpha: .18),
          ),
        ),
        Positioned(
          bottom: -60,
          right: -30,
          child: Transform.rotate(
            angle: -.52,
            child: Container(
              width: 410,
              height: 1,
              color: AppColors.brown.withValues(alpha: .16),
            ),
          ),
        ),
        Positioned(
          top: size.height * .38,
          right: -130,
          child: _shape(
            210,
            AppColors.secondary.withValues(alpha: .10),
          ),
        ),
        Positioned(
          top: size.height * .33,
          left: -105,
          child: _shape(
            170,
            AppColors.peach.withValues(alpha: .08),
          ),
        ),
      ],
    );
  }

  Widget _shape(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: .20),
            blurRadius: 45,
            spreadRadius: 8,
          ),
        ],
      ),
    );
  }
}
