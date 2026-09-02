import 'package:flutter/material.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_gradients.dart';
import '../services/tib_avatar_service.dart';
import '../services/tib_model_service.dart';

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

  String get _modelUrl => widget.modelUrl ?? _storedAvatarUrl ?? '';

  bool get _hasPersonal3D => _modelUrl.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final face = widget.model.faceFile;
    final body = widget.model.bodyFile;
    final ready = widget.model.isComplete;
    final hasBodyReference = body != null && body.existsSync();

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
            child: _hasPersonal3D
                ? ModelViewer(
                    key: ValueKey(_modelUrl),
                    src: _modelUrl,
                    alt: 'Personalised 3D TiB avatar',
                    backgroundColor: Colors.transparent,
                    cameraControls: true,
                    autoRotate: _autoRotate,
                    autoRotateDelay: 1200,
                    disableZoom: false,
                    touchAction: TouchAction.panY,
                    interactionPrompt: InteractionPrompt.auto,
                    interactionPromptStyle: InteractionPromptStyle.basic,
                    orbitSensitivity: 1,
                  )
                : hasBodyReference
                    ? Image.file(body, fit: BoxFit.contain)
                    : const Center(
                        child: Icon(
                          Icons.person_rounded,
                          size: 72,
                          color: AppColors.primary,
                        ),
                      ),
          ),
          if (_loadingAvatar)
            const Positioned.fill(
              child: IgnorePointer(
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              ),
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
                  icon: _hasPersonal3D
                      ? Icons.threesixty_rounded
                      : Icons.photo_camera_front_rounded,
                  label: _hasPersonal3D ? 'MY 3D' : 'MY BODY',
                ),
                if (_hasPersonal3D) ...[
                  const SizedBox(width: 7),
                  _iconButton(
                    icon: _autoRotate
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    tooltip: _autoRotate ? 'Pause rotation' : 'Auto rotate',
                    onPressed: () => setState(() => _autoRotate = !_autoRotate),
                  ),
                ],
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
                  Icon(
                    _hasPersonal3D
                        ? Icons.swipe_rounded
                        : Icons.accessibility_new_rounded,
                    size: 18,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _hasPersonal3D
                          ? 'Your personalised 3D avatar · drag to rotate'
                          : hasBodyReference
                              ? 'Your real full-body reference · used as the silhouette anchor'
                              : _avatarStatus == TibAvatarService.statusReady
                                  ? 'Your TiB Avatar is ready'
                                  : 'Complete your Personal TiB Model to preview your real body',
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
          if (ready && !_hasPersonal3D && hasBodyReference)
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
                  'YOUR REAL BODY REFERENCE · ${widget.model.height.toStringAsFixed(0)} cm · ${widget.model.bodyShape}',
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
