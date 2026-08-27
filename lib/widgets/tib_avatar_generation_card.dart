import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_gradients.dart';
import '../screens/premium/ai_avatar_styling_screen.dart';
import '../services/tib_avatar_service.dart';
import '../services/tib_model_service.dart';

class TibAvatarGenerationCard extends StatefulWidget {
  const TibAvatarGenerationCard({super.key, required this.profile});

  final TibModelProfile profile;

  @override
  State<TibAvatarGenerationCard> createState() => _TibAvatarGenerationCardState();
}

class _TibAvatarGenerationCardState extends State<TibAvatarGenerationCard> {
  bool _loading = true;
  String _status = TibAvatarService.statusBase;
  bool _needsUpdate = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final status = await TibAvatarService.getStatus();
    final needs = await TibAvatarService.needsRegeneration(widget.profile);
    if (!mounted) return;
    setState(() {
      _status = status;
      _needsUpdate = needs;
      _loading = false;
    });
  }

  Future<void> _openAiAvatar() async {
    if (!await TibAvatarService.canBuildPersonalAvatar(widget.profile)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Complete your TiB Model first.')),
      );
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AiAvatarStylingScreen()),
    );
    if (mounted) await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox(
        height: 110,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    final ready = _status == TibAvatarService.statusReady && !_needsUpdate;
    final title = ready ? 'Create another AI look' : 'Create your AI TiB Avatar';
    final subtitle = ready
        ? 'Use your scanned face, wardrobe and style profile to create a new virtual look.'
        : 'Your face scan becomes the identity of a virtual styling model. TiB finds clothes and shoes that suit you and shows the result on your virtual person.';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: AppGradients.soft,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.primarySoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: AppColors.primarySoft,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: AppColors.primaryDark,
                  size: 22,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 10.5,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              _chip('Face · ${widget.profile.faceShape}'),
              _chip('Body · ${widget.profile.bodyShape}'),
              _chip('Colour-aware'),
              _chip('Clothes + Shoes'),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _openAiAvatar,
              icon: const Icon(Icons.face_retouching_natural_rounded),
              label: Text(
                ready ? 'Create New Virtual Look' : 'Create My AI Avatar',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: .72),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800),
      ),
    );
  }
}
