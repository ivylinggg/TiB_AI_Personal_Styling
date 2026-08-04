import 'dart:io';

import 'package:flutter/material.dart';

import '../../services/image_picker_service.dart';
import '../../services/mlkit_service.dart';
import '../../widgets/primary_button.dart';

import '../../models/colour_analysis_result.dart';
import 'analysis_result_screen.dart';

import '../auth/auth_service.dart';
import '../../services/firestore_service.dart';

import '../../services/storage_service.dart';

class AnalysisScreen extends StatefulWidget {
  const AnalysisScreen({super.key});

  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen> {
  File? selectedImage;

  bool isLoading = false;

  String status = "No image selected";

  Future<void> pickCamera() async {
    final image = await ImagePickerService.pickCamera();

    if (image == null) return;

    setState(() {
      selectedImage = image;
      status = "Image selected";
    });
  }

  Future<void> pickGallery() async {
    final image = await ImagePickerService.pickGallery();

    if (image == null) return;

    setState(() {
      selectedImage = image;
      status = "Image selected";
    });
  }

  Future<void> analyse() async {
    if (selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select an image first.")),
      );
      return;
    }

    setState(() {
      isLoading = true;
      status = "Detecting face...";
    });

    try {
      final faces = await MlKitService.detectFace(selectedImage!);

      if (!mounted) return;

      if (faces.isEmpty) {
        setState(() {
          status = "❌ No face detected";
        });
        return;
      }

      if (faces.length > 1) {
        setState(() {
          status = "⚠ Please use a photo with only one face";
        });
        return;
      }

      final face = faces.first;

      debugPrint("Face detected");
      debugPrint("Bounding Box: ${face.boundingBox}");

      setState(() {
        status = "✅ Face detected successfully";
      });

      String imageUrl = "";

      if (AuthService.currentUser != null) {
        imageUrl = await StorageService.uploadAnalysisImage(
          uid: AuthService.currentUser!.uid,
          image: selectedImage!,
        );
      }
      final result = ColourAnalysisResult(
        season: "Warm Spring",
        undertone: "Warm",
        brightness: "Light",
        contrast: "Medium",
        imageUrl: imageUrl,
        colours: const ["Peach", "Coral", "Cream", "Camel", "Olive"],
      );

      // 保存到 Firestore
      if (AuthService.currentUser != null) {
        await FirestoreService.saveAnalysisResult(
          uid: AuthService.currentUser!.uid,
          result: result,
        );
      }

      if (!mounted) return;

      // 跳转到结果页面
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => AnalysisResultScreen(result: result)),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        status = "Analysis failed";
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("AI Colour Analysis")),

      body: Padding(
        padding: const EdgeInsets.all(20),

        child: Column(
          children: [
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(20),
                ),

                child: selectedImage == null
                    ? const Center(child: Icon(Icons.image, size: 100))
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Image.file(selectedImage!, fit: BoxFit.cover),
                      ),
              ),
            ),

            const SizedBox(height: 25),

            Text(status, style: Theme.of(context).textTheme.titleMedium),

            const SizedBox(height: 25),

            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: pickCamera,
                    icon: const Icon(Icons.camera_alt),
                    label: const Text("Camera"),
                  ),
                ),

                const SizedBox(width: 15),

                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: pickGallery,
                    icon: const Icon(Icons.photo),
                    label: const Text("Gallery"),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            PrimaryButton(
              text: isLoading ? "Analysing..." : "Analyse Face",
              icon: Icons.auto_awesome,
              onPressed: isLoading ? null : analyse,
            ),
          ],
        ),
      ),
    );
  }
}
