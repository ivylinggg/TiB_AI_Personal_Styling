import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_gradients.dart';
import '../../data/professional_style_data.dart';
import '../../data/season_colour_guide.dart';
import '../../models/colour_analysis_result.dart';
import '../../providers/analysis_provider.dart';
import '../../services/colour_report_service.dart';
import '../../services/firestore_service.dart';
import '../../services/style_preference_service.dart';
import '../../widgets/colour_swatch.dart';
import '../ai/ai_stylist_screen.dart';
import '../ai/style_preferences_screen.dart';
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
      final wardrobe = data[1] as List;
      final saved = data[2] as List;
      if (!mounted) return;
      setState(() {
        _styles = List<String>.from(prefs?['styles'] ?? const []);
        _preferences = List<String>.from(prefs?['preferences'] ?? const []);
        _wardrobeCount = wardrobe.length;
        _favourites = wardrobe.where((item) => item.isFavourite).length;
        _savedLooks = saved.length;
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

  void _openGuide() => Navigator.push(context, MaterialPageRoute(builder: (_) => const SeasonColourGuideScreen()));
  void _openStyle() => Navigator.push(context, MaterialPageRoute(builder: (_) => const StylePreferencesScreen())).then((_) => _loadPersonalContext());
  void _openAIStylist() => Navigator.push(context, MaterialPageRoute(builder: (_) => const AIStylistScreen()));

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
        actions: [IconButton(tooltip: 'Season Guide', onPressed: _generatingReport ? null : _openGuide, icon: const Icon(Icons.menu_book_outlined))],
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
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: _generatingReport ? null : _removePhotoAndRescan,
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: const Text('Use a different photo'),
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
      child: Row(children: [
        Container(width: 48, height: 48, decoration: BoxDecoration(color: accent.withValues(alpha: .12), shape: BoxShape.circle), child: Icon(Icons.face_retouching_natural, color: accent, size: 22)),
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
      ]),
    );
  }

  Widget _colourReasonCard(Color accent) {
    if (result.colourReasons.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.fromLTRB(17, 16, 17, 14),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(22), border: Border.all(color: AppColors.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Icon(Icons.insights_outlined, color: accent, size: 19), const SizedBox(width: 8), const Text('WHY THESE COLOURS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: .9))]),
        const SizedBox(height: 10),
        ...result.colourReasons.map((reason) => Padding(
          padding: const EdgeInsets.only(bottom: 7),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.check_rounded, size: 15, color: accent),
            const SizedBox(width: 7),
            Expanded(child: Text(reason, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11.5, height: 1.35))),
          ]),
        )),
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
        ...result.faceStylingGuidance.map((tip) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.arrow_forward_rounded, size: 15, color: accent),
            const SizedBox(width: 7),
            Expanded(child: Text(tip, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11.5, height: 1.35))),
          ]),
        )),
      ]),
    );
  }

  Widget _personalContextCard(Color accent) {
    if (_loadingPersonalContext) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(22), border: Border.all(color: AppColors.border)),
        child: const Row(children: [SizedBox(width: 17, height: 17, child: CircularProgressIndicator(strokeWidth: 2)), SizedBox(width: 10), Expanded(child: Text('Connecting your colour profile to your style space…', style: TextStyle(color: AppColors.textSecondary, fontSize: 11.5)))]),
      );
    }
    final hasContext = _styles.isNotEmpty || _preferences.isNotEmpty || _wardrobeCount > 0 || _savedLooks > 0;
    if (!hasContext) return _actionCard(accent: accent, icon: Icons.auto_awesome_rounded, title: 'Turn this result into your style identity', description: 'Choose a few style preferences so VYEA can connect your colours with the way you actually like to dress.', button: 'Set My Style', onPressed: _openStyle);
    return Container(
      padding: const EdgeInsets.fromLTRB(17, 17, 17, 15),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(22), border: Border.all(color: AppColors.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Container(width: 42, height: 42, decoration: BoxDecoration(color: accent.withValues(alpha: .12), shape: BoxShape.circle), child: Icon(Icons.auto_awesome_rounded, color: accent, size: 20)), const SizedBox(width: 11), const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Your style identity', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)), SizedBox(height: 3), Text('Your colour result is now connected to the rest of your VYEA profile.', style: TextStyle(color: AppColors.textSecondary, fontSize: 11.5, height: 1.35))]))]),
        const SizedBox(height: 12),
        if (_styles.isNotEmpty) Wrap(spacing: 6, runSpacing: 6, children: _styles.take(4).map((style) => _miniChip(style, accent)).toList()),
        if (_preferences.isNotEmpty) ...[if (_styles.isNotEmpty) const SizedBox(height: 7), Wrap(spacing: 6, runSpacing: 6, children: _preferences.take(3).map((pref) => _miniChip(pref, accent, subtle: true)).toList())],
        const SizedBox(height: 12),
        Row(children: [Expanded(child: _contextMetric('$_wardrobeCount', 'wardrobe')), _contextDivider(), Expanded(child: _contextMetric('$_favourites', 'favourites')), _contextDivider(), Expanded(child: _contextMetric('$_savedLooks', 'saved looks'))]),
        const SizedBox(height: 12),
        Row(children: [Expanded(child: OutlinedButton.icon(onPressed: _openStyle, icon: const Icon(Icons.tune_rounded, size: 16), label: const Text('Refine Style'))), const SizedBox(width: 8), Expanded(child: FilledButton.icon(onPressed: _openAIStylist, icon: const Icon(Icons.auto_awesome_rounded, size: 16), label: const Text('Style Me')))]),
      ]),
    );
  }

  Widget _hero(String season, SeasonColourProfile profile, Color accent) => Container(padding: const EdgeInsets.all(18), decoration: BoxDecoration(gradient: AppGradients.blush, borderRadius: BorderRadius.circular(24)), child: Row(children: [Container(width: 54, height: 54, decoration: BoxDecoration(color: accent.withValues(alpha: .16), shape: BoxShape.circle), child: Icon(Icons.palette_outlined, color: accent, size: 25)), const SizedBox(width: 13), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(profile.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)), const SizedBox(height: 3), Text(profile.dimension, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)), const SizedBox(height: 5), Text(profile.description, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11.5, height: 1.35))]))]));
  Widget _attributeRow(Color accent) => Row(children: [Expanded(child: _metric('UNDERTONE', result.undertone, accent)), const SizedBox(width: 8), Expanded(child: _metric('DEPTH', result.brightness, accent)), const SizedBox(width: 8), Expanded(child: _metric('CONTRAST', result.contrast, accent))]);
  Widget _metric(String label, String value, Color accent) => Container(padding: const EdgeInsets.all(13), decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(17), border: Border.all(color: AppColors.border)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: .7)), const SizedBox(height: 5), Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800))]));
  Widget _direction(SeasonColourProfile profile, Color accent) => Container(padding: const EdgeInsets.all(17), decoration: BoxDecoration(color: accent.withValues(alpha: .07), borderRadius: BorderRadius.circular(21), border: Border.all(color: accent.withValues(alpha: .15))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('YOUR COLOUR DIRECTION', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1)), const SizedBox(height: 7), Text(profile.dimension, style: TextStyle(color: accent, fontSize: 15, fontWeight: FontWeight.w900)), const SizedBox(height: 5), Text('Use these characteristics as a starting point across clothing, makeup and accessories.', style: const TextStyle(color: AppColors.textSecondary, fontSize: 11.5, height: 1.4))]));
  Widget _sectionHeading(String title, String subtitle) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)), const SizedBox(height: 4), Text(subtitle, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11.5, height: 1.35))]);
  Widget _palette(List<String> names) => Wrap(spacing: 8, runSpacing: 8, children: names.map((name) => ColourSwatch(name: name)).toList());
  Widget _emptyPalette() => const Text('No palette available for this result.', style: TextStyle(color: AppColors.textSecondary));
  Widget _avoidSection(List<String> avoid, Color accent) => Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(21), border: Border.all(color: AppColors.border)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('COLOURS TO APPROACH WITH CARE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1)), const SizedBox(height: 8), Text(avoid.isEmpty ? 'Use personal preference and mirror testing.' : avoid.join(' · '), style: const TextStyle(color: AppColors.textSecondary, fontSize: 11.5, height: 1.4))]));
  Widget _colourPsychologyPreview(Color accent) => Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(21), border: Border.all(color: AppColors.border)), child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('COLOUR PERSONALITY', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1)), SizedBox(height: 7), Text('Your palette can help guide the mood and visual energy you want to express.', style: TextStyle(color: AppColors.textSecondary, fontSize: 11.5, height: 1.4))]));
  Widget _makeupSection(String title, List<String> names, Color accent) => Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(21), border: Border.all(color: AppColors.border)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)), const SizedBox(height: 10), Text(names.join(' · '), style: const TextStyle(color: AppColors.textSecondary, fontSize: 11.5, height: 1.4))]));
  Widget _reportActions() => Row(children: [Expanded(child: OutlinedButton.icon(onPressed: _generatingReport ? null : _downloadReport, icon: const Icon(Icons.download_outlined, size: 17), label: const Text('PDF'))), const SizedBox(width: 8), Expanded(child: FilledButton.icon(onPressed: _generatingReport ? null : _shareReport, icon: const Icon(Icons.ios_share_rounded, size: 17), label: const Text('Share'))]);
  Widget _nextStepCard(Color accent) => _actionCard(accent: accent, icon: Icons.auto_awesome_rounded, title: 'Take your result into your wardrobe', description: 'Use your personal colours and face shape to make your next outfit decisions easier.', button: 'Open AI Stylist', onPressed: _openAIStylist);
  Widget _actionCard({required Color accent, required IconData icon, required String title, required String description, required String button, required VoidCallback onPressed}) => Container(padding: const EdgeInsets.all(17), decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(22), border: Border.all(color: AppColors.border)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(icon, color: accent), const SizedBox(height: 8), Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)), const SizedBox(height: 4), Text(description, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11.5, height: 1.4)), const SizedBox(height: 12), FilledButton(onPressed: onPressed, child: Text(button))]));
  Widget _miniChip(String text, Color accent, {bool subtle = false}) => Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6), decoration: BoxDecoration(color: subtle ? AppColors.surfaceMuted : accent.withValues(alpha: .08), borderRadius: BorderRadius.circular(10), border: Border.all(color: subtle ? AppColors.border : accent.withValues(alpha: .18))), child: Text(text, style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700)));
  Widget _contextMetric(String value, String label) => Column(children: [Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900)), const SizedBox(height: 2), Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 9))]);
  Widget _contextDivider() => Container(width: 1, height: 24, color: AppColors.border);
}
