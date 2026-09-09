import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../models/colour_analysis_result.dart';
import '../../models/wardrobe_item.dart';
import '../../services/firestore_service.dart';
import '../../services/style_preference_service.dart';
import '../../services/tib_model_service.dart';

class PersonalStyleProvider extends ChangeNotifier {
  StreamSubscription<User?>? _authSubscription;

  String? _uid;
  UserModel? _profile;
  ColourAnalysisResult? _colourAnalysis;
  TibModelProfile? _tibModel;
  List<String> _styles = const [];
  List<String> _preferences = const [];
  List<WardrobeItem> _wardrobe = const [];
  List<Map<String, dynamic>> _savedLooks = const [];
  bool _loading = false;
  bool _refreshing = false;
  Object? _error;
  DateTime? _lastLoadedAt;
  int _loadRequest = 0;

  PersonalStyleProvider() {
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((user) async {
      final nextUid = user?.uid;
      if (_uid == nextUid) return;
      _uid = nextUid;
      _clearData(notify: true);
      if (nextUid != null) await refresh(force: true);
    });
  }

  String? get uid => _uid;
  UserModel? get profile => _profile;
  ColourAnalysisResult? get colourAnalysis => _colourAnalysis;
  TibModelProfile? get tibModel => _tibModel;
  List<String> get styles => _styles;
  List<String> get preferences => _preferences;
  List<WardrobeItem> get wardrobe => _wardrobe;
  List<Map<String, dynamic>> get savedLooks => _savedLooks;
  bool get isLoading => _loading;
  bool get isRefreshing => _refreshing;
  bool get hasData => _profile != null || _colourAnalysis != null || _wardrobe.isNotEmpty || _styles.isNotEmpty;
  bool get hasColourProfile => _colourAnalysis != null;
  bool get hasTiBModel => _tibModel?.isComplete == true;
  bool get hasWardrobe => _wardrobe.isNotEmpty;
  bool get hasSavedLooks => _savedLooks.isNotEmpty;
  int get favouriteCount => _wardrobe.where((item) => item.isFavourite).length;
  DateTime? get lastLoadedAt => _lastLoadedAt;
  Object? get error => _error;

  Future<void> refresh({bool force = false}) async {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid == null) {
      _uid = null;
      _clearData(notify: true);
      return;
    }

    if (!force && _lastLoadedAt != null &&
        DateTime.now().difference(_lastLoadedAt!) < const Duration(seconds: 20)) {
      return;
    }

    final requestId = ++_loadRequest;
    _uid = currentUid.uid;
    _error = null;
    _loading = !hasData;
    _refreshing = hasData;
    notifyListeners();

    try {
      final results = await Future.wait<dynamic>([
        FirestoreService.getUser(currentUid.uid),
        FirestoreService.getLatestColourAnalysis(currentUid.uid),
        StylePreferenceService.getStylePreferences(currentUid.uid),
        FirestoreService.getWardrobeItems(currentUid.uid),
        FirestoreService.getSavedOutfitLooks(currentUid.uid),
        TibModelService.loadForUser(currentUid.uid),
      ], eagerError: false);

      final activeUid = FirebaseAuth.instance.currentUser?.uid;
      if (requestId != _loadRequest || activeUid != currentUid.uid) return;

      _profile = results[0] is UserModel ? results[0] as UserModel : null;
      _colourAnalysis = results[1] is ColourAnalysisResult ? results[1] as ColourAnalysisResult : null;

      final preferenceMap = results[2] is Map<String, dynamic>
          ? results[2] as Map<String, dynamic>
          : null;
      _styles = List<String>.unmodifiable(_stringList(preferenceMap?['styles']));
      _preferences = List<String>.unmodifiable(_stringList(preferenceMap?['preferences']));
      _wardrobe = results[3] is List<WardrobeItem>
          ? List<WardrobeItem>.unmodifiable(results[3] as List<WardrobeItem>)
          : const [];
      _savedLooks = results[4] is List<Map<String, dynamic>>
          ? List<Map<String, dynamic>>.unmodifiable(
              (results[4] as List<Map<String, dynamic>>).map(Map<String, dynamic>.unmodifiable),
            )
          : const [];
      _tibModel = results[5] is TibModelProfile ? results[5] as TibModelProfile : null;
      _lastLoadedAt = DateTime.now();
    } catch (error) {
      if (requestId == _loadRequest) _error = error;
    } finally {
      if (requestId == _loadRequest) {
        _loading = false;
        _refreshing = false;
        notifyListeners();
      }
    }
  }

  void invalidate() {
    _lastLoadedAt = null;
    notifyListeners();
  }

  void _clearData({required bool notify}) {
    _loadRequest++;
    _profile = null;
    _colourAnalysis = null;
    _tibModel = null;
    _styles = const [];
    _preferences = const [];
    _wardrobe = const [];
    _savedLooks = const [];
    _loading = false;
    _refreshing = false;
    _error = null;
    _lastLoadedAt = null;
    if (notify) notifyListeners();
  }

  static List<String> _stringList(dynamic value) {
    if (value is! List) return const [];
    return value
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}
