import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../widgets/primary_button.dart';
import '../../services/image_picker_service.dart';
import '../../services/colour_analysis_service.dart';
import '../analysis/analysis_result_screen.dart';

class AnalysisScreen extends StatefulWidget {
  const AnalysisScreen({super.key});

  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen> {
  File? _selectedImage;

  Future<void> _takePhoto() async {
    final image = await ImagePickerService.pickCameraImage();

    if (image == null) return;

    setState(() {
      _selectedImage = image;
    });
  }

  Future<void> _pickGallery() async {
    final image = await ImagePickerService.pickGalleryImage();

    if (image == null) return;

    setState(() {
      _selectedImage = image;
    });
  }

  Future<void> analyseImage() async {
    if (_selectedImage == null) return;

    final result = await ColourAnalysisService.analyse();

    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AnalysisResultScreen(result: result)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,

      appBar: AppBar(
        title: const Text("AI Colour Analysis"),
        centerTitle: true,
      ),

      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Container(
                    width: double.infinity,
                    color: Colors.white,

                    child: _selectedImage == null
                        ? const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.face_retouching_natural,
                                size: 90,
                                color: AppColors.primary,
                              ),

                              SizedBox(height: 20),

                              Text(
                                "No Image Selected",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          )
                        : Image.file(_selectedImage!, fit: BoxFit.cover),
                  ),
                ),
              ),

              const SizedBox(height: 25),

              PrimaryButton(
                text: "Take Selfie",
                icon: Icons.camera_alt,
                onPressed: _takePhoto,
              ),

              const SizedBox(height: 16),

              PrimaryButton(
                text: "Choose From Gallery",
                icon: Icons.photo_library,
                onPressed: _pickGallery,
              ),

              const SizedBox(height: 20),

              PrimaryButton(
                text: "Analyse My Colours",
                icon: Icons.auto_awesome,
                onPressed: analyseImage,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
