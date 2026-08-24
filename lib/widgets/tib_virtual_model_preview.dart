import 'package:flutter/material.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_gradients.dart';
import '../services/tib_avatar_service.dart';
import '../services/tib_model_service.dart';

/// Interactive 3D TiB Model preview.
class TibVirtualModelPreview extends StatefulWidget {
  const TibVirtualModelPreview({
    super.key,
    required this.model,
    this.height = 420,
    this.modelUrl,
  });

  final TibModelProfile model;
  final double height;
  final String? modelUrl;

  @override
  State<TibVirtualModelPreview> createState() => _TibVirtualModelPreviewState();
}

class _TibVirtualModelPreviewState extends State<TibVirtualModelPreview> {
  bool _autoRotate = true;
  String? _storedAvatarUrl;
  String _avatarStatus = TibAvatarService.statusBase;
  bool _loadingAvatar = true;

  @override
  void initState() {
    super.initState();
    _loadAvatar();
  }

  @override
  void didUpdateWidget(covariant TibVirtualModelPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.model.facePath != widget.model.facePath ||
        oldWidget.model.bodyPath != widget.model.bodyPath ||
        oldWidget.model.bodyShape != widget.model.bodyShape ||
        oldWidget.model.faceShape != widget.model.faceShape) {
      _loadAvatar();
    }
  }

  Future<void> _loadAvatar() async {
    if (mounted) setState(() => _loadingAvatar = true);
    final url = await TibAvatarService.getAvatarUrl();
    final status = await TibAvatarService.getStatus();
    if (!mounted) return;
    setState(() {
      _storedAvatarUrl = url;
      _avatarStatus = status;
      _loadingAvatar = false;
    });
  }

  String get _modelUrl =>
      widget.modelUrl ?? _storedAvatarUrl ?? TibAvatarService.fallbackAvatarUrl;

  bool get _isPersonalAvatar =>
      _storedAvatarUrl != null && _storedAvatarUrl!.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final face = widget.model.faceFile;
    final ready = widget.model.isComplete;

    return Container(
      height: widget.height,
      decoration: BoxDecoration(
        gradient: AppGradients.soft,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.primarySoft),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned.fill(
            child: ModelViewer(
              key: ValueKey(_modelUrl),
              src: _modelUrl,
              alt: _isPersonalAvatar
                  ? 'Personalised 3D TiB avatar'
                  : 'Interactive 3D TiB fashion model',
              backgroundColor: Colors.transparent,
              cameraControls: true,
              autoRotate: _autoRotate,
              autoRotateDelay: 1200,
              disableZoom: false,
              touchAction: TouchAction.panY,
              interactionPrompt: InteractionPrompt.auto,
              interactionPromptStyle: InteractionPromptStyle.basic,
              orbitSensitivity: 1,
            ),
          ),
          if (_loadingAvatar)
            const Positioned.fill(
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
          Positioned(
            top: 16,
            left: 16,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppColors.surface.withValues(alpha: .94),
                shape: BoxShape.circle,
              ),
              child: Container(
                width: 48,
                height: 48,
                clipBehavior: Clip.antiAlias,
                decoration: const BoxDecoration(shape: BoxShape.circle),
                child: face != null && face.existsSync()
                    ? Image.file(face, fit: BoxFit.cover)
                    : const Icon(
                        Icons.person_rounded,
                        color: AppColors.primary,
                        size: 28,
                      ),
              ),
            ),
          ),
          Positioned(
            top: 18,
            right: 16,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _pill(
                  icon: Icons.threesixty_rounded,
                  label: _isPersonalAvatar ? 'MY 3D' : '360°',
                ),
                const SizedBox(width: 7),
                _iconButton(
                  icon: _autoRotate
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                  tooltip: _autoRotate ? 'Pause rotation' : 'Auto rotate',
                  onPressed: () => setState(() => _autoRotate = !_autoRotate),
                ),
              ],
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(
                color: AppColors.surface.withValues(alpha: .94),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.swipe_rounded,
                    size: 18,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _isPersonalAvatar
                          ? 'Your personalised 3D avatar · drag to rotate'
                          : _avatarStatus == TibAvatarService.statusReady
                              ? 'Your TiB Avatar is ready · drag to explore'
                              : 'Drag to explore your TiB model · auto-rotating',
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  Text(
                    ready ? widget.model.bodyShape : 'Model setup',
                    style: const TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w900,
                      color: AppColors.primaryDark,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (ready && !_isPersonalAvatar)
            Positioned(
              left: 16,
              right: 16,
              top: 82,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.surface.withValues(alpha: .9),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: Text(
                  'Base 3D preview · ${widget.model.faceShape} face · ${widget.model.bodyShape} body',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _pill({required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: .94),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.primaryDark),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }

  Widget _iconButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: AppColors.surface.withValues(alpha: .94),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Icon(icon, size: 17, color: AppColors.primaryDark),
          ),
        ),
      ),
    );
  }
}
