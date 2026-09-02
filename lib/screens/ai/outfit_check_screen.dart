import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../providers/analysis_provider.dart';
import '../../services/outfit_rating_service.dart';

class OutfitCheckScreen extends StatefulWidget {
  const OutfitCheckScreen({super.key});

  @override
  State<OutfitCheckScreen> createState() => _OutfitCheckScreenState();
}

class _OutfitCheckScreenState extends State<OutfitCheckScreen> {
  final _service = const OutfitRatingService();
  OutfitRatingResult? _result;
  bool _hasAccessories = false;

  void _analyse() {
    final analysis = context.read<AnalysisProvider>().result;
    final season = analysis?.season;
    final result = _service.rate(
      season: season,
      faceShape: analysis?.faceShape,
      bodyShape: analysis?.bodyShape,
      hasAccessories: _hasAccessories,
    );
    setState(() => _result = result);
  }

  @override
  Widget build(BuildContext context) {
    final analysis = context.watch<AnalysisProvider>().result;
    final result = _result;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Outfit Check', style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  const Icon(Icons.auto_awesome_rounded, size: 42, color: AppColors.primary),
                  const SizedBox(height: 10),
                  const Text('How does your outfit look?', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 8),
                  Text(
                    analysis == null
                        ? 'Complete your colour analysis first for more personalised scoring.'
                        : 'We will use your personal styling profile to build your outfit score.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.textSecondary, height: 1.45),
                  ),
                  const SizedBox(height: 18),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('I am wearing accessories', style: TextStyle(fontWeight: FontWeight.w700)),
                    value: _hasAccessories,
                    onChanged: (value) => setState(() => _hasAccessories = value),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _analyse,
                      icon: const Icon(Icons.auto_awesome_rounded),
                      label: const Text('Check My Outfit'),
                    ),
                  ),
                ],
              ),
            ),
            if (result != null) ...[
              const SizedBox(height: 20),
              _scoreCard(result),
              const SizedBox(height: 18),
              _section('What works', result.strengths, Icons.thumb_up_alt_outlined),
              const SizedBox(height: 14),
              _section('What could improve', result.improvements, Icons.tips_and_updates_outlined),
              const SizedBox(height: 18),
              const Text('Complete Your Look', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
              const SizedBox(height: 10),
              ...result.accessories.map(_accessoryCard),
            ],
          ],
        ),
      ),
    );
  }

  Widget _scoreCard(OutfitRatingResult result) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Text('${result.overallScore}', style: const TextStyle(fontSize: 54, fontWeight: FontWeight.w900, color: AppColors.primary)),
          const Text('/ 100', style: TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          _metric('Colour Harmony', result.colourHarmonyScore),
          _metric('Outfit Coordination', result.outfitCoordinationScore),
          _metric('Personal Colour', result.personalColourScore),
          _metric('Styling', result.stylingScore),
          _metric('Accessories', result.accessoryScore),
        ],
      ),
    );
  }

  Widget _metric(String label, int score) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600))),
          Text('$score', style: const TextStyle(fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }

  Widget _section(String title, List<String> items, IconData icon) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [Icon(icon, color: AppColors.primary), const SizedBox(width: 10), Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800))]),
          const SizedBox(height: 12),
          ...items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('•  '), Expanded(child: Text(item, style: const TextStyle(height: 1.4)))]),
              )),
        ],
      ),
    );
  }

  Widget _accessoryCard(AccessoryRecommendation item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.diamond_outlined, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(item.category, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)), const SizedBox(height: 3), Text(item.name, style: const TextStyle(fontWeight: FontWeight.w800)), const SizedBox(height: 5), Text(item.reason, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.35))])),
        ],
      ),
    );
  }
}
