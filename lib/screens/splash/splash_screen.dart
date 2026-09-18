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
      const Duration(milliseconds: 4200),
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
                    const SizedBox(height: 18),
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
      height: 150,
      width: 430,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          Positioned(
            left: 24,
            bottom: 8,
            child: _letter('V', _vReveal, 116, 88, -0.035, 2),
          ),
          Positioned(
            left: 112,
            bottom: 0,
            child: _letter('y', _yReveal, 108, 78, -0.045, 0),
          ),
          Positioned(
            left: 187,
            bottom: 13,
            child: _letter('e', _eReveal, 108, 78, -0.045, 0),
          ),
          Positioned(
            left: 263,
            bottom: 11,
            child: _letter('a', _aReveal, 108, 82, -0.045, 0),
          ),
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
    double yBias,
  ) {
    return SizedBox(
      width: width,
      height: 140,
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, child) {
          final progress = Curves.easeOutCubic.transform(animation.value);
          return Opacity(
            opacity: progress,
            child: Transform.translate(
              offset: Offset((1 - progress) * 72, (1 - progress) * 18),
              child: Transform.rotate(
                angle: angle,
                child: Text(
                  value,
                  style: TextStyle(
                    color: AppColors.primary,
                    fontFamily: 'serif',
                    fontSize: fontSize,
                    fontWeight: FontWeight.w700,
                    fontStyle: FontStyle.italic,
                    letterSpacing: -6.5,
                    height: .80,
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

class _ReferenceCurvePainter extends CustomPainter {
  final Color color;
  final bool reverse;

  const _ReferenceCurvePainter({
    required this.color,
    this.reverse = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.35;

    final path = Path();

    if (!reverse) {
      path
        ..moveTo(size.width * .02, size.height * .97)
        ..cubicTo(
          size.width * .16,
          size.height * .62,
          size.width * .50,
          size.height * .70,
          size.width * .78,
          size.height * .18,
        )
        ..cubicTo(
          size.width * .86,
          size.height * .04,
          size.width * .93,
          size.height * .02,
          size.width * .98,
          0,
        );
    } else {
      path
        ..moveTo(size.width * .02, 0)
        ..cubicTo(
          size.width * .18,
          size.height * .48,
          size.width * .52,
          size.height * .50,
          size.width * .84,
          size.height * .03,
        )
        ..cubicTo(
          size.width * .91,
          -size.height * .05,
          size.width * .96,
          -size.height * .10,
          size.width,
          -size.height * .13,
        );
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _ReferenceCurvePainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.reverse != reverse;
}
