import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_gradients.dart';
import '../../core/constants/app_radius.dart';
import '../../models/colour_analysis_result.dart';
import '../../models/wardrobe_item.dart';
import '../../providers/analysis_provider.dart';
import '../../services/ai_styling_service.dart';
import '../../services/firestore_service.dart';
import '../../services/style_preference_service.dart';
import '../../widgets/premium_badge.dart';
import '../analysis/analysis_screen.dart';
import '../premium/premium_screen.dart';
import '../wardrobe/wardrobe_screen.dart';
import 'style_preferences_screen.dart';

/// TiB's conversational personal stylist.
/// The screen intentionally follows the reference flow: human greeting,
/// occasion chips, real wardrobe suggestions, and a calm chat composer.
class AIStylistScreen extends StatefulWidget {
  final WardrobeItem? selectedItem;
  final String? initialPrompt;

  const AIStylistScreen({super.key, this.selectedItem, this.initialPrompt});

  @override
  State<AIStylistScreen> createState() => _AIStylistScreenState();
}

class _AIStylistScreenState extends State<AIStylistScreen> {
  final TextEditingController _composer = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  bool _loading = true;
  bool _styling = false;
  bool _isPremium = false;
  String? _error;

  List<WardrobeItem> _wardrobe = const [];
  List<String> _styles = const [];
  List<String> _preferences = const [];
  AiStylingResult? _result;
  String? _lastPrompt;

  static const _quickPrompts = [
    'What should I wear for dinner?',
    'Style me for work',
    'What colours suit me?',
    'Make a casual look',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialPrompt?.trim().isNotEmpty == true) {
      _composer.text = widget.initialPrompt!.trim();
    }
    _load();
  }

  @override
  void dispose() {
    _composer.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final values = await Future.wait<dynamic>([
        FirestoreService.getWardrobeItems(uid),
        StylePreferenceService.getStylePreferences(uid),
        FirebaseFirestore.instance.collection('users').doc(uid).get(),
      ]);
      if (!mounted) return;

      final prefs = values[1] as Map<String, dynamic>?;
      final user = (values[2] as DocumentSnapshot<Map<String, dynamic>>).data();

      setState(() {
        _wardrobe = values[0] as List<WardrobeItem>;
        _styles = List<String>.from(prefs?['styles'] ?? const []);
        _preferences = List<String>.from(prefs?['preferences'] ?? const []);
        _isPremium = user?['isPremium'] == true;
        _loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'I could not refresh your styling profile.';
        });
      }
    }
  }

  Future<void> _send([String? preset]) async {
    final prompt = (preset ?? _composer.text).trim();
    if (prompt.isEmpty || _styling) return;

    final profile = context.read<AnalysisProvider>().result;
    if (profile == null) {
      _showMessage('Complete Colour Analysis first so I can style around your palette.');
      return;
    }
    if (_wardrobe.isEmpty) {
      _showMessage('Add a few pieces to My Wardrobe first, then I can style what you already own.');
      return;
    }
    if (!_isPremium) {
      await _showPremiumPrompt();
      return;
    }

    setState(() {
      _styling = true;
      _lastPrompt = prompt;
      _result = null;
      if (preset == null) _composer.clear();
    });
    _scrollToBottom();

    final result = await AiStylingService.getRecommendation(
      profile: profile,
      wardrobe: _wardrobe,
      styles: _styles,
      preferences: _preferences,
      occasion: prompt,
      selectedItem: widget.selectedItem,
    );

    if (!mounted) return;
    setState(() {
      _result = result;
      _styling = false;
    });
    _scrollToBottom();
  }

  Future<void> _showPremiumPrompt() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Container(
            padding: const EdgeInsets.fromLTRB(22, 10, 22, 22),
            decoration: const BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                SizedBox(height: 22),
                Text('Premium AI Styling', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                SizedBox(height: 8),
                Text('Upgrade to use TiB AI Stylist with your real wardrobe and personal styling profile.', style: TextStyle(color: AppColors.textSecondary, height: 1.4)),
              ],
            ),
          ),
        );
      },
    );
  }
}