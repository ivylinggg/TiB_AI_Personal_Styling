import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../data/season_colour_guide.dart';
import '../../widgets/colour_swatch.dart';
import 'analysis_screen.dart';

/// Editorial four-season guide matching the TiB visual direction.
class SeasonColourGuideScreen extends StatelessWidget {
  const SeasonColourGuideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final profiles = SeasonColourGuide.profiles.values.toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _header(context)),
            SliverToBoxAdapter(child: _introBanner()),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
              sliver: SliverGrid(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _SeasonCard(profile: profiles[index]),
                  childCount: profiles.length,
                ),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 14,
                  childAspectRatio: .66,
                ),
              ),
            ),
            SliverToBoxAdapter(child: _analysisCta(context)),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 6),
      child: Row(
        children: [
          _roundButton(
            icon: Icons.arrow_back_ios_new_rounded,
            onTap: () => Navigator.pop(context),
          ),
          const Expanded(
            child: Column(
              children: [
                Text(
                  'Season Colour Guide ✨',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -.6,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Discover the 4 seasonal colour palettes',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          _roundButton(
            icon: Icons.help_outline_rounded,
            onTap: () => _showAbout(context),
          ),
        ],
      ),
    );
  }

  Widget _roundButton({required IconData icon, required VoidCallback onTap}) {
    return Material(
      color: AppColors.surface,
      shape: const CircleBorder(),
      elevation: 1,
      shadowColor: AppColors.primary.withValues(alpha: .10),
      child: IconButton(
        onPressed: onTap,
        icon: Icon(icon, size: 18),
      ),
    );
  }

  Widget _introBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(18, 8, 18, 0),
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF8F1FD), Color(0xFFFFF7F2)],
        ),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: AppColors.primary.withValues(alpha: .15)),
      ),
      child: const Row(
        children: [
          Icon(Icons.auto_awesome_rounded, color: AppColors.primaryDark, size: 18),
          SizedBox(width: 9),
          Expanded(
            child: Text(
              'Each season has a unique harmony that brings out your natural beauty.',
              style: TextStyle(fontSize: 11.5, height: 1.3, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _analysisCta(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(18, 2, 18, 0),
      padding: const EdgeInsets.fromLTRB(13, 12, 11, 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF5EBFA), Color(0xFFFFEFE7)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: const BoxDecoration(
              color: AppColors.primarySoft,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.lightbulb_outline_rounded, color: AppColors.primaryDark),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Not sure which season suits you?', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800)),
                SizedBox(height: 3),
                Text('Take our colour analysis to discover your most flattering seasonal palette.', style: TextStyle(color: AppColors.textSecondary, fontSize: 10.5, height: 1.3)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AnalysisScreen())),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
              minimumSize: Size.zero,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Start', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800)),
                SizedBox(width: 4),
                Icon(Icons.arrow_forward_rounded, size: 14),
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
          padding: EdgeInsets.fromLTRB(20, 8, 20, 26),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('How TiB classifies seasons', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              SizedBox(height: 9),
              Text(
                'TiB checks the portrait for a single visible face, then uses warmth or coolness, brightness and visual contrast as the starting point before mapping the result to the four-season guide.',
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
    final colours = profile.bestColours.take(18).toList();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openDetails(context, profile),
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: accent.withValues(alpha: .22)),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: .06),
                blurRadius: 15,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                child: Text(
                  profile.name.toUpperCase(),
                  style: TextStyle(color: accent, fontSize: 11.5, fontWeight: FontWeight.w900, letterSpacing: .7),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
                child: Text(
                  profile.dimension,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
                child: Text(
                  profile.description,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 10.3, height: 1.35),
                ),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: .035),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 6,
                      crossAxisSpacing: 5,
                      mainAxisSpacing: 6,
                    ),
                    itemCount: colours.length,
                    itemBuilder: (_, index) => ColourSwatch(
                      name: colours[index],
                      size: 21,
                      showLabel: false,
                    ),
                  ),
                ),
              ),
              const Spacer(),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: .045),
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(18)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('View Details', style: TextStyle(color: accent, fontSize: 10.5, fontWeight: FontWeight.w800)),
                    const SizedBox(width: 4),
                    Icon(Icons.arrow_forward_ios_rounded, color: accent, size: 10),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openDetails(BuildContext context, SeasonColourProfile profile) {
    final accent = _accent(profile.name);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: AppColors.background,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 26),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(profile.name, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
                const SizedBox(height: 5),
                Text(profile.dimension, style: TextStyle(color: accent, fontWeight: FontWeight.w900)),
                const SizedBox(height: 10),
                Text(profile.description, style: const TextStyle(color: AppColors.textSecondary, height: 1.45)),
                const SizedBox(height: 18),
                _sectionTitle('Best Colours'),
                Wrap(
                  spacing: 9,
                  runSpacing: 11,
                  children: profile.bestColours
                      .map((name) => ColourSwatch(name: name, size: 54, showLabel: true))
                      .toList(),
                ),
                const SizedBox(height: 18),
                _sectionTitle('Eye Shadow Colour Advise'),
                Text(profile.eyeShadowColours.join(', '), style: const TextStyle(fontSize: 12, height: 1.45)),
                const SizedBox(height: 18),
                _sectionTitle('Blush Colour Advise'),
                Text(profile.blushColours.join(', '), style: const TextStyle(fontSize: 12, height: 1.45)),
                const SizedBox(height: 18),
                _sectionTitle('Image Keywords'),
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: profile.keywords
                      .map((word) => Chip(
                            label: Text(word),
                            visualDensity: VisualDensity.compact,
                            side: BorderSide(color: accent.withValues(alpha: .18)),
                          ))
                      .toList(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
      );

  Color _accent(String season) {
    switch (season) {
      case 'Spring':
        return const Color(0xFF5D8A43);
      case 'Summer':
        return const Color(0xFF7557AD);
      case 'Autumn':
        return const Color(0xFFB66A2A);
      case 'Winter':
        return const Color(0xFF3865A8);
      default:
        return AppColors.primary;
    }
  }
}
