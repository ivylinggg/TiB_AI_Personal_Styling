import 'package:flutter/material.dart';

import '../../models/flash_question.dart';
import '../../services/flash_question_service.dart';
import 'flash_question_result_screen.dart';

class FlashQuestionScreen extends StatefulWidget {
  const FlashQuestionScreen({super.key, required this.gender});

  final String gender;

  @override
  State<FlashQuestionScreen> createState() => _FlashQuestionScreenState();
}

class _FlashQuestionScreenState extends State<FlashQuestionScreen> {
  int _index = 0;
  final Map<String, int> _answers = {};

  FlashQuestion get _question => FlashQuestionService.questions[_index];
  bool get _lastQuestion => _index == FlashQuestionService.questions.length - 1;
  int? get _selected => _answers[_question.id];

  void _select(int value) {
    setState(() => _answers[_question.id] = value);
  }

  void _next() {
    if (_selected == null) return;
    if (_lastQuestion) {
      final result = FlashQuestionService.calculate(
        gender: widget.gender,
        answers: _answers,
      );
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => FlashQuestionResultScreen(result: result),
        ),
      );
      return;
    }
    setState(() => _index++);
  }

  void _previous() {
    if (_index == 0) return;
    setState(() => _index--);
  }

  @override
  Widget build(BuildContext context) {
    final progress = (_index + 1) / FlashQuestionService.questions.length;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Personal Colour Questionnaire'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LinearProgressIndicator(value: progress),
              const SizedBox(height: 18),
              Text(
                'Question ${_index + 1} of ${FlashQuestionService.questions.length}',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 14),
              Text(
                _question.question,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 18),
              Expanded(
                child: ListView.separated(
                  itemCount: _question.options.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, optionIndex) {
                    final selected = _selected == optionIndex;
                    return Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color: selected
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).dividerColor,
                          width: selected ? 2 : 1,
                        ),
                      ),
                      child: RadioListTile<int>(
                        value: optionIndex,
                        groupValue: _selected,
                        onChanged: (value) {
                          if (value != null) _select(value);
                        },
                        title: Text(_question.options[optionIndex]),
                      ),
                    );
                  },
                ),
              ),
              Row(
                children: [
                  if (_index > 0)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _previous,
                        child: const Text('Back'),
                      ),
                    ),
                  if (_index > 0) const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _selected == null ? null : _next,
                      child: Text(_lastQuestion ? 'See My Result' : 'Next'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
