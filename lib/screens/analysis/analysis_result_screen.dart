import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_gradients.dart';
import '../../data/professional_style_data.dart';
import '../../data/season_colour_guide.dart';
import '../../models/colour_analysis_result.dart';
import '../../models/wardrobe_item.dart';
import '../../providers/analysis_provider.dart';
import '../../services/colour_report_service.dart';
import '../../services/firestore_service.dart';
import '../../services/style_preference_service.dart';
import '../../widgets/colour_swatch.dart';
import '../ai/ai_outfit_screen.dart';
import '../ai/ai_stylist_screen.dart';
import '../ai/style_preferences_screen.dart';
import '../professional/professional_style_screen.dart';
import 'season_colour_guide_screen.dart';

class AnalysisResultScreen extends StatefulWidget {
  final ColourAnalysisResult result;
  final AnalysisProvider? analysisProvider;

  const AnalysisResultScreen({super.key, required this.result, this.analysisProvider});

  @override
  State<AnalysisResultScreen> createState() => _AnalysisResultScreenState();
}

class _AnalysisResultScreenState extends State<AnalysisResultScreen> {
  bool _generatingReport = false;
  bool _loadingPersonalContext = true;
  List<String> _styles = const [];
  List<String> _preferences = const [];
  int _wardrobeCount = 0;
  int _favourites = 0;
  int _savedLooks = 0;
  List<WardrobeItem> _matchingItems = const [];

  ColourAnalysisResult get result => widget.result;

  @override
  void initState() {
    super.initState();
    _loadPersonalContext();
  }

  Future<void> _loadPersonalContext() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (mounted) setState(() => _loadingPersonalContext = false);
      return;
    }
    try {
      final data = await Future.wait<dynamic>([
        StylePreferenceService.getStylePreferences(uid),
        FirestoreService.getWardrobeItems(uid),
        FirestoreService.getSavedOutfitLooks(uid),
      ]);
      final prefs = data[0] as Map<String, dynamic>?;
      final wardrobe = data[1] as List<WardrobeItem>;
      final saved = data[2] as List;
      final season = result.season.toLowerCase();
      final colours = result.colours.map((e) => e.toLowerCase()).toList();
      final matches = wardrobe.where((item) {
        final text = '${item.colour} ${item.style} ${item.season}'.toLowerCase();
        return (colours.isNotEmpty && colours.any(text.contains)) || (season.isNotEmpty && text.contains(season));
      }).take(6).toList();
      if (!mounted) return;
      setState(() {
        _styles = List<String>.from(prefs?['styles'] ?? const []);
        _preferences = List<String>.from(prefs?['preferences'] ?? const []);
        _wardrobeCount = wardrobe.length;
        _favourites = wardrobe.where((item) => item.isFavourite).length;
        _savedLooks = saved.length;
        _matchingItems = matches;
        _loadingPersonalContext = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingPersonalContext = false);
    }
  }

  Future<void> _downloadReport() async {
    if (_generatingReport) return;
    setState(() => _generatingReport = true);
    try {
      await ColourReportService.saveReport(result: result);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PDF saved to Files > On My iPhone > TiB AI Personal Styling > Reports.')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not save the PDF report: $error')));
    } finally {
      if (mounted) setState(() => _generatingReport = false);
    }
  }

  Future<void> _shareReport() async {
    if (_generatingReport) return;
    setState(() => _generatingReport = true);
    try {
      await ColourReportService.generateAndShare(result: result, shareText: 'My ${result.season} personal colour analysis from VYEA.');
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not share the PDF report: $error')));
    } finally {
      if (mounted) setState(() => _generatingReport = false);
    }
  }

  void _removePhotoAndRescan() {
    if (_generatingReport) return;
    (widget.analysisProvider ?? context.read<AnalysisProvider>()).clear();
    Navigator.pop(context, true);
  }

  void _openGuide() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const SeasonColourGuideScreen()));
  }

  void _openStyle() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const StylePreferencesScreen())).then((_) => _loadPersonalContext());
  }

  void _openAIStylist() => Navigator.push(context, MaterialPageRoute(builder: (_) => const AIStylistScreen()));
  void _openAIOutfit() => Navigator.push(context, MaterialPageRoute(builder: (_) => const AIOutfitScreen()));

  @override
  Widget build(BuildContext context) {
    final profile = SeasonColourGuide.forSeason(result.season);
    final accent = AppColors.seasonAccent(result.season);
    final avoid = ProfessionalStyleData.avoidColours[result.season] ?? const <String>[];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18), onPressed: () => Navigator.pop(context, true)),
        title: const Text('Personal Analysis'),
        centerTitle: true,
        actions: [
          IconButton(tooltip: 'Season Guide', onPressed: _generatingReport ? null : _openGuide, icon: const Icon(Icons.menu_book_outlined)),
        ],
      ),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  const Text('YOUR PERSONAL RESULT', style: TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.3)),
                  const SizedBox(height: 7),
                  Text(result.season.toUpperCase(), style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900, letterSpacing: -1.2)),
                  const SizedBox(height: 4),
                  Text('${result.undertone}  ·  ${result.brightness}  ·  ${result.contrast}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                  const SizedBox(height: 18),
                  _hero(result.season, profile, accent),
                  const SizedBox(height: 18),
                  _attributeRow(accent),
                  const SizedBox(height: 18),
                  _faceShapeCard(accent),
                  const SizedBox(height: 18),
                  _colourReasonCard(accent),
                  const SizedBox(height: 22),
                  _direction(profile, accent),
                  const SizedBox(height: 22),
                  _personalContextCard(accent),
                  const SizedBox(height: 24),
                  _sectionHeading('Your Personal Colour Palette', 'Colours selected from your observed colour characteristics.'),
                  const SizedBox(height: 14),
                  profile.bestColours.isEmpty ? _emptyPalette() : _palette(profile.bestColours),
                  const SizedBox(height: 24),
                  _avoidSection(avoid, accent),
                  const SizedBox(height: 22),
                  _colourPsychologyPreview(accent),
                  const SizedBox(height: 22),
                  _makeupSection('Eye Shadow Colour Advice', profile.eyeShadowColours, accent),
                  const SizedBox(height: 16),
                  _makeupSection('Blush Colour Advice', profile.blushColours, accent),
                  if (result.faceStylingGuidance.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    _faceGuidanceCard(accent),
                  ],
                  if (result.imageUrl.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    _sectionHeading('Your Analysis Photo', 'Keep this reference alongside your result when comparing colours.'),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: CachedNetworkImage(
                        imageUrl: result.imageUrl,
                        height: 250,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(height: 250, color: AppColors.surfaceMuted, child: const Center(child: CircularProgressIndicator())),
                        errorWidget: (context, url, error) => Container(height: 250, color: AppColors.surfaceMuted, child: const Center(child: Icon(Icons.image_not_supported_outlined))),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: _generatingReport ? null : _removePhotoAndRescan,
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: const Text('Use a different photo'),
                        style: TextButton.styleFrom(foregroundColor: AppColors.primaryDark),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  _reportActions(),
                  const SizedBox(height: 14),
                  _nextStepCard(accent),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _faceShapeCard(Color accent) {
    final shape = result.faceShape.trim().isEmpty ? 'Unknown' : result.faceShape;
    return Container(
      padding: const EdgeInsets.fromLTRB(17, 17, 17, 15),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(22), border: Border.all(color: AppColors.border)),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(color: accent.withValues(alpha: .12), shape: BoxShape.circle),
            child: Icon(Icons.face_retouching_natural, color: accent, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('YOUR FACE SHAPE', style: TextStyle(color: AppColors.textMuted, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1)),
              const SizedBox(height: 4),
              Text(shape.toUpperCase(), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
              if (result.faceShapeDescription.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(result.faceShapeDescription, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11.5, height: 1.35)),
              ],
            ]),
          ),
        ],
      ),
    );
  }

  Widget _colourReasonCard(Color accent) {
    if (result.colourReasons.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.fromLTRB(17, 16, 17, 14),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(22), border: Border.all(color: AppColors.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Icon(Icons.insights_outlined, color: accent, size: 19), const SizedBox(width: 8), const Text('WHY THIS COLOUR PROFILE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: .9))]),
        const SizedBox(height: 10),
        ...result.colourReasons.map((reason) => Padding(padding: const EdgeInsets.only(bottom: 7), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(Icons.check_rounded, size: 15, color: accent), const SizedBox(width: 7), Expanded(child: Text(reason, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11.5, height: 1.35)))]))),
      ]),
    );
  }

  Widget _faceGuidanceCard(Color accent) {
    return Container(
      padding: const EdgeInsets.fromLTRB(17, 17, 17, 15),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(22), border: Border.all(color: AppColors.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Icon(Icons.auto_awesome_outlined, color: accent, size: 20), const SizedBox(width: 8), const Text('STYLE FROM YOUR FACE SHAPE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: .9))]),
        const SizedBox(height: 11),
        ...result.faceStylingGuidance.map((tip) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(Icons.arrow_forward_rounded, size: 15, color: accent), const SizedBox(width: 7), Expanded(child: Text(tip, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11.5, height: 1.35)))]))),
      ]),
    );
  }

  Widget _personalContextCard(Color accent) {
    if (_loadingPersonalContext) {
      return Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(22), border: Border.all(color: AppColors.border)), child: const Row(children: [SizedBox(width: 17, height: 17, child: CircularProgressIndicator(strokeWidth: 2)), SizedBox(width: 10), Expanded(child: Text('Connecting your colour profile to your style space…', style: TextStyle(color: AppColors.textSecondary, fontSize: 11.5)))]));
    }
    final hasContext = _styles.isNotEmpty || _preferences.isNotEmpty || _wardrobeCount > 0 || _savedLooks > 0;
    if (!hasContext) {
      return _actionCard(accent: accent, icon: Icons.auto_awesome_rounded, title: 'Turn this result into your style identity', description: 'Choose a few style preferences so VYEA can connect your colours with the way you actually like to dress.', button: 'Set My Style', onPressed: _openStyle);
    }
    return Container(
      padding: const EdgeInsets.fromLTRB(17, 17, 17, 15),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(22), border: Border.all(color: AppColors.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Container(width: 42, height: 42, decoration: BoxDecoration(color: accent.withValues(alpha: .12), shape: BoxShape.circle), child: Icon(Icons.auto_awesome_rounded, color: accent, size: 20)), const SizedBox(width: 11), const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Your style identity', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)), SizedBox(height: 3), Text('Your colour result is now connected to the rest of your VYEA profile.', style: TextStyle(color: AppColors.textSecondary, fontSize: 11.5, height: 1.35))]))]),
        const SizedBox(height: 12),
        if (_styles.isNotEmpty) Wrap(spacing: 6, runSpacing: 6, children: _styles.take(4).map((style) => _miniChip(style, accent)).toList()),
        if (_preferences.isNotEmpty) ...[
          if (_styles.isNotEmpty) const SizedBox(height: 7),
          Wrap(spacing: 6, runSpacing: 6, children: _preferences.take(3).map((pref) => _miniChip(pref, accent, subtle: true)).toList()),
        ],
        const SizedBox(height: 12),
        Row(children: [Expanded(child: _contextMetric('$_wardrobeCount', 'wardrobe')), _contextDivider(), Expanded(child: _contextMetric('$_favourites', 'favourites')), _contextDivider(), Expanded(child: _contextMetric('$_savedLooks', 'saved looks'))]),
        if (_matchingItems.isNotEmpty) ...[
          const SizedBox(height: 13),
          const Text('PALETTE-MATCHED PIECES', style: TextStyle(color: AppColors.textMuted, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1)),
          const SizedBox(height: 8),
          SizedBox(height: 72, child: ListView.separated(scrollDirection: Axis.horizontal, itemCount: _matchingItems.length, separatorBuilder: (_, _) => const SizedBox(width: 8), itemBuilder: (_, index) {
            final item = _matchingItems[index];
            return Container(width: 130, padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8), decoration: BoxDecoration(color: AppColors.surfaceMuted, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)), child: Row(children: [Container(width: 50, height: 56, decoration: BoxDecoration(color: AppColors.secondary, borderRadius: BorderRadius.circular(10)), clipBehavior: Clip.antiAlias, child: item.imageUrl.isEmpty ? const Icon(Icons.checkroom_outlined, color: AppColors.primary) : CachedNetworkImage(imageUrl: item.imageUrl, fit: BoxFit.cover, errorWidget: (_, _, _) => const Icon(Icons.checkroom_outlined, color: AppColors.primary))), const SizedBox(width: 7), Expanded(child: Text(item.name, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800)))]));
          })),
        ],
        const SizedBox(height: 12),
        Row(children: [Expanded(child: OutlinedButton.icon(onPressed: _openStyle, icon: const Icon(Icons.tune_rounded, size: 16), label: const Text('Refine Style'))), const SizedBox(width: 8), Expanded(child: FilledButton.icon(onPressed: _openAIStylist, icon: const Icon(Icons.auto_awesome_rounded, size: 16), label: const Text('Style Me')))]),
      ]),
    );
  }

  // Existing helper methods below are intentionally preserved in the same screen:
  // _hero, _attributeRow, _direction, _sectionHeading, _palette, _emptyPalette,
  // _avoidSection, _colourPsychologyPreview, _makeupSection, _reportActions,
  // _nextStepCard, _actionCard, _miniChip, _contextMetric, _contextDivider.
}
