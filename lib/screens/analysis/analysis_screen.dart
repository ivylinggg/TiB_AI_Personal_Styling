import 'dart:io';

import 'package:flutter/material.dart';

import '../../services/colour_analysis_service.dart';
import '../../services/firestore_service.dart';
import '../../services/image_picker_service.dart';
import '../../services/mlkit_service.dart';
import '../../services/storage_service.dart';
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
  File? selectedImage;

  bool isLoading = false;

  String status = 'No image selected';

  // ============================================================
  // CAMERA
  // ============================================================

  Future<void> pickCamera() async {
    if (isLoading) return;

    final image = await ImagePickerService.pickCamera();

    if (image == null) return;

    if (!mounted) return;

    setState(() {
      selectedImage = image;
      status = 'Image selected';
    });
  }

  // ============================================================
  // GALLERY
  // ============================================================

  Future<void> pickGallery() async {
    if (isLoading) return;

    final image = await ImagePickerService.pickGallery();

    if (image == null) return;

    if (!mounted) return;

    setState(() {
      selectedImage = image;
      status = 'Image selected';
    });
  }

  // ============================================================
  // ANALYSE
  // ============================================================

  Future<void> analyse() async {
    if (selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an image first.')),
      );

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

    setState(() {
      isLoading = true;
      status = 'Detecting face...';
    });

    try {
      // ========================================================
      // STEP 1 — FACE DETECTION
      // ========================================================

      final faces = await MlKitService.detectFace(selectedImage!);

      if (!mounted) return;

      if (faces.isEmpty) {
        setState(() {
          status = 'No face detected';
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No face was detected. Please use a clear front-facing photo.',
            ),
          ),
        );

        return;
      }

      if (faces.length > 1) {
        setState(() {
          status = 'Multiple faces detected';
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please use a photo with only one face.'),
          ),
        );

        return;
      }

      setState(() {
        status = 'Face detected. Preparing analysis...';
      });

      // ========================================================
      // STEP 2 — UPLOAD IMAGE
      // ========================================================

      setState(() {
        status = 'Uploading analysis image...';
      });

      final imageUrl = await StorageService.uploadAnalysisImage(
        uid: currentUser.uid,
        image: selectedImage!,
      );

      // ========================================================
      // STEP 3 — COLOUR ANALYSIS
      // ========================================================

      if (!mounted) return;

      setState(() {
        status = 'Analysing your colours...';
      });

      final result = await ColourAnalysisService.analyse(
        image: selectedImage!,
        imageUrl: imageUrl,
      );

      // ========================================================
      // STEP 4 — SAVE RESULT
      // ========================================================

      if (!mounted) return;

      setState(() {
        status = 'Saving your analysis...';
      });

      await FirestoreService.saveAnalysisResult(
        uid: currentUser.uid,
        result: result,
      );

      // ========================================================
      // STEP 5 — SHOW RESULT
      // ========================================================

      if (!mounted) return;

      setState(() {
        status = 'Analysis completed successfully';
      });

      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => AnalysisResultScreen(result: result)),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        status = 'Analysis failed';
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Analysis failed: $e')));
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  // ============================================================
  // OPEN ANALYSIS HISTORY
  // ============================================================

  void openAnalysisHistory() {
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
                              'Select a clear photo',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),

                            const SizedBox(height: 6),

                            Text(
                              'Use a front-facing photo with one face.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                          ],
                        )
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(20),

                          child: Image.file(selectedImage!, fit: BoxFit.cover),
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

                child: Text(
                  status,
                  textAlign: TextAlign.center,

                  style: const TextStyle(fontWeight: FontWeight.w600),
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

                      label: const Text('Camera'),
                    ),
                  ),

                  const SizedBox(width: 12),

                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: isLoading ? null : pickGallery,

                      icon: const Icon(Icons.photo_outlined),

                      label: const Text('Gallery'),
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

              const SizedBox(height: 12),

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
  }
}
