import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_radius.dart';
import '../../widgets/flash_face_scan_panel.dart';

/// Single-photo face scan used by Colour Analysis and Flash Profile.
///
/// This is intentionally a straight-on scan. It does not ask the user to
/// turn left/right/up/down or take five separate photos.
class FaceScanScreen extends StatefulWidget {
  const FaceScanScreen({super.key});

  @override
  State<FaceScanScreen> createState() => _FaceScanScreenState();
}

class _FaceScanScreenState extends State<FaceScanScreen> {
  bool _busy = false;

  void _onCaptured(File file) {
    if (!mounted) return;
    setState(() => _busy = true);
    Navigator.pop(context, file);
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < 600;
    final contentWidth = width > 900 ? 760.0 : width - 32;
    final horizontal = compact ? 16.0 : 24.0;
    final titleSize = compact ? 25.0 : 30.0;
    final panelPadding = compact ? 16.0 : 28.0;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: contentWidth),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 0),
                child: Row(
                  children: [
                    Material(
                      color: AppColors.surface,
                      shape: const CircleBorder(),
                      child: Semantics(
                        button: true,
                        label: 'Back',
                        child: IconButton(
                          tooltip: 'Back',
                          onPressed: _busy ? null : () => Navigator.pop(context),
                          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                        ),
                      ),
                    ),
                    const Spacer(),
                    const Semantics(
                      label: 'Face scan step 5 of 5',
                      child: Text(
                        '5 of 5',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                    ),
                    const Spacer(),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
            ),
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: contentWidth),
              child: Padding(
                padding: EdgeInsets.fromLTRB(compact ? 58 : 110, 0, compact ? 58 : 110, 4),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.full),
                  child: Semantics(
                    label: 'Face scan progress, step 5 of 5',
                    child: const LinearProgressIndicator(
                      minHeight: 3,
                      value: 1,
                      backgroundColor: AppColors.border,
                      valueColor: AlwaysStoppedAnimation(AppColors.primary),
                    ),
                  ),
                ),
              ),
            ),
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: contentWidth),
              child: Padding(
                padding: EdgeInsets.fromLTRB(horizontal, compact ? 18 : 22, horizontal, 12),
                child: Column(
                  children: [
                    Semantics(
                      header: true,
                      child: Text(
                        'Let’s scan your\nbeautiful you ✨',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: titleSize,
                          fontWeight: FontWeight.w800,
                          height: 1.1,
                          letterSpacing: -.4,
                        ),
                      ),
                    ),
                    const SizedBox(height: 9),
                    const Text(
                      'We’ll analyze your natural coloring\nto find the best shades for you',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: contentWidth),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(panelPadding, 4, panelPadding, 8),
                  child: Semantics(
                    liveRegion: true,
                    label: _busy ? 'Capturing face scan' : 'Face scan camera area',
                    child: FlashFaceScanPanel(
                      busy: _busy,
                      onCaptured: _onCaptured,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
