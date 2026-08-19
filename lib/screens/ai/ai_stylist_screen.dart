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
import '../wardrobe/wardrobe_screen.dart';
import 'style_preferences_screen.dart';

/// TiB's conversational personal stylist.
/// The screen intentionally follows the reference flow: human greeting,
/// occasion chips, real wardrobe suggestions, and a calm chat composer.
class AIStylistScreen extends StatefulWidget {
  const AIStylistScreen({super.key});

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

    setState(() {
      _styling = true;
      _lastPrompt = prompt;
      _result = null;
      if (preset == null) _composer.clear();
    });
    _scrollToBottom();

    AiStylingResult? result;
    if (_isPremium) {
      result = await AiStylingService.getRecommendation(
        profile: profile,
        wardrobe: _wardrobe,
        styles: _styles,
        preferences: _preferences,
        occasion: prompt,
      );
    }

    if (!mounted) return;
    setState(() {
      _result = result;
      _styling = false;
    });
    _scrollToBottom();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  WardrobeItem? _find(String? id) {
    if (id == null) return null;
    for (final item in _wardrobe) {
      if (item.id == id) return item;
    }
    return null;
  }

  List<WardrobeItem> get _look {
    if (_result == null) return const [];
    return [
      _find(_result!.topId),
      _find(_result!.bottomId),
      _find(_result!.shoesId),
      _find(_result!.accessoryId),
    ].whereType<WardrobeItem>().toList();
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<AnalysisProvider>().result;
    final season = profile?.season;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: const BoxDecoration(
                gradient: AppGradients.primary,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 16),
            ),
            const SizedBox(width: 8),
            const Text('TiB AI Stylist', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'My style',
            onPressed: _openPreferences,
            icon: const Icon(Icons.more_horiz_rounded),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _load,
                    child: ListView(
                      controller: _scrollController,
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 10, 20, 18),
                      children: [
                        _assistantGreeting(profile),
                        const SizedBox(height: 18),
                        if (_error != null) _errorCard(),
                        if (season != null) _profileStrip(profile!),
                        const SizedBox(height: 17),
                        _quickPromptSection(),
                        if (_lastPrompt != null) ...[
                          const SizedBox(height: 18),
                          _userBubble(_lastPrompt!),
                        ],
                        if (_styling) ...[
                          const SizedBox(height: 14),
                          _typingBubble(),
                        ],
                        if (_lastPrompt != null && !_styling) ...[
                          const SizedBox(height: 14),
                          _assistantReply(profile),
                        ],
                        if (_result != null && !_styling) ...[
                          const SizedBox(height: 14),
                          _lookCard(profile!),
                        ],
                        const SizedBox(height: 20),
                        _contextLinks(),
                      ],
                    ),
                  ),
                ),
                _composerBar(),
              ],
            ),
    );
  }

  Widget _assistantGreeting(ColourAnalysisResult? profile) {
    final name = FirebaseAuth.instance.currentUser?.displayName?.split(' ').first;
    final greeting = name == null || name.isEmpty ? 'Hi there' : 'Hi $name';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: AppColors.secondary,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.auto_awesome_rounded, color: AppColors.primary, size: 20),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(greeting, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              const SizedBox(height: 4),
              Text(
                profile == null
                    ? 'I’m here to help you feel confident in what you wear.'
                    : 'I know your ${profile.season} palette. Tell me what you’re dressing for and we’ll work it out together.',
                style: const TextStyle(color: AppColors.textSecondary, height: 1.45, fontSize: 13),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _errorCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: .07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.error.withValues(alpha: .16)),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_off_rounded, color: AppColors.error, size: 19),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              _error!,
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 11.5, height: 1.35),
            ),
          ),
          IconButton(
            onPressed: _load,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
            icon: const Icon(Icons.refresh_rounded, color: AppColors.primary, size: 18),
          ),
        ],
      ),
    );
  }

  Widget _profileStrip(ColourAnalysisResult profile) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.palette_outlined, color: AppColors.primary, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${profile.season} · ${profile.undertone} · ${_wardrobe.length} wardrobe pieces',
              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
            ),
          ),
          if (_isPremium) const PremiumBadge(compact: true),
        ],
      ),
    );
  }

  Widget _quickPromptSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Try asking me', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
        const SizedBox(height: 9),
        Wrap(
          spacing: 7,
          runSpacing: 8,
          children: _quickPrompts.map((prompt) {
            return ActionChip(
              label: Text(prompt),
              onPressed: () => _send(prompt),
              backgroundColor: AppColors.surface,
              side: const BorderSide(color: AppColors.border),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.full)),
              labelStyle: const TextStyle(fontSize: 11.5, color: AppColors.textPrimary, fontWeight: FontWeight.w600),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _userBubble(String text) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 300),
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
        decoration: BoxDecoration(
          gradient: AppGradients.primary,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomLeft: Radius.circular(18),
            bottomRight: Radius.circular(5),
          ),
        ),
        child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.4)),
      ),
    );
  }

  Widget _typingBubble() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: AppColors.surfaceMuted,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(width: 7, height: 7, child: CircularProgressIndicator(strokeWidth: 1.5)),
              SizedBox(width: 9),
              Text('Styling your look…', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _assistantReply(ColourAnalysisResult? profile) {
    final explanation = _result?.explanation.trim();
    final text = explanation == null || explanation.isEmpty
        ? 'I’ve looked at your wardrobe and profile. Here’s a look I’d start with.'
        : explanation;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: const BoxDecoration(color: AppColors.secondary, shape: BoxShape.circle),
          child: const Icon(Icons.auto_awesome_rounded, color: AppColors.primary, size: 15),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surfaceMuted,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(5),
                topRight: Radius.circular(18),
                bottomLeft: Radius.circular(18),
                bottomRight: Radius.circular(18),
              ),
            ),
            child: Text(text, style: const TextStyle(fontSize: 12.5, height: 1.5)),
          ),
        ),
      ],
    );
  }

  Widget _lookCard(ColourAnalysisResult profile) {
    final look = _look;
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .035), blurRadius: 18, offset: const Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(child: Text('A LOOK FOR YOU', style: TextStyle(fontSize: 10, color: AppColors.primary, fontWeight: FontWeight.w800, letterSpacing: 1.1))),
              if (_isPremium) const PremiumBadge(compact: true),
            ],
          ),
          const SizedBox(height: 10),
          if (look.isEmpty)
            const Text('I need a few more suitable pieces in your wardrobe to complete this look.', style: TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.4))
          else
            SizedBox(
              height: 164,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: look.length,
                separatorBuilder: (_, index) => const SizedBox(width: 9),
                itemBuilder: (_, index) => _lookItem(look[index]),
              ),
            ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.palette_outlined, size: 15, color: AppColors.primary),
              const SizedBox(width: 5),
              Expanded(child: Text('Built around your ${profile.season} palette', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _lookItem(WardrobeItem item) {
    return SizedBox(
      width: 112,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: item.imageUrl.isEmpty
                  ? Container(color: AppColors.surfaceMuted, child: const Center(child: Icon(Icons.checkroom_outlined, color: AppColors.primary)))
                  : CachedNetworkImage(imageUrl: item.imageUrl, width: double.infinity, fit: BoxFit.cover),
            ),
          ),
          const SizedBox(height: 6),
          Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800)),
          Text('${item.category} · ${item.colour}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 9.5, color: AppColors.textMuted)),
        ],
      ),
    );
  }

  Widget _contextLinks() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Keep your style profile fresh', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
        const SizedBox(height: 9),
        Row(
          children: [
            Expanded(child: _linkCard(Icons.checkroom_outlined, 'My Wardrobe', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WardrobeScreen())))),
            const SizedBox(width: 9),
            Expanded(child: _linkCard(Icons.tune_rounded, 'Style Preferences', _openPreferences)),
            const SizedBox(width: 9),
            Expanded(child: _linkCard(Icons.palette_outlined, 'Colour Profile', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AnalysisScreen())))),
          ],
        ),
      ],
    );
  }

  Widget _linkCard(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(17),
      child: Container(
        padding: const EdgeInsets.fromLTRB(9, 12, 9, 11),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(17), border: Border.all(color: AppColors.border)),
        child: Column(children: [Icon(icon, color: AppColors.primary, size: 20), const SizedBox(height: 6), Text(label, textAlign: TextAlign.center, maxLines: 2, style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700))]),
      ),
    );
  }

  Widget _composerBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(14, 8, 14, 10 + MediaQuery.paddingOf(context).bottom),
      decoration: BoxDecoration(
        color: AppColors.background,
        border: const Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: _composer,
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _send(),
              decoration: InputDecoration(
                hintText: 'Ask anything about your style…',
                filled: true,
                fillColor: AppColors.surface,
                contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: const BorderSide(color: AppColors.border)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: const BorderSide(color: AppColors.border)),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: AppColors.primary,
            shape: const CircleBorder(),
            child: InkWell(
              onTap: _styling ? null : _send,
              customBorder: const CircleBorder(),
              child: const SizedBox(width: 46, height: 46, child: Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 20)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openPreferences() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const StylePreferencesScreen()));
    await _load();
  }
}
