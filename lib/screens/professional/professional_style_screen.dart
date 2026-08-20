import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../data/professional_style_data.dart';
import '../../providers/analysis_provider.dart';

class ProfessionalStyleScreen extends StatelessWidget {
  const ProfessionalStyleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final result = context.watch<AnalysisProvider>().result;
    final season = result?.season ?? 'Autumn';
    final profile = ProfessionalStyleData.profile(season);
    final avoid = ProfessionalStyleData.avoidColours[season] ?? const <String>[];
    final accent = AppColors.seasonAccent(season);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: const Text('Professional Style'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          _hero(season, profile, accent),
          const SizedBox(height: 18),
          _sectionTitle('Colour Psychology', 'Choose the impression first, then choose a season-friendly shade.'),
          const SizedBox(height: 10),
          ...ProfessionalStyleData.colourPsychology.map((cue) => _psychologyCard(cue, accent)),
          const SizedBox(height: 20),
          _sectionTitle('Less-Flattering Colours', 'These are starting points for colours to use carefully with your season.'),
          const SizedBox(height: 10),
          _avoidCard(avoid, accent),
          const SizedBox(height: 20),
          _sectionTitle('Professional / Work Styling', 'Pick the situation and use the brief in AI Stylist.'),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: ProfessionalStyleData.professionalOccasions
                .map(
                  (occasion) => ActionChip(
                    label: Text(occasion),
                    onPressed: () => Navigator.pop(context, occasion),
                    backgroundColor: AppColors.lavenderMist,
                    side: BorderSide(color: accent.withValues(alpha: .18)),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 14),
          _guidanceCard(ProfessionalStyleData.occasionGuidance, accent),
        ],
      ),
    );
  }

  Widget _hero(String season, dynamic profile, Color accent) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, Color.lerp(AppColors.primaryDark, accent, .28)!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(26),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('YOUR PROFESSIONAL IMAGE', style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
          const SizedBox(height: 8),
          Text(season, style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(profile.dimension, style: const TextStyle(color: Colors.white70, fontSize: 12.5, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          const Text(
            'Use your personal colour direction as the base, then adjust silhouette, polish and colour psychology for the situation.',
            style: TextStyle(color: Colors.white70, fontSize: 12.5, height: 1.45),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text(subtitle, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.4)),
      ],
    );
  }

  Widget _psychologyCard(ColourPsychologyCue cue, Color accent) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 12, height: 12, decoration: BoxDecoration(color: _colour(cue.colour), shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Text(cue.colour, style: const TextStyle(fontWeight: FontWeight.w800)),
              const Spacer(),
              Icon(Icons.auto_awesome_rounded, size: 16, color: accent),
            ],
          ),
          const SizedBox(height: 7),
          Text(cue.impression, style: TextStyle(color: accent, fontSize: 11.5, fontWeight: FontWeight.w800)),
          const SizedBox(height: 5),
          Text('Best for: ${cue.bestFor}', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(cue.note, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11.5, height: 1.4)),
        ],
      ),
    );
  }

  Widget _avoidCard(List<String> avoid, Color accent) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: avoid
            .map(
              (name) => Chip(
                avatar: const Icon(Icons.remove_circle_outline_rounded, size: 16),
                label: Text(name, style: const TextStyle(fontSize: 10.5)),
                side: BorderSide(color: accent.withValues(alpha: .15)),
                backgroundColor: AppColors.surfaceMuted,
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _guidanceCard(Map<String, List<String>> guidance, Color accent) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: guidance.entries.map((entry) {
          return ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: Text(entry.key, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
            iconColor: accent,
            collapsedIconColor: AppColors.textMuted,
            childrenPadding: const EdgeInsets.fromLTRB(0, 0, 0, 10),
            children: entry.value
                .map((point) => Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 3),
                        child: Text('• $point', style: const TextStyle(color: AppColors.textSecondary, fontSize: 11.5, height: 1.4)),
                      ),
                    ))
                .toList(),
          );
        }).toList(),
      ),
    );
  }

  Color _colour(String name) {
    final n = name.toLowerCase();
    if (n.contains('red')) return const Color(0xFFB84A55);
    if (n.contains('pink')) return const Color(0xFFE6A5B9);
    if (n.contains('green')) return const Color(0xFF879C65);
    if (n.contains('black')) return Colors.black87;
    if (n.contains('white') || n.contains('ivory')) return const Color(0xFFF4EEE6);
    if (n.contains('navy') || n.contains('blue')) return const Color(0xFF536E9F);
    return AppColors.taupe;
  }
}
