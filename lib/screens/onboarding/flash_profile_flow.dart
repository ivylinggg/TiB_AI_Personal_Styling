import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_radius.dart';
import '../../models/flash_question.dart';
import '../../providers/analysis_provider.dart';
import '../../services/flash_question_persistence_service.dart';
import '../../services/flash_question_service.dart';
import '../../services/firestore_service.dart';
import '../../widgets/flash_face_scan_panel.dart';
import '../../widgets/primary_button.dart';
import '../auth/auth_service.dart';
import '../main/main_screen.dart';
import 'flash_scan_result_screen.dart';

class FlashProfileFlow extends StatefulWidget {
  const FlashProfileFlow({super.key});

  @override
  State<FlashProfileFlow> createState() => _FlashProfileFlowState();
}

class _FlashProfileFlowState extends State<FlashProfileFlow> {
  static const _genders = ['Female', 'Male', 'Non-binary', 'Prefer not to say'];
  static const _ages = ['Under 18', '18–24', '25–34', '35–44', '45–54', '55+'];
  static const _ethnicities = [
    'White / Caucasian',
    'East Asian',
    'South Asian',
    'Southeast Asian',
    'Middle Eastern',
    'Hispanic / Latino',
    'Black / African',
    'Mixed / Multiracial',
    'Other',
  ];
  static const _occupations = [
    'Student',
    'Office / Corporate',
    'Business Owner',
    'Healthcare',
    'Education / Teacher',
    'Hospitality / Service',
    'Creative / Design',
    'Beauty / Fashion',
    'Sales / Retail',
    'Freelancer',
    'Homemaker',
    'Retired',
    'Currently looking for work',
    'Other',
  ];

  static const _occupationEmojis = [
    '🎓', '💼', '🏢', '🩺', '📚', '☕', '🎨',
    '💄', '🛍️', '💻', '🏠', '🌿', '🔎', '✨',
  ];

  static const _brands = [
    'Zara', 'Uniqlo', 'Shein', 'Cotton On', 'H&M', 'Forever 21',
    'Mango', 'Primark', 'Fashion Nova', 'Gap', 'Cider', 'ASOS',
    'Romwe', 'Bershka', 'Target', 'Charlotte Russe', 'Dynamite',
  ];

  int _step = 0;
  String? _gender;
  String? _ageRange;
  String? _ethnicity;
  String? _occupation;
  final TextEditingController _occupationOtherController = TextEditingController();
  final List<String> _preferredBrands = [];
  File? _scanImage;
  bool _saving = false;

  double get _progress => (_step + 1) / 7;

  bool get _canContinue => switch (_step) {
    0 => _gender != null,
    1 => _ageRange != null,
    2 => _ethnicity != null,
    3 => _preferredBrands.isNotEmpty,
    4 => _occupation != null &&
        (_occupation != 'Other' || _occupationOtherController.text.trim().isNotEmpty),
    5 => true,
    _ => false,
  };

  Future<void> _continue() async {
    if (!_canContinue || _saving || _step >= 6) return;
    setState(() => _step += 1);
  }

  @override
  void dispose() {
    _occupationOtherController.dispose();
    super.dispose();
  }

  Future<void> _handleQuestionnaireDone(FlashQuestionnaireResult result) async {
    if (_saving) return;
    final uid = AuthService.currentUser?.uid;
    if (uid == null) {
      _message('Please login before completing your questionnaire.');
      return;
    }

    setState(() => _saving = true);
    try {
      await FlashQuestionPersistenceService.save(result);
      await FirestoreService.updateUser(uid, {
        'gender': _gender,
        'ageRange': _ageRange,
        'ethnicity': _ethnicity,
        'preferredBrands': List<String>.from(_preferredBrands),
        'occupation': _occupation == 'Other'
            ? _occupationOtherController.text.trim()
            : _occupation,
        'questionnaireAnswers': result.answers,
        'questionnaireSeason': result.season,
        'questionnaireScores': result.counts,
        'questionnaireGender': result.gender,
        'onboardingProfile': {
          'gender': _gender,
          'ageRange': _ageRange,
          'ethnicity': _ethnicity,
          'preferredBrands': List<String>.from(_preferredBrands),
          'occupation': _occupation == 'Other'
              ? _occupationOtherController.text.trim()
              : _occupation,
          'occupationCategory': _occupation,
          'questionnaireSeason': result.season,
          'questionnaireScores': result.counts,
          'source': 'flash_questions',
        },
      });
      if (!mounted) return;
      setState(() {
        _gender = result.gender;
        _saving = false;
        _step = 6;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _message('Could not save your questionnaire result: $e');
    }
  }

  Future<void> _handleFaceScan(File file) async {
    if (_saving) return;
    setState(() => _scanImage = file);
    await _runColourAnalysis();
  }

  Future<void> _runColourAnalysis() async {
    if (_saving || _scanImage == null) return;
    final uid = AuthService.currentUser?.uid;
    final scanImage = _scanImage;
    if (uid == null || scanImage == null) {
      _message('Please complete the face scan first.');
      return;
    }

    setState(() => _saving = true);
    try {
      final questionnaire = await FlashQuestionPersistenceService.load();
      await FirestoreService.updateUser(uid, {
        'gender': _gender,
        'ageRange': _ageRange,
        'ethnicity': _ethnicity,
        'preferredBrands': List<String>.from(_preferredBrands),
        'occupation': _occupation == 'Other'
            ? _occupationOtherController.text.trim()
            : _occupation,
        if (questionnaire != null) ...{
          'questionnaireAnswers': questionnaire.answers,
          'questionnaireSeason': questionnaire.season,
          'questionnaireScores': questionnaire.counts,
          'questionnaireGender': questionnaire.gender,
        },
        'onboardingProfile': {
          'gender': _gender,
          'ageRange': _ageRange,
          'ethnicity': _ethnicity,
          'preferredBrands': List<String>.from(_preferredBrands),
          'occupation': _occupation == 'Other'
              ? _occupationOtherController.text.trim()
              : _occupation,
          'occupationCategory': _occupation,
          if (questionnaire != null) ...{
            'questionnaireSeason': questionnaire.season,
            'questionnaireScores': questionnaire.counts,
          },
          'source': 'flash_questions',
        },
      });

      if (!mounted) return;
      final provider = context.read<AnalysisProvider>();
      provider.setImage(scanImage);
      final success = await provider.analyse(uid: uid);
      if (!mounted) return;

      if (!success || provider.result == null) {
        setState(() => _saving = false);
        _message(provider.errorMessage ?? 'We could not generate your colour profile yet.');
        return;
      }

      final analysis = provider.result!;
      final questionnaireResult = await FlashQuestionPersistenceService.load();
      final effectiveSeason = questionnaireResult?.season ?? analysis.season;

      if (effectiveSeason != analysis.season) {
        await FirestoreService.updateUser(uid, {'colourSeason': effectiveSeason});
      }

      setState(() => _saving = false);
      final action = await Navigator.push<FlashScanResultAction>(
        context,
        MaterialPageRoute(
          builder: (_) => FlashScanResultScreen(
            result: analysis.copyWithSeason(effectiveSeason),
            scanImage: scanImage,
          ),
        ),
      );

      if (!mounted) return;
      if (action == FlashScanResultAction.continueOnboarding) {
        await FirestoreService.updateUser(uid, {
          'onboardingComplete': true,
          'onboardingScanCompleted': true,
          'questionnaireSeason': effectiveSeason,
        });
        await FlashQuestionPersistenceService.clear();
        if (!mounted) return;
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const MainScreen()),
          (_) => false,
        );
      } else if (action == FlashScanResultAction.rescan) {
        setState(() => _scanImage = null);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _message('Your colour profile could not be generated. Please try again.');
    }
  }

  void _toggleBrand(String brand) {
    setState(() {
      if (_preferredBrands.contains(brand)) {
        _preferredBrands.remove(brand);
      } else if (_preferredBrands.length < 10) {
        _preferredBrands.add(brand);
      } else {
        _message('Choose up to 10 brands.');
      }
    });
  }

  void _back() {
    if (_saving) return;
    if (_step == 0) {
      Navigator.pop(context);
    } else {
      setState(() {
        _step -= 1;
        if (_step < 5) _scanImage = null;
      });
    }
  }

  void _message(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned(
              left: -80,
              bottom: -120,
              child: _blob(240, AppColors.blush.withValues(alpha: .42)),
            ),
            Positioned(
              right: -90,
              bottom: -140,
              child: _blob(270, AppColors.primarySoft.withValues(alpha: .48)),
            ),
            Column(
              children: [
                _topBar(),
                _progressBar(),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 240),
                    child: Padding(
                      key: ValueKey(_step),
                      padding: const EdgeInsets.fromLTRB(20, 22, 20, 10),
                      child: _buildStep(),
                    ),
                  ),
                ),
                if (_step < 5)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(22, 4, 22, 22),
                    child: PrimaryButton(
                      text: 'Continue',
                      icon: Icons.arrow_forward_rounded,
                      onPressed: _saving || !_canContinue ? null : _continue,
                    ),
                  ),
                if (_step == 5 && !_saving)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(22, 4, 22, 22),
                    child: PrimaryButton(
                      text: 'Continue',
                      icon: Icons.arrow_forward_rounded,
                      onPressed: _canContinue ? _continue : null,
                    ),
                  ),
                if (_step == 6 && _saving)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(22, 4, 22, 22),
                    child: PrimaryButton(
                      text: 'Creating your colour profile…',
                      onPressed: null,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep() => switch (_step) {
    0 => _choiceStep('What’s your gender? ✨', 'This helps us personalize your style recommendations', _genders, _gender, (v) => setState(() => _gender = v), ['👩🏻', '👨🏻', '🌈', '🔒']),
    1 => _choiceStep('What’s your age range? 📅', 'We’ll tailor style tips to your life stage', _ages, _ageRange, (v) => setState(() => _ageRange = v), ['🧸', '🌸', '✨', '🌿', '💜', '🔵']),
    2 => _choiceStep('What’s your ethnicity? 🌎', 'Helps us understand your unique coloring', _ethnicities, _ethnicity, (v) => setState(() => _ethnicity = v), ['🤍', '👩🏻', '👩🏽', '🧑🏻', '👩🏻', '🧑🏽', '🧑🏿', '🤎', '🌈']),
    3 => _brandStep(),
    4 => _occupationStep(),
    5 => _questionnaireStep(),
    6 => _scanStep(),
    _ => const SizedBox.shrink(),
  };

  Widget _questionnaireStep() {
    return Column(
      children: [
        const SizedBox(height: 6),
        const Text(
          'Quick colour questions ✨',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        const Text(
          'Answer these questions before your face scan.\nYour answers will be used for your final season result.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4),
        ),
        const SizedBox(height: 20),
        Expanded(
          child: _InlineQuestionnaire(
            gender: _gender ?? 'Prefer not to say',
            onCompleted: _handleQuestionnaireDone,
            busy: _saving,
          ),
        ),
      ],
    );
  }

  Widget _scanStep() {
    return Column(
      children: [
        const SizedBox(height: 8),
        const Text('Let’s scan your\nbeautiful you ✨', textAlign: TextAlign.center, style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800, height: 1.1)),
        const SizedBox(height: 10),
        const Text('We’ll analyze your natural coloring\nto find the best shades for you', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4)),
        const SizedBox(height: 16),
        Expanded(child: FlashFaceScanPanel(busy: _saving, onCaptured: _handleFaceScan)),
      ],
    );
  }

  Widget _choiceStep(String title, String subtitle, List<String> options, String? selected, ValueChanged<String> onSelect, List<String> emojis) {
    return Column(
      children: [
        const SizedBox(height: 8),
        Center(child: Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -.5))),
        const SizedBox(height: 10),
        Center(child: Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.45))),
        const SizedBox(height: 28),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.only(bottom: 10),
            itemCount: options.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, index) {
              final option = options[index];
              return _selectCard(option, emoji: emojis[index], selected: selected == option, onTap: () => onSelect(option));
            },
          ),
        ),
      ],
    );
  }

  Widget _selectCard(String label, {required String emoji, required bool selected, required VoidCallback onTap}) {
    return InkWell(
      onTap: _saving ? null : onTap,
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: selected ? AppColors.lavenderMist : Colors.white.withValues(alpha: .92),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: selected ? AppColors.primary.withValues(alpha: .45) : AppColors.border, width: selected ? 1.3 : 1),
        ),
        child: Row(
          children: [
            Container(width: 40, height: 40, alignment: Alignment.center, decoration: BoxDecoration(color: selected ? AppColors.primarySoft : AppColors.surfaceMuted, shape: BoxShape.circle), child: Text(emoji, style: const TextStyle(fontSize: 20))),
            const SizedBox(width: 12),
            Expanded(child: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600))),
            if (selected) const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 23),
          ],
        ),
      ),
    );
  }

  Widget _brandStep() {
    final remaining = _brands.where((brand) => !_preferredBrands.contains(brand)).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        const Center(child: Text('What brands\nmatch your vibe? 🛍️', textAlign: TextAlign.center, style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800, height: 1.1))),
        const SizedBox(height: 10),
        const Center(child: Text('Pick a few — we’ll tailor\nyour recommendations', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4))),
        const SizedBox(height: 22),
        Row(children: [const Expanded(child: Text('Your picks', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800))), Text('${_preferredBrands.length}/10', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w700))]),
        const SizedBox(height: 9),
        if (_preferredBrands.isNotEmpty)
          Wrap(spacing: 8, runSpacing: 8, children: _preferredBrands.map((brand) => InputChip(label: Text(brand, style: const TextStyle(fontSize: 11)), onDeleted: () => _toggleBrand(brand), backgroundColor: AppColors.lavenderMist, side: BorderSide(color: AppColors.primary.withValues(alpha: .22)), deleteIconColor: AppColors.textMuted)).toList())
        else
          const Text('Tap the brands you actually wear.', style: TextStyle(color: AppColors.textSecondary, fontSize: 11.5)),
        const SizedBox(height: 20),
        const Text('You might also like', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
        const SizedBox(height: 9),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.only(bottom: 10),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 3.9),
            itemCount: remaining.length,
            itemBuilder: (_, index) {
              final brand = remaining[index];
              return InkWell(
                onTap: () => _toggleBrand(brand),
                borderRadius: BorderRadius.circular(15),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: .95), borderRadius: BorderRadius.circular(15), border: Border.all(color: AppColors.border)),
                  child: Row(children: [Expanded(child: Text(brand, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600))), const Icon(Icons.favorite_border_rounded, color: AppColors.textMuted, size: 18)]),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _occupationStep() {
    return Column(
      children: [
        const SizedBox(height: 8),
        const Center(child: Text('What do you do? 💼', textAlign: TextAlign.center, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800))),
        const SizedBox(height: 10),
        const Center(child: Text('Your daily life helps us understand how\nyou actually dress and style yourself', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.45))),
        const SizedBox(height: 22),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.only(bottom: 10),
            itemCount: _occupations.length + (_occupation == 'Other' ? 1 : 0),
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, index) {
              if (_occupation == 'Other' && index == _occupations.length) {
                return TextField(controller: _occupationOtherController, enabled: !_saving, onChanged: (_) => setState(() {}), decoration: InputDecoration(labelText: 'Tell us what you do', hintText: 'e.g. Content creator, Engineer...', prefixIcon: const Icon(Icons.edit_rounded), filled: true, fillColor: Colors.white.withValues(alpha: .95), border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: AppColors.border)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: AppColors.border)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide(color: AppColors.primary.withValues(alpha: .55), width: 1.3))));
              }
              final occupation = _occupations[index];
              return _selectCard(occupation, emoji: _occupationEmojis[index], selected: _occupation == occupation, onTap: () => setState(() { _occupation = occupation; if (occupation != 'Other') _occupationOtherController.clear(); }));
            },
          ),
        ),
      ],
    );
  }

  Widget _blob(double size, Color color) => Transform.rotate(angle: -.28, child: Container(width: size, height: size * .62, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(size))));

  Widget _topBar() => Padding(padding: const EdgeInsets.fromLTRB(18, 8, 18, 0), child: Row(children: [IconButton(onPressed: _saving ? null : _back, icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18)), const Spacer(), Text('${_step + 1} of 7', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)), const Spacer(), const SizedBox(width: 48)]));

  Widget _progressBar() => Padding(padding: const EdgeInsets.fromLTRB(64, 0, 64, 4), child: ClipRRect(borderRadius: BorderRadius.circular(AppRadius.full), child: LinearProgressIndicator(minHeight: 3, value: _progress, backgroundColor: AppColors.border, valueColor: const AlwaysStoppedAnimation(AppColors.primary))));
}

class _InlineQuestionnaire extends StatefulWidget {
  const _InlineQuestionnaire({required this.gender, required this.onCompleted, required this.busy});

  final String gender;
  final ValueChanged<FlashQuestionnaireResult> onCompleted;
  final bool busy;

  @override
  State<_InlineQuestionnaire> createState() => _InlineQuestionnaireState();
}

class _InlineQuestionnaireState extends State<_InlineQuestionnaire> {
  int _index = 0;
  final Map<String, int> _answers = {};

  FlashQuestion get _question => FlashQuestionService.questions[_index];
  bool get _last => _index == FlashQuestionService.questions.length - 1;
  int? get _selected => _answers[_question.id];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        LinearProgressIndicator(value: (_index + 1) / FlashQuestionService.questions.length),
        const SizedBox(height: 12),
        Align(alignment: Alignment.centerLeft, child: Text('Question ${_index + 1} of ${FlashQuestionService.questions.length}', style: Theme.of(context).textTheme.labelLarge)),
        const SizedBox(height: 12),
        Text(_question.question, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 14),
        Expanded(
          child: ListView.separated(
            itemCount: _question.options.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, optionIndex) => Card(
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: _selected == optionIndex ? Theme.of(context).colorScheme.primary : Theme.of(context).dividerColor, width: _selected == optionIndex ? 2 : 1)),
              child: RadioListTile<int>(value: optionIndex, groupValue: _selected, onChanged: widget.busy ? null : (value) => setState(() => _answers[_question.id] = value!), title: Text(_question.options[optionIndex])),
            ),
          ),
        ),
        Row(children: [if (_index > 0) Expanded(child: OutlinedButton(onPressed: widget.busy ? null : () => setState(() => _index--), child: const Text('Back'))), if (_index > 0) const SizedBox(width: 10), Expanded(child: FilledButton(onPressed: widget.busy || _selected == null ? null : () { if (_last) { widget.onCompleted(FlashQuestionService.calculate(gender: widget.gender, answers: _answers)); } else { setState(() => _index++); } }, child: Text(_last ? 'Save Answers' : 'Next')))]),
      ],
    );
  }
}
