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
            children: const [
              Text(
                'Colour Analysis',
                style: TextStyle(
                  color: _text,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),
              SizedBox(height: 5),
              Text(
                'A guided AI scan for a more reliable starting point.',
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
                    Expanded(
                      child: Text(
                        isPremium ? 'Premium Colour Analysis' : 'Basic Colour Analysis',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: _text,
                        ),
                      ),
                    ),
                    if (isPremium) const PremiumBadge(compact: true),
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
                      Icons.center_focus_strong_rounded,
                      size: 36,
                      color: _brown,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Add a clear photo', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 5),
                  const Text('Use natural light and keep your face visible.', style: TextStyle(color: _muted, fontSize: 12)),
                ],
              )
            : ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.xl),
                child: Image.file(selectedImage, fit: BoxFit.cover),
              ),
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
                  const SizedBox(height: 18),
                  _reveal(_imageReveal, _buildImagePreview(provider.selectedImage, provider.isLoading)),
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
                  const SizedBox(height: 14),
                  _reveal(
                    _actionsReveal,
                    PrimaryButton(
                      text: provider.isLoading ? 'Analysing your colours…' : 'Analyse My Colours',
                      icon: Icons.auto_awesome_rounded,
                      onPressed: provider.selectedImage == null || provider.isLoading ? null : analyse,
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
