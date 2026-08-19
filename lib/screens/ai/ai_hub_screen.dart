import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_gradients.dart';
import '../analysis/analysis_screen.dart';
import '../wardrobe/wardrobe_screen.dart';
import 'ai_outfit_screen.dart';
import 'ai_stylist_screen.dart';
import 'style_me_screen.dart';

/// One calm entry point for TiB's three styling experiences.
/// This keeps the bottom navigation simple while still exposing the
/// reference flow: Style Me -> AI Outfit -> conversational Stylist.
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
            const Text('Your styling space', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            const SizedBox(height: 3),
            const Text('Let’s get you dressed.', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: -.8)),
            const SizedBox(height: 8),
            const Text('Choose how you want TiB to help today. Your palette, personality and wardrobe stay at the centre.', style: TextStyle(color: AppColors.textSecondary, height: 1.45, fontSize: 12.5)),
            const SizedBox(height: 20),
            _featureCard(
              context,
              icon: Icons.auto_awesome_rounded,
              title: 'Style Me',
              subtitle: 'Tell me where you’re going and build a look from clothes you already own.',
              gradient: AppGradients.ai,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StyleMeScreen())),
            ),
            const SizedBox(height: 12),
            _featureCard(
              context,
              icon: Icons.checkroom_rounded,
              title: 'AI Outfit',
              subtitle: 'Pick an occasion and get a complete personal look with a clear match score.',
              gradient: AppGradients.blush,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AIOutfitScreen())),
            ),
            const SizedBox(height: 12),
            _featureCard(
              context,
              icon: Icons.chat_bubble_outline_rounded,
              title: 'Talk to TiB',
              subtitle: 'Ask naturally: “I have dinner tonight. What should I wear?”',
              gradient: AppGradients.primary,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AIStylistScreen())),
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(child: _smallLink(context, Icons.palette_outlined, 'Colour profile', const AnalysisScreen())),
                const SizedBox(width: 10),
                Expanded(child: _smallLink(context, Icons.checkroom_outlined, 'My wardrobe', const WardrobeScreen())),
              ],
            ),
          ],
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
  }) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(25),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(25),
        child: Ink(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(gradient: gradient, borderRadius: BorderRadius.circular(25)),
          child: Row(
            children: [
              Container(width: 48, height: 48, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle), child: Icon(icon, color: AppColors.primary, size: 22)),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w800)), const SizedBox(height: 5), Text(subtitle, style: const TextStyle(color: Colors.white70, fontSize: 11.5, height: 1.4))])),
              const SizedBox(width: 8),
              const Icon(Icons.arrow_forward_rounded, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }

  Widget _smallLink(BuildContext context, IconData icon, String label, Widget page) {
    return InkWell(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => page)),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.border)),
        child: Row(children: [Icon(icon, color: AppColors.primary, size: 19), const SizedBox(width: 8), Expanded(child: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)))])
      ),
    );
  }
}
