/// Source-derived asset naming convention from the supplied questionnaire
/// package. The actual binaries are not bundled here; this map lets the
/// Flutter UI resolve the same per-question/per-result naming format when
/// matching assets are added under assets/images/tib_questionnaire/.
class FlashQuestionAssets {
  const FlashQuestionAssets._();

  static String optionAsset({
    required String gender,
    required int questionNumber,
    required String value,
  }) {
    final folder = gender.trim().toLowerCase() == 'male' ? 'm' : 'f';
    final safe = value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    return 'assets/images/tib_questionnaire/$folder/q$questionNumber/$safe.jpg';
  }

  static String resultAsset({required String gender, required String season}) {
    final folder = gender.trim().toLowerCase() == 'male' ? 'm' : 'f';
    final safeSeason = season.trim().toLowerCase();
    return 'assets/images/tib_questionnaire/$folder/result/$safeSeason-season.jpg';
  }
}
