import '../models/flash_question.dart';

class FlashQuestionService {
  const FlashQuestionService._();

  static const seasonMapping = <String, String>{
    'A': 'Spring',
    'B': 'Autumn',
    'C': 'Winter',
    'D': 'Summer',
  };

  static const maleQuestions = <FlashQuestion>[
    FlashQuestion(id: 'questionOne', question: 'What is your natural hair colour?', options: ['Medium to Light Brown', 'Deep Dark Brown', 'Jet Black / Deep Black / Blue Black', 'Soft Ashy Black-Brown']),
    FlashQuestion(id: 'questionTwo', question: 'What is your natural eye colour?', options: ['Hazel / Light Brown with Golden Flecks', 'Deep Warm Brown to Dark Brown', 'Very Black', 'Soft Medium Brown']),
    FlashQuestion(id: 'questionThree', question: 'Which description best matches your natural skin tone?', options: ['Warm, golden, peachy', 'Warm, golden, olive, bronzy', 'Cool, neutral or bluish', 'Cool, pink-beige or bluish']),
    FlashQuestion(id: 'questionFour', question: 'How does your skin react to the sun?', options: ['Tans easily, rarely burns', 'Tans deeply and evenly', 'Burns easily, minimal tan', 'Burns first, then tans slightly']),
    FlashQuestion(id: 'questionFive', question: 'Which white looks best near your face?', options: ['Off White / Ivory White / Beige White', 'Cream / Warm White', 'Pure White / Snowy White', 'Bluish White / Very Light Grey White']),
    FlashQuestion(id: 'questionSix', question: 'Which colour family feels most natural on you?', options: ['Bright colours', 'Earth tones', 'Very cool tones', 'Muted colours']),
    FlashQuestion(id: 'questionSeven', question: 'Which grey looks best on you?', options: ['Light Beige – Grey', 'Warm Taupe- Grey', 'Charcoal Grey', 'Soft Dusty Grey']),
    FlashQuestion(id: 'questionEight', question: 'What level of contrast suits your appearance?', options: ['Low Contrast', 'Medium Contrast', 'Very High Contrast', 'Soft / Low-Medium Contrast']),
    FlashQuestion(id: 'questionNine', question: 'Which eyebrow colour is closest to yours?', options: ['Medium brown or lighter warm brown', 'Dark brown with a warm tone', 'Jet black / very dark', 'Soft black, dark ash brown, or cool brown']),
    FlashQuestion(id: 'questionTen', question: 'Which overall impression feels most like you?', options: ['Cheerful & Energetic', 'Warm & Grounded', 'Strong, Confident and Distance', 'Gentle & Approachable']),
  ];

  static const femaleQuestions = <FlashQuestion>[
    FlashQuestion(id: 'questionOne', question: 'What is your natural hair colour?', options: ['Medium to Light Brown', 'Dark Brown', 'Jet Black / Deep Black / Blue Black', 'Soft Ashy Black-Brown']),
    FlashQuestion(id: 'questionTwo', question: 'What is your natural eye colour?', options: ['Hazel / Light Brown with Golden Flecks', 'Deep Warm Brown to Dark Brown', 'Very Black', 'Soft Medium Brown']),
    FlashQuestion(id: 'questionThree', question: 'Which white looks best near your face?', options: ['Off White / Ivory White / Beige White', 'Cream / Warm White', 'Pure White / Snowy White', 'Bluish White / Very Light Grey White']),
    FlashQuestion(id: 'questionFour', question: 'Which jewellery metal usually suits you best?', options: ['Bright Yellow Gold / Rose Gold', 'Antique Gold / Bronze / Warm Pearl', 'Silver / Diamond / Crystal', 'Soft Silver / Rose Gold']),
    FlashQuestion(id: 'questionFive', question: 'Which lip colour family suits you best?', options: ['Soft Coral / Peachy Pink / Light Red', 'Orange-based / Brick Red / Brown Nudes Tone', 'Pink / Purple / Fuchsia Tone', 'Pinkish Nude / Soft Berry Tone']),
    FlashQuestion(id: 'questionSix', question: 'How does your skin react to the sun?', options: ['Becomes Golden Brown Quickly', 'Turns Deep Tan / Rich Brown', 'Barely Changes, Stays Very Fair', 'Burns Red, then Tans Lightly']),
    FlashQuestion(id: 'questionSeven', question: 'Which blush family looks most harmonious on you?', options: ['Soft Peach / Coral Pink / Apricot', 'Deep Peach / Warm Coral / Burnt Orange', 'Fuchsia Pink / Berry Pink / Raspberry Pink', 'Soft Rose Pink']),
    FlashQuestion(id: 'questionEight', question: 'Which colour palette feels most natural on you?', options: ['Light, warm, and bright pastels', 'Warm, rich, and earthy basics', 'Cool, clear, and high-contrast basics', 'Cool, soft, and muted pastels']),
    FlashQuestion(id: 'questionNine', question: 'Which red / pink family looks best on you?', options: ['Coral Peach / Nude Beige', 'Rust Red / Warm Brown', 'Deep Burgundy / True Red', 'Baby Pink / Soft Mauve']),
    FlashQuestion(id: 'questionTen', question: 'Which description best matches your natural skin undertone?', options: ['Warm, golden, or peachy', 'Warm, deeper tone', 'Cool, pink-beige or bluish', 'Rosy pink or cool beige']),
  ];

  static List<FlashQuestion> questionsForGender(String gender) {
    return gender.trim().toLowerCase() == 'male'
        ? maleQuestions
        : femaleQuestions;
  }

  static FlashQuestionnaireResult calculate({
    required String gender,
    required Map<String, int> answers,
  }) {
    final questions = questionsForGender(gender);
    final counts = <String, int>{'A': 0, 'B': 0, 'C': 0, 'D': 0};

    for (final question in questions) {
      final selectedIndex = answers[question.id];
      if (selectedIndex == null || selectedIndex < 0 || selectedIndex >= 4) {
        continue;
      }
      final key = String.fromCharCode('A'.codeUnitAt(0) + selectedIndex);
      counts[key] = (counts[key] ?? 0) + 1;
    }

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
