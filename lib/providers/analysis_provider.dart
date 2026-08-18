import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/colour_analysis_result.dart';
import '../services/colour_analysis_service.dart';
import '../services/firestore_service.dart';
import '../services/mlkit_service.dart';
import '../services/storage_service.dart';

class AnalysisProvider extends ChangeNotifier {
  File? _selectedImage;
  ColourAnalysisResult? _result;
  bool _isLoading = false;
  bool _isLoadingSavedResult = false;
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

  /// Loads the user's most recently saved colour analysis (if any) from
  /// Firestore into [result], so screens that depend on [result] (Dashboard,
  /// AI Stylist) reflect a previous analysis without requiring the user to
  /// run a fresh one in the current session. Called once per session, e.g.
  /// when the customer's main shell first mounts after login.
  Future<void> loadLatestResult(String uid) async {
    if (uid.trim().isEmpty) {
      return;
    }

    _isLoadingSavedResult = true;
    notifyListeners();

    try {
      final latest = await FirestoreService.getLatestColourAnalysis(uid);

      if (latest != null) {
        _result = latest;
      }
    } catch (_) {
      // Best-effort background load: if it fails, keep whatever is
      // already in memory (nothing, on a fresh session) rather than
      // surfacing an error for a load the user didn't explicitly request.
    } finally {
      _isLoadingSavedResult = false;
      notifyListeners();
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
    final image = _selectedImage;

    if (image == null) {
      _setError('Please select an image first.');
      return false;
    }

    if (uid.trim().isEmpty) {
      _setError('Please login before starting an analysis.');
      return false;
    }

    _isLoading = true;
    _errorMessage = null;
    _status = 'Checking Premium access...';
    notifyListeners();

    try {
      final userSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

      _isPremium = userSnapshot.data()?['isPremium'] == true;
      _status = _isPremium
          ? 'Premium access active. Detecting face...'
          : 'Detecting face...';
      notifyListeners();
    } catch (_) {
      _isPremium = false;
      _status = 'Detecting face...';
      notifyListeners();
    }

    try {
      // 1. Validate that the photo contains exactly one face.
      final faces = await MlKitService.detectFace(image);

      if (faces.isEmpty) {
        _setError(
          'No face was detected. Please use a clear front-facing photo.',
        );
        return false;
      }

      if (faces.length > 1) {
        _setError('Please use a photo with only one face.');
        return false;
      }

      _status = 'Face detected. Uploading image...';
      notifyListeners();

      // 2. Upload the original analysis image.
      final imageUrl = await StorageService.uploadAnalysisImage(
        uid: uid,
        image: image,
      );

      _status = _isPremium
          ? 'Analysing your colours with Premium insights...'
          : 'Analysing your colours...';
      notifyListeners();

      // 3. Run the colour analysis against the selected image.
      final analysisResult = await ColourAnalysisService.analyse(
        image: image,
        imageUrl: imageUrl,
      );

      _status = _isPremium
          ? 'Preparing your Premium colour insights...'
          : 'Saving your analysis...';
      notifyListeners();

      // 4. Persist the result in the authenticated user's history.
      await FirestoreService.saveAnalysisResult(
        uid: uid,
        result: analysisResult,
      );

      // 5. Sync the summary colourSeason/skinTone fields onto the user's
      // profile document so Profile and the admin screens can display
      // them directly. This is best-effort: the analysis itself is
      // already saved successfully above, so a failure here should not
      // fail the analysis the user is waiting on.
      try {
        await FirestoreService.updateColourProfile(
          uid: uid,
          colourSeason: analysisResult.season,
          skinTone: '${analysisResult.brightness} ${analysisResult.undertone}'
              .trim(),
        );
      } catch (_) {
        // Ignore: see comment above.
      }

      _result = analysisResult;
      _status = _isPremium
          ? 'Premium colour analysis completed successfully'
          : 'Analysis completed successfully';
      return true;
    } catch (e) {
      _setError('Analysis failed: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clear() {
    _selectedImage = null;
    _result = null;
    _isLoading = false;
    _isLoadingSavedResult = false;
    _status = 'No image selected';
    _errorMessage = null;
    notifyListeners();
  }

  void _setError(String message) {
    _isLoading = false;
    _errorMessage = message;
    _status = 'Analysis failed';
    notifyListeners();
  }
}
