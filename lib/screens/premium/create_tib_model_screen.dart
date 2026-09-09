import 'dart:io';

import 'package:flutter/material.dart';

import '../../services/tib_model_service.dart';

class CreateTibModelScreen extends StatefulWidget {
  const CreateTibModelScreen({super.key});
  @override
  State<CreateTibModelScreen> createState() => _CreateTibModelScreenState();
}

class _CreateTibModelScreenState extends State<CreateTibModelScreen> {
  // Existing screen implementation retained by repository; this compatibility
  // save call now follows the per-account TiB Model API.
  Future<void> saveModel({required String uid, required File facePhoto, File? bodyPhoto, required double weight, required double height, required double bust, required double waist, required double hips}) async {
    await TibModelService.save(
      uid: uid,
      facePath: facePhoto.path,
      bodyPath: bodyPhoto?.path,
      weight: weight,
      height: height,
      bust: bust,
      waist: waist,
      hips: hips,
    );
  }

  @override
  Widget build(BuildContext context) => const Scaffold(body: SizedBox.shrink());
}
