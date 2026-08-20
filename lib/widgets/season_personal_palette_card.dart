import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import '../data/season_colour_guide.dart';
import 'colour_swatch.dart';

class SeasonPersonalPaletteCard extends StatelessWidget {
  final String season;

  const SeasonPersonalPaletteCard({super.key, required this.season});

  @override
  Widget build(BuildContext context) {
    final profile = SeasonColourGuide.forSeason(season);
    final accent = AppColors.seasonAccent(season);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
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
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: .12),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.palette_outlined, color: accent, size: 20),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Best colours for you',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      profile.dimension,
                      style: TextStyle(color: accent, fontSize: 11.5, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 46,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: profile.bestColours.take(8).length,
              separatorBuilder: (_, index) => const SizedBox(width: 7),
              itemBuilder: (_, index) => ColourSwatch(
                name: profile.bestColours[index],
                size: 46,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
