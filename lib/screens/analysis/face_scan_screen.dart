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
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 0),
              child: Row(
                children: [
                  Material(
                    color: AppColors.surface,
                    shape: const CircleBorder(),
                    child: IconButton(
                      tooltip: 'Back',
                      onPressed: _busy ? null : () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                    ),
                  ),
                  const Spacer(),
                  const Text(
                    '5 of 5',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                  const Spacer(),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(64, 0, 64, 4),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.full),
                child: const LinearProgressIndicator(
                  minHeight: 3,
                  value: 1,
                  backgroundColor: AppColors.border,
                  valueColor: AlwaysStoppedAnimation(AppColors.primary),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 18, 20, 12),
              child: Column(
                children: [
                  Text(
                    'Let’s scan your\nbeautiful you ✨',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.w800,
                      height: 1.1,
                      letterSpacing: -.4,
                    ),
                  ),
                  SizedBox(height: 9),
                  Text(
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
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: FlashFaceScanPanel(
                  busy: _busy,
                  onCaptured: _onCaptured,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
