import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_gradients.dart';
import '../../models/colour_analysis_result.dart';
import '../../providers/analysis_provider.dart';
import '../../services/style_score_service.dart';
import '../../widgets/colour_swatch.dart';
import '../analysis/analysis_result_screen.dart';
import '../analysis/analysis_screen.dart';
import 'style_score_detail_screen.dart';

class DashboardDesignedScreen extends StatelessWidget {
  const DashboardDesignedScreen({super.key});

  static const _challenges = <_DailyChallenge>[];

  int _dayOfYear(DateTime date) => date.difference(DateTime(date.year, 1, 1)).inDays + 1;
  String _normaliseColour(String value) => value.toLowerCase().replaceAll('-', ' ').replaceAll('_', ' ').trim();

  String _todayColourName(ColourAnalysisResult? result) {
    if (result == null || result.colours.isEmpty) return '—';
    return result.colours[_dayOfYear(DateTime.now()) % result.colours.length];
  }

  String _todayColourMessage(String colour) {
    final key = _normaliseColour(colour);
    if (key.contains('pink') || key.contains('rose')) return 'A little romance may find you today ✨';
    if (key.contains('red') || key.contains('ruby') || key.contains('burgundy')) return 'Be a little bolder today — your confidence will stand out ❤️';
    if (key.contains('orange') || key.contains('coral') || key.contains('peach')) return 'Be a little more proactive today. Good things may follow 🧡';
    if (key.contains('yellow') || key.contains('gold')) return 'Bring a little sunshine with you today — inspiration and good vibes will follow 💛';
    if (key.contains('green') || key.contains('olive') || key.contains('sage') || key.contains('mint')) return 'Take it slow and steady today. Your calm confidence will shine naturally 🌿';
    if (key.contains('teal') || key.contains('turquoise') || key.contains('cyan') || key.contains('aqua')) return 'Your words may carry extra warmth today. Stay clear, sincere and positive 🩵';
    if (key.contains('blue') || key.contains('navy') || key.contains('cobalt')) return 'Communication may flow more smoothly today. Let your calm and reliability show 💙';
    if (key.contains('purple') || key.contains('lavender') || key.contains('mauve')) return 'Let your creativity show today and give people something memorable about you 💜';
    if (key.contains('brown') || key.contains('camel') || key.contains('chocolate') || key.contains('tan')) return 'You are giving off a grounded, dependable energy today 🤎';
    if (key.contains('beige') || key.contains('cream') || key.contains('ivory') || key.contains('taupe')) return 'Keep it easy today. A clean, effortless look may be all you need 🤍';
    if (key.contains('white')) return 'Today feels like a fresh start. Stay light and open to new possibilities 🤍';
    if (key.contains('black') || key.contains('charcoal')) return 'Own your presence today. You may feel more powerful than you expect 🖤';
    if (key.contains('grey') || key.contains('gray')) return 'Stay calm and composed today. Understated can still look incredibly polished 🩶';
    return 'Wear it with confidence and let your colour set the tone for a good day ✨';
  }

  _TodayStyle _todayStyle(ColourAnalysisResult? result) {
    final day = DateTime.now().weekday;
    final colourKey = _normaliseColour(_todayColourName(result));
    if (colourKey.contains('pink') || colourKey.contains('rose') || colourKey.contains('red')) {
      return const _TodayStyle('Soft & Romantic', ['Feminine', 'Sweet', 'Elegant']);
    }
    if (colourKey.contains('black') || colourKey.contains('grey') || colourKey.contains('gray') || colourKey.contains('white')) {
      return const _TodayStyle('Minimal Chic', ['Simple', 'Clean', 'Polished']);
    }
    if (colourKey.contains('blue') || colourKey.contains('teal')) {
      return const _TodayStyle('Smart Casual', ['Relaxed', 'Refined', 'Confident']);
    }
    if (colourKey.contains('orange') || colourKey.contains('yellow')) {
      return const _TodayStyle('Bright & Playful', ['Sunny', 'Fresh', 'Energetic']);
    }
    if (colourKey.contains('purple') || colourKey.contains('lavender')) {
      return const _TodayStyle('Soft Creative', ['Gentle', 'Creative', 'Unique']);
    }
    return switch (day) {
      DateTime.monday => const _TodayStyle('Clean Start', ['Simple', 'Fresh', 'Put-together']),
      DateTime.tuesday => const _TodayStyle('Easy Smart', ['Casual', 'Neat', 'Versatile']),
      DateTime.wednesday => const _TodayStyle('Balanced Chic', ['Simple', 'Elegant', 'Comfortable']),
      DateTime.thursday => const _TodayStyle('Modern Feminine', ['Soft', 'Stylish', 'Polished']),
      DateTime.friday => const _TodayStyle('Casual Glow', ['Relaxed', 'Bright', 'Fun']),
      DateTime.saturday => const _TodayStyle('Effortless Weekend', ['Casual', 'Easy', 'Cool']),
      _ => const _TodayStyle('Soft Sunday', ['Comfortable', 'Calm', 'Clean']),
    };
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AnalysisProvider>();
    final result = provider.result;
    final todayColour = _todayColourName(result);
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final userName = FirebaseAuth.instance.currentUser?.displayName?.trim();
    final greeting = userName?.isNotEmpty == true ? 'Hi, $userName' : 'Welcome back';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async { if (uid != null) await provider.loadLatestResult(uid); },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
            children: [
              Text(greeting, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
              const SizedBox(height: 5),
              const Text('Your personal styling space', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              const SizedBox(height: 18),
              _todayRecommendationCard(context, result, todayColour),
              const SizedBox(height: 14),
              _styleScoreCard(context, uid, provider),
            ],
          ),
        ),
      ),
    );
  }

  Widget _todayRecommendationCard(BuildContext context, ColourAnalysisResult? result, String colour) {
    final style = _todayStyle(result);
    final message = result == null ? 'Complete your colour analysis to unlock personalised styling.' : _todayColourMessage(colour);
    final target = result == null ? const AnalysisScreen() : AnalysisResultScreen(analysisProvider: context.read<AnalysisProvider>(), result: result);

    return _card(context, target, Container(
      decoration: BoxDecoration(
        gradient: AppGradients.soft,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primarySoft),
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 14, 17),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Expanded(child: Text("TODAY'S RECOMMENDATION", style: TextStyle(color: AppColors.textMuted, fontSize: 9.5, fontWeight: FontWeight.w900, letterSpacing: .7))),
            Text('${DateTime.now().day}/${DateTime.now().month}', style: const TextStyle(color: AppColors.textMuted, fontSize: 9.5, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 10),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(width: 62, height: 62, decoration: const BoxDecoration(color: AppColors.primarySoft, shape: BoxShape.circle), child: const Icon(Icons.auto_awesome_rounded, color: AppColors.primaryDark, size: 27)),
            const SizedBox(width: 13),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(style.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              Wrap(spacing: 6, runSpacing: 6, children: style.tags.map(_styleTag).toList()),
              const SizedBox(height: 7),
              Text(message, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11, height: 1.4)),
            ])),
          ]),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
            decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
            child: Row(children: [
              ColourSwatch(name: colour, size: 22),
              const SizedBox(width: 8),
              Expanded(child: Text(result == null ? 'Complete your colour analysis to personalise today\'s recommendation.' : 'Best colour today: $colour', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: AppColors.textSecondary))),
              const Icon(Icons.chevron_right_rounded, color: AppColors.primary, size: 20),
            ]),
          ),
        ],
      ),
    ));
  }

  Widget _styleTag(String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    decoration: BoxDecoration(color: AppColors.primarySoft.withValues(alpha: .65), borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.primarySoft)),
    child: Text(label, style: const TextStyle(fontSize: 8.8, fontWeight: FontWeight.w800, color: AppColors.primaryDark)),
  );

  Widget _styleScoreCard(BuildContext context, String? uid, AnalysisProvider provider) {
    if (uid == null) return _card(context, null, const Text('Sign in to build your Style Score', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)));
    return FutureBuilder<StyleScoreSnapshot>(
      future: StyleScoreService.calculate(uid: uid, analysis: provider.result),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return _card(context, null, const Text('Updating your Style Score…', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)));
        if (snapshot.hasError || !snapshot.hasData) return _card(context, null, const Text('Style Score is unavailable right now.', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)));
        final score = snapshot.data!;
        final label = _scoreLabel(score.total);
        return _card(context, StyleScoreDetailScreen(analysisProvider: provider), Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [const Expanded(child: Text('STYLE SCORE', style: TextStyle(color: AppColors.textMuted, fontSize: 9.5, fontWeight: FontWeight.w900, letterSpacing: .7))), Text(label, style: const TextStyle(color: AppColors.primaryDark, fontSize: 10.5, fontWeight: FontWeight.w800))]),
          const SizedBox(height: 10),
          Row(children: [Text('${score.total}', style: const TextStyle(fontSize: 42, fontWeight: FontWeight.w900, color: AppColors.textPrimary)), const Text('/100', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textMuted)), const Spacer(), SizedBox(width: 95, height: 95, child: CircularProgressIndicator(value: score.total / 100, strokeWidth: 10, color: AppColors.primary, backgroundColor: AppColors.border))]),
          const SizedBox(height: 9),
          ClipRRect(borderRadius: BorderRadius.circular(20), child: LinearProgressIndicator(value: score.total / 100, minHeight: 6, color: AppColors.primary, backgroundColor: AppColors.border)),
          const SizedBox(height: 11),
          Wrap(spacing: 7, runSpacing: 7, children: [_scoreChip('A', score.appearance, 40), _scoreChip('B', score.behavior, 25), _scoreChip('C', score.communication, 20), _scoreChip('D', score.digitalEtiquette, 15)]),
          const SizedBox(height: 9),
          const Text('Tap to see your full Style Score breakdown.', style: TextStyle(color: AppColors.textMuted, fontSize: 10.5)),
        ]));
      },
    );
  }

  Widget _scoreChip(String label, int value, int max) => Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7), decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)), child: Text('$label  $value/$max', style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800)));

  String _scoreLabel(int score) {
    if (score >= 90) return 'Signature ready';
    if (score >= 75) return 'Well styled';
    if (score >= 55) return 'Good foundation';
    if (score >= 35) return 'Building your style';
    return 'Start your style journey';
  }

  Widget _card(BuildContext context, Widget? target, Widget child) => Material(color: AppColors.surface, borderRadius: BorderRadius.circular(20), child: InkWell(borderRadius: BorderRadius.circular(20), onTap: target == null ? null : () => Navigator.push(context, MaterialPageRoute(builder: (_) => target)), child: Padding(padding: const EdgeInsets.all(16), child: child)));
}

class _DailyChallenge {
  final String category;
  final String title;
  final String description;
  final String howTo;
  final IconData icon;
  const _DailyChallenge(this.category, this.title, this.description, this.howTo, this.icon);
}

class _TodayStyle {
  final String name;
  final List<String> tags;
  const _TodayStyle(this.name, this.tags);
}
