import 'dart:io';

import 'package:flutter/material.dart';

import '../models/colour_analysis_result.dart';
import '../services/colour_analysis_service.dart';

class AnalysisProvider extends ChangeNotifier {
  File? _selectedImage;
  ColourAnalysisResult? _result;
  bool _isLoading = false;

  // ============================================================
  // GETTERS
  // ============================================================

  File? get selectedImage => _selectedImage;

  ColourAnalysisResult? get result => _result;

  bool get isLoading => _isLoading;

  // ============================================================
  // SET IMAGE
  // ============================================================

  void setImage(File image) {
    _selectedImage = image;
    _result = null;

    notifyListeners();
  }

  // ============================================================
  // ANALYSE
  // ============================================================

  Future<void> analyse({required String imageUrl}) async {
    if (_selectedImage == null) {
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      _result = await ColourAnalysisService.analyse(
        image: _selectedImage!,
        imageUrl: imageUrl,
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ============================================================
  // CLEAR
  // ============================================================

  void clear() {
    _selectedImage = null;
    _result = null;
    _isLoading = false;

    notifyListeners();
  }
}
