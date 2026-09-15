import 'package:shared_preferences/shared_preferences.dart';

import '../models/flash_question.dart';

class FlashQuestionPersistenceService {
  const FlashQuestionPersistenceService._();

  static const _genderKey = 'flash_question_gender';
  static const _seasonKey = 'flash_question_season';
  static const _answersKey = 'flash_question_answers';

  static Future<void> save(FlashQuestionnaireResult result) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_genderKey, result.gender);
    await prefs.setString(_seasonKey, result.season);
    await prefs.setStringList(
      _answersKey,
      result.answers.entries.map((entry) => '${entry.key}=${entry.value}').toList(),
    );
  }

  static Future<FlashQuestionnaireResult?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final gender = prefs.getString(_genderKey);
    final season = prefs.getString(_seasonKey);
    if (gender == null || season == null) return null;

    final answers = <String, int>{};
    for (final encoded in prefs.getStringList(_answersKey) ?? const []) {
      final parts = encoded.split('=');
      if (parts.length != 2) continue;
      final value = int.tryParse(parts[1]);
      if (value != null) answers[parts[0]] = value;
    }

    final calculated = FlashQuestionService.calculate(
      gender: gender,
      answers: answers,
    );

    // Prefer the calculated season so stored answer data remains the source
    // of truth if question scoring changes later.
    return FlashQuestionnaireResult(
      gender: gender,
      answers: answers,
      season: calculated.season,
      counts: calculated.counts,
    );
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_genderKey);
    await prefs.remove(_seasonKey);
    await prefs.remove(_answersKey);
  }
}
