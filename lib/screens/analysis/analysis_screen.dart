import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_radius.dart';
import '../../providers/analysis_provider.dart';
import '../../services/auth_service.dart';
import '../../services/image_picker_service.dart';
import '../../widgets/primary_button.dart';
import 'analysis_result_screen.dart';
import 'history/analysis_history_screen.dart';

class AnalysisScreen extends StatefulWidget {
  const AnalysisScreen({super.key});

  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _header;
  late final Animation<double> _camera;
  late final Animation<double> _tips;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
    _header = _interval(0, .42);
    _camera = _interval(.12, .72);
    _tips = _interval(.35, 1);
  }

  Animation<double> _interval(double begin, double end) => CurvedAnimation(
        parent: _controller,
        curve: Interval(begin, end, curve: Curves.easeOutCubic),
      );

  Widget _reveal(Animation<double> animation, Widget child) {
    return FadeTransition(
      opacity: animation,
      child: AnimatedBuilder(
        animation: animation,
        child: child,
        builder: (_, value) => Transform.translate(
          offset: Offset(0, 14 * (1 - animation.value)),
          child: value,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _camera() async {
    final provider = context.read<AnalysisProvider>();
    if (provider.isLoading) return;
    final image = await ImagePickerService.pickCamera();
    if (!mounted || image == null) return;
    provider.setImage(image);
  }

  Future<void> _gallery() async {
    final provider = context.read<AnalysisProvider>();
    if (provider.isLoading) return;
    final image = await ImagePickerService.pickGallery();
    if (!mounted || image == null) return;
    provider.setImage(image);
  }

  Future<void> _analyse() async {
    final provider = context.read<AnalysisProvider>();
    if (provider.isLoading) return;

    final user = AuthService.currentUser;
    if (user == null) {
      _message('Please login before starting your colour analysis.');
      return;
    }

    final success = await provider.analyse(uid: user.uid);
    if (!mounted) return;

    if (success && provider.result != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AnalysisResultScreen(result: provider.result!),
        ),
      );
    } else if (provider.errorMessage != null) {
      _message(provider.errorMessage!);
    }
  }

  void _message(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  void _history() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AnalysisHistoryScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AnalysisProvider>(
      builder: (context, provider, _) {
        final image = provider.selectedImage;
        final loading = provider.isLoading;

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            title: const Text('Colour Analysis'),
            actions: [
              IconButton(
                tooltip: 'History',
                onPressed: loading ? null : _history,
                icon: const Icon(Icons.history_rounded),
              ),
            ],
          ),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 34),
              children: [
                _reveal(_header, _buildHeader(provider.isPremium)),
                const SizedBox(height: 24),
                _reveal(
                  _camera,
                  _buildCameraFrame(image, loading),
                ),
                const SizedBox(height: 16),
                _reveal(_camera, _buildStatus(provider, image)),
                const SizedBox(height: 22),
                _reveal(_camera, _buildSources(loading)),
                const SizedBox(height: 22),
                _reveal(_tips, _buildTips()),
                const SizedBox(height: 24),
                _reveal(
                  _tips,
                  PrimaryButton(
                    text: loading ? 'Analysing your colours…' : 'Discover My Colours',
                    icon: Icons.auto_awesome_rounded,
                    onPressed: loading || image == null ? null : _analyse,
                  ),
                ),
                const SizedBox(height: 10),
                _reveal(
                  _tips,
                  const Text(
                    'Your photo is used only to create your personalised result.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 11.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(bool premium) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'LET’S FIND YOUR COLOURS',
          style: TextStyle(
            color: AppColors.primaryDark,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 7),
        const Text(
          'Colours that feel\nlike you.',
          style: TextStyle(
            color: AppColors.charcoal,
            fontSize: 31,
            height: 1.08,
            fontWeight: FontWeight.w700,
            letterSpacing: -1,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          premium
              ? 'Premium analysis gives you deeper, more personalised colour guidance.'
              : 'A simple photo is all we need to create your personal colour profile.',
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 14,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildCameraFrame(File? image, bool loading) {
    return Container(
      height: 390,
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (image != null)
            Image.file(image, fit: BoxFit.cover)
          else
            _emptyCamera(),
          if (image == null) _faceGuide(),
          if (loading) _loadingOverlay(),
          if (image != null && !loading)
            Positioned(
              top: 14,
              right: 14,
              child: _roundButton(
                Icons.refresh_rounded,
                _gallery,
                tooltip: 'Choose another photo',
              ),
            ),
        ],
      ),
    );
  }

  Widget _emptyCamera() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.lavenderMist, AppColors.blush],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Center(
        child: Icon(
          Icons.face_retouching_natural_outlined,
          size: 76,
          color: AppColors.primaryDark,
        ),
      ),
    );
  }

  Widget _faceGuide() {
    return Center(
      child: Container(
        width: 190,
        height: 255,
        decoration: BoxDecoration(
          border: Border.all(
            color: Colors.white.withValues(alpha: .9),
            width: 2,
          ),
          borderRadius: BorderRadius.circular(95),
        ),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            margin: const EdgeInsets.only(bottom: 20),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .88),
              borderRadius: BorderRadius.circular(30),
            ),
            child: const Text(
              'Place your face here',
              style: TextStyle(
                color: AppColors.charcoal,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _loadingOverlay() {
    return Container(
      color: AppColors.charcoal.withValues(alpha: .55),
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 42,
              height: 42,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 16),
            Text(
              'Reading your colour profile…',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _roundButton(
    IconData icon,
    VoidCallback onTap, {
    required String tooltip,
  }) {
    return Material(
      color: Colors.white.withValues(alpha: .92),
      shape: const CircleBorder(),
      child: IconButton(
        tooltip: tooltip,
        onPressed: onTap,
        icon: Icon(icon, color: AppColors.charcoal),
      ),
    );
  }

  Widget _buildStatus(AnalysisProvider provider, File? image) {
    final text = provider.isLoading
        ? provider.status
        : image == null
            ? 'Choose a clear, front-facing photo to begin.'
            : 'Your photo is ready. Take a moment, then discover your palette.';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(
            provider.isLoading
                ? Icons.auto_awesome
                : image == null
                    ? Icons.info_outline_rounded
                    : Icons.check_circle_outline_rounded,
            color: AppColors.primaryDark,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 12.5,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSources(bool loading) {
    return Row(
      children: [
        Expanded(
          child: _source(
            Icons.camera_alt_outlined,
            'Camera',
            loading ? null : _camera,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _source(
            Icons.photo_library_outlined,
            'Gallery',
            loading ? null : _gallery,
          ),
        ),
      ],
    );
  }

  Widget _source(IconData icon, String label, VoidCallback? onTap) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Container(
          height: 62,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: AppColors.primaryDark, size: 21),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.charcoal,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTips() {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: AppColors.lavenderMist,
        borderRadius: BorderRadius.circular(22),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'For a better result',
            style: TextStyle(
              color: AppColors.charcoal,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 12),
          _Tip(icon: Icons.wb_sunny_outlined, text: 'Use natural daylight.'),
          _Tip(icon: Icons.face_outlined, text: 'Keep your full face visible.'),
          _Tip(icon: Icons.no_photography_outlined, text: 'Avoid heavy makeup and filters.'),
          _Tip(icon: Icons.palette_outlined, text: 'Choose a simple, neutral background.'),
        ],
      ),
    );
  }
}

class _Tip extends StatelessWidget {
  final IconData icon;
  final String text;

  const _Tip({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        children: [
          Icon(icon, size: 17, color: AppColors.primaryDark),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
