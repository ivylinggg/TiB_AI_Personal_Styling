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
                    Container(
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: const Text(
                        'Your score improves as you build your colour profile, grow your wardrobe, complete daily challenges, refine your style preferences and keep your profile complete.',
                        style: TextStyle(
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
}
