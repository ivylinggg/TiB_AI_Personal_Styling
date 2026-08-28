import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_gradients.dart';
import '../premium/ai_virtual_styling_studio_screen.dart';
import '../premium/personal_tib_model_screen.dart';
import 'ai_outfit_screen.dart';
import 'ai_stylist_screen.dart';
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
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
          children: [
            const Text('YOUR PERSONAL STYLIST', style: TextStyle(fontSize: 9, letterSpacing: 1.4, fontWeight: FontWeight.w800, color: AppColors.textMuted)),
            const SizedBox(height: 5),
            const Text('What are we wearing?', style: TextStyle(fontSize: 29, fontWeight: FontWeight.w800, letterSpacing: -1)),
            const SizedBox(height: 8),
            const Text('TiB starts with one person: you. Build your Personal TiB Model once, then use it across your styling experiences.', style: TextStyle(color: AppColors.textSecondary, height: 1.45, fontSize: 12.5)),
            const SizedBox(height: 20),
            _personalModelCard(context),
            const SizedBox(height: 18),
            _featureCard(context, icon: Icons.view_in_ar_rounded, title: 'Dress My TiB Model', subtitle: 'Choose clothes from your wardrobe and put them on your Personal TiB Model.', gradient: AppGradients.premium, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AIVirtualStylingStudioScreen())), primary: true, badge: 'VIRTUAL FITTING ROOM'),
            const SizedBox(height: 11),
            _featureCard(context, icon: Icons.auto_awesome_rounded, title: 'Style Me', subtitle: 'Let TiB choose a complete look using your real wardrobe, colours and preferences.', gradient: AppGradients.ai, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StyleMeScreen())), primary: false),
            const SizedBox(height: 11),
            _featureCard(context, icon: Icons.checkroom_rounded, title: 'AI Outfit', subtitle: 'Build a complete outfit around your occasion and personal styling profile.', gradient: AppGradients.blush, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AIOutfitScreen())), primary: false),
            const SizedBox(height: 11),
            _featureCard(context, icon: Icons.chat_bubble_outline_rounded, title: 'Talk to TiB', subtitle: 'Get instant automated answers, then switch to a real TiB consultant whenever you need human advice.', gradient: AppGradients.soft, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TalkToTibScreen())), primary: false, badge: 'FREE'),
          ],
        ),
      ),
    );
  }

  Widget _personalModelCard(BuildContext context) {
    return Material(color: Colors.transparent, borderRadius: BorderRadius.circular(28), child: InkWell(onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PersonalTibModelScreen())), borderRadius: BorderRadius.circular(28), child: Ink(padding: const EdgeInsets.all(19), decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(28), border: Border.all(color: AppColors.primarySoft), boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: .06), blurRadius: 18, offset: const Offset(0, 8))]), child: Row(children: [Container(width: 66, height: 78, decoration: BoxDecoration(gradient: AppGradients.soft, borderRadius: BorderRadius.circular(21)), child: const Icon(Icons.person_rounded, color: AppColors.primary, size: 34)), const SizedBox(width: 14), const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('MY TIΒ MODEL', style: TextStyle(color: AppColors.primary, fontSize: 9, letterSpacing: 1.2, fontWeight: FontWeight.w900)), SizedBox(height: 5), Text('Your real self,\nready to be styled.', style: TextStyle(fontSize: 19, height: 1.05, fontWeight: FontWeight.w900)), SizedBox(height: 5), Text('Face + full-body reference + real measurements.', style: TextStyle(color: AppColors.textSecondary, fontSize: 10.5))])), const Icon(Icons.arrow_forward_rounded, color: AppColors.primary)]))));
  }

  Widget _featureCard(BuildContext context, {required IconData icon, required String title, required String subtitle, required LinearGradient gradient, required VoidCallback onTap, required bool primary, String? badge}) {
    return Material(color: Colors.transparent, borderRadius: BorderRadius.circular(24), child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(24), child: Ink(padding: const EdgeInsets.all(18), decoration: BoxDecoration(gradient: gradient, borderRadius: BorderRadius.circular(24)), child: Row(children: [Container(width: 46, height: 46, decoration: BoxDecoration(color: Colors.white.withValues(alpha: primary ? .95 : .78), shape: BoxShape.circle), child: Icon(icon, color: AppColors.primaryDark, size: 21)), const SizedBox(width: 13), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Expanded(child: Text(title, style: TextStyle(color: primary ? Colors.white : AppColors.textPrimary, fontSize: 17, fontWeight: FontWeight.w800))), if (badge != null) ...[const SizedBox(width: 7), Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4), decoration: BoxDecoration(color: Colors.white.withValues(alpha: .72), borderRadius: BorderRadius.circular(10)), child: Text(badge, style: const TextStyle(color: AppColors.primaryDark, fontSize: 7.5, fontWeight: FontWeight.w900, letterSpacing: .7)))]],), const SizedBox(height: 4), Text(subtitle, style: TextStyle(color: primary ? Colors.white70 : AppColors.textSecondary, fontSize: 11, height: 1.35))])), const SizedBox(width: 7), Icon(Icons.arrow_forward_rounded, color: primary ? Colors.white : AppColors.primary)]))));
  }
}
