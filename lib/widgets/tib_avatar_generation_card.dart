import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_gradients.dart';
import '../services/tib_avatar_service.dart';
import '../services/tib_model_service.dart';
import '../services/tib_personal_avatar_service.dart';

class TibAvatarGenerationCard extends StatefulWidget {
  const TibAvatarGenerationCard({super.key, required this.profile});

  final TibModelProfile profile;

  @override
  State<TibAvatarGenerationCard> createState() => _TibAvatarGenerationCardState();
}

class _TibAvatarGenerationCardState extends State<TibAvatarGenerationCard> {
  bool _loading = true;
  bool _generating = false;
  bool _needsUpdate = false;
  String _status = TibAvatarService.statusBase;
  String _message = '';

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

  Future<void> _generate() async {
    if (_generating) return;
    final canBuild = await TibAvatarService.canBuildPersonalAvatar(widget.profile);
    if (!canBuild) {
      setState(() => _message = 'Complete your TiB Model first.');
      return;
    }

    setState(() {
      _generating = true;
      _status = TibAvatarService.statusGenerating;
      _message = 'Creating your personalised 3D Avatar…';
    });

    await TibAvatarService.markGenerating(widget.profile);
    final result = await TibPersonalAvatarService.generate(widget.profile);

    if (!mounted) return;
    setState(() {
      _generating = false;
      _message = result.status;
    });
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox(height: 110, child: Center(child: CircularProgressIndicator(strokeWidth: 2)));
    }

    final ready = _status == TibAvatarService.statusReady && !_needsUpdate;
    final generating = _generating || _status == TibAvatarService.statusGenerating;
    final title = ready
        ? 'Your TiB 3D Avatar is ready'
        : generating
            ? 'Creating your TiB Avatar…'
            : _needsUpdate
                ? 'Your TiB Avatar needs an update'
                : 'Create your Personal 3D Avatar';

    final subtitle = ready
        ? 'This avatar can be reused across Virtual Try-On and AI Styling.'
        : _needsUpdate
            ? 'Your body profile has changed. Regenerate your avatar to keep the proportions accurate.'
            : 'Use your face scan, body shape and measurements to create your reusable avatar.';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: ready || _needsUpdate ? AppGradients.soft : null,
        color: ready || _needsUpdate ? null : AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: ready || _needsUpdate ? AppColors.primarySoft : AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(width: 42, height: 42, decoration: const BoxDecoration(color: AppColors.primarySoft, shape: BoxShape.circle), child: Icon(ready ? Icons.check_rounded : Icons.view_in_ar_rounded, color: AppColors.primaryDark, size: 21)),
            const SizedBox(width: 11),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900)), const SizedBox(height: 3), Text(subtitle, style: const TextStyle(color: AppColors.textSecondary, fontSize: 10.5, height: 1.35))])),
          ]),
          const SizedBox(height: 13),
          Wrap(spacing: 7, runSpacing: 7, children: [
            _chip('Face · ${widget.profile.faceShape}'),
            _chip('Body · ${widget.profile.bodyShape}'),
            _chip('${_n(widget.profile.height)} cm'),
            _chip('Bust ${_n(widget.profile.bust)}'),
            _chip('Waist ${_n(widget.profile.waist)}'),
            _chip('Hips ${_n(widget.profile.hips)}'),
          ]),
          if (_message.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(_message, style: const TextStyle(color: AppColors.textSecondary, fontSize: 10.5, height: 1.4)),
          ],
          const SizedBox(height: 14),
          SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: generating ? null : _generate, icon: generating ? const SizedBox(width: 17, height: 17, child: CircularProgressIndicator(strokeWidth: 2)) : Icon(ready ? Icons.refresh_rounded : Icons.auto_awesome_rounded), label: Text(generating ? 'Generating…' : ready ? 'Regenerate Avatar' : _needsUpdate ? 'Update My Avatar' : 'Create My 3D Avatar'))),
        ],
      ),
    );
  }

  String _n(double value) => value == value.roundToDouble() ? value.toInt().toString() : value.toStringAsFixed(1);

  Widget _chip(String text) => Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6), decoration: BoxDecoration(color: AppColors.surfaceMuted, borderRadius: BorderRadius.circular(13)), child: Text(text, style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800)));
}
