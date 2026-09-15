import '../models/flash_question.dart';

class FlashQuestionService {
  const FlashQuestionService._();

  static const seasonMapping = <String, String>{
    'A': 'Spring',
    'B': 'Autumn',
    'C': 'Winter',
    'D': 'Summer',
  };

  static const questions = <FlashQuestion>[
    FlashQuestion(id: 'q1', question: 'Which colour family makes your skin look brighter?', options: ['Warm light tones', 'Warm earthy tones', 'Cool deep tones', 'Cool soft tones']),
    FlashQuestion(id: 'q2', question: 'Which overall colour contrast feels most natural on you?', options: ['Fresh and clear', 'Rich and muted', 'Bold and dramatic', 'Soft and elegant']),
    FlashQuestion(id: 'q3', question: 'Which neutral usually looks best on you?', options: ['Cream / warm beige', 'Camel / warm brown', 'Black / crisp white', 'Soft grey / cool beige']),
    FlashQuestion(id: 'q4', question: 'Which jewellery metal tends to suit you best?', options: ['Gold', 'Antique gold / bronze', 'Silver / platinum', 'Soft silver']),
    FlashQuestion(id: 'q5', question: 'Which colour intensity do you prefer on yourself?', options: ['Light and vibrant', 'Deep and earthy', 'Clear and high-impact', 'Muted and understated']),
  ];

  static FlashQuestionnaireResult calculate({
    required String gender,
    required Map<String, int> answers,
  }) {
    final counts = <String, int>{'A': 0, 'B': 0, 'C': 0, 'D': 0};

    for (final question in questions) {
      final selectedIndex = answers[question.id];
      if (selectedIndex == null) continue;
      if (selectedIndex < 0 || selectedIndex >= question.options.length) continue;
      final key = String.fromCharCode('A'.codeUnitAt(0) + selectedIndex);
      counts[key] = (counts[key] ?? 0) + 1;
    }

    // Matches the supplied WordPress Questionnaire implementation:
    // highest score wins; ties resolve in A, B, C, D order.
    var winningKey = 'A';
    for (final key in const ['A', 'B', 'C', 'D']) {
      if (counts[key]! > counts[winningKey]!) winningKey = key;
    }

    return FlashQuestionnaireResult(
      gender: gender,
      answers: Map<String, int>.unmodifiable(answers),
      season: seasonMapping[winningKey]!,
      counts: Map<String, int>.unmodifiable(counts),
    );
  }
}
