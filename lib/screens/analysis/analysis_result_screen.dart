import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_gradients.dart';
import '../../models/colour_analysis_result.dart';
import '../../widgets/colour_swatch.dart';

/// Editorial colour-profile result. Users see the season first, then the
/// useful palette and the natural next step into outfit styling.
class AnalysisResultScreen extends StatelessWidget {
  final ColourAnalysisResult result;

  const AnalysisResultScreen({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.seasonAccent(result.season);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Your Colour Season'),
        centerTitle: true,
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
            _hero(accent),
            const SizedBox(height: 18),
            _attributeRow(accent),
            const SizedBox(height: 26),
            const Text('Best Colours', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 5),
            const Text('These shades are the easiest place to start when building outfits.', style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5, height: 1.4)),
            const SizedBox(height: 16),
            if (result.colours.isEmpty) _emptyPalette() else _palette(),
            const SizedBox(height: 24),
            _whyItWorks(accent),
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
                  placeholder: (_, __) => Container(height: 230, color: AppColors.surfaceMuted, child: const Center(child: CircularProgressIndicator())),
                  errorWidget: (_, __, ___) => Container(height: 230, color: AppColors.surfaceMuted, child: const Center(child: Icon(Icons.image_not_supported_outlined))),
                ),
              ),
            ],
            const SizedBox(height: 25),
            FilledButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.auto_awesome_rounded),
              label: const Text('Style an Outfit With My Colours'),
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54), backgroundColor: AppColors.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17))),
            ),
          ],
        ),
      ),
    );
  }

  Widget _hero(Color accent) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      decoration: BoxDecoration(gradient: AppGradients.season(result.season), borderRadius: BorderRadius.circular(26), boxShadow: [BoxShadow(color: accent.withValues(alpha: .18), blurRadius: 24, offset: const Offset(0, 10))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('YOUR PALETTE', style: TextStyle(color: Colors.white70, fontSize: 9.5, fontWeight: FontWeight.w800, letterSpacing: 1.1)),
        const SizedBox(height: 10),
        Text(result.season, style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800)),
        const SizedBox(height: 5),
        const Text('A softer, more personal way to choose colours that feel like you.', style: TextStyle(color: Colors.white70, fontSize: 12.5, height: 1.4)),
        if (result.colours.isNotEmpty) ...[
          const SizedBox(height: 18),
          SizedBox(height: 42, child: ListView.separated(scrollDirection: Axis.horizontal, itemCount: result.colours.take(7).length, separatorBuilder: (_, index) => const SizedBox(width: 7), itemBuilder: (_, index) => ColourSwatch(name: result.colours[index], size: 42))),
        ],
      ]),
    );
  }

  Widget _attributeRow(Color accent) => Row(children: [_attribute('Undertone', result.undertone, Icons.thermostat_outlined, accent), _attribute('Brightness', result.brightness, Icons.wb_sunny_outlined, accent), _attribute('Contrast', result.contrast, Icons.contrast_rounded, accent)]);

  Widget _attribute(String label, String value, IconData icon, Color accent) {
    return Expanded(child: Container(margin: const EdgeInsets.only(right: 7), padding: const EdgeInsets.fromLTRB(9, 13, 9, 13), decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.border)), child: Column(children: [Icon(icon, color: accent, size: 20), const SizedBox(height: 8), Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 9.5, fontWeight: FontWeight.w700)), const SizedBox(height: 3), Text(value, maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800))])));
  }

  Widget _palette() => Wrap(spacing: 14, runSpacing: 16, children: result.colours.map((colour) => ColourSwatch(name: colour, size: 58, showLabel: true)).toList());

  Widget _emptyPalette() => Container(padding: const EdgeInsets.all(18), decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.border)), child: const Text('Your saved result does not contain a colour palette yet. You can run the analysis again later.', style: TextStyle(color: AppColors.textSecondary, height: 1.45, fontSize: 12)));

  Widget _whyItWorks(Color accent) {
    return Container(padding: const EdgeInsets.all(19), decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(22), border: Border.all(color: AppColors.border)), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Container(width: 42, height: 42, decoration: BoxDecoration(color: accent.withValues(alpha: .14), shape: BoxShape.circle), child: Icon(Icons.auto_awesome_rounded, color: accent, size: 20)), const SizedBox(width: 12), const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Why it works', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)), SizedBox(height: 5), Text('Your natural colouring is the starting point. Use these shades to make outfits feel more harmonious, then mix them with neutrals and pieces you already love.', style: TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.45))]))]));
  }
}
