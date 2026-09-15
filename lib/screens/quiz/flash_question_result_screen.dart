import 'package:flutter/material.dart';

import '../../models/flash_question.dart';
import '../../services/flash_question_service.dart';
import 'flash_question_screen.dart';

class FlashQuestionResultScreen extends StatelessWidget {
  const FlashQuestionResultScreen({super.key, required this.result});

  final FlashQuestionnaireResult result;

  static const descriptions = <String, String>{
    'Spring': 'Fresh, light and vibrant. Warm, clear colours tend to bring out your natural brightness.',
    'Summer': 'Cool, soft and elegant. Muted cool tones tend to create a balanced, refined look.',
    'Autumn': 'Warm, rich and earthy. Deep warm colours tend to complement your overall colouring.',
    'Winter': 'Cool, clear and dramatic. Bold cool colours tend to create your strongest contrast.',
  };

  void _retake(BuildContext context) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => FlashQuestionScreen(gender: result.gender)),
      (route) => route.isFirst,
    );
  }

  @override
  Widget build(BuildContext context) {
    final season = result.season;
    return Scaffold(
      appBar: AppBar(title: const Text('Your Colour Season')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
          children: [
            Text(
              season,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            Text(
              descriptions[season] ?? '',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 24),
            Card(
              elevation: 0,
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Score breakdown', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 12),
                    ...result.counts.entries.map(
                      (entry) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        child: Row(
                          children: [
                            Text(entry.key, style: const TextStyle(fontWeight: FontWeight.w700)),
                            const SizedBox(width: 12),
                            Expanded(child: Text(FlashQuestionService.seasonMapping[entry.key]!)),
                            Text('${entry.value}'),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 22),
            FilledButton(
              onPressed: () => _retake(context),
              child: const Text('Retake Questionnaire'),
            ),
          ],
        ),
      ),
    );
  }
}
