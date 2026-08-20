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
    setState(() { _loading = true; _error = null; });
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
      if (mounted) setState(() { _loading = false; _error = 'I could not refresh your styling profile.'; });
    }
  }

  Future<void> _send([String? preset]) async {
    final prompt = (preset ?? _composer.text).trim();
    if (prompt.isEmpty || _styling) return;
    final profile = context.read<AnalysisProvider>().result;
    if (profile == null) { _showMessage('Complete Colour Analysis first so I can style around your palette.'); return; }
    if (_wardrobe.isEmpty) { _showMessage('Add a few pieces to My Wardrobe first, then I can style what you already own.'); return; }
    if (!_isPremium) { await _showPremiumPrompt(); return; }
    setState(() { _styling = true; _lastPrompt = prompt; _result = null; if (preset == null) _composer.clear(); });
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
    setState(() { _result = result; _styling = false; });
    _scrollToBottom();
  }

  Future<void> _showPremiumPrompt() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(22, 10, 22, 22),
          decoration: const BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 38, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(99)))),
              const SizedBox(height: 22),
              Row(children: [
                Container(width: 44, height: 44, decoration: const BoxDecoration(color: AppColors.secondary, shape: BoxShape.circle), child: const Icon(Icons.auto_awesome_rounded, color: AppColors.primary, size: 22)),
                const SizedBox(width: 12),
                const Expanded(child: Text('Make it personal', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800))),
              ]),
              const SizedBox(height: 12),
              const Text('Premium connects your colour profile, style preferences and real wardrobe to TiB’s personalised AI styling.', style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.5)),
              const SizedBox(height: 18),
              SizedBox(width: double.infinity, child: FilledButton.icon(
                onPressed: () async {
                  Navigator.pop(sheetContext);
                  await Navigator.push(context, MaterialPageRoute(builder: (_) => const PremiumScreen()));
                  await _load();
                },
                icon: const Icon(Icons.workspace_premium_rounded, size: 18),
                label: const Text('Explore Premium'),
                style: FilledButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
              )),
              const SizedBox(height: 8),
              SizedBox(width: double.infinity, child: TextButton(onPressed: () => Navigator.pop(sheetContext), child: const Text('Maybe later'))),
            ],
          ),
        ),
      ),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))));
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(_scrollController.position.maxScrollExtent, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    });
  }

  WardrobeItem? _find(String? id) {
    if (id == null) return null;
    for (final item in _wardrobe) { if (item.id == id) return item; }
    return null;
  }

  List<WardrobeItem> get _look {
    if (_result == null) return const [];
    return [_find(_result!.topId), _find(_result!.bottomId), _find(_result!.shoesId), _find(_result!.accessoryId)].whereType<WardrobeItem>().toList();
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
        scrolledUnderElevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18), onPressed: () => Navigator.pop(context)),
        title: Row(mainAxisSize: MainAxisSize.min, children: [Container(width: 30, height: 30, decoration: const BoxDecoration(gradient: AppGradients.primary, shape: BoxShape.circle), child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 16)), const SizedBox(width: 8), const Text('TiB AI Stylist', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16))]),
        centerTitle: true,
        actions: [IconButton(tooltip: 'My style', onPressed: _openPreferences, icon: const Icon(Icons.more_horiz_rounded))],
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
                        if (widget.selectedItem != null) ...[_selectedItemBanner(widget.selectedItem!), const SizedBox(height: 17)],
                        _quickPromptSection(),
                        if (!_isPremium) ...[const SizedBox(height: 14), _premiumTeaser()],
                        if (_lastPrompt != null) ...[const SizedBox(height: 18), _userBubble(_lastPrompt!)],
                        if (_styling) ...[const SizedBox(height: 14), _typingBubble()],
                        if (_lastPrompt != null && !_styling) ...[const SizedBox(height: 14), _assistantReply()],
                        if (_result != null && !_styling && profile != null) ...[const SizedBox(height: 14), _lookCard(profile), const SizedBox(height: 10), _resultActions()],
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

  Widget _selectedItemBanner(WardrobeItem item) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: AppColors.secondary.withValues(alpha: .55), borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.primary.withValues(alpha: .12))),
    child: Row(children: [
      ClipRRect(borderRadius: BorderRadius.circular(12), child: SizedBox(width: 52, height: 52, child: item.imageUrl.isEmpty ? Container(color: AppColors.surfaceMuted, child: const Icon(Icons.checkroom_outlined, color: AppColors.primary)) : CachedNetworkImage(imageUrl: item.imageUrl, fit: BoxFit.cover))),
      const SizedBox(width: 11),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('STYLING AROUND', style: TextStyle(fontSize: 9, letterSpacing: 1, fontWeight: FontWeight.w800, color: AppColors.textMuted)), const SizedBox(height: 3), Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)), const SizedBox(height: 2), Text('${item.category} · ${item.colour}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10.5, color: AppColors.textSecondary))])),
      const Icon(Icons.auto_awesome_rounded, color: AppColors.primary, size: 18),
    ]),
  );

  Widget _assistantGreeting(ColourAnalysisResult? profile) {
    final name = FirebaseAuth.instance.currentUser?.displayName?.split(' ').first;
    final greeting = name == null || name.isEmpty ? 'Hi there' : 'Hi $name';
    final intro = profile == null ? 'I’m here to help you feel confident in what you wear.' : _isPremium ? 'I know your ${profile.season} palette. Tell me what you’re dressing for and we’ll work it out together.' : 'Your ${profile.season} palette is ready. Add your wardrobe and I can help you build looks around it.';
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Container(width: 38, height: 38, decoration: BoxDecoration(color: AppColors.secondary, borderRadius: BorderRadius.circular(14)), child: const Icon(Icons.auto_awesome_rounded, color: AppColors.primary, size: 20)), const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(greeting, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)), const SizedBox(height: 4), Text(intro, style: const TextStyle(color: AppColors.textSecondary, height: 1.45, fontSize: 13))]))]);
  }

  Widget _errorCard() => Container(margin: const EdgeInsets.only(bottom: 4), padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12), decoration: BoxDecoration(color: AppColors.error.withValues(alpha: .07), borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.error.withValues(alpha: .16))), child: Row(children: [const Icon(Icons.cloud_off_rounded, color: AppColors.error, size: 19), const SizedBox(width: 9), Expanded(child: Text(_error!, style: const TextStyle(color: AppColors.textPrimary, fontSize: 11.5, height: 1.35))), IconButton(onPressed: _load, padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 30, minHeight: 30), icon: const Icon(Icons.refresh_rounded, color: AppColors.primary, size: 18))]));

  Widget _profileStrip(ColourAnalysisResult profile) => Container(padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11), decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(17), border: Border.all(color: AppColors.border)), child: Row(children: [const Icon(Icons.palette_outlined, color: AppColors.primary, size: 18), const SizedBox(width: 8), Expanded(child: Text('${profile.season} · ${profile.undertone} · ${_wardrobe.length} wardrobe pieces', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700))), if (_isPremium) const PremiumBadge(compact: true)]));

  Widget _quickPromptSection() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Try asking me', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800)), const SizedBox(height: 9), Wrap(spacing: 8, runSpacing: 8, children: _quickPrompts.map((prompt) => ActionChip(label: Text(prompt, style: const TextStyle(fontSize: 10.5)), onPressed: _styling ? null : () => _send(prompt), backgroundColor: AppColors.surface, side: const BorderSide(color: AppColors.border))).toList())]);

  Widget _premiumTeaser() => Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: AppColors.premiumAccentLight, borderRadius: BorderRadius.circular(17), border: Border.all(color: AppColors.border)), child: Row(children: [const Icon(Icons.workspace_premium_outlined, color: AppColors.premiumAccent), const SizedBox(width: 10), const Expanded(child: Text('Premium unlocks personalised AI styling using your colour profile, preferences and wardrobe.', style: TextStyle(fontSize: 11.5, height: 1.4))), TextButton(onPressed: _showPremiumPrompt, child: const Text('Explore'))]));

  Widget _userBubble(String text) => Align(alignment: Alignment.centerRight, child: Container(margin: const EdgeInsets.only(left: 40), padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11), decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(17)), child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 12.5, height: 1.35)));

  Widget _typingBubble() => Align(alignment: Alignment.centerLeft, child: Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11), decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(17), border: Border.all(color: AppColors.border)), child: const Row(mainAxisSize: MainAxisSize.min, children: [SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)), SizedBox(width: 8), Text('Styling your look…', style: TextStyle(color: AppColors.textSecondary, fontSize: 12))]));

  Widget _assistantReply() => Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(17), border: Border.all(color: AppColors.border)), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [const Icon(Icons.auto_awesome_rounded, color: AppColors.primary, size: 19), const SizedBox(width: 9), Expanded(child: Text(_result?.explanation ?? 'I’m ready to build a look from your wardrobe.', style: const TextStyle(fontSize: 12.5, height: 1.45)))]));

  Widget _lookCard(ColourAnalysisResult profile) {
    final look = _look;
    if (look.isEmpty) return Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(17), border: Border.all(color: AppColors.border)), child: const Text('I couldn’t find enough matching pieces in your current wardrobe for this request.', style: TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.4)));
    return Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(19), border: Border.all(color: AppColors.border)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('YOUR LOOK', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: .8, color: AppColors.textMuted)), const SizedBox(height: 10), SizedBox(height: 150, child: Row(children: look.map((item) => Expanded(child: Padding(padding: const EdgeInsets.only(right: 7), child: _lookItem(item)))).toList()))]));
  }

  Widget _lookItem(WardrobeItem item) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(15), child: item.imageUrl.isEmpty ? Container(color: AppColors.surfaceMuted, child: const Center(child: Icon(Icons.checkroom_outlined, color: AppColors.primary))) : CachedNetworkImage(imageUrl: item.imageUrl, width: double.infinity, fit: BoxFit.cover))), const SizedBox(height: 6), Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800)), Text('${item.category} · ${item.colour}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 9.5, color: AppColors.textMuted))]);

  Widget _resultActions() => Row(children: [Expanded(child: OutlinedButton.icon(onPressed: _styling ? null : () => _send(_lastPrompt), icon: const Icon(Icons.refresh_rounded, size: 17), label: const Text('Try another'), style: OutlinedButton.styleFrom(foregroundColor: AppColors.primary, side: const BorderSide(color: AppColors.border), padding: const EdgeInsets.symmetric(vertical: 11), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)))), const SizedBox(width: 9), Expanded(child: FilledButton.icon(onPressed: _styling ? null : () { _composer.text = 'Make this look a little more casual'; _composer.selection = TextSelection.fromPosition(TextPosition(offset: _composer.text.length)); _send(); }, icon: const Icon(Icons.tune_rounded, size: 17), label: const Text('Refine it'), style: FilledButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 11), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))))]);

  Widget _contextLinks() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Keep your style profile fresh', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800)), const SizedBox(height: 9), Row(children: [Expanded(child: _linkCard(Icons.checkroom_outlined, 'My Wardrobe', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WardrobeScreen())))), const SizedBox(width: 9), Expanded(child: _linkCard(Icons.tune_rounded, 'Style Preferences', _openPreferences)), const SizedBox(width: 9), Expanded(child: _linkCard(Icons.palette_outlined, 'Colour Profile', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AnalysisScreen()))))]);

  Widget _linkCard(IconData icon, String label, VoidCallback onTap) => InkWell(onTap: onTap, borderRadius: BorderRadius.circular(17), child: Ink(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(17), border: Border.all(color: AppColors.border)), child: Column(children: [Icon(icon, color: AppColors.primary, size: 19), const SizedBox(height: 6), Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800))])));

  Widget _composerBar() => SafeArea(top: false, child: Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 12), child: Row(children: [Expanded(child: TextField(controller: _composer, minLines: 1, maxLines: 4, textInputAction: TextInputAction.send, onSubmitted: (_) => _send(), decoration: InputDecoration(hintText: 'Tell TiB what you’re dressing for…', filled: true, fillColor: AppColors.surface, border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: AppColors.border)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: AppColors.border)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: AppColors.primary))))), const SizedBox(width: 8), Material(color: AppColors.primary, borderRadius: BorderRadius.circular(18), child: InkWell(onTap: _styling ? null : _send, borderRadius: BorderRadius.circular(18), child: const SizedBox(width: 50, height: 52, child: Icon(Icons.arrow_upward_rounded, color: Colors.white)))]));

  Future<void> _openPreferences() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const StylePreferencesScreen()));
    if (mounted) await _load();
  }
}
