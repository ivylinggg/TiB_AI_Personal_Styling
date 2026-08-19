import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_radius.dart';
import '../../providers/analysis_provider.dart';
import '../../services/image_picker_service.dart';
import '../../widgets/premium_badge.dart';
import '../../widgets/primary_button.dart';
import '../auth/auth_service.dart';
import 'analysis_result_screen.dart';
import 'history/analysis_history_screen.dart';

class AnalysisScreen extends StatefulWidget {
  const AnalysisScreen({super.key});

  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen>
    with SingleTickerProviderStateMixin {
  static const _brown = AppColors.primary;
  static const _soft = AppColors.secondary;
  static const _text = AppColors.textPrimary;
  static const _muted = AppColors.textSecondary;

  // One-time entrance reveal (fade + gentle slide-up, no bounce), the
  // same recipe already used across Colour Analysis Result/Dashboard/
  // AI Stylist/Wardrobe/Profile. Plays once on first mount only.
  late final AnimationController _revealController;
  late final Animation<double> _headerReveal;
  late final Animation<double> _imageReveal;
  late final Animation<double> _actionsReveal;

  @override
  void initState() {
    super.initState();
    _revealController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _headerReveal = _stage(0.00, 0.40);
    _imageReveal = _stage(0.15, 0.70);
    _actionsReveal = _stage(0.40, 1.00);
    _revealController.forward();
  }

  Animation<double> _stage(double begin, double end) {
    return CurvedAnimation(
      parent: _revealController,
      curve: Interval(begin, end, curve: Curves.easeOut),
    );
  }

  Widget _reveal(Animation<double> animation, Widget child) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, animatedChild) {
        final value = animation.value.clamp(0.0, 1.0);
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 14),
            child: animatedChild,
          ),
        );
      },
      child: child,
    );
  }

  @override
  void dispose() {
    _revealController.dispose();
    super.dispose();
  }

  // ============================================================
  // CAMERA
  // ============================================================

  Future<void> pickCamera() async {
    final provider = context.read<AnalysisProvider>();

    if (provider.isLoading) {
      return;
    }

    final image = await ImagePickerService.pickCamera();

    if (image == null) {
      return;
    }

    if (!mounted) {
      return;
    }

    provider.setImage(image);
  }

  // ============================================================
  // GALLERY
  // ============================================================

  Future<void> pickGallery() async {
    final provider = context.read<AnalysisProvider>();

    if (provider.isLoading) {
      return;
    }

    final image = await ImagePickerService.pickGallery();

    if (image == null) {
      return;
    }

    if (!mounted) {
      return;
    }

    provider.setImage(image);
  }

  // ============================================================
  // ANALYSE
  // ============================================================

  Future<void> analyse() async {
    final provider = context.read<AnalysisProvider>();

    if (provider.isLoading) {
      return;
    }

    final currentUser = AuthService.currentUser;

    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please login before starting an analysis.'),
        ),
      );

      return;
    }

    final success = await provider.analyse(uid: currentUser.uid);

    if (!mounted) {
      return;
    }

    if (success && provider.result != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AnalysisResultScreen(result: provider.result!),
        ),
      );
    } else if (provider.errorMessage != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(provider.errorMessage!)));
    }
  }

  // ============================================================
  // OPEN HISTORY
  // ============================================================

  void openAnalysisHistory() {
    if (context.read<AnalysisProvider>().isLoading) {
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AnalysisHistoryScreen()),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  Widget _buildHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: const BoxDecoration(color: _soft, shape: BoxShape.circle),
          child: const Icon(
            Icons.face_retouching_natural,
            color: _brown,
            size: 27,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Colour Analysis',
                style: TextStyle(
                  color: _text,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 5),
              const Text(
                'Let’s find the colours that suit you.',
                style: TextStyle(color: _muted, fontSize: 14, height: 1.4),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAnalysisAccessCard(bool isPremium) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: isPremium ? AppColors.premiumAccentLight : AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isPremium ? Icons.workspace_premium_outlined : Icons.palette_outlined,
            color: _brown,
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      isPremium ? 'Premium Colour Analysis' : 'Basic Colour Analysis',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: _text,
                      ),
                    ),
                    if (isPremium) ...[
                      const SizedBox(width: 8),
                      const PremiumBadge(compact: true),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  isPremium
                      ? 'Your analysis includes Premium colour insights and a more personalised result.'
                      : 'Get your personalised colour analysis. Premium insights are available to Premium members.',
                  style: const TextStyle(
                    color: _muted,
                    fontSize: 12.5,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImagePreview(File? selectedImage, bool isLoading) {
    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: Border.all(color: AppColors.border),
        ),
        child: selectedImage == null
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 76,
                    height: 76,
                    decoration: const BoxDecoration(
                      color: _soft,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.face_retouching_natural,
                      size: 36,
                      color: _brown,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Ready when you are',
                    style: TextStyle(
                      color: _text,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      'Take a photo or choose one from your gallery. '
                      'For the best result, keep your face clearly visible.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: _muted, height: 1.4),
                    ),
                  ),
                ],
              )
            : Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.xl),
                    child: Image.file(
                      selectedImage,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    right: 12,
                    top: 12,
                    child: Material(
                      color: AppColors.textPrimary.withValues(alpha: 0.55),
                      shape: const CircleBorder(),
                      child: IconButton(
                        tooltip: 'Choose another photo',
                        onPressed: isLoading ? null : () => pickGallery(),
                        color: AppColors.background,
                        icon: const Icon(Icons.refresh_rounded),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildStatusCard(String status, bool isLoading, File? selectedImage) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _soft,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          if (isLoading)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2.4, color: _brown),
            )
          else
            Icon(
              selectedImage != null ? Icons.check_circle_outline : Icons.info_outline,
              size: 20,
              color: _brown,
            ),
          const SizedBox(width: 12),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: Text(
                status,
                key: ValueKey(status),
                textAlign: TextAlign.left,
                style: const TextStyle(
                  color: _text,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _photoSourceTile({
    required IconData icon,
    required String label,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return Material(
      color: AppColors.surfaceMuted,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: enabled ? onTap : null,
        child: Container(
          height: 96,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 26, color: enabled ? _brown : AppColors.textMuted),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  color: enabled ? _text : AppColors.textMuted,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AnalysisProvider>(
      builder: (context, provider, child) {
        final selectedImage = provider.selectedImage;
        final isLoading = provider.isLoading;

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            backgroundColor: AppColors.background,
            elevation: 0,
            title: const Text('Colour Analysis'),
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _reveal(_headerReveal, _buildHeader()),
                  const SizedBox(height: 18),
                  _reveal(_headerReveal, _buildAnalysisAccessCard(provider.isPremium)),
                  const SizedBox(height: 20),
                  _reveal(
                    _imageReveal,
                    _buildImagePreview(selectedImage, isLoading),
                  ),
                  const SizedBox(height: 16),
                  _reveal(
                    _imageReveal,
                    _buildStatusCard(provider.status, isLoading, selectedImage),
                  ),
                  const SizedBox(height: 20),
                  _reveal(
                    _actionsReveal,
                    Row(
                      children: [
                        Expanded(
                          child: _photoSourceTile(
                            icon: Icons.camera_alt_outlined,
                            label: 'Take a Photo',
                            enabled: !isLoading,
                            onTap: pickCamera,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _photoSourceTile(
                            icon: Icons.photo_outlined,
                            label: 'Gallery',
                            enabled: !isLoading,
                            onTap: pickGallery,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  _reveal(
                    _actionsReveal,
                    PrimaryButton(
                      text: isLoading
                          ? 'Analysing...'
                          : provider.isPremium
                              ? 'Analyse with Premium Insights'
                              : 'Analyse My Colours',
                      icon: Icons.auto_awesome,
                      onPressed: isLoading ? null : analyse,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _reveal(
                    _actionsReveal,
                    const Text(
                      'Your photo is used to create your personalised colour result.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: _muted, fontSize: 12.5),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _reveal(
                    _actionsReveal,
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: isLoading ? null : openAnalysisHistory,
                        icon: const Icon(Icons.history_rounded),
                        label: const Text('View Analysis History'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _brown,
                          side: BorderSide(color: AppColors.border),
                          minimumSize: const Size.fromHeight(52),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
