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

  Animation<double> _stage(double begin, double end) => CurvedAnimation(
        parent: _revealController,
        curve: Interval(begin, end, curve: Curves.easeOutCubic),
      );

  Widget _reveal(Animation<double> animation, Widget child) => AnimatedBuilder(
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'COLOUR ANALYSIS',
          style: TextStyle(
            color: _brown,
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.7,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Find the colours\nthat feel like you.',
          style: TextStyle(
            color: _text,
            fontSize: 31,
            height: 1.03,
            fontWeight: FontWeight.w800,
            letterSpacing: -1.0,
          ),
        ),
        const SizedBox(height: 9),
        const Text(
          'A guided AI analysis to build your personal colour identity.',
          style: TextStyle(
            color: _muted,
            fontSize: 13.5,
            height: 1.45,
          ),
        ),
      ],
    );
  }

  Widget _buildAnalysisAccessCard(bool isPremium) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: isPremium ? AppColors.premiumAccentLight : AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: const BoxDecoration(
              color: _soft,
              shape: BoxShape.circle,
            ),
            child: Icon(
              isPremium
                  ? Icons.workspace_premium_outlined
                  : Icons.palette_outlined,
              color: _brown,
              size: 20,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        isPremium
                            ? 'Premium colour insights'
                            : 'Personal colour analysis',
                        style: const TextStyle(
                          color: _text,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (isPremium) const PremiumBadge(compact: true),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  isPremium
                      ? 'More personalised seasonal detail.'
                      : 'Your result becomes the colour foundation for VYEA styling.',
                  style: const TextStyle(
                    color: _muted,
                    fontSize: 11.5,
                    height: 1.35,
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
      aspectRatio: 0.98,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: AppColors.border),
        ),
        child: selectedImage == null
            ? const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 34,
                    backgroundColor: _soft,
                    child: Icon(
                      Icons.center_focus_strong_rounded,
                      size: 32,
                      color: _brown,
                    ),
                  ),
                  SizedBox(height: 15),
                  Text(
                    'Start with a clear photo',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                  SizedBox(height: 5),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 30),
                    child: Text(
                      'Natural light works best. Keep your face visible and avoid heavy filters.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: _muted, fontSize: 11.5, height: 1.4),
                    ),
                  ),
                ],
              )
            : ClipRRect(
                borderRadius: BorderRadius.circular(26),
                child: Image.file(selectedImage, fit: BoxFit.cover),
              ),
      ),
    );
  }

  Widget _buildPhotoQualityGuide(bool hasImage) {
    final items = [
      ('LIGHT', 'Natural and even', Icons.wb_sunny_outlined),
      ('FACE', 'Fully visible', Icons.face_retouching_natural),
      ('FILTER', 'Keep it natural', Icons.filter_alt_off_outlined),
    ];
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 13),
      decoration: BoxDecoration(
        color: hasImage ? AppColors.surface : AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  hasImage ? 'PHOTO READY' : 'BEFORE YOU START',
                  style: const TextStyle(
                    color: _brown,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.1,
                  ),
                ),
              ),
              if (hasImage)
                const Icon(Icons.check_circle_outline_rounded, size: 17, color: AppColors.success),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              for (var index = 0; index < items.length; index++) ...[
                if (index > 0) const SizedBox(width: 7),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      children: [
                        Icon(items[index].$3, size: 17, color: _brown),
                        const SizedBox(height: 5),
                        Text(items[index].$1, style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: .6, color: _muted)),
                        const SizedBox(height: 2),
                        Text(items[index].$2, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 9.2, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHowItWorks() {
    const steps = [
      ('01', 'Choose a photo', 'Use Face Scan or pick a clear photo from your gallery.'),
      ('02', 'Let VYEA analyse', 'Build your personal seasonal colour profile.'),
      ('03', 'Style with it', 'Use your palette across outfits, wardrobe matching and AI styling.'),
    ];

    return Container(
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
            'YOUR COLOUR JOURNEY',
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
        final hasImage = provider.selectedImage != null;
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
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 34),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _reveal(_headerReveal, _buildHeader()),
                  const SizedBox(height: 18),
                  _buildAnalysisAccessCard(provider.isPremium),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: provider.isLoading ? null : openSeasonGuide,
                    icon: const Icon(Icons.menu_book_outlined),
                    label: const Text('Explore Season Colour Guide'),
                    style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(44)),
                  ),
                  const SizedBox(height: 18),
                  _reveal(_imageReveal, _buildImagePreview(provider.selectedImage)),
                  const SizedBox(height: 10),
                  _buildPhotoQualityGuide(hasImage),
                  const SizedBox(height: 11),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: provider.isLoading ? null : openFaceScan,
                          icon: const Icon(Icons.face_retouching_natural),
                          label: const Text('Face Scan'),
                        ),
                      ),
                      const SizedBox(width: 9),
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
                    const SizedBox(height: 6),
                    Align(
                      alignment: Alignment.center,
                      child: TextButton.icon(
                        onPressed: provider.isLoading ? null : removeSelectedPhoto,
                        icon: const Icon(Icons.delete_outline_rounded, size: 17),
                        label: const Text('Choose another photo'),
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  _reveal(
                    _actionsReveal,
                    PrimaryButton(
                      text: provider.isLoading ? 'Analysing your colours…' : 'Analyse My Colours',
                      icon: Icons.auto_awesome_rounded,
                      onPressed: provider.selectedImage == null || provider.isLoading ? null : analyse,
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
