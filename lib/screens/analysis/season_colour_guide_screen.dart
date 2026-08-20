import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_gradients.dart';
import '../../data/season_colour_guide.dart';
import '../../widgets/colour_swatch.dart';

class SeasonColourGuideScreen extends StatelessWidget {
  const SeasonColourGuideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final profiles = SeasonColourGuide.profiles.values.toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Season Colour Guide'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'About the guide',
            onPressed: () => _showAbout(context),
            icon: const Icon(Icons.help_outline_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 6, 18, 28),
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            decoration: BoxDecoration(
              gradient: AppGradients.soft,
              borderRadius: BorderRadius.circular(17),
              border: Border.all(color: AppColors.border),
            ),
            child: const Row(
              children: [
                Icon(Icons.auto_awesome_rounded, color: AppColors.primary, size: 18),
                SizedBox(width: 9),
                Expanded(
                  child: Text(
                    'Each season has a unique harmony that brings out your natural beauty.',
                    style: TextStyle(fontSize: 11.5, height: 1.35),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 15),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: .74,
            ),
            itemCount: profiles.length,
            itemBuilder: (context, index) => _SeasonCard(profile: profiles[index]),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    color: AppColors.secondary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.face_retouching_natural, color: AppColors.primary),
                ),
                const SizedBox(width: 11),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Not sure which season suits you?', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                      SizedBox(height: 4),
                      Text('Take Colour Analysis to discover your most flattering seasonal palette.', style: TextStyle(color: AppColors.textSecondary, fontSize: 11.5, height: 1.35)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showAbout(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: AppColors.background,
      builder: (context) => const SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, 6, 20, 25),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('How TiB classifies seasons', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              SizedBox(height: 9),
              Text(
                'TiB first checks the detected portrait for a single visible face, then analyses the image for skin-colour warmth/coolness, brightness and visual contrast. Those results are mapped to the four-season colour framework used in this guide.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5, height: 1.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SeasonCard extends StatelessWidget {
  final SeasonColourProfile profile;

  const _SeasonCard({required this.profile});

  @override
  Widget build(BuildContext context) {
    final accent = _accent(profile.name);
    final colours = profile.bestColours.take(12).toList();

    return InkWell(
      onTap: () => _openDetails(context, profile),
      borderRadius: BorderRadius.circular(22),
      child: Ink(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: accent.withValues(alpha: .28)),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: .08),
              blurRadius: 18,
              offset: const Offset(0, 7),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(13, 13, 13, 0),
              child: Text(
                profile.name.toUpperCase(),
                style: TextStyle(color: accent, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: .8),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(13, 8, 13, 0),
              child: Text(profile.dimension, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(13, 6, 13, 0),
              child: Text(profile.description, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.textSecondary, fontSize: 10.5, height: 1.35)),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Container(
                height: 88,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [accent.withValues(alpha: .10), accent.withValues(alpha: .03)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: GridView.count(
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 6,
                  padding: const EdgeInsets.all(8),
                  mainAxisSpacing: 6,
                  crossAxisSpacing: 5,
                  children: colours.map((name) => ColourSwatch(name: name, size: 20, showLabel: false)).toList(),
                ),
              ),
            ),
            const Spacer(),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: .05),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(22)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('View Details', style: TextStyle(color: accent, fontSize: 11.5, fontWeight: FontWeight.w700)),
                  const SizedBox(width: 5),
                  Icon(Icons.arrow_forward_ios_rounded, color: accent, size: 11),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openDetails(BuildContext context, SeasonColourProfile profile) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: AppColors.background,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 5, 20, 25),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(profile.name, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(profile.dimension, style: TextStyle(color: _accent(profile.name), fontWeight: FontWeight.w800)),
                const SizedBox(height: 10),
                Text(profile.description, style: const TextStyle(color: AppColors.textSecondary, height: 1.45)),
                const SizedBox(height: 18),
                _heading('Best Colours'),
                Wrap(spacing: 10, runSpacing: 12, children: profile.bestColours.map((name) => ColourSwatch(name: name, size: 56, showLabel: true)).toList()),
                const SizedBox(height: 18),
                _heading('Eye Shadow Colour Advise'),
                Text(profile.eyeShadowColours.join(', '), style: const TextStyle(fontSize: 12, height: 1.45)),
                const SizedBox(height: 18),
                _heading('Blush Colour Advise'),
                Text(profile.blushColours.join(', '), style: const TextStyle(fontSize: 12, height: 1.45)),
                const SizedBox(height: 18),
                _heading('Image Keywords'),
                Wrap(spacing: 7, runSpacing: 7, children: profile.keywords.map((word) => Chip(label: Text(word), visualDensity: VisualDensity.compact, side: BorderSide(color: _accent(profile.name).withValues(alpha: .2)))).toList()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _heading(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
      );

  Color _accent(String season) {
    switch (season) {
      case 'Winter':
        return const Color(0xFF4D63A0);
      case 'Summer':
        return const Color(0xFF8D68B4);
      case 'Spring':
        return const Color(0xFFD58A4D);
      case 'Autumn':
        return const Color(0xFF9B5A38);
      default:
        return AppColors.primary;
    }
  }
}
