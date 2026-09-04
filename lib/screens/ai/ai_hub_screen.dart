import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_gradients.dart';
import '../premium/ai_virtual_styling_studio_screen.dart';
import '../premium/personal_tib_model_screen.dart';
import 'ai_outfit_screen.dart';
import 'style_me_screen.dart';
import 'talk_to_tib_screen.dart';

class AIHubScreen extends StatelessWidget {
  const AIHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 36),
          children: [
            const Text(
              'VYEA  /  PERSONAL STYLING',
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 9.5,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.45,
              ),
            ),
            const SizedBox(height: 9),
            const Text(
              'Your style,\nshaped around you.',
              style: TextStyle(
                fontSize: 34,
                height: 1.0,
                fontWeight: FontWeight.w900,
                letterSpacing: -1.4,
              ),
            ),
            const SizedBox(height: 9),
            const Text(
              'Choose how you want VYEA to help — build a look, dress for a moment, explore your model or simply talk it through.',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 22),
            _heroAction(context),
            const SizedBox(height: 25),
            _heading('STYLE TOOLS', 'Start with the result you want.'),
            const SizedBox(height: 11),
            Row(
              children: [
                Expanded(
                  child: _toolCard(
                    context,
                    icon: Icons.auto_awesome_rounded,
                    eyebrow: 'PERSONAL',
                    title: 'Style Me',
                    subtitle: 'Build a complete look from your profile.',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const StyleMeScreen()),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _toolCard(
                    context,
                    icon: Icons.event_available_outlined,
                    eyebrow: 'OCCASION',
                    title: 'AI Outfit',
                    subtitle: 'Get dressed for a specific moment.',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AIOutfitScreen()),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 25),
            _heading('YOUR VISUAL STYLE SPACE', 'See your own styling possibilities.'),
            const SizedBox(height: 11),
            _modelFeature(context),
            const SizedBox(height: 10),
            _virtualFeature(context),
            const SizedBox(height: 25),
            _heading('QUICK CONVERSATION', 'Start with a question instead of a form.'),
            const SizedBox(height: 11),
            _talkFeature(context),
          ],
        ),
      ),
    );
  }

  Widget _heading(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 9.5,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.3,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 11.5,
            height: 1.35,
          ),
        ),
      ],
    );
  }

  Widget _heroAction(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(28),
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const TalkToTibScreen()),
        ),
        borderRadius: BorderRadius.circular(28),
        child: Ink(
          padding: const EdgeInsets.fromLTRB(19, 20, 18, 18),
          decoration: BoxDecoration(
            gradient: AppGradients.soft,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.chat_bubble_outline_rounded,
                      color: AppColors.primary,
                      size: 22,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .72),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: const Text(
                      'FREE',
                      style: TextStyle(
                        color: AppColors.primaryDark,
                        fontSize: 8,
                        fontWeight: FontWeight.w900,
                        letterSpacing: .8,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 19),
              const Text(
                'Talk it through\nwith VYEA.',
                style: TextStyle(
                  fontSize: 25,
                  height: 1.04,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -.75,
                ),
              ),
              const SizedBox(height: 7),
              const Text(
                'Tell VYEA what you are wearing, where you are going or what feels off. Start naturally and turn the conversation into a useful styling direction.',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11.8,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 17),
              Row(
                children: [
                  _tag('Ask'),
                  const SizedBox(width: 7),
                  _tag('Explore'),
                  const SizedBox(width: 7),
                  _tag('Refine'),
                  const Spacer(),
                  const Icon(
                    Icons.arrow_forward_rounded,
                    color: AppColors.primary,
                    size: 20,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tag(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .68),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.primaryDark,
          fontSize: 9.5,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _toolCard(
    BuildContext context, {
    required IconData icon,
    required String eyebrow,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(21),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(21),
        child: Ink(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(21),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: const BoxDecoration(
                  color: AppColors.secondary,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: AppColors.primary, size: 20),
              ),
              const SizedBox(height: 13),
              Text(
                eyebrow,
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 8,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                subtitle,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 10.5,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _modelFeature(BuildContext context) {
    return _visualFeature(
      context,
      eyebrow: 'PERSONAL MODEL',
      title: 'Your VYEA Model',
      subtitle: 'Your face, body reference and measurements in one styling space.',
      icon: Icons.person_outline_rounded,
      background: AppColors.surface,
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const PersonalTibModelScreen()),
      ),
    );
  }

  Widget _virtualFeature(BuildContext context) {
    return _visualFeature(
      context,
      eyebrow: 'VISUAL STYLING',
      title: 'Dress Your Model',
      subtitle: 'Explore wardrobe pieces visually and see how a look comes together.',
      icon: Icons.view_in_ar_rounded,
      background: null,
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const AIVirtualStylingStudioScreen()),
      ),
    );
  }

  Widget _talkFeature(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(21),
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const TalkToTibScreen()),
        ),
        borderRadius: BorderRadius.circular(21),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(21),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: const BoxDecoration(
                  color: AppColors.secondary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.forum_outlined,
                  color: AppColors.primary,
                  size: 21,
                ),
              ),
              const SizedBox(width: 13),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Quick styling question?',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'One question is enough. VYEA helps you decide what to wear next.',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 10.8,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.arrow_forward_rounded,
                color: AppColors.primary,
                size: 19,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _visualFeature(
    BuildContext context, {
    required String eyebrow,
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
    Color? background,
  }) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(21),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(21),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: background,
            gradient: background == null ? AppGradients.premium : null,
            borderRadius: BorderRadius.circular(21),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .82),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: AppColors.primaryDark, size: 22),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      eyebrow,
                      style: const TextStyle(
                        color: AppColors.primaryDark,
                        fontSize: 7.8,
                        fontWeight: FontWeight.w900,
                        letterSpacing: .85,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 10.8,
                        height: 1.38,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 7),
              const Icon(
                Icons.arrow_forward_rounded,
                color: AppColors.primary,
                size: 19,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
