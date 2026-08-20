import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_gradients.dart';
import '../analysis/analysis_screen.dart';
import '../wardrobe/wardrobe_screen.dart';
import 'ai_outfit_screen.dart';
import 'ai_stylist_screen.dart';
import 'style_me_screen.dart';

/// TiB's central styling hub: one place for every AI styling action.
class AIHubScreen extends StatelessWidget {
  const AIHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
          children: [
            const Text(
              'YOUR PERSONAL STYLIST',
              style: TextStyle(
                fontSize: 9,
                letterSpacing: 1.4,
                fontWeight: FontWeight.w800,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 5),
            const Text(
              'What are we wearing?',
              style: TextStyle(
                fontSize: 29,
                fontWeight: FontWeight.w800,
                letterSpacing: -1,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'TiB combines your colours, personality and wardrobe to make getting dressed feel easier.',
              style: TextStyle(
                color: AppColors.textSecondary,
                height: 1.45,
                fontSize: 12.5,
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.fromLTRB(19, 19, 19, 18),
              decoration: BoxDecoration(
                gradient: AppGradients.primary,
                borderRadius: BorderRadius.circular(28),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 43,
                        height: 43,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.auto_awesome_rounded,
                          color: AppColors.primaryDark,
                          size: 21,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: .18),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'TIB AI',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Your style,\nwithout the guesswork.',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      height: 1.05,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -.6,
                    ),
                  ),
                  const SizedBox(height: 9),
                  const Text(
                    'Start with what you need today.',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            _featureCard(
              context,
              icon: Icons.auto_awesome_rounded,
              title: 'Style Me',
              subtitle: 'A personalised look using your real wardrobe.',
              gradient: AppGradients.ai,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const StyleMeScreen()),
              ),
              primary: true,
            ),
            const SizedBox(height: 11),
            _featureCard(
              context,
              icon: Icons.checkroom_rounded,
              title: 'AI Outfit',
              subtitle: 'Build a complete outfit for the occasion.',
              gradient: AppGradients.blush,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AIOutfitScreen()),
              ),
              primary: false,
            ),
            const SizedBox(height: 11),
            _featureCard(
              context,
              icon: Icons.chat_bubble_outline_rounded,
              title: 'Talk to TiB',
              subtitle: 'Ask your stylist anything, naturally.',
              gradient: AppGradients.soft,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AIStylistScreen()),
              ),
              primary: false,
            ),
            const SizedBox(height: 22),
            _sectionLabel('YOUR STYLE DATA'),
            const SizedBox(height: 9),
            Row(
              children: [
                Expanded(
                  child: _smallLink(
                    context,
                    Icons.palette_outlined,
                    'Colour profile',
                    const AnalysisScreen(),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _smallLink(
                    context,
                    Icons.checkroom_outlined,
                    'My wardrobe',
                    const WardrobeScreen(),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 9,
        letterSpacing: 1.2,
        fontWeight: FontWeight.w800,
        color: AppColors.textMuted,
      ),
    );
  }

  Widget _featureCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required LinearGradient gradient,
    required VoidCallback onTap,
    required bool primary,
  }) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Ink(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: primary ? .95 : .78),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: AppColors.primaryDark,
                  size: 21,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: primary ? Colors.white : AppColors.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: primary
                            ? Colors.white70
                            : AppColors.textSecondary,
                        fontSize: 11,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 7),
              Icon(
                Icons.arrow_forward_rounded,
                color: primary ? Colors.white : AppColors.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _smallLink(
    BuildContext context,
    IconData icon,
    String label,
    Widget page,
  ) {
    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => page),
      ),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.primary, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
