import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import 'live_consultancy_screen.dart';
import 'talk_to_tib_screen.dart';

class ConsultationHubScreen extends StatelessWidget {
  const ConsultationHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 38),
          children: [
            const Text(
              'VYEA  /  CONVERSATIONS',
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 9.5,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.45,
              ),
            ),
            const SizedBox(height: 9),
            const Text(
              'Talk it through.',
              style: TextStyle(
                fontSize: 34,
                height: 1.0,
                fontWeight: FontWeight.w900,
                letterSpacing: -1.4,
              ),
            ),
            const SizedBox(height: 9),
            const Text(
              'Choose how you want to get styling advice — from VYEA instantly or from a real TiB consultant.',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            _conversationCard(
              context,
              icon: Icons.chat_bubble_outline_rounded,
              eyebrow: 'AI STYLING CHAT',
              title: 'Talk with VYEA',
              subtitle:
                  'Ask about colours, your wardrobe, proportions or what to wear next. VYEA can turn the conversation into a complete look.',
              badge: 'INSTANT',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TalkToTibScreen()),
              ),
              dark: true,
            ),
            const SizedBox(height: 14),
            _conversationCard(
              context,
              icon: Icons.support_agent_rounded,
              eyebrow: 'REAL CONSULTANT',
              title: 'Live Consultancy',
              subtitle:
                  'Start a consultation with a TiB consultant, send your questions and continue the conversation until it is resolved.',
              badge: 'LIVE',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LiveConsultancyScreen()),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _conversationCard(
    BuildContext context, {
    required IconData icon,
    required String eyebrow,
    required String title,
    required String subtitle,
    required String badge,
    required VoidCallback onTap,
    bool dark = false,
  }) {
    final textColor = dark ? Colors.white : AppColors.textPrimary;
    final secondary = dark ? Colors.white70 : AppColors.textSecondary;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(25),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(25),
        child: Ink(
          padding: const EdgeInsets.all(19),
          decoration: BoxDecoration(
            color: dark ? AppColors.primaryDark : AppColors.surface,
            borderRadius: BorderRadius.circular(25),
            border: Border.all(
              color: dark ? AppColors.primaryDark : AppColors.border,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: dark ? Colors.white : AppColors.secondary,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      icon,
                      color: AppColors.primary,
                      size: 22,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: dark
                          ? Colors.white.withValues(alpha: .14)
                          : AppColors.secondary,
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      badge,
                      style: TextStyle(
                        color: dark ? Colors.white : AppColors.primaryDark,
                        fontSize: 8,
                        fontWeight: FontWeight.w900,
                        letterSpacing: .8,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                eyebrow,
                style: TextStyle(
                  color: dark ? Colors.white70 : AppColors.textMuted,
                  fontSize: 8,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                title,
                style: TextStyle(
                  color: textColor,
                  fontSize: 23,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -.5,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                subtitle,
                style: TextStyle(
                  color: secondary,
                  fontSize: 11.5,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 17),
              Row(
                children: [
                  Text(
                    'Open',
                    style: TextStyle(
                      color: dark ? Colors.white : AppColors.primary,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Icon(
                    Icons.arrow_forward_rounded,
                    color: dark ? Colors.white : AppColors.primary,
                    size: 18,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
