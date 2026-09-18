class FlashQuestion {
  const FlashQuestion({
    required this.id,
    required this.question,
    required this.options,
  });

  final String id;
  final String question;
  final List<String> options;
}

class FlashQuestionnaireResult {
  const FlashQuestionnaireResult({
    required this.gender,
    required this.answers,
    required this.season,
    required this.counts,
  });

  final String gender;
  final Map<String, int> answers;
  final String season;
  final Map<String, int> counts;
}
