import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_gradients.dart';
import '../../models/colour_analysis_result.dart';
import '../../models/wardrobe_item.dart';
import '../../providers/analysis_provider.dart';
import '../../services/ai_styling_service.dart';
import '../../services/firestore_service.dart';
import '../../services/style_preference_service.dart';
import '../analysis/analysis_screen.dart';
import '../wardrobe/wardrobe_screen.dart';
import 'style_preferences_screen.dart';

class AIStylistScreen extends StatefulWidget {
  final WardrobeItem? selectedItem;
  final String? initialPrompt;

  const AIStylistScreen({super.key, this.selectedItem, this.initialPrompt});

  @override
  State<AIStylistScreen> createState() => _AIStylistScreenState();
}

class _AIStylistScreenState extends State<AIStylistScreen> with WidgetsBindingObserver {
  final TextEditingController _composer = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _loading = true;
  bool _styling = false;
  String? _error;
  String? _requestUid;
  List<WardrobeItem> _wardrobe = const [];
  List<String> _styles = const [];
  List<String> _preferences = const [];
  AiStylingResult? _result;
  String? _lastPrompt;
  static const _quickPrompts = ['Dinner tonight', 'Smart work look', 'Casual weekend', 'Use my colours'];

  @override
  void initState() { super.initState(); WidgetsBinding.instance.addObserver(this); final initialPrompt = widget.initialPrompt?.trim(); if (initialPrompt != null && initialPrompt.isNotEmpty) _composer.text = initialPrompt; _load(); }
  @override
  void dispose() { WidgetsBinding.instance.removeObserver(this); _composer.dispose(); _scrollController.dispose(); super.dispose(); }
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) { if (state == AppLifecycleState.resumed && mounted && !_styling) _load(showLoading: false); }

  Future<void> _load({bool showLoading = true}) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    _requestUid = uid;
    if (uid == null) { if (mounted) setState(() { _loading = false; _wardrobe = const []; _styles = const []; _preferences = const []; _result = null; _lastPrompt = null; }); return; }
    if (showLoading && mounted) setState(() { _loading = true; _error = null; });
    try {
      final values = await Future.wait<dynamic>([FirestoreService.getWardrobeItems(uid), StylePreferenceService.getStylePreferences(uid)], eagerError: false);
      if (!mounted || FirebaseAuth.instance.currentUser?.uid != uid || _requestUid != uid) return;
      final prefs = values[1] is Map ? Map<String, dynamic>.from(values[1] as Map) : <String, dynamic>{};
      final items = values[0] is List<WardrobeItem> ? List<WardrobeItem>.from(values[0] as List<WardrobeItem>) : <WardrobeItem>[];
      setState(() { _wardrobe = items.where((item) => item.userId.isEmpty || item.userId == uid).toList(growable: false); _styles = _stringList(prefs['styles']); _preferences = _stringList(prefs['preferences']); _loading = false; _error = null; });
    } catch (_) {
      if (mounted && FirebaseAuth.instance.currentUser?.uid == uid) setState(() { _loading = false; _error = 'I could not refresh your styling profile.'; });
    }
  }

  Future<void> _send([String? preset]) async {
    final prompt = (preset ?? _composer.text).trim();
    if (prompt.isEmpty || _styling) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || _requestUid != uid) { _showMessage('Please sign in again before using the AI stylist.'); return; }
    final profile = context.read<AnalysisProvider>().result;
    if (profile == null) { _showMessage('Complete Colour Analysis first so I can style around your palette.'); return; }
    if (_wardrobe.isEmpty) { _showMessage('Add a few pieces to My Wardrobe first, then I can style what you already own.'); return; }
    final requestUid = uid;
    setState(() { _styling = true; _lastPrompt = prompt; _result = null; _error = null; if (preset == null) _composer.clear(); });
    _scrollToBottom();
    try {
      final result = await AiStylingService.getRecommendation(
        uid: requestUid,
        profile: profile,
        wardrobe: _wardrobe,
        styles: _styles,
        preferences: _preferences,
        occasion: prompt,
        selectedItem: widget.selectedItem,
      );
      if (!mounted || FirebaseAuth.instance.currentUser?.uid != requestUid || _requestUid != requestUid) return;
      setState(() { _result = result; _styling = false; if (result == null) _error = 'I could not build a look from the current styling service. Try again or refine your request.'; });
    } catch (_) {
      if (!mounted || FirebaseAuth.instance.currentUser?.uid != requestUid || _requestUid != requestUid) return;
      setState(() { _styling = false; _error = 'I could not build a look right now. Please try again.'; });
    }
    _scrollToBottom();
  }

  void _showMessage(String message) { if (!mounted) return; ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)))); }
  void _scrollToBottom() { WidgetsBinding.instance.addPostFrameCallback((_) { if (_scrollController.hasClients) _scrollController.animateTo(_scrollController.position.maxScrollExtent, duration: const Duration(milliseconds: 300), curve: Curves.easeOut); }); }
  WardrobeItem? _find(String? id) { if (id == null) return null; for (final item in _wardrobe) { if (item.id == id) return item; } return null; }

  List<WardrobeItem> get _look {
    if (_result == null) return const [];
    return [_find(_result!.topId), _find(_result!.bottomId), _find(_result!.dressId), _find(_result!.suitId), _find(_result!.jacketId), _find(_result!.shoesId), _find(_result!.accessoryId)].whereType<WardrobeItem>().toList(growable: false);
  }

  List<String> _stringList(dynamic value) => value is List ? value.map((item) => item.toString().trim()).where((item) => item.isNotEmpty).toList(growable: false) : const [];

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<AnalysisProvider>().result;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background, elevation: 0, scrolledUnderElevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18), onPressed: () => Navigator.pop(context)),
        title: Row(mainAxisSize: MainAxisSize.min, children: [Container(width: 30, height: 30, decoration: const BoxDecoration(gradient: AppGradients.primary, shape: BoxShape.circle), child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 16)), const SizedBox(width: 8), const Text('VYEA Personal Stylist', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16))]),
        centerTitle: true,
        actions: [IconButton(tooltip: 'My style', onPressed: _openPreferences, icon: const Icon(Icons.tune_rounded))],
      ),
      body: _loading ? const Center(child: CircularProgressIndicator()) : Column(children: [
        Expanded(child: RefreshIndicator(onRefresh: _load, child: ListView(controller: _scrollController, physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.fromLTRB(20, 10, 20, 18), children: [
          _assistantGreeting(profile), const SizedBox(height: 15),
          if (_error != null) ...[_errorCard(), const SizedBox(height: 14)],
          if (profile != null) ...[_profileStrip(profile), const SizedBox(height: 14)],
          if (widget.selectedItem != null) ...[_selectedItemBanner(widget.selectedItem!), const SizedBox(height: 15)],
          _stylingBrief(profile), const SizedBox(height: 14), _quickPromptSection(),
          if (_lastPrompt != null) ...[const SizedBox(height: 18), _userBubble(_lastPrompt!)],
          if (_styling) ...[const SizedBox(height: 14), _typingBubble()],
          if (_result != null && !_styling) ...[const SizedBox(height: 14), _assistantResultHeader(), const SizedBox(height: 10), _lookCard(), const SizedBox(height: 10), _resultActions()],
          const SizedBox(height: 20), _contextLinks(),
        ]))),
        _composerBar(),
      ]),
    );
  }

  Widget _assistantGreeting(ColourAnalysisResult? profile) {
    final name = FirebaseAuth.instance.currentUser?.displayName?.trim();
    final firstName = name == null || name.isEmpty ? '' : name.split(RegExp(r'\s+')).first;
    final greeting = firstName.isEmpty ? 'Hi there' : 'Hi $firstName';
    final intro = profile == null ? 'Tell me what you are getting dressed for and I’ll help shape the look.' : 'I’m working with your ${profile.season} palette, ${profile.faceShape} face shape and wardrobe context.';
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Container(width: 42, height: 42, decoration: BoxDecoration(gradient: AppGradients.primary, borderRadius: BorderRadius.circular(15)), child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 21)), const SizedBox(width: 11), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(greeting, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)), const SizedBox(height: 4), Text(intro, style: const TextStyle(color: AppColors.textSecondary, height: 1.45, fontSize: 13))]))]);
  }

  Widget _errorCard() => Container(padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12), decoration: BoxDecoration(color: AppColors.error.withValues(alpha: .07), borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.error.withValues(alpha: .16))), child: Row(children: [const Icon(Icons.cloud_off_rounded, color: AppColors.error, size: 19), const SizedBox(width: 9), Expanded(child: Text(_error!, style: const TextStyle(fontSize: 11.5, height: 1.35))), IconButton(onPressed: _load, padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 30, minHeight: 30), icon: const Icon(Icons.refresh_rounded, color: AppColors.primary, size: 18))]));

  Widget _stylingBrief(ColourAnalysisResult? profile) {
    final styleText = _styles.isEmpty ? 'Style preferences not set' : _styles.take(2).join(' · ');
    final colourText = profile == null ? 'Colour profile not loaded' : '${profile.undertone} · ${profile.brightness} · ${profile.contrast}';
    return Container(padding: const EdgeInsets.all(15), decoration: BoxDecoration(gradient: AppGradients.soft, borderRadius: BorderRadius.circular(19), border: Border.all(color: AppColors.border)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Container(width: 40, height: 40, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle), child: const Icon(Icons.checkroom_outlined, color: AppColors.primary)), const SizedBox(width: 11), const Expanded(child: Text('YOUR STYLING CONTEXT', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1.1))), _contextPill(_wardrobe.length >= 3 ? 'READY' : 'BUILDING')]), const SizedBox(height: 12), _contextLine(Icons.palette_outlined, colourText), const SizedBox(height: 6), _contextLine(Icons.face_retouching_natural_outlined, profile?.faceShape ?? 'Face shape not loaded'), const SizedBox(height: 6), _contextLine(Icons.checkroom_outlined, '${_wardrobe.length} wardrobe pieces'), const SizedBox(height: 6), _contextLine(Icons.style_outlined, styleText), if (widget.selectedItem != null) ...[const SizedBox(height: 6), _contextLine(Icons.push_pin_outlined, 'Styling around ${widget.selectedItem!.name}')]]));
  }

  Widget _contextLine(IconData icon, String text) => Row(children: [Icon(icon, size: 16, color: AppColors.primary), const SizedBox(width: 8), Expanded(child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10.8, color: AppColors.textSecondary, fontWeight: FontWeight.w600)))]);
  Widget _contextPill(String text) => Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5), decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(10)), child: Text(text, style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: .8, color: AppColors.primaryDark)));
  Widget _quickPromptSection() => SizedBox(height: 36, child: ListView.separated(scrollDirection: Axis.horizontal, itemCount: _quickPrompts.length, separatorBuilder: (_, __) => const SizedBox(width: 7), itemBuilder: (_, index) => ActionChip(label: Text(_quickPrompts[index]), onPressed: _styling ? null : () => _send(_quickPrompts[index]))));
  Widget _profileStrip(ColourAnalysisResult profile) => Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(15), border: Border.all(color: AppColors.border)), child: Row(children: [const Icon(Icons.palette_outlined, size: 16, color: AppColors.primary), const SizedBox(width: 8), Expanded(child: Text('${profile.season} · ${profile.undertone} · ${profile.brightness}', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700))), Text(profile.faceShape, style: const TextStyle(fontSize: 9.5, color: AppColors.textSecondary))]));
  Widget _selectedItemBanner(WardrobeItem item) => Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: AppColors.peach.withValues(alpha: .25), borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.peach)), child: Row(children: [const Icon(Icons.push_pin_rounded, size: 18, color: AppColors.primary), const SizedBox(width: 8), Expanded(child: Text('Styling around ${item.name}', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)))]));
  Widget _assistantResultHeader() => Row(children: [const Expanded(child: Text('VYEA’S LOOK', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w900, letterSpacing: 1.2, color: AppColors.primary))), Text('${_result?.matchScore ?? 0}% MATCH', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: AppColors.success))]);

  Widget _lookCard() => Container(padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(21), border: Border.all(color: AppColors.border)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(_result?.displayTitle ?? 'Your personal look', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)), const SizedBox(height: 8), if (_result?.explanation.isNotEmpty == true) Text(_result!.explanation, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.45)), const SizedBox(height: 12), if (_look.isEmpty) const Text('No complete wardrobe match was returned.') else GridView.builder(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: _look.length, gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 9, mainAxisSpacing: 9, childAspectRatio: .82), itemBuilder: (_, index) { final item = _look[index]; return Container(decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)), clipBehavior: Clip.antiAlias, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: item.imageUrl.isEmpty ? const Center(child: Icon(Icons.checkroom_outlined, color: AppColors.primary)) : CachedNetworkImage(imageUrl: item.imageUrl, fit: BoxFit.cover, width: double.infinity)), Padding(padding: const EdgeInsets.all(8), child: Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700)))])); }), const SizedBox(height: 12), if (_result?.colourDirection != null) Text(_result!.colourDirection!, style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary, height: 1.4)), if (_result?.stylingNotes.isNotEmpty == true) ...[const SizedBox(height: 10), ..._result!.stylingNotes.take(3).map((note) => Padding(padding: const EdgeInsets.only(bottom: 5), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [const Icon(Icons.circle, size: 5, color: AppColors.primary), const SizedBox(width: 7), Expanded(child: Text(note, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)))])))]));

  Widget _resultActions() => Row(children: [Expanded(child: OutlinedButton.icon(onPressed: _styling ? null : () => _send(_lastPrompt), icon: const Icon(Icons.refresh_rounded), label: const Text('Try again'))), const SizedBox(width: 8), Expanded(child: FilledButton.icon(onPressed: _openSavedLooks, icon: const Icon(Icons.bookmark_outline_rounded), label: const Text('Saved Looks'))]);

  Widget _contextLinks() => Row(children: [Expanded(child: OutlinedButton.icon(onPressed: _openWardrobe, icon: const Icon(Icons.checkroom_outlined), label: const Text('Wardrobe'))), const SizedBox(width: 8), Expanded(child: OutlinedButton.icon(onPressed: _openAnalysis, icon: const Icon(Icons.palette_outlined), label: const Text('Colour Profile'))]);
  Widget _composerBar() => SafeArea(child: Padding(padding: const EdgeInsets.fromLTRB(14, 7, 14, 10), child: Row(children: [Expanded(child: Container(padding: const EdgeInsets.symmetric(horizontal: 14), decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(22), border: Border.all(color: AppColors.border)), child: TextField(controller: _composer, minLines: 1, maxLines: 3, textInputAction: TextInputAction.send, onSubmitted: (_) => _send(), decoration: const InputDecoration(hintText: 'Ask VYEA to style a moment…', border: InputBorder.none))), const SizedBox(width: 8), FloatingActionButton.small(onPressed: _styling ? null : _send, child: const Icon(Icons.arrow_upward_rounded))]));

  void _openPreferences() { Navigator.push(context, MaterialPageRoute(builder: (_) => const StylePreferencesScreen())); }
  void _openWardrobe() { Navigator.push(context, MaterialPageRoute(builder: (_) => const WardrobeScreen())); }
  void _openAnalysis() { Navigator.push(context, MaterialPageRoute(builder: (_) => const AnalysisScreen())); }
  void _openSavedLooks() { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Open Saved Looks from the main AI Studio.'))); }
}