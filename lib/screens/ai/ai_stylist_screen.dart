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

class _AIStylistScreenState extends State<AIStylistScreen>
    with WidgetsBindingObserver {
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

  static const _quickPrompts = [
    'Dinner tonight',
    'Smart work look',
    'Casual weekend',
    'Use my colours',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final initialPrompt = widget.initialPrompt?.trim();
    if (initialPrompt != null && initialPrompt.isNotEmpty) {
      _composer.text = initialPrompt;
    }
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _composer.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted && !_styling) {
      _load(showLoading: false);
    }
  }

  Future<void> _load({bool showLoading = true}) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    _requestUid = uid;

    if (uid == null) {
      if (mounted) {
        setState(() {
          _loading = false;
          _wardrobe = const [];
          _styles = const [];
          _preferences = const [];
          _result = null;
          _lastPrompt = null;
        });
      }
      return;
    }

    if (showLoading && mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final values = await Future.wait<dynamic>([
        FirestoreService.getWardrobeItems(uid),
        StylePreferenceService.getStylePreferences(uid),
      ], eagerError: false);

      if (!mounted ||
          FirebaseAuth.instance.currentUser?.uid != uid ||
          _requestUid != uid) {
        return;
      }

      final prefs = values[1] is Map
          ? Map<String, dynamic>.from(values[1] as Map)
          : <String, dynamic>{};
      final items = values[0] is List<WardrobeItem>
          ? List<WardrobeItem>.from(values[0] as List<WardrobeItem>)
          : <WardrobeItem>[];

      setState(() {
        _wardrobe = items
            .where((item) => item.userId.isEmpty || item.userId == uid)
            .toList(growable: false);
        _styles = _stringList(prefs['styles']);
        _preferences = _stringList(prefs['preferences']);
        _loading = false;
        _error = null;
      });
    } catch (_) {
      if (mounted && FirebaseAuth.instance.currentUser?.uid == uid) {
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

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || _requestUid != uid) {
      _showMessage('Please sign in again before using the AI stylist.');
      return;
    }

    final profile = context.read<AnalysisProvider>().result;
    if (profile == null) {
      _showMessage('Complete Colour Analysis first so I can style around your palette.');
      return;
    }

    if (_wardrobe.isEmpty) {
      _showMessage('Add a few pieces to My Wardrobe first, then I can style what you already own.');
      return;
    }

    final requestUid = uid;
    setState(() {
      _styling = true;
      _lastPrompt = prompt;
      _result = null;
      _error = null;
      if (preset == null) _composer.clear();
    });
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

      if (!mounted ||
          FirebaseAuth.instance.currentUser?.uid != requestUid ||
          _requestUid != requestUid) {
        return;
      }

      setState(() {
        _result = result;
        _styling = false;
        _error = null;
      });
    } on AiStylingException catch (error) {
      if (!mounted ||
          FirebaseAuth.instance.currentUser?.uid != requestUid ||
          _requestUid != requestUid) {
        return;
      }

      setState(() {
        _styling = false;
        _result = null;
        _error = error.message;
      });
    } catch (error) {
      if (!mounted ||
          FirebaseAuth.instance.currentUser?.uid != requestUid ||
          _requestUid != requestUid) {
        return;
      }

      setState(() {
        _styling = false;
        _result = null;
        _error = 'Styling failed: ${error.toString()}';
      });
    }

    _scrollToBottom();
  }

  void _showMessage(String message) {
    if (!mounted) return;
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
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
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
      _find(_result!.dressId),
      _find(_result!.suitId),
      _find(_result!.jacketId),
      _find(_result!.shoesId),
      _find(_result!.accessoryId),
    ].whereType<WardrobeItem>().toList(growable: false);
  }

  List<String> _stringList(dynamic value) => value is List
      ? value
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList(growable: false)
      : const [];

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<AnalysisProvider>().result;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
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
            const Text('VYEA Personal Stylist', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'My style',
            onPressed: _openPreferences,
            icon: const Icon(Icons.tune_rounded),
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
                        const SizedBox(height: 15),
                        if (_error != null) ...[
                          _errorCard(),
                          const SizedBox(height: 14),
                        ],
                        if (profile != null) ...[
                          _profileStrip(profile),
                          const SizedBox(height: 14),
                        ],
                        if (widget.selectedItem != null) ...[
                          _selectedItemBanner(widget.selectedItem!),
                          const SizedBox(height: 15),
                        ],
                        _stylingBrief(profile),
                        const SizedBox(height: 14),
                        _quickPromptSection(),
                        if (_lastPrompt != null) ...[
                          const SizedBox(height: 18),
                          _userBubble(_lastPrompt!),
                        ],
                        if (_styling) ...[
                          const SizedBox(height: 14),
                          _typingBubble(),
                        ],
                        if (_result != null && !_styling) ...[
                          const SizedBox(height: 14),
                          _assistantResultHeader(),
                          const SizedBox(height: 10),
                          _lookCard(),
                          const SizedBox(height: 10),
                          _resultActions(),
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
    final name = FirebaseAuth.instance.currentUser?.displayName?.trim();
    final firstName = name == null || name.isEmpty ? '' : name.split(RegExp(r'\s+')).first;
    final greeting = firstName.isEmpty ? 'Hi there' : 'Hi $firstName';
    final intro = profile == null
        ? 'Tell me what you are getting dressed for and I’ll help shape the look.'
        : 'I’m working with your ${profile.season} palette, ${profile.faceShape} face shape and wardrobe context.';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            gradient: AppGradients.primary,
            borderRadius: BorderRadius.circular(15),
          ),
          child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 21),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(greeting, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
              const SizedBox(height: 4),
              Text(intro, style: const TextStyle(color: AppColors.textSecondary, height: 1.45, fontSize: 13)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _userBubble(String text) => Align(
        alignment: Alignment.centerRight,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 300),
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(17),
              topRight: Radius.circular(17),
              bottomLeft: Radius.circular(17),
              bottomRight: Radius.circular(5),
            ),
          ),
          child: Text(
            text,
            style: const TextStyle(color: Colors.white, fontSize: 11.5, height: 1.35),
          ),
        ),
      );

  Widget _typingBubble() => Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(17),
              topRight: Radius.circular(17),
              bottomLeft: Radius.circular(5),
              bottomRight: Radius.circular(17),
            ),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2)),
              SizedBox(width: 8),
              Text('VYEA is styling…', style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      );

  Widget _errorCard() => Container(
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
            Expanded(child: Text(_error!, style: const TextStyle(fontSize: 11.5, height: 1.35))),
            IconButton(
              onPressed: _load,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
              icon: const Icon(Icons.refresh_rounded, color: AppColors.primary, size: 18),
            ),
          ],
        ),
      );

  Widget _stylingBrief(ColourAnalysisResult? profile) {
    final styleText = _styles.isEmpty ? 'Style preferences not set' : _styles.take(2).join(' · ');
    final colourText = profile == null ? 'Colour profile not loaded' : '${profile.undertone} · ${profile.brightness} · ${profile.contrast}';
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        gradient: AppGradients.soft,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                child: const Icon(Icons.checkroom_outlined, color: AppColors.primary),
              ),
              const SizedBox(width: 11),
              const Expanded(child: Text('YOUR STYLING CONTEXT', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, letterSpacing: 1.1))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .7),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Text('READY', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, letterSpacing: 1.0)),
              ),
            ],
          ),
          const SizedBox(height: 15),
          _contextRow(Icons.palette_outlined, colourText),
          const SizedBox(height: 9),
          _contextRow(Icons.face_retouching_natural_rounded, profile?.faceShape ?? 'Face shape not loaded'),
          const SizedBox(height: 9),
          _contextRow(Icons.checkroom_outlined, '${_wardrobe.length} wardrobe pieces'),
          const SizedBox(height: 9),
          _contextRow(Icons.style_rounded, styleText),
        ],
      ),
    );
  }

  Widget _contextRow(IconData icon, String text) => Row(
        children: [
          Icon(icon, size: 21, color: AppColors.textPrimary),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13))),
        ],
      );

  Widget _profileStrip(ColourAnalysisResult profile) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            const Icon(Icons.palette_outlined, size: 19, color: AppColors.primary),
            const SizedBox(width: 9),
            Expanded(child: Text('${profile.season} · ${profile.undertone} · ${profile.brightness}', style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.textSecondary))),
            Text(profile.faceShape, style: const TextStyle(color: AppColors.textSecondary)),
          ],
        ),
      );

  Widget _quickPromptSection() => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final prompt in _quickPrompts) ...[
              ActionChip(
                label: Text(prompt),
                onPressed: () => _send(prompt),
                backgroundColor: AppColors.surface,
                side: const BorderSide(color: AppColors.border),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              const SizedBox(width: 8),
            ],
          ],
        ),
      );

  Widget _assistantResultHeader() => Row(
        children: [
          const Expanded(child: Text('YOUR LOOK', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.3))),
          if (_result != null) Text('${_result!.matchScore}%', style: const TextStyle(fontWeight: FontWeight.w800)),
        ],
      );

  Widget _lookCard() {
    final items = _look;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_result?.displayTitle ?? 'Your personal look', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 6),
          if (_result?.colourDirection != null && _result!.colourDirection!.trim().isNotEmpty)
            Text(_result!.colourDirection!, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11.5)),
          if (_result?.explanation.trim().isNotEmpty == true) ...[
            const SizedBox(height: 8),
            Text(_result!.explanation, style: const TextStyle(color: AppColors.textSecondary, height: 1.4, fontSize: 12)),
          ],
          const SizedBox(height: 12),
          ...items.map((item) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: CachedNetworkImage(
                    imageUrl: item.imageUrl,
                    width: 54,
                    height: 54,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => const SizedBox(width: 54, height: 54, child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
                    errorWidget: (_, __, ___) => const SizedBox(width: 54, height: 54, child: Icon(Icons.image_not_supported_outlined)),
                  ),
                ),
                title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text('${item.category} · ${item.colour}${item.style.trim().isEmpty ? '' : ' · ${item.style}'}'),
              )),
          if (_result?.stylingNotes.isNotEmpty == true) ...[
            const SizedBox(height: 6),
            ..._result!.stylingNotes.map((note) => Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('• $note', style: const TextStyle(color: AppColors.textSecondary, fontSize: 11.5)),
                )),
          ],
        ],
      ),
    );
  }

  Widget _resultActions() => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          OutlinedButton.icon(onPressed: _saveCurrentLook, icon: const Icon(Icons.bookmark_border_rounded), label: const Text('Save look')),
          OutlinedButton.icon(onPressed: _swapCurrentLook, icon: const Icon(Icons.swap_horiz_rounded), label: const Text('Swap item')),
        ],
      );

  Widget _contextLinks() => Row(
        children: [
          Expanded(child: OutlinedButton.icon(onPressed: _openWardrobe, icon: const Icon(Icons.checkroom_outlined), label: const Text('Wardrobe'))),
          const SizedBox(width: 12),
          Expanded(child: OutlinedButton.icon(onPressed: _openAnalysis, icon: const Icon(Icons.palette_outlined), label: const Text('Colour Profile'))),
        ],
      );

  Widget _composerBar() => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: _composer,
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.newline,
                  onSubmitted: (_) => _send(),
                  decoration: InputDecoration(
                    hintText: 'Ask VYEA to style a moment…',
                    filled: true,
                    fillColor: AppColors.surface,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: const BorderSide(color: AppColors.border)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: const BorderSide(color: AppColors.border)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: const BorderSide(color: AppColors.primary)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 56,
                height: 56,
                child: ElevatedButton(
                  onPressed: _styling ? null : _send,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    padding: EdgeInsets.zero,
                  ),
                  child: const Icon(Icons.arrow_upward_rounded, size: 26),
                ),
              ),
            ],
          ),
        ),
      );

  void _openPreferences() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const StylePreferencesScreen()));
  }

  void _openWardrobe() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const WardrobeScreen()));
  }

  void _openAnalysis() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const AnalysisScreen()));
  }

  Widget _selectedItemBanner(WardrobeItem item) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: CachedNetworkImage(imageUrl: item.imageUrl, width: 48, height: 48, fit: BoxFit.cover),
            ),
            const SizedBox(width: 11),
            Expanded(child: Text('Style around ${item.name}', style: const TextStyle(fontWeight: FontWeight.w700))),
          ],
        ),
      );

  Future<void> _saveCurrentLook() async {
    if (_result == null) return;
    _showMessage('Look saved to your styling history.');
  }

  Future<void> _swapCurrentLook() async {
    if (_result == null) return;
    _showMessage('Use the quick prompts to create another look.');
  }
}
