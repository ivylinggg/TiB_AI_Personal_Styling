import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../auth/login_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _page = 0;

  static const _pages = [
    _OnboardingData(
      eyebrow: 'COLOUR • STYLE • YOU',
      title: 'Discover the colours\nthat feel like you.',
      subtitle: 'Find your personal palette with a guided AI colour analysis.',
      icon: Icons.palette_outlined,
    ),
    _OnboardingData(
      eyebrow: 'YOUR EVERYDAY STYLIST',
      title: 'Get dressed\nwithout the guesswork.',
      subtitle: 'Turn your colours, wardrobe and personality into looks that feel natural to you.',
      icon: Icons.auto_awesome_outlined,
    ),
    _OnboardingData(
      eyebrow: 'MADE FOR YOUR LIFE',
      title: 'Build a style\nthat feels like you.',
      subtitle: 'Save your wardrobe, explore your style and let VYEA help when you need inspiration.',
      icon: Icons.favorite_outline,
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _finish() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  void _next() {
    if (_page == _pages.length - 1) {
      _finish();
      return;
    }
    _controller.nextPage(
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 800;
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1180),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(wide ? 42 : 22, 12, wide ? 42 : 22, 20),
                  child: Column(
                    children: [
                      _topBar(),
                      Expanded(
                        child: PageView.builder(
                          controller: _controller,
                          itemCount: _pages.length,
                          onPageChanged: (value) => setState(() => _page = value),
                          itemBuilder: (_, index) => _OnboardingPage(data: _pages[index], wide: wide),
                        ),
                      ),
                      _bottomBar(),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _topBar() {
    return Row(
      children: [
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'VYEA',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                letterSpacing: 4,
                color: AppColors.primary,
              ),
            ),
            SizedBox(height: 3),
            Text(
              'STYLE BUT PERSONAL',
              style: TextStyle(
                fontSize: 8.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.8,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
        const Spacer(),
        TextButton(
          onPressed: _finish,
          child: const Text('Skip'),
        ),
      ],
    );
  }

  Widget _bottomBar() {
    return Row(
      children: [
        Row(
          children: List.generate(
            _pages.length,
            (index) => AnimatedContainer(
              duration: const Duration(milliseconds: 280),
              margin: const EdgeInsets.only(right: 6),
              width: _page == index ? 28 : 7,
              height: 7,
              decoration: BoxDecoration(
                color: _page == index ? AppColors.primary : AppColors.border,
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
        ),
        const Spacer(),
        SizedBox(
          width: 150,
          child: FilledButton(
            onPressed: _next,
            child: Text(_page == _pages.length - 1 ? 'Get Started' : 'Continue'),
          ),
        ),
      ],
    );
  }
}

class _OnboardingData {
  final String eyebrow;
  final String title;
  final String subtitle;
  final IconData icon;

  const _OnboardingData({
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.icon,
  });
}

class _OnboardingPage extends StatelessWidget {
  final _OnboardingData data;
  final bool wide;

  const _OnboardingPage({required this.data, required this.wide});

  @override
  Widget build(BuildContext context) {
    if (wide) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: Row(
          children: [
            Expanded(flex: 7, child: _visual()),
            const SizedBox(width: 48),
            Expanded(flex: 5, child: _copy(context)),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 12, 0, 12),
      child: Column(
        children: [
          Expanded(flex: 6, child: _visual()),
          const SizedBox(height: 26),
          Expanded(flex: 3, child: _copy(context)),
        ],
      ),
    );
  }

  Widget _visual() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(34),
        border: Border.all(color: AppColors.border),
      ),
      child: Stack(
        children: [
          Positioned(
            top: 24,
            left: 24,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: AppColors.border),
              ),
              child: Text(
                data.eyebrow,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 8.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: .9,
                ),
              ),
            ),
          ),
          Center(
            child: Container(
              width: wide ? 230 : 176,
              height: wide ? 300 : 220,
              decoration: BoxDecoration(
                color: AppColors.secondary,
                borderRadius: BorderRadius.circular(120),
              ),
              child: Icon(
                data.icon,
                size: wide ? 88 : 72,
                color: AppColors.primaryDark,
              ),
            ),
          ),
          Positioned(
            right: 26,
            bottom: 24,
            child: Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.arrow_forward_rounded,
                color: Colors.white,
                size: 19,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _copy(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: wide ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        Text(
          'VYEA / ${data.eyebrow}',
          textAlign: wide ? TextAlign.left : TextAlign.center,
          style: const TextStyle(
            color: AppColors.primary,
            fontSize: 9,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 13),
        Text(
          data.title,
          textAlign: wide ? TextAlign.left : TextAlign.center,
          style: const TextStyle(
            fontSize: 34,
            height: 1.02,
            fontWeight: FontWeight.w800,
            letterSpacing: -1,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          data.subtitle,
          textAlign: wide ? TextAlign.left : TextAlign.center,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 13,
            height: 1.55,
          ),
        ),
        const SizedBox(height: 18),
        Container(
          width: 46,
          height: 2,
          color: AppColors.primary,
        ),
      ],
    );
  }
}
