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
      width: 360,
      height: 150,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          _letter('V', _vReveal, 116, 94, 0, -0.02),
          _letter('y', _yReveal, 108, 82, 82, -0.04),
          _letter('e', _eReveal, 108, 82, 152, -0.04),
          _letter('a', _aReveal, 108, 86, 218, -0.04),
        ],
      ),
    );
  }

  Widget _letter(
    String value,
    Animation<double> animation,
    double fontSize,
    double width,
    double left,
    double rotation,
  ) {
    return Positioned(
      left: left,
      bottom: 0,
      child: SizedBox(
        width: width,
        height: 150,
        child: AnimatedBuilder(
          animation: animation,
          builder: (context, child) {
            final progress = Curves.easeOutCubic.transform(animation.value);
            return Opacity(
              opacity: progress,
              child: Transform.translate(
                offset: Offset((1 - progress) * 34, (1 - progress) * 9),
                child: Transform.rotate(
                  angle: rotation,
                  child: Text(
                    value,
                    style: TextStyle(
                      color: AppColors.primary,
                      fontFamily: 'serif',
                      fontSize: fontSize,
                      fontWeight: FontWeight.w700,
                      fontStyle: FontStyle.italic,
                      letterSpacing: -6.2,
                      height: .80,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _backgroundDecor() {
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned(
          top: -125,
          left: -130,
          child: _referenceBlob(
            width: 500,
            height: 465,
            color: AppColors.brown.withValues(alpha: .72),
            topLeft: true,
          ),
        ),
        Positioned(
          top: -5,
          left: -8,
          child: SizedBox(
            width: 515,
            height: 405,
            child: CustomPaint(
              painter: _ReferenceTopCurvePainter(
                color: AppColors.brown.withValues(alpha: .48),
              ),
            ),
          ),
        ),
        Positioned(
          left: -120,
          top: 560,
          child: _softShape(
            180,
            AppColors.secondary.withValues(alpha: .22),
          ),
        ),
        Positioned(
          bottom: -185,
          right: -145,
          child: _referenceBlob(
            width: 555,
            height: 455,
            color: AppColors.brown.withValues(alpha: .50),
            topLeft: false,
          ),
        ),
        Positioned(
          bottom: -70,
          right: -5,
          child: SizedBox(
            width: 500,
            height: 375,
            child: CustomPaint(
              painter: _ReferenceBottomCurvePainter(
                color: AppColors.brown.withValues(alpha: .50),
              ),
            ),
          ),
        ),
        Positioned(
          bottom: -75,
          right: 145,
          child: _softShape(
            250,
            AppColors.secondary.withValues(alpha: .26),
          ),
        ),
      ],
    );
  }

  Widget _referenceBlob({
    required double width,
    required double height,
    required Color color,
    required bool topLeft,
  }) {
    return ClipPath(
      clipper: _ReferenceBlobClipper(topLeft: topLeft),
      child: SizedBox(
        width: width,
        height: height,
        child: ColoredBox(color: color),
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

class _ReferenceBlobClipper extends CustomClipper<Path> {
  final bool topLeft;

  const _ReferenceBlobClipper({required this.topLeft});

  @override
  Path getClip(Size size) {
    final path = Path();

    if (topLeft) {
      path
        ..moveTo(0, 0)
        ..lineTo(size.width * .80, 0)
        ..cubicTo(
          size.width * .70,
          size.height * .08,
          size.width * .56,
          size.height * .17,
          size.width * .46,
          size.height * .34,
        )
        ..cubicTo(
          size.width * .35,
          size.height * .53,
          size.width * .30,
          size.height * .75,
          size.width * .03,
          size.height * .93,
        )
        ..lineTo(0, size.height)
        ..close();
    } else {
      path
        ..moveTo(size.width, size.height)
        ..lineTo(size.width * .13, size.height)
        ..cubicTo(
          size.width * .25,
          size.height * .82,
          size.width * .37,
          size.height * .68,
          size.width * .50,
          size.height * .47,
        )
        ..cubicTo(
          size.width * .62,
          size.height * .28,
          size.width * .77,
          size.height * .10,
          size.width,
          size.height * .01,
        )
        ..close();
    }

    return path;
  }

  @override
  bool shouldReclip(covariant _ReferenceBlobClipper oldClipper) =>
      oldClipper.topLeft != topLeft;
}

class _ReferenceTopCurvePainter extends CustomPainter {
  final Color color;

  const _ReferenceTopCurvePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.35;

    final path = Path()
      ..moveTo(size.width * .02, size.height * .98)
      ..cubicTo(
        size.width * .18,
        size.height * .58,
        size.width * .55,
        size.height * .68,
        size.width * .73,
        size.height * .15,
      )
      ..cubicTo(
        size.width * .80,
        size.height * -.04,
        size.width * .89,
        size.height * -.08,
        size.width,
        -size.height * .13,
      );

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _ReferenceTopCurvePainter oldDelegate) =>
      oldDelegate.color != color;
}

class _ReferenceBottomCurvePainter extends CustomPainter {
  final Color color;

  const _ReferenceBottomCurvePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.35;

    final path = Path()
      ..moveTo(size.width * .02, size.height)
      ..cubicTo(
        size.width * .10,
        size.height * .54,
        size.width * .42,
        size.height * .59,
        size.width * .70,
        size.height * .17,
      )
      ..cubicTo(
        size.width * .82,
        size.height * .01,
        size.width * .92,
        -size.height * .04,
        size.width,
        -size.height * .13,
      );

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _ReferenceBottomCurvePainter oldDelegate) =>
      oldDelegate.color != color;
}
