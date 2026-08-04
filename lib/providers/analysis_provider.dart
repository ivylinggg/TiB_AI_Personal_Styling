import 'dart:io';

import 'package:flutter/material.dart';

import '../models/colour_analysis_result.dart';
import '../services/colour_analysis_service.dart';

class AnalysisProvider extends ChangeNotifier {
  File? _selectedImage;
  ColourAnalysisResult? _result;
  bool _isLoading = false;

  File? get selectedImage => _selectedImage;
  ColourAnalysisResult? get result => _result;
  bool get isLoading => _isLoading;

  void setImage(File image) {
    _selectedImage = image;
    notifyListeners();
  }

  Future<void> analyse() async {
    _isLoading = true;
    notifyListeners();

    _result = await ColourAnalysisService.analyse();

    _isLoading = false;
    notifyListeners();
  }

  void clear() {
    _selectedImage = null;
    _result = null;
    notifyListeners();
  }
}
