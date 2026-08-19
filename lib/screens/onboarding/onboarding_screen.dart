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

  final _pages = const [
    _OnboardingData(
      title: 'Discover\nYour Best Colours',
      subtitle: 'AI-powered colour analysis made just for you.',
      icon: Icons.palette_outlined,
      gradient: AppGradients.blush,
    ),
    _OnboardingData(
      title: 'Style Smarter\nEvery Day',
      subtitle: 'Get outfit ideas that match your colours, style and life.',
      icon: Icons.auto_awesome_outlined,
      gradient: AppGradients.soft,
    ),
    _OnboardingData(
      title: 'Build Confidence\nThat Lasts',
      subtitle: 'Look good, feel amazing, and make every outfit feel like you.',
      icon: Icons.favorite_outline,
      gradient: AppGradients.ai,
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    if (_page == _pages.length - 1) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
      return;
    }
    _controller.nextPage(
      duration: const Duration(milliseconds: 350),
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
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                ),
                child: const Text('Skip'),
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
              padding: const EdgeInsets.fromLTRB(28, 0, 28, 28),
              child: Row(
                children: [
                  Row(
                    children: List.generate(
                      _pages.length,
                      (index) => AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        margin: const EdgeInsets.only(right: 6),
                        width: _page == index ? 22 : 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: _page == index
                              ? AppColors.primary
                              : AppColors.border,
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                  SizedBox(
                    width: 150,
                    child: ElevatedButton(
                      onPressed: _next,
                      child: Text(_page == _pages.length - 1 ? 'Get Started' : 'Next'),
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
  final String title;
  final String subtitle;
  final IconData icon;
  final LinearGradient gradient;

  const _OnboardingData({
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
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        children: [
          Expanded(
            flex: 6,
            child: Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 28),
              decoration: BoxDecoration(
                gradient: data.gradient,
                borderRadius: BorderRadius.circular(28),
              ),
              child: Stack(
                children: [
                  Positioned(
                    top: 30,
                    right: 30,
                    child: Icon(Icons.auto_awesome, color: Colors.white.withValues(alpha: .7), size: 26),
                  ),
                  Center(
                    child: Container(
                      width: 150,
                      height: 190,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .78),
                        borderRadius: BorderRadius.circular(80),
                      ),
                      child: Icon(data.icon, size: 70, color: AppColors.primaryDark),
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
                    fontWeight: FontWeight.w700,
                    height: 1.12,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  data.subtitle,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
