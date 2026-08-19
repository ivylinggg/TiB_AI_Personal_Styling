import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_gradients.dart';
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
      gradient: AppGradients.blush,
    ),
    _OnboardingData(
      eyebrow: 'YOUR EVERYDAY STYLIST',
      title: 'Get dressed\nwithout the guesswork.',
      subtitle: 'Turn your colours, wardrobe and personality into looks that feel natural to you.',
      icon: Icons.auto_awesome_outlined,
      gradient: AppGradients.soft,
    ),
    _OnboardingData(
      eyebrow: 'MADE FOR YOUR LIFE',
      title: 'Build a style\nthat feels like you.',
      subtitle: 'Save your wardrobe, explore your style and let TiB help when you need inspiration.',
      icon: Icons.favorite_outline,
      gradient: AppGradients.ai,
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
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 10, 22, 0),
              child: Row(
                children: [
                  const Text(
                    'TiB',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: -1),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _finish,
                    child: const Text('Skip'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _pages.length,
                onPageChanged: (value) => setState(() => _page = value),
                itemBuilder: (_, index) => _OnboardingPage(data: _pages[index]),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Row(
                children: [
                  Row(
                    children: List.generate(
                      _pages.length,
                      (index) => AnimatedContainer(
                        duration: const Duration(milliseconds: 280),
                        margin: const EdgeInsets.only(right: 6),
                        width: _page == index ? 24 : 7,
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
                    width: 142,
                    child: FilledButton(
                      onPressed: _next,
                      child: Text(_page == _pages.length - 1 ? 'Get Started' : 'Continue'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingData {
  final String eyebrow;
  final String title;
  final String subtitle;
  final IconData icon;
  final LinearGradient gradient;

  const _OnboardingData({
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.gradient,
  });
}

class _OnboardingPage extends StatelessWidget {
  final _OnboardingData data;

  const _OnboardingPage({required this.data});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
      child: Column(
        children: [
          Expanded(
            flex: 6,
            child: Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 28),
              decoration: BoxDecoration(
                gradient: data.gradient,
                borderRadius: BorderRadius.circular(32),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: .10),
                    blurRadius: 28,
                    offset: const Offset(0, 14),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  Positioned(
                    top: 24,
                    left: 24,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .20),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Text(
                        data.eyebrow,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 8.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: .9,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 28,
                    right: 28,
                    child: Icon(Icons.auto_awesome, color: Colors.white.withValues(alpha: .65), size: 24),
                  ),
                  Center(
                    child: Container(
                      width: 172,
                      height: 205,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .78),
                        borderRadius: BorderRadius.circular(88),
                      ),
                      child: Icon(data.icon, size: 72, color: AppColors.primaryDark),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Column(
              children: [
                Text(
                  data.title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    height: 1.08,
                    letterSpacing: -.7,
                  ),
                ),
                const SizedBox(height: 13),
                Text(
                  data.subtitle,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
