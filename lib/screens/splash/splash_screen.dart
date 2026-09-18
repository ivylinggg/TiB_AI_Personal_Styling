import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    with TickerProviderStateMixin {
  bool _hasRouted = false;

  late final AnimationController _animationController;
  late final AnimationController _footerController;

  late final Animation<double> _logoFade;
  late final Animation<double> _logoScale;
  late final Animation<Offset> _logoSlide;
  late final Animation<double> _contentFade;
  late final Animation<Offset> _contentSlide;
  late final Animation<double> _footerFade;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1700),
    );

    _footerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _logoFade = CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.08, 0.50, curve: Curves.easeOut),
    );

    _logoScale = Tween<double>(
      begin: 0.95,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.58, curve: Curves.easeOutCubic),
      ),
    );

    _logoSlide = Tween<Offset>(
      begin: const Offset(0, 0.03),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.04, 0.58, curve: Curves.easeOutCubic),
      ),
    );

    _contentFade = CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.35, 0.82, curve: Curves.easeOut),
    );

    _contentSlide = Tween<Offset>(
      begin: const Offset(0, 0.04),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.32, 0.85, curve: Curves.easeOutCubic),
      ),
    );

    _footerFade = CurvedAnimation(
      parent: _footerController,
      curve: Curves.easeOut,
    );

    _animationController.forward();

    Future<void>.delayed(
      const Duration(milliseconds: 750),
      _footerController.forward,
    );

    Future<void>.delayed(
      const Duration(milliseconds: 3000),
      _routeFromSplash,
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _footerController.dispose();
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

          final onboardingComplete =
              profile['onboardingComplete'] == true;

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
      backgroundColor: const Color(0xFFF7F3EC),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const _TopOrganicDecoration(),
          const _BottomOrganicDecoration(),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final h = constraints.maxHeight;

                return Stack(
                  children: [
                    Align(
                      alignment: const Alignment(0, -0.03),
                      child: AnimatedBuilder(
                        animation: _animationController,
                        builder: (context, _) {
                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SlideTransition(
                                position: _logoSlide,
                                child: FadeTransition(
                                  opacity: _logoFade,
                                  child: ScaleTransition(
                                    scale: _logoScale,
                                    child: Column(
                                      children: [
                                        const Text(
                                          'Vyea',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontFamily: 'serif',
                                            fontSize: 74,
                                            fontWeight: FontWeight.w400,
                                            fontStyle: FontStyle.italic,
                                            color: Color(0xFF0F0E0D),
                                            letterSpacing: -2.5,
                                            height: 0.9,
                                          ),
                                        ),
                                        const SizedBox(height: 20),
                                        const Text(
                                          'Visual · You · Expression · Aesthetic',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontFamily: 'serif',
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w400,
                                            color: Color(0xFF1A1714),
                                            letterSpacing: 2.05,
                                            height: 1.1,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 78),
                              SlideTransition(
                                position: _contentSlide,
                                child: FadeTransition(
                                  opacity: _contentFade,
                                  child: const Column(
                                    children: [
                                      Text(
                                        'AI PERSONAL STYLING & COLOUR',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontFamily: 'serif',
                                          fontSize: 15,
                                          fontWeight: FontWeight.w500,
                                          color: Color(0xFF151210),
                                          letterSpacing: 2.45,
                                          height: 1.1,
                                        ),
                                      ),
                                      SizedBox(height: 49),
                                      Text(
                                        'Be your best you',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontFamily: 'serif',
                                          fontSize: 19.5,
                                          fontWeight: FontWeight.w400,
                                          color: Color(0xFF191511),
                                          letterSpacing: 1.5,
                                          height: 1.1,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: h * 0.185,
                      child: FadeTransition(
                        opacity: _footerFade,
                        child: const Text(
                          'Developed by TiB Consultancy',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'serif',
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                            color: Color(0xFF201B17),
                            letterSpacing: 0.65,
                            height: 1.1,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _TopOrganicDecoration extends StatelessWidget {
  const _TopOrganicDecoration();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: 430,
          height: 430,
          child: CustomPaint(
            painter: _TopOrganicPainter(),
          ),
        ),
      ),
    );
  }
}

class _BottomOrganicDecoration extends StatelessWidget {
  const _BottomOrganicDecoration();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Align(
        alignment: Alignment.bottomRight,
        child: SizedBox(
          width: 440,
          height: 400,
          child: CustomPaint(
            painter: _BottomOrganicPainter(),
          ),
        ),
      ),
    );
  }
}

class _TopOrganicPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()..color = const Color(0xFFAE9178);

    final organic = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..cubicTo(
        size.width * 0.77,
        size.height * 0.03,
        size.width * 0.61,
        size.height * 0.11,
        size.width * 0.50,
        size.height * 0.25,
      )
      ..cubicTo(
        size.width * 0.39,
        size.height * 0.39,
        size.width * 0.42,
        size.height * 0.56,
        size.width * 0.25,
        size.height * 0.72,
      )
      ..cubicTo(
        size.width * 0.16,
        size.height * 0.81,
        size.width * 0.07,
        size.height * 0.87,
        0,
        size.height * 0.90,
      )
      ..close();

    canvas.drawPath(organic, fill);

    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = const Color(0xFFD7C8B8);

    final curve = Path()
      ..moveTo(size.width * 0.97, -10)
      ..cubicTo(
        size.width * 0.86,
        size.height * 0.16,
        size.width * 0.72,
        size.height * 0.39,
        size.width * 0.43,
        size.height * 0.50,
      )
      ..cubicTo(
        size.width * 0.20,
        size.height * 0.58,
        size.width * 0.05,
        size.height * 0.64,
        -12,
        size.height * 0.81,
      );

    canvas.drawPath(curve, line);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _BottomOrganicPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final dark = Paint()..color = const Color(0xFFAE9178);
    final light = Paint()..color = const Color(0xFFE8DFD4);

    final lightShape = Path()
      ..moveTo(0, size.height)
      ..cubicTo(
        size.width * 0.04,
        size.height * 0.76,
        size.width * 0.17,
        size.height * 0.60,
        size.width * 0.35,
        size.height * 0.51,
      )
      ..cubicTo(
        size.width * 0.57,
        size.height * 0.41,
        size.width * 0.76,
        size.height * 0.32,
        size.width,
        size.height * 0.28,
      )
      ..lineTo(size.width, size.height)
      ..close();

    canvas.drawPath(lightShape, light);

    final darkShape = Path()
      ..moveTo(size.width * 0.22, size.height)
      ..cubicTo(
        size.width * 0.22,
        size.height * 0.82,
        size.width * 0.39,
        size.height * 0.69,
        size.width * 0.55,
        size.height * 0.63,
      )
      ..cubicTo(
        size.width * 0.72,
        size.height * 0.57,
        size.width * 0.84,
        size.height * 0.49,
        size.width,
        size.height * 0.41,
      )
      ..lineTo(size.width, size.height)
      ..close();

    canvas.drawPath(darkShape, dark);

    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = const Color(0xFFCDBAA7);

    final curve = Path()
      ..moveTo(size.width * 0.51, size.height + 5)
      ..cubicTo(
        size.width * 0.48,
        size.height * 0.75,
        size.width * 0.53,
        size.height * 0.53,
        size.width * 0.72,
        size.height * 0.40,
      )
      ..cubicTo(
        size.width * 0.83,
        size.height * 0.32,
        size.width * 0.93,
        size.height * 0.28,
        size.width * 1.02,
        size.height * 0.24,
      );

    canvas.drawPath(curve, line);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
