import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/colour_analysis_result.dart';
import '../services/colour_analysis_service.dart';
import '../services/face_shape_analysis_service.dart';
import '../services/firestore_service.dart';
import '../services/mlkit_service.dart';
import '../services/storage_service.dart';

class AnalysisProvider extends ChangeNotifier {
  File? _selectedImage;
  ColourAnalysisResult? _result;
  bool _isLoading = false;
  bool _isLoadingSavedResult = false;
  String _loadedUid = '';
  String _status = 'No image selected';
  String? _errorMessage;
  bool _isPremium = false;

  File? get selectedImage => _selectedImage;
  ColourAnalysisResult? get result => _result;
  bool get isLoading => _isLoading;
  bool get isLoadingSavedResult => _isLoadingSavedResult;
  String get status => _status;
  String? get errorMessage => _errorMessage;
  bool get isPremium => _isPremium;
  String get loadedUid => _loadedUid;

  /// Loads only the analysis belonging to [uid]. Changing accounts clears the
  /// previous user's in-memory result before reading the new user's data.
  Future<void> loadLatestResult(String uid) async {
    final cleanUid = uid.trim();
    if (cleanUid.isEmpty) return;

    if (_loadedUid.isNotEmpty && _loadedUid != cleanUid) {
      _selectedImage = null;
      _result = null;
      _errorMessage = null;
      _status = 'No image selected';
      _isPremium = false;
      notifyListeners();
    }

    if (_loadedUid == cleanUid && _result != null) return;

    _loadedUid = cleanUid;
    _isLoadingSavedResult = true;
    notifyListeners();

    try {
      final latest = await FirestoreService.getLatestColourAnalysis(cleanUid);
      // Never apply an asynchronous response after the account has changed.
      if (_loadedUid != cleanUid) return;
      _result = latest;
      _status = latest == null ? 'No saved analysis yet' : 'Saved colour profile loaded';
    } catch (_) {
      if (_loadedUid != cleanUid) return;
    } finally {
      if (_loadedUid == cleanUid) {
        _isLoadingSavedResult = false;
        notifyListeners();
      }
    }
  }

  void setImage(File image) {
    _selectedImage = image;
    _result = null;
    _errorMessage = null;
    _status = 'Image selected';
    notifyListeners();
  }

  Future<bool> analyse({required String uid}) async {
    final cleanUid = uid.trim();
    final image = _selectedImage;

    if (image == null) {
      _setError('Please select an image first.');
      return false;
    }
    if (cleanUid.isEmpty) {
      _setError('Please login before starting an analysis.');
      return false;
    }

    _loadedUid = cleanUid;
    _isLoading = true;
    _errorMessage = null;
    _status = 'Checking your profile...';
    notifyListeners();

    try {
      final userSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(cleanUid)
          .get();
      if (_loadedUid != cleanUid) return false;

      _isPremium = userSnapshot.data()?['isPremium'] == true;
      _status = _isPremium ? 'Premium access active. Detecting face...' : 'Detecting face...';
      notifyListeners();
    } catch (_) {
      _isPremium = false;
      _status = 'Detecting face...';
      notifyListeners();
    }

    try {
      final faces = await MlKitService.detectFace(image);
      if (_loadedUid != cleanUid) return false;

      if (faces.isEmpty) {
        _setError('No face was detected. Please use a clear front-facing photo.');
        return false;
      }
      if (faces.length > 1) {
        _setError('Please use a photo with only one face.');
        return false;
      }

      _status = 'Face detected. Measuring your face shape...';
      notifyListeners();

      final faceShape = await FaceShapeAnalysisService.analyse(
        image: image,
        faces: faces,
      );
      if (_loadedUid != cleanUid) return false;

      _status = 'Face shape detected. Analysing your personal colours...';
      notifyListeners();

      // Analyse the local image before uploading it. This keeps an invalid
      ///ambiguous analysis from becoming a permanent user asset.
      final localColourResult = await ColourAnalysisService.analyse(
        image: image,
        imageUrl: '',
      );
      if (_loadedUid != cleanUid) return false;

      _status = 'Uploading your analysis photo...';
      notifyListeners();

      final imageUrl = await StorageService.uploadAnalysisImage(
        uid: cleanUid,
        image: image,
      );
      if (_loadedUid != cleanUid) return false;

      final analysisResult = ColourAnalysisResult(
        season: localColourResult.season,
        undertone: localColourResult.undertone,
        brightness: localColourResult.brightness,
        contrast: localColourResult.contrast,
        imageUrl: imageUrl,
        colours: localColourResult.colours,
        faceShape: faceShape.shape,
        faceShapeDescription: faceShape.description,
        faceMeasurements: faceShape.measurements,
        faceStylingGuidance: faceShape.stylingGuidance,
        colourReasons: localColourResult.colourReasons,
      );

      _status = 'Saving your personal colour & face profile...';
      notifyListeners();

      await FirestoreService.saveAnalysisResult(
        uid: cleanUid,
        result: analysisResult,
      );
      if (_loadedUid != cleanUid) return false;

      try {
        await FirestoreService.updateColourProfile(
          uid: cleanUid,
          colourSeason: analysisResult.season,
          skinTone: '${analysisResult.brightness} ${analysisResult.undertone}'.trim(),
        );
      } catch (_) {
        // Analysis itself is already safely saved under the owner's UID.
      }

      _result = analysisResult;
      _status = 'Personal colour & face analysis completed successfully';
      return true;
    } catch (e) {
      if (_loadedUid != cleanUid) return false;
      _setError('Analysis failed: $e');
      return false;
    } finally {
      if (_loadedUid == cleanUid) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  void clear({bool clearAccountContext = false}) {
    _selectedImage = null;
    _result = null;
    _isLoading = false;
    _isLoadingSavedResult = false;
    _status = 'No image selected';
    _errorMessage = null;
    if (clearAccountContext) {
      _loadedUid = '';
      _isPremium = false;
    }
    notifyListeners();
  }

  void _setError(String message) {
    _isLoading = false;
    _errorMessage = message;
    _status = 'Analysis failed';
    notifyListeners();
  }
}
