import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_gradients.dart';
import '../screens/premium/realtime_virtual_try_on_screen.dart';
import '../services/tib_avatar_service.dart';
import '../services/tib_model_service.dart';

/// Entry point for the user's AI Virtual You experience.
class TibAvatarGenerationCard extends StatefulWidget {
  const TibAvatarGenerationCard({super.key, required this.profile});

  final TibModelProfile profile;

  @override
  State<TibAvatarGenerationCard> createState() => _TibAvatarGenerationCardState();
}

class _TibAvatarGenerationCardState extends State<TibAvatarGenerationCard> {
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    await TibAvatarService.getStatus();
    if (!mounted) return;
    setState(() => _loading = false);
  }

  Future<void> _openAiAvatar() async {
    if (!await TibAvatarService.canBuildPersonalAvatar(widget.profile)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Complete your face scan and TiB Model first.')),
      );
      return;
    }

    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const RealtimeVirtualTryOnScreen()),
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
                  Icons.face_retouching_natural_rounded,
                  color: AppColors.primaryDark,
                  size: 22,
                ),
              ),
              const SizedBox(width: 11),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Your Live Virtual Try-On', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
                    SizedBox(height: 3),
                    Text(
                      'See yourself wearing pieces from your own wardrobe in real time.',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 10.5, height: 1.4),
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
              _chip('Live camera'),
              _chip('Your identity'),
              _chip('Your wardrobe'),
              _chip('Real-time swap'),
              _chip('AI VTON'),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _openAiAvatar,
              icon: const Icon(Icons.auto_awesome_rounded),
              label: const Text('Start Live Try-On'),
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
      child: Text(text, style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800)),
    );
  }
}
