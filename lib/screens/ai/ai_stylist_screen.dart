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
        if (result == null) {
          _error = 'I could not build a look from the current styling service. Try again or refine your request.';
        }
      });
    } catch (_) {
      if (!mounted ||
          FirebaseAuth.instance.currentUser?.uid != requestUid ||
          _requestUid != requestUid) {
        return;
      }

      setState(() {
        _styling = false;
        _error = 'I could not build a look right now. Please try again.';
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
            const Text(
              'VYEA Personal Stylist',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
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
    final firstName = name == null || name.isEmpty
        ? ''
        : name.split(RegExp(r'\s+')).first;
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

  Widget _errorCard() {
    return Container(
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
              style: const TextStyle(fontSize: 11.5, height: 1.35),
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

  Widget _stylingBrief(ColourAnalysisResult? profile) {
    final styleText = _styles.isEmpty
        ? 'Style preferences not set'
        : _styles.take(2).join(' · ');
    final colourText = profile == null
        ? 'Colour profile not loaded'
        : '${profile.undertone} · ${profile.brightness} · ${profile.contrast}';

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
              const Expanded(
                child: Text(
                  'YOUR STYLING CONTEXT',
                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1.1),
                ),
              ),
              _contextPill(_wardrobe.length >= 3 ? 'READY' : 'BUILDING'),
            ],
          ),
          const SizedBox(height: 12),
          _contextLine(Icons.palette_outlined, colourText),
          const SizedBox(height: 6),
          _contextLine(Icons.face_retouching_natural_outlined, profile?.faceShape ?? 'Face shape not loaded'),
          const SizedBox(height: 6),
          _contextLine(Icons.checkroom_outlined, '${_wardrobe.length} wardrobe pieces'),
          const SizedBox(height: 6),
          _contextLine(Icons.style_outlined, styleText),
          if (widget.selectedItem != null) ...[
            const SizedBox(height: 6),
            _contextLine(Icons.push_pin_outlined, 'Styling around ${widget.selectedItem!.name}'),
          ],
        ],
      ),
    );
  }

  Widget _contextLine(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 10.8, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  Widget _contextPill(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 7.5, fontWeight: FontWeight.w900, letterSpacing: .8, color: AppColors.primary),
      ),
    );
  }

  Widget _selectedItemBanner(WardrobeItem item) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.secondary.withValues(alpha: .55),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.primary.withValues(alpha: .12)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 52,
              height: 52,
              child: item.imageUrl.isEmpty
                  ? Container(
                      color: AppColors.surfaceMuted,
                      child: const Icon(Icons.checkroom_outlined, color: AppColors.primary),
                    )
                  : CachedNetworkImage(imageUrl: item.imageUrl, fit: BoxFit.cover),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('STYLING AROUND', style: TextStyle(fontSize: 9, letterSpacing: 1, fontWeight: FontWeight.w800, color: AppColors.textMuted)),
                const SizedBox(height: 3),
                Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text('${item.category} · ${item.colour}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10.5, color: AppColors.textSecondary)),
              ],
            ),
          ),
          const Icon(Icons.auto_awesome_rounded, color: AppColors.primary, size: 18),
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
              '${profile.season} · ${profile.undertone} · ${profile.brightness} · ${profile.contrast}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _quickPromptSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Expanded(
              child: Text(
                'START WITH A VIBE',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.05),
              ),
            ),
            Text('or type your own', style: TextStyle(fontSize: 9.5, color: AppColors.textMuted)),
          ],
        ),
        const SizedBox(height: 9),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _quickPrompts
              .map(
                (prompt) => ActionChip(
                  label: Text(prompt, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700)),
                  onPressed: _styling ? null : () => _send(prompt),
                  backgroundColor: AppColors.surface,
                  side: const BorderSide(color: AppColors.border),
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  Widget _userBubble(String text) => Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.only(left: 55),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: const BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(18),
              topRight: Radius.circular(18),
              bottomLeft: Radius.circular(18),
              bottomRight: Radius.circular(6),
            ),
          ),
          child: Text(
            text,
            style: const TextStyle(color: Colors.white, fontSize: 12.5, height: 1.45),
          ),
        ),
      );

  Widget _typingBubble() => Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
              SizedBox(width: 9),
              Text('VYEA is styling…', style: TextStyle(color: AppColors.textSecondary, fontSize: 11.5, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      );

  Widget _assistantResultHeader() {
    final title = _result?.lookTitle?.trim();
    final colour = _result?.colourDirection?.trim();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('VYEA LOOK', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.2, color: AppColors.primary)),
              const SizedBox(height: 3),
              Text(
                title?.isNotEmpty == true ? title! : 'Your personalised outfit',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: -.4),
              ),
            ],
          ),
        ),
        if (colour != null && colour.isNotEmpty)
          Flexible(
            child: Text(
              colour,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 9.5, color: AppColors.textSecondary, fontWeight: FontWeight.w700),
            ),
          ),
      ],
    );
  }

  Widget _lookCard() {
    final look = _look;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_result?.explanation.trim().isNotEmpty == true) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.auto_awesome_rounded, color: AppColors.primary, size: 18),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        _result!.explanation,
                        style: const TextStyle(fontSize: 11.5, height: 1.45, color: AppColors.textSecondary),
                      ),
                    ),
                  ],
                ),
                if (look.isNotEmpty) const SizedBox(height: 14),
              ],
              if (look.isEmpty)
                const Text(
                  'I could not connect the returned items to your current wardrobe. Try again after refreshing your wardrobe.',
                  style: TextStyle(fontSize: 11.5, height: 1.45, color: AppColors.textSecondary),
                )
              else
                ...look.asMap().entries.map((entry) {
                  final index = entry.key;
                  final item = entry.value;
                  return Padding(
                    padding: EdgeInsets.only(bottom: index == look.length - 1 ? 0 : 10),
                    child: _lookItem(item),
                  );
                }),
            ],
          ),
        ),
        if (_result?.stylingNotes.isNotEmpty == true) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('STYLING NOTES', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1.05, color: AppColors.textMuted)),
                const SizedBox(height: 8),
                ..._result!.stylingNotes.map(
                  (note) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 5),
                          child: Icon(Icons.circle, size: 5, color: AppColors.primary),
                        ),
                        const SizedBox(width: 8),
                        Expanded(child: Text(note, style: const TextStyle(fontSize: 11, height: 1.4, color: AppColors.textSecondary))),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _lookItem(WardrobeItem item) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(11),
            child: SizedBox(
              width: 58,
              height: 58,
              child: item.imageUrl.isEmpty
                  ? Container(
                      color: AppColors.surfaceMuted,
                      child: const Icon(Icons.checkroom_outlined, color: AppColors.primary),
                    )
                  : CachedNetworkImage(imageUrl: item.imageUrl, fit: BoxFit.cover),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.category.toUpperCase(), style: const TextStyle(fontSize: 8, color: AppColors.textMuted, fontWeight: FontWeight.w900, letterSpacing: .9)),
                const SizedBox(height: 3),
                Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text('${item.colour} · ${item.style}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10.5, color: AppColors.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _resultActions() {
    final look = _look;
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: look.isEmpty
                ? null
                : () => _showMessage('This look is ready to use. Save it from AI Outfit or your Saved Looks workflow.'),
            icon: const Icon(Icons.bookmark_border_rounded, size: 17),
            label: const Text('Use this look'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.primarySoft),
              padding: const EdgeInsets.symmetric(vertical: 11),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            ),
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: FilledButton.icon(
            onPressed: _styling ? null : () => _send('Give me another version with a different silhouette'),
            icon: const Icon(Icons.refresh_rounded, size: 17),
            label: const Text('Refine'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 11),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _contextLinks() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('PERSONALISE MORE', style: TextStyle(fontSize: 9, color: AppColors.textMuted, fontWeight: FontWeight.w900, letterSpacing: 1.1)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ActionChip(
              avatar: const Icon(Icons.palette_outlined, size: 15),
              label: const Text('Colour Analysis'),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AnalysisScreen())),
            ),
            ActionChip(
              avatar: const Icon(Icons.checkroom_outlined, size: 15),
              label: const Text('Wardrobe'),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WardrobeScreen())),
            ),
            ActionChip(
              avatar: const Icon(Icons.tune_rounded, size: 15),
              label: const Text('Style Preferences'),
              onPressed: _openPreferences,
            ),
          ],
        ),
      ],
    );
  }

  Widget _composerBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _composer,
                minLines: 1,
                maxLines: 3,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _send(),
                decoration: InputDecoration(
                  hintText: 'Tell VYEA what you need…',
                  filled: true,
                  fillColor: AppColors.background,
                  prefixIcon: const Icon(Icons.edit_note_rounded, size: 18),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(17),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(17),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(17),
                    borderSide: const BorderSide(color: AppColors.brown, width: 1.2),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Material(
              color: _styling ? AppColors.primary.withValues(alpha: .45) : AppColors.primary,
              borderRadius: BorderRadius.circular(17),
              child: InkWell(
                onTap: _styling ? null : _send,
                borderRadius: BorderRadius.circular(17),
                child: SizedBox(
                  width: 50,
                  height: 52,
                  child: Icon(
                    _styling ? Icons.hourglass_top_rounded : Icons.arrow_upward_rounded,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openPreferences() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const StylePreferencesScreen()),
    );
    if (mounted) await _load(showLoading: false);
  }
}
