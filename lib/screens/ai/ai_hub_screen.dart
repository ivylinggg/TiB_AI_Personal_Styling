import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_gradients.dart';
import '../../core/state/personal_style_provider.dart';
import '../premium/ai_virtual_styling_studio_screen.dart';
import '../premium/personal_tib_model_screen.dart';
import 'ai_outfit_screen.dart';
import 'style_me_screen.dart';
import 'talk_to_tib_screen.dart';

class AIHubScreen extends StatelessWidget {
  const AIHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final style = context.watch<PersonalStyleProvider>();
    final readyInputs = [
      style.hasColourProfile,
      style.hasTiBModel,
      style.hasWardrobe,
    ].where((value) => value).length;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => context.read<PersonalStyleProvider>().refresh(force: true),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 38),
            children: [
              const Text(
                'VYEA  /  PERSONAL AI STUDIO',
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
              Text(
                readyInputs == 3
                    ? 'Your colour profile, Personal TiB and real wardrobe are connected to the styling tools below.'
                    : 'Complete your personal inputs to make VYEA more specific to you. $readyInputs of 3 core inputs are ready.',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 18),
              _contextCard(style, readyInputs),
              const SizedBox(height: 22),
              _heading('START HERE', 'Choose how you want VYEA to help.'),
              const SizedBox(height: 11),
              _heroAction(context),
              const SizedBox(height: 22),
              _heading('BUILD A LOOK', 'Use your wardrobe, palette and occasion together.'),
              const SizedBox(height: 11),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _toolCard(
                      icon: Icons.auto_awesome_rounded,
                      eyebrow: 'PERSONAL',
                      title: 'Style Me',
                      subtitle: 'Describe the moment and style what you own.',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const StyleMeScreen()),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _toolCard(
                      icon: Icons.event_available_outlined,
                      eyebrow: 'OCCASION',
                      title: 'AI Outfit',
                      subtitle: 'Generate a complete look for the moment.',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const AIOutfitScreen()),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              _heading('VISUAL STYLE SPACE', 'Move from advice to something you can see.'),
              const SizedBox(height: 11),
              _modelFeature(context, style),
              const SizedBox(height: 10),
              _virtualFeature(context),
              const SizedBox(height: 22),
              _heading('CONVERSATION', 'Start naturally, then turn advice into action.'),
              const SizedBox(height: 11),
              _talkFeature(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _contextCard(PersonalStyleProvider style, int readyInputs) {
    final colour = style.colourAnalysis;
    final colourParts = <String>[];
    if (colour != null) {
      if (colour.season.trim().isNotEmpty) colourParts.add(colour.season.trim());
      if (colour.faceShape.trim().isNotEmpty) colourParts.add(colour.faceShape.trim());
    }
    final colourText = colourParts.isEmpty ? 'Colour profile not set' : colourParts.join(' · ');
    final styleText = style.styles.isEmpty ? 'Style preferences not set' : style.styles.take(2).join(' · ');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppGradients.soft,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 43,
                height: 43,
                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                child: const Icon(Icons.auto_awesome_rounded, color: AppColors.primary),
              ),
              const SizedBox(width: 11),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('YOUR AI CONTEXT', style: TextStyle(fontSize: 8.8, fontWeight: FontWeight.w900, letterSpacing: 1.15)),
                    SizedBox(height: 3),
                    Text('VYEA styles from your real inputs.', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
              _miniPill('$readyInputs/3 READY'),
            ],
          ),
          const SizedBox(height: 13),
          _contextRow(Icons.palette_outlined, colourText),
          const SizedBox(height: 7),
          _contextRow(Icons.person_outline_rounded, style.hasTiBModel ? 'Personal TiB ready' : 'Personal TiB not set'),
          const SizedBox(height: 7),
          _contextRow(Icons.checkroom_outlined, '${style.wardrobe.length} wardrobe pieces'),
          const SizedBox(height: 7),
          _contextRow(Icons.style_outlined, styleText),
        ],
      ),
    );
  }

  Widget _contextRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 10.5, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  Widget _heading(String title, String subtitle) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: AppColors.textMuted, fontSize: 9.5, fontWeight: FontWeight.w900, letterSpacing: 1.3)),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11.5, height: 1.35)),
        ],
      );

  Widget _heroAction(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(28),
      child: InkWell(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TalkToTibScreen())),
        borderRadius: BorderRadius.circular(28),
        child: Ink(
          padding: const EdgeInsets.fromLTRB(19, 20, 18, 18),
          decoration: BoxDecoration(gradient: AppGradients.primary, borderRadius: BorderRadius.circular(28)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(width: 48, height: 48, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle), child: const Icon(Icons.chat_bubble_outline_rounded, color: AppColors.primary, size: 22)),
                  const Spacer(),
                  _miniPill('FREE'),
                ],
              ),
              const SizedBox(height: 18),
              const Text('Talk it through\nwith VYEA.', style: TextStyle(color: Colors.white, fontSize: 25, height: 1.04, fontWeight: FontWeight.w900, letterSpacing: -.75)),
              const SizedBox(height: 7),
              const Text('Ask about your wardrobe, colours, proportions or what to wear next. Then move into a complete look when you are ready.', style: TextStyle(color: Colors.white70, fontSize: 11.8, height: 1.45)),
              const SizedBox(height: 17),
              Row(children: [_tag('Ask'), const SizedBox(width: 7), _tag('Explore'), const SizedBox(width: 7), _tag('Build'), const Spacer(), const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 20)]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _miniPill(String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: .16), borderRadius: BorderRadius.circular(99)),
        child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: .8)),
      );

  Widget _tag(String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: .12), borderRadius: BorderRadius.circular(10)),
        child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.w800)),
      );

  Widget _toolCard({required IconData icon, required String eyebrow, required String title, required String subtitle, required VoidCallback onTap}) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(21),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(21),
        child: Ink(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(21), border: Border.all(color: AppColors.border)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(width: 42, height: 42, decoration: const BoxDecoration(color: AppColors.secondary, shape: BoxShape.circle), child: Icon(icon, color: AppColors.primary, size: 20)),
              const SizedBox(height: 13),
              Text(eyebrow, style: const TextStyle(color: AppColors.textMuted, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 1)),
              const SizedBox(height: 4),
              Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
              const SizedBox(height: 5),
              Text(subtitle, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.textSecondary, fontSize: 10.5, height: 1.35)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _modelFeature(BuildContext context, PersonalStyleProvider style) => _visualFeature(
        context,
        eyebrow: 'PERSONAL MODEL',
        title: 'Your VYEA Model',
        subtitle: style.hasTiBModel ? 'Your personal model is ready to support more tailored styling.' : 'Create your personal model for more tailored styling.',
        icon: Icons.person_outline_rounded,
        background: AppColors.surface,
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PersonalTibModelScreen())),
      );

  Widget _virtualFeature(BuildContext context) => _visualFeature(
        context,
        eyebrow: 'VISUAL STYLING',
        title: 'Dress Your Model',
        subtitle: 'Explore your styling direction in a visual workspace.',
        icon: Icons.view_in_ar_rounded,
        background: null,
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AIVirtualStylingStudioScreen())),
      );

  Widget _talkFeature(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(21),
      child: InkWell(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TalkToTibScreen())),
        borderRadius: BorderRadius.circular(21),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(21), border: Border.all(color: AppColors.border)),
          child: const Row(
            children: [
              _ConversationIcon(),
              SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Quick styling question?', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
                    SizedBox(height: 4),
                    Text('One question is enough. Start here, then build the look.', style: TextStyle(color: AppColors.textSecondary, fontSize: 10.8, height: 1.35)),
                  ],
                ),
              ),
              SizedBox(width: 8),
              Icon(Icons.arrow_forward_rounded, color: AppColors.primary, size: 19),
            ],
          ),
        ),
      ),
    );
  }

  Widget _visualFeature(BuildContext context, {required String eyebrow, required String title, required String subtitle, required IconData icon, required VoidCallback onTap, Color? background}) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(21),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(21),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: background, gradient: background == null ? AppGradients.premium : null, borderRadius: BorderRadius.circular(21), border: Border.all(color: AppColors.border)),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(width: 48, height: 48, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle), child: Icon(icon, color: AppColors.primaryDark, size: 22)),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(eyebrow, style: const TextStyle(color: AppColors.primaryDark, fontSize: 7.8, fontWeight: FontWeight.w900, letterSpacing: .85)),
                    const SizedBox(height: 4),
                    Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 5),
                    Text(subtitle, style: const TextStyle(color: AppColors.textSecondary, fontSize: 10.8, height: 1.38)),
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

class _ConversationIcon extends StatelessWidget {
  const _ConversationIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 46,
      decoration: const BoxDecoration(color: AppColors.secondary, shape: BoxShape.circle),
      child: const Icon(Icons.forum_outlined, color: AppColors.primary, size: 21),
    );
  }
}
