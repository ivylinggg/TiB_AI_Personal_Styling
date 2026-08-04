import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';

class StyleScoreCard extends StatelessWidget {
  final int score;
  final String season;

  const StyleScoreCard({super.key, required this.score, required this.season});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 15,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              "$score%",
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          ),

          const SizedBox(width: 20),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Style Score",
                  style: Theme.of(context).textTheme.titleMedium,
                ),

                const SizedBox(height: 6),

                Text(
                  "Season Colour",
                  style: Theme.of(context).textTheme.bodySmall,
                ),

                Text(
                  season,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 12),

                LinearProgressIndicator(
                  value: score / 100,
                  minHeight: 8,
                  borderRadius: const BorderRadius.all(Radius.circular(20)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
