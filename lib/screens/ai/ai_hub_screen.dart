import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_gradients.dart';
import '../premium/ai_virtual_styling_studio_screen.dart';
import '../premium/personal_tib_model_screen.dart';
import 'ai_outfit_screen.dart';
import 'style_me_screen.dart';
import 'talk_to_tib_screen.dart';

/// VYEA Style hub. Existing destinations and actions remain intact.
class AIHubScreen extends StatelessWidget {
  const AIHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 34),
          children: [
            Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'VYEA',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 3.4,
                          color: AppColors.brown,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Your personal stylist.',
                        style: TextStyle(
                          fontSize: 30,
                          height: 1.04,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -1.0,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Icon(Icons.auto_awesome_rounded, color: AppColors.primary, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 9),
            const Text(
              'Style around your colours, your wardrobe and the way you want to express yourself.',
              style: TextStyle(color: AppColors.textSecondary, height: 1.5, fontSize: 13),
            ),
            const SizedBox(height: 20),
            _personalModelCard(context),
            const SizedBox(height: 18),
            _sectionLabel('START WITH A REQUEST'),
            const SizedBox(height: 9),
            _promptCard(context),
            const SizedBox(height: 18),
            _sectionLabel('STYLE WITH YOUR CLOSET'),
            const SizedBox(height: 9),
            _featureCard(context, icon: Icons.auto_awesome_rounded, title: 'Style Me', subtitle: 'Build a complete look around your real wardrobe, colours and preferences.', gradient: AppGradients.soft, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StyleMeScreen()))),
            const SizedBox(height: 10),
            _featureCard(context, icon: Icons.checkroom_rounded, title: 'AI Outfit', subtitle: 'Create a complete outfit for your occasion and personal styling profile.', gradient: AppGradients.blush, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AIOutfitScreen()))),
            const SizedBox(height: 18),
            _sectionLabel('STYLE YOUR VYEA MODEL'),
            const SizedBox(height: 9),
            _featureCard(context, icon: Icons.view_in_ar_rounded, title: 'Dress My VYEA Model', subtitle: 'Choose clothes from your wardrobe and put them on your Personal Model.', gradient: AppGradients.premium, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AIVirtualStylingStudioScreen())), badge: 'VIRTUAL FITTING ROOM'),
            const SizedBox(height: 10),
            _featureCard(context, icon: Icons.chat_bubble_outline_rounded, title: 'Talk to VYEA', subtitle: 'Get a quick styling answer, then move into your personal look when you are ready.', gradient: AppGradients.soft, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TalkToTibScreen())), badge: 'FREE'),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String label) => Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.25, color: AppColors.textMuted));

  Widget _personalModelCard(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PersonalTibModelScreen())),
        borderRadius: BorderRadius.circular(24),
        child: Ink(
          padding: const EdgeInsets.all(17),
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(24), border: Border.all(color: AppColors.border), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .035), blurRadius: 18, offset: const Offset(0, 8))]),
          child: Row(
            children: [
              Container(width: 68, height: 78, decoration: BoxDecoration(color: AppColors.surfaceMuted, borderRadius: BorderRadius.circular(19)), child: const Icon(Icons.person_outline_rounded, color: AppColors.primary, size: 34)),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('MY VYEA MODEL', style: TextStyle(color: AppColors.brown, fontSize: 9, letterSpacing: 1.35, fontWeight: FontWeight.w900)),
                    SizedBox(height: 5),
                    Text('Your real self,\nready to be styled.', style: TextStyle(fontSize: 19, height: 1.08, fontWeight: FontWeight.w900, letterSpacing: -.3)),
                    SizedBox(height: 6),
                    Text('Face + full-body reference + real measurements.', style: TextStyle(color: AppColors.textSecondary, fontSize: 10.5)),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_rounded, color: AppColors.primary, size: 19),
            ],
          ),
        ),
      ),
    );
  }

  Widget _promptCard(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(21),
      child: InkWell(
        borderRadius: BorderRadius.circular(21),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TalkToTibScreen())),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(21), border: Border.all(color: AppColors.border)),
          child: Row(
            children: [
              Container(width: 46, height: 46, decoration: const BoxDecoration(color: AppColors.secondary, shape: BoxShape.circle), child: const Icon(Icons.edit_note_rounded, color: AppColors.primary, size: 23)),
              const SizedBox(width: 13),
              const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('What are you dressing for?', style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800)), SizedBox(height: 4), Text('Dinner, work, weekend, event — tell VYEA the context.', style: TextStyle(color: AppColors.textSecondary, fontSize: 11.5, height: 1.35))])),
              const Icon(Icons.arrow_forward_rounded, color: AppColors.primary, size: 19),
            ],
          ),
        ),
      ),
    );
  }

  Widget _featureCard(BuildContext context, {required IconData icon, required String title, required String subtitle, required LinearGradient gradient, required VoidCallback onTap, String? badge}) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(21),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(21),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(gradient: gradient, borderRadius: BorderRadius.circular(21), border: Border.all(color: AppColors.border.withValues(alpha: .78))),
          child: Row(
            children: [
              Container(width: 45, height: 45, decoration: BoxDecoration(color: Colors.white.withValues(alpha: .86), shape: BoxShape.circle), child: Icon(icon, color: AppColors.primaryDark, size: 21)),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [Expanded(child: Text(title, style: const TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: -.15))), if (badge != null) ...[const SizedBox(width: 6), Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4), decoration: BoxDecoration(color: Colors.white.withValues(alpha: .72), borderRadius: BorderRadius.circular(9)), child: Text(badge, style: const TextStyle(color: AppColors.primaryDark, fontSize: 7.2, fontWeight: FontWeight.w900, letterSpacing: .55)))]]),
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
