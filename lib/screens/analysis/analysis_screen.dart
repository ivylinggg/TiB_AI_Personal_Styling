import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/analysis_provider.dart';
import '../../services/image_picker_service.dart';
import '../../widgets/primary_button.dart';
import '../auth/auth_service.dart';
import 'analysis_result_screen.dart';
import 'history/analysis_history_screen.dart';

class AnalysisScreen extends StatefulWidget {
  const AnalysisScreen({super.key});

  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen> {
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

  @override
  Widget build(BuildContext context) {
    return Consumer<AnalysisProvider>(
      builder: (context, provider, child) {
        final selectedImage = provider.selectedImage;
        final isLoading = provider.isLoading;

        return Scaffold(
          appBar: AppBar(title: const Text('AI Colour Analysis')),

          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),

              child: Column(
                children: [
                  // ==================================================
                  // IMAGE PREVIEW
                  // ==================================================
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Let’s find the colours that suit you',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),

                  const SizedBox(height: 6),

                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Choose a clear, front-facing photo in natural light.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey.shade600,
                          ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  Expanded(
                    child: Container(
                      width: double.infinity,

                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(20),
                      ),

                      child: selectedImage == null
                          ? Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.face_retouching_natural,
                                  size: 90,
                                  color: Colors.grey.shade500,
                                ),

                                const SizedBox(height: 16),

                                Text(
                                  'Ready when you are',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),

                                const SizedBox(height: 6),

                                Text(
                                  'Take a photo or choose one from your gallery.\nFor the best result, keep your face clearly visible.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.grey.shade600),
                                ),
                              ],
                            )
                          : Stack(
                              fit: StackFit.expand,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(20),
                                  child: Image.file(
                                    selectedImage,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                Positioned(
                                  right: 12,
                                  top: 12,
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.55),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: IconButton(
                                      tooltip: 'Choose another photo',
                                      onPressed: isLoading
                                          ? null
                                          : () => pickGallery(),
                                      color: Colors.white,
                                      icon: const Icon(Icons.refresh),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ==================================================
                  // STATUS
                  // ==================================================
                  Container(
                    width: double.infinity,

                    padding: const EdgeInsets.all(14),

                    decoration: BoxDecoration(
                      color: const Color(0xFFF5D8C7),
                      borderRadius: BorderRadius.circular(12),
                    ),

                    child: Row(
                      children: [
                        Icon(
                          isLoading
                              ? Icons.hourglass_top_rounded
                              : selectedImage != null
                                  ? Icons.check_circle_outline
                                  : Icons.info_outline,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            provider.status,
                            textAlign: TextAlign.left,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  // ==================================================
                  // CAMERA + GALLERY
                  // ==================================================
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: isLoading ? null : pickCamera,

                          icon: const Icon(Icons.camera_alt_outlined),

                          label: const Text('Take a Photo'),
                        ),
                      ),

                      const SizedBox(width: 12),

                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: isLoading ? null : pickGallery,

                          icon: const Icon(Icons.photo_outlined),

                          label: const Text('Choose from Gallery'),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // ==================================================
                  // ANALYSE BUTTON
                  // ==================================================
                  PrimaryButton(
                    text: isLoading ? 'Analysing...' : 'Analyse My Colours',

                    icon: Icons.auto_awesome,

                    onPressed: isLoading ? null : analyse,
                  ),

                  const SizedBox(height: 10),

                  Text(
                    'Your photo is used to create your personalised colour result.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey.shade600,
                        ),
                  ),

                  const SizedBox(height: 14),

                  // ==================================================
                  // ANALYSIS HISTORY
                  // ==================================================
                  SizedBox(
                    width: double.infinity,

                    child: OutlinedButton.icon(
                      onPressed: isLoading ? null : openAnalysisHistory,

                      icon: const Icon(Icons.history),

                      label: const Text('View Analysis History'),

                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 52),

                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
