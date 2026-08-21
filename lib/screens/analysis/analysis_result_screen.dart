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

  const AnalysisResultScreen({super.key, required this.result});

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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('PDF saved to Files > On My iPhone > TiB AI Personal Styling > Reports.'),
          duration: Duration(seconds: 4),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save the PDF report: $error')),
      );
    } finally {
      if (mounted) setState(() => _generatingReport = false);
    }
  }

  Future<void> _shareReport() async {
    if (_generatingReport) return;
    setState(() => _generatingReport = true);
    try {
      await ColourReportService.generateAndShare(
        result: result,
        shareText: 'My ${result.season} personal colour analysis from TiB.',
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not share the PDF report: $error')),
      );
    } finally {
      if (mounted) setState(() => _generatingReport = false);
    }
  }

  void _removePhotoAndRescan() {
    if (_generatingReport) return;
    context.read<AnalysisProvider>().clear();
    Navigator.pop(context, true);
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
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Navigator.pop(context, true),
        ),
        title: const Text('Your Colour Season'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Season Guide',
            onPressed: _generatingReport
                ? null
                : () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const SeasonColourGuideScreen(),
                      ),
                    ),
            icon: const Icon(Icons.menu_book_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            const Text('YOUR COLOUR PROFILE', style: TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
            const SizedBox(height: 7),
            Text(result.season.toUpperCase(), style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800, letterSpacing: -1)),
            const SizedBox(height: 4),
            Text('${result.undertone} · ${result.brightness} · ${result.contrast}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            const SizedBox(height: 18),
            _hero(accent, profile),
            const SizedBox(height: 18),
            _attributeRow(accent),
            const SizedBox(height: 22),
            _guideSummary(profile, accent),
            const SizedBox(height: 24),
            const Text('Best Colours', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 5),
            const Text('These shades are the easiest place to start when building outfits.', style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5, height: 1.4)),
            const SizedBox(height: 16),
            if (profile.bestColours.isEmpty) _emptyPalette() else _palette(profile.bestColours),
            const SizedBox(height: 24),
            _avoidSection(avoid, accent),
            const SizedBox(height: 22),
            _colourPsychologyPreview(accent),
            const SizedBox(height: 22),
            _makeupSection('Eye Shadow Colour Advise', profile.eyeShadowColours, accent),
            const SizedBox(height: 18),
            _makeupSection('Blush Colour Advise', profile.blushColours, accent),
            const SizedBox(height: 24),
            _whyItWorks(accent, profile),
            if (result.imageUrl.isNotEmpty) ...[
              const SizedBox(height: 24),
              const Text('Your Analysis', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: CachedNetworkImage(
                  imageUrl: result.imageUrl,
                  height: 230,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(height: 230, color: AppColors.surfaceMuted, child: const Center(child: CircularProgressIndicator())),
                  errorWidget: (context, url, error) => Container(height: 230, color: AppColors.surfaceMuted, child: const Center(child: Icon(Icons.image_not_supported_outlined))),
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.center,
                child: TextButton.icon(
                  onPressed: _generatingReport ? null : _removePhotoAndRescan,
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                  label: const Text('Remove Photo & Scan Again'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primaryDark,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _generatingReport ? null : _downloadReport,
                      icon: _generatingReport
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.download_rounded),
                      label: Text(_generatingReport ? 'Saving…' : 'Download PDF'),
                      style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _generatingReport ? null : _shareReport,
                      icon: const Icon(Icons.ios_share_rounded),
                      label: const Text('Share Report'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(50),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                'Tip: On iPhone, open Files → On My iPhone → TiB AI Personal Styling → Reports to find your saved PDF.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 11.5, height: 1.4),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProfessionalStyleScreen()),
              ),
              icon: const Icon(Icons.work_outline_rounded),
              label: const Text('Explore Professional Image'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(54),
                backgroundColor: AppColors.surface,
                foregroundColor: AppColors.primaryDark,
                side: const BorderSide(color: AppColors.border),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => Navigator.pop(context, true),
              icon: const Icon(Icons.auto_awesome_rounded),
              label: const Text('Style an Outfit With My Colours'),
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54), backgroundColor: AppColors.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17))),
            ),
          ],
        ),
      ),
    );
  }

  Widget _hero(Color accent, SeasonColourProfile profile) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      decoration: BoxDecoration(
        gradient: AppGradients.season(result.season),
        borderRadius: BorderRadius.circular(26),
        boxShadow: [BoxShadow(color: accent.withValues(alpha: .18), blurRadius: 24, offset: const Offset(0, 10))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('YOUR PALETTE', style: TextStyle(color: Colors.white70, fontSize: 9.5, fontWeight: FontWeight.w800, letterSpacing: 1.1)),
          const SizedBox(height: 10),
          Text(result.season, style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800)),
          const SizedBox(height: 5),
          Text(profile.description, style: const TextStyle(color: Colors.white70, fontSize: 12.5, height: 1.4)),
          const SizedBox(height: 12),
          Text(profile.dimension, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800)),
          if (profile.bestColours.isNotEmpty) ...[
            const SizedBox(height: 18),
            SizedBox(
              height: 42,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: profile.bestColours.take(7).length,
                separatorBuilder: (context, index) => const SizedBox(width: 7),
                itemBuilder: (context, index) => ColourSwatch(name: profile.bestColours[index], size: 42),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _guideSummary(SeasonColourProfile profile, Color accent) {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(21),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(color: accent.withValues(alpha: .12), shape: BoxShape.circle),
            child: Icon(Icons.auto_awesome_rounded, color: accent, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Your seasonal direction', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(profile.keywords.take(6).join(' • '), style: TextStyle(color: accent, fontSize: 11, fontWeight: FontWeight.w700)),
                const SizedBox(height: 5),
                const Text('TiB uses this season reference for your wardrobe matching, makeup colour advice and AI styling prompts.', style: TextStyle(color: AppColors.textSecondary, fontSize: 11.5, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _avoidSection(List<String> colours, Color accent) {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Less-Flattering Colours', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          const SizedBox(height: 5),
          const Text('Use these colours more carefully when they sit close to your face or dominate the outfit.', style: TextStyle(color: AppColors.textSecondary, fontSize: 11.5, height: 1.4)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 7,
            children: colours.map((name) => Chip(
              avatar: const Icon(Icons.remove_circle_outline_rounded, size: 16),
              label: Text(name, style: const TextStyle(fontSize: 10.5)),
              side: BorderSide(color: accent.withValues(alpha: .16)),
              backgroundColor: AppColors.surfaceMuted,
            )).toList(),
          ),
        ],
      ),
    );
  }

  Widget _colourPsychologyPreview(Color accent) {
    final cues = ProfessionalStyleData.colourPsychology.take(3).toList();
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.lavenderMist, Colors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Colour Psychology', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          const SizedBox(height: 5),
          const Text('Colour can help shape the impression you want to create.', style: TextStyle(color: AppColors.textSecondary, fontSize: 11.5, height: 1.4)),
          const SizedBox(height: 10),
          ...cues.map((cue) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Icon(Icons.auto_awesome_rounded, size: 14, color: accent),
                    const SizedBox(width: 7),
                    Expanded(child: Text('${cue.colour}  •  ${cue.impression}', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700))),
                  ],
                ),
              )),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfessionalStyleScreen())),
              child: const Text('Explore professional styling'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _attributeRow(Color accent) => Row(children: [_attribute('Undertone', result.undertone, Icons.thermostat_outlined, accent), _attribute('Brightness', result.brightness, Icons.wb_sunny_outlined, accent), _attribute('Contrast', result.contrast, Icons.contrast_rounded, accent)]);

  Widget _attribute(String label, String value, IconData icon, Color accent) {
    return Expanded(child: Container(margin: const EdgeInsets.only(right: 7), padding: const EdgeInsets.fromLTRB(9, 13, 9, 13), decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.border)), child: Column(children: [Icon(icon, color: accent, size: 20), const SizedBox(height: 8), Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 9.5, fontWeight: FontWeight.w700)), const SizedBox(height: 3), Text(value, maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800))])));
  }

  Widget _palette(List<String> colours) => Wrap(spacing: 9, runSpacing: 10, children: colours.map((name) => ColourSwatch(name: name, size: 66)).toList());

  Widget _emptyPalette() => Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: AppColors.surfaceMuted, borderRadius: BorderRadius.circular(18)), child: const Text('Your personal palette will appear here after the analysis.', style: TextStyle(color: AppColors.textSecondary)));

  Widget _makeupSection(String title, List<String> colours, Color accent) {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: colours.map((name) => Chip(label: Text(name, style: const TextStyle(fontSize: 10.5)), backgroundColor: accent.withValues(alpha: .08), side: BorderSide(color: accent.withValues(alpha: .14)))).toList()),
      ]),
    );
  }

  Widget _whyItWorks(Color accent, SeasonColourProfile profile) {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(children: [
        Icon(Icons.tips_and_updates_outlined, color: accent),
        const SizedBox(width: 11),
        Expanded(child: Text('Your ${profile.name} palette works best when the colours support its ${profile.dimension.toLowerCase()} qualities and stay close to your natural colouring.', style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary, height: 1.4))),
      ]),
    );
  }
}
