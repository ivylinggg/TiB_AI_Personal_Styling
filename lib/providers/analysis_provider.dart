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

  // The provider is shared by the whole app, so every piece of analysis
  // state must be associated with the Firebase user that owns it.
  String? _loadedUid;

  File? get selectedImage => _selectedImage;
  ColourAnalysisResult? get result => _result;
  bool get isLoading => _isLoading;
  bool get isLoadingSavedResult => _isLoadingSavedResult;
  String get status => _status;
  String? get errorMessage => _errorMessage;
  bool get isPremium => _isPremium;
  String? get loadedUid => _loadedUid;

  /// Starts a fresh analysis session for [uid].
  ///
  /// This provider is intentionally shared across the app, therefore a new
  /// Firebase user must never inherit the previous user's in-memory result.
  /// The UID guard also prevents a slow request from the previous user from
  /// writing its result after the account has changed.
  Future<void> loadLatestResult(String uid) async {
    final normalizedUid = uid.trim();
    if (normalizedUid.isEmpty) return;

    // A different account has entered the customer shell. Clear all
    // user-specific in-memory state before loading the new account.
    if (_loadedUid != normalizedUid) {
      _loadedUid = normalizedUid;
      _selectedImage = null;
      _result = null;
      _isLoading = false;
      _errorMessage = null;
      _status = 'No image selected';
      _isPremium = false;
      notifyListeners();
    }

    _isLoadingSavedResult = true;
    notifyListeners();

    try {
      final latest = await FirestoreService.getLatestColourAnalysis(
        normalizedUid,
      );

      // Ignore a response that belongs to an account that has already been
      // replaced by another signed-in user.
      if (_loadedUid != normalizedUid) return;

      _result = latest;
    } catch (_) {
      // If the new user's history cannot be loaded, keep the new user's
      // state empty rather than exposing data from a previous account.
      if (_loadedUid == normalizedUid) {
        _result = null;
      }
    } finally {
      if (_loadedUid == normalizedUid) {
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
    final image = _selectedImage;
    final normalizedUid = uid.trim();

    if (image == null) {
      _setError('Please select an image first.');
      return false;
    }

    if (normalizedUid.isEmpty) {
      _setError('Please login before starting an analysis.');
      return false;
    }

    // Make sure an analysis cannot be started with stale provider state from
    // another account.
    if (_loadedUid != normalizedUid) {
      _loadedUid = normalizedUid;
      _result = null;
      _selectedImage = image;
      _errorMessage = null;
      notifyListeners();
    }

    _isLoading = true;
    _errorMessage = null;
    _status = 'Checking Premium access...';
    notifyListeners();

    try {
      final userSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(normalizedUid)
          .get();

      if (_loadedUid != normalizedUid) return false;

      _isPremium = userSnapshot.data()?['isPremium'] == true;
      _status = _isPremium
          ? 'Premium access active. Detecting face...'
          : 'Detecting face...';
      notifyListeners();
    } catch (_) {
      if (_loadedUid != normalizedUid) return false;
      _isPremium = false;
      _status = 'Detecting face...';
      notifyListeners();
    }

    try {
      // 1. Validate that the photo contains exactly one face.
      final faces = await MlKitService.detectFace(image);

      if (_loadedUid != normalizedUid) return false;

      if (faces.isEmpty) {
        _setError('No face was detected. Please use a clear front-facing photo.');
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
        uid: normalizedUid,
        image: image,
      );

      if (_loadedUid != normalizedUid) return false;

      _status = _isPremium
          ? 'Analysing your colours with Premium insights...'
          : 'Analysing your colours...';
      notifyListeners();

      // 3. Run the colour analysis against the selected image.
      final analysisResult = await ColourAnalysisService.analyse(
        image: image,
        imageUrl: imageUrl,
      );

      if (_loadedUid != normalizedUid) return false;

      _status = _isPremium
          ? 'Preparing your Premium colour insights...'
          : 'Saving your analysis...';
      notifyListeners();

      // 4. Persist the result in the authenticated user's history.
      await FirestoreService.saveAnalysisResult(
        uid: normalizedUid,
        result: analysisResult,
      );

      if (_loadedUid != normalizedUid) return false;

      // 5. Sync the summary colourSeason/skinTone fields onto the user's
      // profile document so Profile and the admin screens can display them.
      try {
        await FirestoreService.updateColourProfile(
          uid: normalizedUid,
          colourSeason: analysisResult.season,
          skinTone: '${analysisResult.brightness} ${analysisResult.undertone}'
              .trim(),
        );
      } catch (_) {
        // The analysis itself is already saved successfully.
      }

      if (_loadedUid != normalizedUid) return false;

      _result = analysisResult;
      _status = _isPremium
          ? 'Premium colour analysis completed successfully'
          : 'Analysis completed successfully';
      return true;
    } catch (e) {
      if (_loadedUid != normalizedUid) return false;
      _setError('Analysis failed: $e');
      return false;
    } finally {
      if (_loadedUid == normalizedUid) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  /// Clears all user-specific analysis state.
  void clear() {
    _loadedUid = null;
    _selectedImage = null;
    _result = null;
    _isLoading = false;
    _isLoadingSavedResult = false;
    _status = 'No image selected';
    _errorMessage = null;
    _isPremium = false;
    notifyListeners();
  }

  void _setError(String message) {
    _isLoading = false;
    _errorMessage = message;
    _status = 'Analysis failed';
    notifyListeners();
  }
}
