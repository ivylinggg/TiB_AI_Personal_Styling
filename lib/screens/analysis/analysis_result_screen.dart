import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_gradients.dart';
import '../../data/professional_style_data.dart';
import '../../data/season_colour_guide.dart';
import '../../models/colour_analysis_result.dart';
import '../../providers/analysis_provider.dart';
import '../../services/colour_report_service.dart';
import '../../widgets/colour_swatch.dart';
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

  ColourAnalysisResult get result => widget.result;

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
      await ColourReportService.generateAndShare(result: result, shareText: 'My ${result.season} personal colour analysis from TiB.');
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
        title: const Text('Colour Profile'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Season Guide',
            onPressed: _generatingReport ? null : _openGuide,
            icon: const Icon(Icons.menu_book_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  const Text('YOUR RESULT', style: TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.3)),
                  const SizedBox(height: 7),
                  Text(result.season.toUpperCase(), style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900, letterSpacing: -1.2)),
                  const SizedBox(height: 4),
                  Text('${result.undertone}  ·  ${result.brightness}  ·  ${result.contrast}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                  const SizedBox(height: 18),
                  _hero(result.season, profile, accent),
                  const SizedBox(height: 18),
                  _attributeRow(accent),
                  const SizedBox(height: 22),
                  _direction(profile, accent),
                  const SizedBox(height: 24),
                  _sectionHeading('Your Best Colours', 'The shades that make the easiest starting point for your wardrobe.'),
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

  Widget _hero(String season, SeasonColourProfile profile, Color accent) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      decoration: BoxDecoration(
        gradient: AppGradients.season(season),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [BoxShadow(color: accent.withValues(alpha: .16), blurRadius: 26, offset: const Offset(0, 12))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('YOUR SEASON', style: TextStyle(color: Colors.white70, fontSize: 9.5, fontWeight: FontWeight.w800, letterSpacing: 1.1)),
          const SizedBox(height: 10),
          Text(season, style: const TextStyle(color: Colors.white, fontSize: 29, fontWeight: FontWeight.w900, letterSpacing: -.4)),
          const SizedBox(height: 6),
          Text(profile.description, style: const TextStyle(color: Colors.white70, fontSize: 12.5, height: 1.45)),
          const SizedBox(height: 12),
          Text(profile.dimension, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800)),
          if (profile.bestColours.isNotEmpty) ...[
            const SizedBox(height: 17),
            SizedBox(
              height: 44,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: profile.bestColours.take(7).length,
                separatorBuilder: (context, index) => const SizedBox(width: 7),
                itemBuilder: (context, index) => ColourSwatch(name: profile.bestColours[index], size: 44),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _attributeRow(Color accent) => Row(
        children: [
          _attribute('Undertone', result.undertone, Icons.thermostat_outlined, accent),
          const SizedBox(width: 7),
          _attribute('Brightness', result.brightness, Icons.wb_sunny_outlined, accent),
          const SizedBox(width: 7),
          _attribute('Contrast', result.contrast, Icons.contrast_rounded, accent),
        ],
      );

  Widget _attribute(String label, String value, IconData icon, Color accent) => Expanded(
        child: Container(
          padding: const EdgeInsets.fromLTRB(9, 13, 9, 13),
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.border)),
          child: Column(
            children: [
              Icon(icon, color: accent, size: 18),
              const SizedBox(height: 7),
              Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 9.5, fontWeight: FontWeight.w800)),
              const SizedBox(height: 3),
              Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800)),
            ],
          ),
        ),
      );

  Widget _direction(SeasonColourProfile profile, Color accent) => Container(
        padding: const EdgeInsets.all(17),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(22), border: Border.all(color: AppColors.border)),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(width: 44, height: 44, decoration: BoxDecoration(color: accent.withValues(alpha: .12), shape: BoxShape.circle), child: Icon(Icons.auto_awesome_rounded, color: accent, size: 20)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Your seasonal direction', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 5),
                  Text(profile.keywords.take(6).join('  ·  '), style: TextStyle(color: accent, fontSize: 11, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 7),
                  const Text('VYEA uses this colour identity across wardrobe matching, makeup guidance and personal styling.', style: TextStyle(color: AppColors.textSecondary, fontSize: 11.5, height: 1.45)),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _sectionHeading(String title, String subtitle) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900, letterSpacing: -.5)),
          const SizedBox(height: 5),
          Text(subtitle, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5, height: 1.4)),
        ],
      );

  Widget _avoidSection(List<String> colours, Color accent) => Container(
        padding: const EdgeInsets.all(17),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(21), border: Border.all(color: AppColors.border)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Less-Flattering Colours', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            const SizedBox(height: 5),
            const Text('Use these shades more carefully when they sit close to your face or dominate an outfit.', style: TextStyle(color: AppColors.textSecondary, fontSize: 11.5, height: 1.4)),
            const SizedBox(height: 11),
            Wrap(
              spacing: 8,
              runSpacing: 7,
              children: colours.map((name) => Chip(
                    avatar: Icon(Icons.remove_circle_outline_rounded, size: 16, color: accent),
                    label: Text(name, style: const TextStyle(fontSize: 10.5)),
                    side: BorderSide(color: accent.withValues(alpha: .16)),
                    backgroundColor: AppColors.surfaceMuted,
                  )).toList(),
            ),
          ],
        ),
      );

  Widget _colourPsychologyPreview(Color accent) {
    final cues = ProfessionalStyleData.colourPsychology.take(3).toList();
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(21), border: Border.all(color: AppColors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: _sectionHeading('Colour Psychology', 'Use colour intentionally for the impression you want to create.')),
              Icon(Icons.psychology_alt_outlined, color: accent, size: 21),
            ],
          ),
          const SizedBox(height: 11),
          ...cues.map((cue) => Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: Row(
                  children: [
                    Icon(Icons.auto_awesome_rounded, size: 14, color: accent),
                    const SizedBox(width: 7),
                    Expanded(child: Text('${cue.colour}  ·  ${cue.impression}', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700))),
                  ],
                ),
              )),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _generatingReport ? null : () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfessionalStyleScreen())),
              child: const Text('Explore professional styling'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _makeupSection(String title, List<String> colours, Color accent) => Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.border)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
                Icon(Icons.palette_outlined, color: accent, size: 19),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: colours.map((name) => ColourSwatch(name: name, size: 40, showLabel: true)).toList()),
          ],
        ),
      );

  Widget _palette(List<String> colours) => Wrap(spacing: 10, runSpacing: 11, children: colours.map((name) => ColourSwatch(name: name, size: 64, showLabel: true)).toList());

  Widget _emptyPalette() => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(color: AppColors.surfaceMuted, borderRadius: BorderRadius.circular(18)),
        child: const Text('Your personalised palette will appear here after analysis.', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
      );

  Widget _reportActions() => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(22), border: Border.all(color: AppColors.border)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('SAVE YOUR COLOUR PROFILE', style: TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.1)),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _generatingReport ? null : _downloadReport,
                    icon: _generatingReport ? const SizedBox(width: 17, height: 17, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.download_rounded),
                    label: Text(_generatingReport ? 'Saving…' : 'Download PDF'),
                    style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _generatingReport ? null : _shareReport,
                    icon: const Icon(Icons.ios_share_rounded),
                    label: const Text('Share'),
                    style: FilledButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, minimumSize: const Size.fromHeight(50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 9),
            const Text('Saved reports are available in Files > On My iPhone > TiB AI Personal Styling > Reports.', style: TextStyle(color: AppColors.textSecondary, fontSize: 11, height: 1.4)),
          ],
        ),
      );

  Widget _nextStepCard(Color accent) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(color: AppColors.primaryDark, borderRadius: BorderRadius.circular(23)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('NOW STYLE AROUND THIS COLOUR IDENTITY', style: TextStyle(color: accent.withValues(alpha: .95), fontSize: 9.5, fontWeight: FontWeight.w800, letterSpacing: 1.05)),
            const SizedBox(height: 7),
            const Text('Turn your result into outfits that still feel like you.', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: -.4)),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _generatingReport ? null : () => Navigator.pop(context, true),
              icon: const Icon(Icons.auto_awesome_rounded),
              label: const Text('Style an Outfit With My Colours'),
              style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: AppColors.primaryDark, minimumSize: const Size.fromHeight(52), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
            ),
            const SizedBox(height: 9),
            OutlinedButton.icon(
              onPressed: _generatingReport ? null : () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfessionalStyleScreen())),
              icon: const Icon(Icons.work_outline_rounded),
              label: const Text('Explore Professional Image'),
              style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white24), minimumSize: const Size.fromHeight(50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
            ),
          ],
        ),
      );
}
