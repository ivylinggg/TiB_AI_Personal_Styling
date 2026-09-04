import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_gradients.dart';
import '../premium/ai_virtual_styling_studio_screen.dart';
import '../premium/personal_tib_model_screen.dart';
import 'ai_outfit_screen.dart';
import 'style_me_screen.dart';
import 'talk_to_tib_screen.dart';

/// VYEA's main personal-styling hub. Navigation and destinations remain intact.
class AIHubScreen extends StatelessWidget {
  const AIHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 34),
          children: [
            const Text('VYEA', style: TextStyle(color: AppColors.brown, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 3.4)),
            const SizedBox(height: 8),
            const Text(
              'Style that starts\nwith you.',
              style: TextStyle(fontSize: 34, height: 1.01, fontWeight: FontWeight.w900, letterSpacing: -1.35),
            ),
            const SizedBox(height: 9),
            const Text(
              'Your colours, wardrobe and preferences — brought together into one personal styling space.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.5),
            ),
            const SizedBox(height: 22),
            _primaryStudioCard(context),
            const SizedBox(height: 24),
            _sectionHeading('START WITH WHAT YOU NEED', 'Choose a styling route.'),
            const SizedBox(height: 11),
            Row(
              children: [
                Expanded(
                  child: _quickAction(
                    context,
                    icon: Icons.auto_awesome_rounded,
                    title: 'Style Me',
                    subtitle: 'Complete look',
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StyleMeScreen())),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _quickAction(
                    context,
                    icon: Icons.checkroom_rounded,
                    title: 'AI Outfit',
                    subtitle: 'Dress for an occasion',
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AIOutfitScreen())),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _sectionHeading('YOUR PERSONAL MODEL', 'See yourself in the styling flow.'),
            const SizedBox(height: 11),
            _modelCard(context),
            const SizedBox(height: 24),
            _sectionHeading('EXPLORE THE VYEA EXPERIENCE', 'From quick advice to visual styling.'),
            const SizedBox(height: 11),
            _visualFeature(
              context,
              title: 'Dress My VYEA Model',
              eyebrow: 'VIRTUAL FITTING ROOM',
              subtitle: 'Put pieces from your wardrobe onto your Personal Model and explore the look.',
              icon: Icons.view_in_ar_rounded,
              gradient: AppGradients.premium,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AIVirtualStylingStudioScreen())),
            ),
            const SizedBox(height: 10),
            _visualFeature(
              context,
              title: 'Talk to VYEA',
              eyebrow: 'FREE',
              subtitle: 'Ask a styling question, get a quick answer, and turn it into a look when ready.',
              icon: Icons.chat_bubble_outline_rounded,
              gradient: AppGradients.soft,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TalkToTibScreen())),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeading(String title, String subtitle) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.25, color: AppColors.textMuted)),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11.5)),
        ],
      );

  Widget _primaryStudioCard(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(28),
      child: InkWell(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TalkToTibScreen())),
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
                    width: 46,
                    height: 46,
                    decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                    child: const Icon(Icons.edit_note_rounded, color: AppColors.primary, size: 23),
                  ),
                  const Spacer(),
                  const Text('FREE', style: TextStyle(color: AppColors.primaryDark, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: .75)),
                  const SizedBox(width: 7),
                  const Icon(Icons.arrow_forward_rounded, color: AppColors.primary, size: 19),
                ],
              ),
              const SizedBox(height: 20),
              const Text('Tell VYEA\nwhat you need.', style: TextStyle(fontSize: 25, height: 1.05, fontWeight: FontWeight.w900, letterSpacing: -.8)),
              const SizedBox(height: 7),
              const Text('Dinner, work, weekend, event — start with the context and let VYEA help shape your look.', style: TextStyle(color: AppColors.textSecondary, fontSize: 11.8, height: 1.45)),
              const SizedBox(height: 17),
              Row(
                children: [
                  _contextPill('Occasion'),
                  const SizedBox(width: 7),
                  _contextPill('Mood'),
                  const SizedBox(width: 7),
                  _contextPill('Colours'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _contextPill(String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: .72), borderRadius: BorderRadius.circular(10)),
        child: Text(label, style: const TextStyle(color: AppColors.primaryDark, fontSize: 9.5, fontWeight: FontWeight.w800)),
      );

  Widget _quickAction(BuildContext context, {required IconData icon, required String title, required String subtitle, required VoidCallback onTap}) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.border)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(width: 40, height: 40, decoration: const BoxDecoration(color: AppColors.secondary, shape: BoxShape.circle), child: Icon(icon, color: AppColors.primary, size: 20)),
              const SizedBox(height: 13),
              Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              Text(subtitle, style: const TextStyle(color: AppColors.textSecondary, fontSize: 10.5, height: 1.3)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _modelCard(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(23),
      child: InkWell(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PersonalTibModelScreen())),
        borderRadius: BorderRadius.circular(23),
        child: Ink(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(23), border: Border.all(color: AppColors.border)),
          child: Row(
            children: [
              Container(width: 76, height: 90, decoration: BoxDecoration(color: AppColors.surfaceMuted, borderRadius: BorderRadius.circular(20)), child: const Icon(Icons.person_outline_rounded, color: AppColors.primary, size: 38)),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('MY VYEA MODEL', style: TextStyle(color: AppColors.brown, fontSize: 9, letterSpacing: 1.35, fontWeight: FontWeight.w900)),
                    SizedBox(height: 5),
                    Text('Your real self,\nready to be styled.', style: TextStyle(fontSize: 20, height: 1.05, fontWeight: FontWeight.w900, letterSpacing: -.35)),
                    SizedBox(height: 6),
                    Text('Face + body reference + measurements.', style: TextStyle(color: AppColors.textSecondary, fontSize: 10.5, height: 1.3)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.arrow_forward_rounded, color: AppColors.primary, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _visualFeature(BuildContext context, {required String title, required String eyebrow, required String subtitle, required IconData icon, required LinearGradient gradient, required VoidCallback onTap}) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          padding: const EdgeInsets.all(17),
          decoration: BoxDecoration(gradient: gradient, borderRadius: BorderRadius.circular(22), border: Border.all(color: AppColors.border.withValues(alpha: .82))),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(width: 48, height: 48, decoration: BoxDecoration(color: Colors.white.withValues(alpha: .86), shape: BoxShape.circle), child: Icon(icon, color: AppColors.primaryDark, size: 22)),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(eyebrow, style: const TextStyle(color: AppColors.primaryDark, fontSize: 7.6, fontWeight: FontWeight.w900, letterSpacing: .8)),
                    const SizedBox(height: 4),
                    Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: -.2)),
                    const SizedBox(height: 5),
                    Text(subtitle, style: const TextStyle(color: AppColors.textSecondary, fontSize: 10.8, height: 1.4)),
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
