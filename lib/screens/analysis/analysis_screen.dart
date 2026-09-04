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
import 'face_scan_screen.dart';
import 'history/analysis_history_screen.dart';
import 'season_colour_guide_screen.dart';

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
      curve: Interval(begin, end, curve: Curves.easeOutCubic),
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

  Future<void> openFaceScan() async {
    if (context.read<AnalysisProvider>().isLoading) return;
    final file = await Navigator.push<File?>(
      context,
      MaterialPageRoute(builder: (_) => const FaceScanScreen()),
    );
    if (!mounted || file == null) return;
    context.read<AnalysisProvider>().setImage(file);
  }

  Future<void> pickGallery() async {
    final provider = context.read<AnalysisProvider>();
    if (provider.isLoading) return;
    final image = await ImagePickerService.pickGallery();
    if (image == null || !mounted) return;
    provider.setImage(image);
  }

  void removeSelectedPhoto() {
    final provider = context.read<AnalysisProvider>();
    if (provider.isLoading) return;
    provider.clear();
  }

  Future<void> analyse() async {
    final provider = context.read<AnalysisProvider>();
    if (provider.isLoading) return;
    final currentUser = AuthService.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login before starting an analysis.')),
      );
      return;
    }

    final success = await provider.analyse(uid: currentUser.uid);
    if (!mounted) return;

    if (success && provider.result != null) {
      final completed = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => AnalysisResultScreen(result: provider.result!),
        ),
      );
      if (!mounted) return;
      if (completed == true) {
        provider.clear();
        Navigator.pop(context, true);
      }
    } else if (provider.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(provider.errorMessage!)),
      );
    }
  }

  void openAnalysisHistory() {
    if (context.read<AnalysisProvider>().isLoading) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AnalysisHistoryScreen()),
    );
  }

  void openSeasonGuide() {
    if (context.read<AnalysisProvider>().isLoading) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SeasonColourGuideScreen()),
    );
  }

  Widget _buildHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: const BoxDecoration(
            color: _soft,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.face_retouching_natural,
            color: _brown,
            size: 27,
          ),
        ),
        const SizedBox(width: 14),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Find Your Colours',
                style: TextStyle(
                  color: _text,
                  fontSize: 25,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                ),
              ),
              SizedBox(height: 5),
              Text(
                'Discover the palette that feels most like you.',
                style: TextStyle(
                  color: _muted,
                  fontSize: 14,
                  height: 1.4,
                ),
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
        color: isPremium
            ? AppColors.premiumAccentLight
            : AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isPremium
                ? Icons.workspace_premium_outlined
                : Icons.palette_outlined,
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
                    Expanded(
                      child: Text(
                        isPremium
                            ? 'Premium Colour Analysis'
                            : 'Personal Colour Analysis',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: _text,
                        ),
                      ),
                    ),
                    if (isPremium)
                      const PremiumBadge(compact: true),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  isPremium
                      ? 'Explore deeper colour insights and a more personalised seasonal profile.'
                      : 'Start with your personalised colour profile and use it across your wardrobe and styling.',
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

  Widget _buildImagePreview(File? selectedImage) {
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
            ? const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 38,
                    backgroundColor: _soft,
                    child: Icon(
                      Icons.center_focus_strong_rounded,
                      size: 36,
                      color: _brown,
                    ),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Add a clear photo',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 5),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 30),
                    child: Text(
                      'Use natural light and keep your face visible.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: _muted, fontSize: 12),
                    ),
                  ),
                ],
              )
            : ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.xl),
                child: Image.file(selectedImage, fit: BoxFit.cover),
              ),
      ),
    );
  }

  Widget _buildHowItWorks() {
    const steps = [
      ('01', 'Choose a photo', 'Use Face Scan or pick a clear photo from your gallery.'),
      ('02', 'Let VYEA analyse', 'Your image is used to build a personal seasonal colour profile.'),
      ('03', 'Style with it', 'Use your palette across outfits, wardrobe matching and AI styling.'),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'HOW VYEA WORKS',
            style: TextStyle(
              color: _muted,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 15),
          ...steps.map(
            (step) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: _soft,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      step.$1,
                      style: const TextStyle(
                        color: _brown,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          step.$2,
                          style: const TextStyle(
                            color: _text,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          step.$3,
                          style: const TextStyle(
                            color: _muted,
                            fontSize: 11.5,
                            height: 1.4,
                          ),
                        ),
                      ],
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

  @override
  Widget build(BuildContext context) {
    return Consumer<AnalysisProvider>(
      builder: (context, provider, _) {
        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            title: const Text('Colour Analysis'),
            actions: [
              IconButton(
                tooltip: 'Season Colour Guide',
                onPressed: provider.isLoading ? null : openSeasonGuide,
                icon: const Icon(Icons.menu_book_outlined),
              ),
              IconButton(
                tooltip: 'Analysis History',
                onPressed: provider.isLoading ? null : openAnalysisHistory,
                icon: const Icon(Icons.history_rounded),
              ),
            ],
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _reveal(_headerReveal, _buildHeader()),
                  const SizedBox(height: 20),
                  _buildAnalysisAccessCard(provider.isPremium),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: provider.isLoading ? null : openSeasonGuide,
                    icon: const Icon(Icons.auto_awesome_rounded),
                    label: const Text('Explore the 4 Season Colour Guide'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(46),
                    ),
                  ),
                  const SizedBox(height: 18),
                  _reveal(
                    _imageReveal,
                    _buildImagePreview(provider.selectedImage),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: provider.isLoading ? null : openFaceScan,
                          icon: const Icon(Icons.face_retouching_natural),
                          label: const Text('Face Scan'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: provider.isLoading ? null : pickGallery,
                          icon: const Icon(Icons.photo_library_outlined),
                          label: const Text('Gallery'),
                        ),
                      ),
                    ],
                  ),
                  if (provider.selectedImage != null) ...[
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.center,
                      child: TextButton.icon(
                        onPressed: provider.isLoading
                            ? null
                            : removeSelectedPhoto,
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          size: 18,
                        ),
                        label: const Text('Remove Photo & Scan Again'),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.primaryDark,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 6),
                  _reveal(
                    _actionsReveal,
                    PrimaryButton(
                      text: provider.isLoading
                          ? 'Analysing your colours…'
                          : 'Analyse My Colours',
                      icon: Icons.auto_awesome_rounded,
                      onPressed: provider.selectedImage == null ||
                              provider.isLoading
                          ? null
                          : analyse,
                    ),
                  ),
                  const SizedBox(height: 22),
                  _reveal(_actionsReveal, _buildHowItWorks()),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
