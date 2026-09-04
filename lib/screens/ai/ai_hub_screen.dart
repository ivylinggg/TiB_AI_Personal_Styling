import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_gradients.dart';
import '../premium/ai_virtual_styling_studio_screen.dart';
import '../premium/personal_tib_model_screen.dart';
import 'ai_outfit_screen.dart';
import 'style_me_screen.dart';
import 'talk_to_tib_screen.dart';

/// VYEA Style hub.
/// Visual hierarchy only: all existing destinations and actions remain intact.
class AIHubScreen extends StatelessWidget {
  const AIHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 32),
          children: [
            const Text(
              'VYEA · PERSONAL STYLING',
              style: TextStyle(fontSize: 9, letterSpacing: 1.7, fontWeight: FontWeight.w800, color: AppColors.brown),
            ),
            const SizedBox(height: 7),
            const Text(
              'What are we wearing?',
              style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, letterSpacing: -1.05, height: 1.05),
            ),
            const SizedBox(height: 9),
            const Text(
              'Personal styling built around your colours, wardrobe and the way you want to express yourself.',
              style: TextStyle(color: AppColors.textSecondary, height: 1.5, fontSize: 13),
            ),
            const SizedBox(height: 20),
            _personalModelCard(context),
            const SizedBox(height: 18),
            _featureCard(
              context,
              icon: Icons.view_in_ar_rounded,
              title: 'Dress My VYEA Model',
              subtitle: 'Choose clothes from your wardrobe and put them on your Personal Model.',
              gradient: AppGradients.premium,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AIVirtualStylingStudioScreen())),
              primary: false,
              badge: 'VIRTUAL FITTING ROOM',
            ),
            const SizedBox(height: 10),
            _featureCard(
              context,
              icon: Icons.auto_awesome_rounded,
              title: 'Style Me',
              subtitle: 'Build a complete look around your real wardrobe, colours and preferences.',
              gradient: AppGradients.soft,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StyleMeScreen())),
              primary: false,
            ),
            const SizedBox(height: 10),
            _featureCard(
              context,
              icon: Icons.checkroom_rounded,
              title: 'AI Outfit',
              subtitle: 'Create a complete outfit for your occasion and personal styling profile.',
              gradient: AppGradients.blush,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AIOutfitScreen())),
              primary: false,
            ),
            const SizedBox(height: 10),
            _featureCard(
              context,
              icon: Icons.chat_bubble_outline_rounded,
              title: 'Talk to TiB',
              subtitle: 'Get instant styling answers, then switch to a real consultant when you need human advice.',
              gradient: AppGradients.soft,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TalkToTibScreen())),
              primary: false,
              badge: 'FREE',
            ),
          ],
        ),
      ),
    );
  }

  Widget _personalModelCard(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PersonalTibModelScreen())),
        borderRadius: BorderRadius.circular(24),
        child: Ink(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 64,
                height: 76,
                decoration: BoxDecoration(color: AppColors.surfaceMuted, borderRadius: BorderRadius.circular(19)),
                child: const Icon(Icons.person_rounded, color: AppColors.primary, size: 34),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('MY VYEA MODEL', style: TextStyle(color: AppColors.brown, fontSize: 9, letterSpacing: 1.3, fontWeight: FontWeight.w900)),
                    SizedBox(height: 5),
                    Text('Your real self,\nready to be styled.', style: TextStyle(fontSize: 19, height: 1.08, fontWeight: FontWeight.w900)),
                    SizedBox(height: 6),
                    Text('Face + full-body reference + real measurements.', style: TextStyle(color: AppColors.textSecondary, fontSize: 10.5)),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_rounded, color: AppColors.primary, size: 20),
            ],
          ),
        ),
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
    String? badge,
  }) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(21),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(21),
        child: Ink(
          padding: const EdgeInsets.all(17),
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(21),
            border: Border.all(color: AppColors.border.withValues(alpha: .7)),
          ),
          child: Row(
            children: [
              Container(
                width: 45,
                height: 45,
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: .88), shape: BoxShape.circle),
                child: Icon(icon, color: AppColors.primaryDark, size: 21),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(title, style: const TextStyle(color: AppColors.textPrimary, fontSize: 16.5, fontWeight: FontWeight.w800))),
                        if (badge != null) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                            decoration: BoxDecoration(color: Colors.white.withValues(alpha: .68), borderRadius: BorderRadius.circular(9)),
                            child: Text(badge, style: const TextStyle(color: AppColors.primaryDark, fontSize: 7.5, fontWeight: FontWeight.w900, letterSpacing: .55)),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(subtitle, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11, height: 1.38)),
                  ],
                ),
              ),
              const SizedBox(width: 7),
              const Icon(Icons.arrow_forward_rounded, color: AppColors.primary, size: 19),
            ],
          ),
        ),
      ),
    );
  }
}
