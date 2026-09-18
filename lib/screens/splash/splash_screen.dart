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
      duration: const Duration(milliseconds: 3400),
    )..forward();

    // V → Y → E → A: each letter enters separately from left to right.
    _vReveal = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.03, 0.24, curve: Curves.easeOutCubic),
    );
    _yReveal = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.18, 0.39, curve: Curves.easeOutCubic),
    );
    _eReveal = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.34, 0.55, curve: Curves.easeOutCubic),
    );
    _aReveal = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.50, 0.71, curve: Curves.easeOutCubic),
    );

    _taglineReveal = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.68, 0.82, curve: Curves.easeOutCubic),
    );
    _subtitleReveal = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.73, 0.87, curve: Curves.easeOutCubic),
    );
    _creditReveal = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.80, 0.94, curve: Curves.easeOutCubic),
    );
    _lineReveal = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.90, 1.0, curve: Curves.easeOutCubic),
    );

    Future<void>.delayed(
      const Duration(milliseconds: 3900),
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
      height: 138,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _letter('V', _vReveal, 104, 76, -0.025),
          _letter('y', _yReveal, 98, 64, -0.035),
          _letter('e', _eReveal, 98, 65, -0.035),
          _letter('a', _aReveal, 98, 70, -0.035),
        ],
      ),
    );
  }

  Widget _letter(
    String value,
    Animation<double> animation,
    double fontSize,
    double width,
    double angle,
  ) {
    return SizedBox(
      width: width,
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, child) {
          final progress = animation.value;
          final curve = Curves.easeOutCubic.transform(progress);
          return Opacity(
            opacity: curve,
            child: Transform.translate(
              offset: Offset((1 - curve) * 46, (1 - curve) * 10),
              child: Transform.rotate(
                angle: angle,
                child: Text(
                  value,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.primary,
                    fontFamily: 'serif',
                    fontSize: fontSize,
                    fontWeight: FontWeight.w900,
                    fontStyle: FontStyle.italic,
                    letterSpacing: -5.8,
                    height: .78,
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
          top: -130,
          left: -155,
          child: Transform.rotate(
            angle: -.22,
            child: _cornerShape(
              width: 505,
              height: 440,
              color: AppColors.brown.withValues(alpha: .72),
            ),
          ),
        ),
        Positioned(
          top: 15,
          left: -15,
          child: Transform.rotate(
            angle: -.22,
            child: CustomPaint(
              size: const Size(470, 130),
              painter: _CurveLinePainter(
                color: AppColors.brown.withValues(alpha: .55),
              ),
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
          bottom: -180,
          right: -175,
          child: Transform.rotate(
            angle: .04,
            child: _cornerShape(
              width: 520,
              height: 410,
              color: AppColors.brown.withValues(alpha: .50),
            ),
          ),
        ),
        Positioned(
          bottom: -45,
          right: -10,
          child: Transform.rotate(
            angle: -.50,
            child: CustomPaint(
              size: const Size(450, 180),
              painter: _CurveLinePainter(
                color: AppColors.brown.withValues(alpha: .50),
              ),
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

  Widget _cornerShape({
    required double width,
    required double height,
    required Color color,
  }) {
    return ClipPath(
      clipper: _OrganicCornerClipper(),
      child: Container(
        width: width,
        height: height,
        color: color,
      ),
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

class _OrganicCornerClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width * .78, 0)
      ..cubicTo(
        size.width * .70,
        size.height * .10,
        size.width * .58,
        size.height * .18,
        size.width * .48,
        size.height * .34,
      )
      ..cubicTo(
        size.width * .36,
        size.height * .55,
        size.width * .31,
        size.height * .76,
        size.width * .06,
        size.height,
      )
      ..lineTo(0, size.height)
      ..close();
    return path;
  }

  @override
  bool shouldReclip(covariant _OrganicCornerClipper oldClipper) => false;
}

class _CurveLinePainter extends CustomPainter {
  final Color color;

  const _CurveLinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.35;

    final path = Path()
      ..moveTo(size.width * .12, size.height * .96)
      ..cubicTo(
        size.width * .22,
        size.height * .53,
        size.width * .64,
        size.height * .60,
        size.width * .88,
        size.height * .06,
      );

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _CurveLinePainter oldDelegate) =>
      oldDelegate.color != color;
}
