import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../providers/analysis_provider.dart';
import '../../services/style_score_service.dart';

class StyleScoreDetailScreen extends StatelessWidget {
  final AnalysisProvider analysisProvider;

  const StyleScoreDetailScreen({
    super.key,
    required this.analysisProvider,
  });

  String _label(int score) {
    if (score >= 90) return 'Signature ready';
    if (score >= 75) return 'Well styled';
    if (score >= 55) return 'Good foundation';
    if (score >= 35) return 'Building your style';
    return 'Start your style journey';
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: const Text(
          'Style Score',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: uid == null
          ? const Center(child: Text('Please sign in again.'))
          : FutureBuilder<StyleScoreSnapshot>(
              future: StyleScoreService.calculate(
                uid: uid,
                analysis: analysisProvider.result,
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError || !snapshot.hasData) {
                  return const Center(
                    child: Text('Unable to load your Style Score right now.'),
                  );
                }

                final score = snapshot.data!;
                final sections = <String, int>{
                  'Appearance': score.appearance,
                  'Behavior': score.behavior,
                  'Communication': score.communication,
                  'Digital Etiquette': score.digitalEtiquette,
                };
                const maximums = <String, int>{
                  'Appearance': 40,
                  'Behavior': 25,
                  'Communication': 20,
                  'Digital Etiquette': 15,
                };

                return ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                  children: [
                    Text(
                      '${score.total}/100',
                      style: const TextStyle(
                        fontSize: 44,
                        fontWeight: FontWeight.w900,
                        height: .95,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _label(score.total),
                      style: const TextStyle(
                        color: AppColors.primaryDark,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 22),
                    ...sections.entries.map((entry) {
                      final max = maximums[entry.key]!;
                      final progress = max == 0 ? 0.0 : entry.value / max;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    entry.key,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                Text(
                                  '${entry.value}/$max',
                                  style: const TextStyle(
                                    color: AppColors.primaryDark,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 7),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(99),
                              child: LinearProgressIndicator(
                                value: progress,
                                minHeight: 8,
                                backgroundColor: AppColors.border,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                    _progressCard(
                      title: 'Wardrobe alignment',
                      subtitle: 'How well your wardrobe supports your personal colour profile.',
                      rows: [
                        _ProgressRow(
                          label: 'Best-colour matches',
                          value: score.wardrobePaletteMatches,
                          max: 5,
                        ),
                        _ProgressRow(
                          label: 'Season matches',
                          value: score.wardrobeSeasonMatches,
                          max: 5,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Text(
                        'Your score improves as you build your colour profile, add wardrobe pieces that suit your season and palette, complete daily challenges, refine your style preferences and keep your profile complete.',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                          height: 1.45,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }

  Widget _progressCard({
    required String title,
    required String subtitle,
    required List<_ProgressRow> rows,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11.5,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          ...rows.map(
            (row) => Padding(
              padding: const EdgeInsets.only(bottom: 11),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          row.label,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Text(
                        '${row.value}/${row.max}',
                        style: const TextStyle(
                          color: AppColors.primaryDark,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      value: (row.value / row.max).clamp(0.0, 1.0),
                      minHeight: 6,
                      backgroundColor: AppColors.border,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressRow {
  final String label;
  final int value;
  final int max;

  const _ProgressRow({
    required this.label,
    required this.value,
    required this.max,
  });
}
