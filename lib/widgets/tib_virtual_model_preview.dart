import 'dart:io';

import 'package:flutter/material.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_gradients.dart';
import '../services/tib_model_service.dart';

/// Interactive 3D TiB Model preview.
///
/// The viewer is intentionally isolated from the AI generation pipeline so a
/// future personalised GLB/GLTF avatar URL can be supplied without changing
/// the surrounding screens. The current fallback model is a CC0 female
/// fashion mannequin from the Khronos glTF Sample Assets collection.
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

  static const String fallbackModelUrl =
      'https://raw.githubusercontent.com/KhronosGroup/glTF-Sample-Assets/main/Models/Corset/glTF-Binary/Corset.glb';

  @override
  State<TibVirtualModelPreview> createState() => _TibVirtualModelPreviewState();
}

class _TibVirtualModelPreviewState extends State<TibVirtualModelPreview> {
  bool _autoRotate = true;

  @override
  Widget build(BuildContext context) {
    final face = widget.model.faceFile;
    final modelUrl = widget.modelUrl ?? TibVirtualModelPreview.fallbackModelUrl;
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
              src: modelUrl,
              alt: 'Interactive 3D TiB fashion model',
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

          // Identity reference — the scanned face stays visible without
          // pretending a 2D face photo is already a true 3D head texture.
          Positioned(
            top: 16,
            left: 16,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppColors.surface.withValues(alpha: .94),
                shape: BoxShape.circle,
                boxShadow: const [
                  BoxShadow(
                    blurRadius: 14,
                    offset: Offset(0, 5),
                    color: Color(0x22000000),
                  ),
                ],
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
                  label: '360°',
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
                      _autoRotate
                          ? 'Drag to explore your model · auto-rotating'
                          : 'Drag left or right to explore your model',
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
