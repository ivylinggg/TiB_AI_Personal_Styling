import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../models/colour_analysis_result.dart';
import '../../providers/analysis_provider.dart';
import '../../services/style_score_service.dart';
import '../../widgets/colour_swatch.dart';
import '../analysis/analysis_result_screen.dart';
import '../analysis/analysis_screen.dart';
import 'style_score_detail_screen.dart';

class DashboardDesignedScreen extends StatelessWidget {
  const DashboardDesignedScreen({super.key});

  static const _challenges = <_DailyChallenge>[
    _DailyChallenge('Appearance', 'Colour Confidence', 'Wear today\'s recommended colour near your face.', 'Choose one piece from your personal palette and notice what looks brighter or more harmonious.', Icons.palette_outlined),
    _DailyChallenge('Appearance', 'Wardrobe Polish', 'Improve one small detail of today\'s outfit.', 'Check fit, pressing, layering or one finishing accessory before you leave.', Icons.checkroom_outlined),
    _DailyChallenge('Appearance', 'Grooming Reset', 'Take five minutes for a polished grooming check.', 'Check hair, skin, nails, fragrance and clothing finish. Make one small improvement.', Icons.face_retouching_natural_outlined),
    _DailyChallenge('Appearance', 'Posture Presence', 'Reset your posture before your next interaction.', 'Relax your shoulders, keep your chin neutral and ground your feet for three calm breaths.', Icons.accessibility_new_rounded),
    _DailyChallenge('Appearance', 'Signature Colour Look', 'Build today\'s outfit around one of your strongest colours.', 'Keep the rest simple so your personal colour becomes the visual focus.', Icons.auto_awesome_rounded),
    _DailyChallenge('Appearance', 'Accessory Finish', 'Add one intentional finishing accessory.', 'Choose one piece that supports the outfit instead of competing with it.', Icons.watch_outlined),
    _DailyChallenge('Appearance', 'Professional Fit Check', 'Check that your outfit matches today\'s setting.', 'Ask whether it is appropriate, comfortable, polished and aligned with the impression you want to create.', Icons.business_center_outlined),
    _DailyChallenge('Behavior', 'Calm Confidence', 'Pause for one breath before reacting.', 'Respond after the pause rather than from the first emotional impulse.', Icons.self_improvement_outlined),
    _DailyChallenge('Behavior', 'Warm Greeting', 'Make your next greeting more intentional.', 'Use eye contact, a genuine smile and a clear greeting.', Icons.waving_hand_outlined),
    _DailyChallenge('Behavior', 'Listen First', 'Practise listening without preparing your reply.', 'Ask one thoughtful follow-up question before giving your opinion.', Icons.hearing_outlined),
    _DailyChallenge('Behavior', 'Dining Polish', 'Practise one small dining etiquette habit.', 'Slow down, keep your posture open and use calm table manners.', Icons.restaurant_outlined),
    _DailyChallenge('Behavior', 'Grace Under Pressure', 'Handle one difficult moment with composure.', 'Your goal is not to win the moment; it is to stay professional in it.', Icons.shield_outlined),
    _DailyChallenge('Behavior', 'Respect & Awareness', 'Notice hierarchy, culture and personal-space cues.', 'Adjust your approach so the other person feels respected and comfortable.', Icons.diversity_3_outlined),
    _DailyChallenge('Behavior', 'Confidence Without Force', 'Let confidence come from clarity.', 'Speak clearly, stay grounded and allow others room to contribute.', Icons.psychology_alt_outlined),
    _DailyChallenge('Communication', 'Clear Introduction', 'Introduce yourself with clarity.', 'Say who you are, what you do and what you can help with.', Icons.person_add_alt_1_outlined),
    _DailyChallenge('Communication', 'Voice Polish', 'Notice your speaking pace today.', 'Use a comfortable pace, clear pauses and a warm tone in one important conversation.', Icons.record_voice_over_outlined),
    _DailyChallenge('Communication', 'Body Language Check', 'Match your body language to your message.', 'Focus on open posture, attentive eye contact and relaxed hands.', Icons.pan_tool_alt_outlined),
    _DailyChallenge('Communication', 'Empathy Language', 'Replace one sharp phrase with a constructive one.', 'Acknowledge the other person before moving into problem solving.', Icons.favorite_border_rounded),
    _DailyChallenge('Communication', 'Name Card Confidence', 'Practise calm, respectful name-card etiquette.', 'Use the person\'s name naturally afterwards so the interaction feels personal.', Icons.badge_outlined),
    _DailyChallenge('Communication', 'Meeting Presence', 'Make one useful contribution in your next meeting.', 'Ask a question, summarise a point or add one concise idea.', Icons.groups_2_outlined),
    _DailyChallenge('Communication', 'Digital Message Tone', 'Read one important message from the receiver\'s point of view.', 'Remove unnecessary emotion, ambiguity or wording that could sound abrupt.', Icons.chat_bubble_outline_rounded),
    _DailyChallenge('Digital Etiquette', 'Professional Profile', 'Check whether your visible profile supports your professional image.', 'Use a clear photo, consistent display name and an appropriate bio.', Icons.account_circle_outlined),
    _DailyChallenge('Digital Etiquette', 'Email Hygiene', 'Make one important email easier to act on.', 'Use a useful subject, concise body and clear next step.', Icons.email_outlined),
    _DailyChallenge('Digital Etiquette', 'Camera Ready', 'Prepare your camera frame before an online meeting.', 'Use good light, a clean background and an eye-level camera.', Icons.videocam_outlined),
    _DailyChallenge('Digital Etiquette', 'WhatsApp Polish', 'Review one important chat message before sending.', 'Check tone, timing, formatting and whether the request is easy to understand.', Icons.phone_iphone_outlined),
    _DailyChallenge('Digital Etiquette', 'Digital Boundaries', 'Choose one small digital boundary today.', 'Turn off one unnecessary notification or create a focused reply window.', Icons.notifications_off_outlined),
    _DailyChallenge('Digital Etiquette', 'Professional Sharing', 'Pause before posting or sharing publicly.', 'Think about audience, context and long-term professional impression.', Icons.public_outlined),
    _DailyChallenge('Digital Etiquette', 'Online Presence Reset', 'Clean one visible part of your digital presence.', 'Update a bio, remove an outdated image or make one detail more consistent.', Icons.language_outlined),
  ];

  int _dayOfYear(DateTime date) => date.difference(DateTime(date.year, 1, 1)).inDays + 1;
  String _normaliseColour(String value) => value.toLowerCase().replaceAll('-', ' ').replaceAll('_', ' ').trim();

  String _todayColourName(ColourAnalysisResult? result) {
    if (result == null || result.colours.isEmpty) return '—';
    return result.colours[_dayOfYear(DateTime.now()) % result.colours.length];
  }

  String _todayColourMessage(String colour) {
    final key = _normaliseColour(colour);
    const exact = <String, String>{
      'pink': 'A little romance may find you today ✨',
      'rose': 'You are giving off a romantic energy today — stay open to new connections 🌹',
      'coral': 'Take the lead today. A good thing may begin when you speak up 🧡',
      'red': 'Be a little bolder today — your confidence will stand out ❤️',
      'orange': 'Be a little more proactive today. Good things may follow 🧡',
      'yellow': 'Bring a little sunshine with you today — inspiration and good vibes will follow 💛',
      'green': 'Take it slow and steady today. Your calm confidence will shine naturally 🌿',
      'teal': 'Your words may carry extra warmth today. Stay clear, sincere and positive 🩵',
      'blue': 'Communication may flow more smoothly today. Let your calm and reliability show 💙',
      'purple': 'Let your creativity show today and give people something memorable about you 💜',
      'brown': 'You are giving off a grounded, dependable energy today 🤎',
      'beige': 'Keep it easy today. A clean, effortless look may be all you need 🤍',
      'white': 'Today feels like a fresh start. Stay light and open to new possibilities 🤍',
      'black': 'Own your presence today. You may feel more powerful than you expect 🖤',
      'grey': 'Stay calm and composed today. Understated can still look incredibly polished 🩶',
      'gray': 'Stay calm and composed today. Understated can still look incredibly polished 🩶',
    };
    if (exact.containsKey(key)) return exact[key]!;
    if (key.contains('pink') || key.contains('rose')) return exact['pink']!;
    if (key.contains('red') || key.contains('ruby') || key.contains('burgundy')) return exact['red']!;
    if (key.contains('orange') || key.contains('coral') || key.contains('peach')) return exact['orange']!;
    if (key.contains('yellow') || key.contains('gold')) return exact['yellow']!;
    if (key.contains('green') || key.contains('olive') || key.contains('sage') || key.contains('mint')) return exact['green']!;
    if (key.contains('teal') || key.contains('turquoise') || key.contains('cyan') || key.contains('aqua')) return exact['teal']!;
    if (key.contains('blue') || key.contains('navy') || key.contains('cobalt')) return exact['blue']!;
    if (key.contains('purple') || key.contains('lavender') || key.contains('mauve')) return exact['purple']!;
    if (key.contains('brown') || key.contains('camel') || key.contains('chocolate') || key.contains('tan')) return exact['brown']!;
    if (key.contains('beige') || key.contains('cream') || key.contains('ivory') || key.contains('taupe')) return exact['beige']!;
    if (key.contains('white')) return exact['white']!;
    if (key.contains('black') || key.contains('charcoal')) return exact['black']!;
    if (key.contains('grey') || key.contains('gray')) return exact['grey']!;
    return 'Wear it with confidence and let your colour set the tone for a good day ✨';
  }

  int _challengeIndex(DateTime date) => _dayOfYear(date) % _challenges.length;
  String _dateKey(DateTime date) => '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  Future<bool> _isChallengeCompleted(String uid, DateTime date) async {
    final snapshot = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final data = snapshot.data();
    return data?['dailyChallengeDate'] == _dateKey(date) && data?['dailyChallengeId'] == _challengeIndex(date) && data?['dailyChallengeCompleted'] == true;
  }

  Future<void> _completeChallenge(BuildContext context) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final now = DateTime.now();
    if (uid == null) return;
    final challengeId = _challengeIndex(now);
    final challenge = _challenges[challengeId];
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'dailyChallengeDate': _dateKey(now),
        'dailyChallengeId': challengeId,
        'dailyChallengeCompleted': true,
        'dailyChallengeCategory': challenge.category,
        'dailyChallengeTitle': challenge.title,
        'dailyChallengeXp': 10,
        'dailyChallengeHistory': FieldValue.arrayUnion([
          {'date': _dateKey(now), 'challengeId': challengeId, 'category': challenge.category, 'title': challenge.title, 'xp': 10},
        ]),
      }, SetOptions(merge: true));
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nice work — today\'s challenge is complete! +10 XP ✨')));
      Navigator.pop(context);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not save your challenge progress. Please try again.')));
    }
  }

  Future<void> _showChallengeDetails(BuildContext context, ColourAnalysisResult? result) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final now = DateTime.now();
    final challenge = _challenges[_challengeIndex(now)];
    final completed = uid == null ? false : await _isChallengeCompleted(uid, now);
    if (!context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: AppColors.background,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [Container(width: 48, height: 48, decoration: const BoxDecoration(color: AppColors.lavenderMist, shape: BoxShape.circle), child: Icon(challenge.icon, color: AppColors.primaryDark)), const SizedBox(width: 11), Expanded(child: Text(challenge.title, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900)))]),
              const SizedBox(height: 7),
              Text(challenge.category.toUpperCase(), style: const TextStyle(color: AppColors.primaryDark, fontSize: 9.5, fontWeight: FontWeight.w900, letterSpacing: .8)),
              const SizedBox(height: 12),
              Text(challenge.description, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5, height: 1.45)),
              const SizedBox(height: 12),
              Container(padding: const EdgeInsets.all(13), decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(15), border: Border.all(color: AppColors.border)), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [const Icon(Icons.lightbulb_outline_rounded, color: AppColors.primaryDark, size: 20), const SizedBox(width: 9), Expanded(child: Text(challenge.howTo, style: const TextStyle(fontSize: 11.5, height: 1.4, fontWeight: FontWeight.w600)))])),
              const SizedBox(height: 15),
              if (result == null)
                const Text('Complete your colour analysis first to unlock personalised daily challenges.', style: TextStyle(color: AppColors.textMuted, fontSize: 10.5))
              else
                SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: completed ? null : () => _completeChallenge(sheetContext), icon: Icon(completed ? Icons.check_rounded : Icons.auto_awesome_rounded), label: Text(completed ? 'Completed today' : 'Mark as complete'))),
            ],
          ),
        ),
      ),
    );
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
              _todayColourCard(context, result, todayColour),
              const SizedBox(height: 14),
              _styleScoreCard(context, uid, provider),
              const SizedBox(height: 14),
              _challengeCard(context, result),
            ],
          ),
        ),
      ),
    );
  }

  Widget _todayColourCard(BuildContext context, ColourAnalysisResult? result, String colour) {
    return _card(context, result == null ? const AnalysisScreen() : AnalysisResultScreen(result: result), Row(children: [
      result == null ? Container(width: 62, height: 62, decoration: const BoxDecoration(color: AppColors.primarySoft, shape: BoxShape.circle), child: const Icon(Icons.palette_outlined, color: AppColors.primaryDark, size: 27)) : ColourSwatch(name: colour, size: 62),
      const SizedBox(width: 13),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [const Expanded(child: Text("TODAY'S COLOUR", style: TextStyle(color: AppColors.textMuted, fontSize: 9.5, fontWeight: FontWeight.w900, letterSpacing: .7))), if (result != null) Text('${DateTime.now().day}/${DateTime.now().month}', style: const TextStyle(color: AppColors.textMuted, fontSize: 9.5, fontWeight: FontWeight.w700))]),
        const SizedBox(height: 3),
        Text(result == null ? 'Discover your colour' : colour, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
        const SizedBox(height: 4),
        Text(result == null ? 'Complete your colour analysis to unlock your daily colour.' : 'From your personal best-colour palette', style: const TextStyle(color: AppColors.primaryDark, fontSize: 10, fontWeight: FontWeight.w700)),
        if (result != null) ...[const SizedBox(height: 5), Text(_todayColourMessage(colour), style: const TextStyle(color: AppColors.textSecondary, fontSize: 11, height: 1.4))],
      ])),
      const SizedBox(width: 5), const Icon(Icons.chevron_right_rounded, color: AppColors.primary, size: 20),
    ]));
  }

  Widget _styleScoreCard(BuildContext context, String? uid, AnalysisProvider provider) {
    if (uid == null) return _card(context, null, const Text('Sign in to build your Style Score', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)));
    return FutureBuilder<StyleScoreSnapshot>(
      future: StyleScoreService.calculate(uid: uid, analysis: provider.result),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return _card(context, null, const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('STYLE SCORE', style: TextStyle(color: AppColors.textMuted, fontSize: 9.5, fontWeight: FontWeight.w900, letterSpacing: .7)), SizedBox(height: 8), Text('Updating your Style Score…', style: TextStyle(color: AppColors.textSecondary, fontSize: 12))]));
        if (snapshot.hasError || !snapshot.hasData) return _card(context, null, const Text('Style Score is unavailable right now.', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)));
        final score = snapshot.data!;
        final label = _scoreLabel(score.total);
        return _card(context, const StyleScoreDetailScreen(), Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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

  Widget _challengeCard(BuildContext context, ColourAnalysisResult? result) {
    final challenge = _challenges[_challengeIndex(DateTime.now())];
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return FutureBuilder<StyleScoreSnapshot>(
      future: uid == null ? Future.value(const StyleScoreSnapshot(appearance: 0, behavior: 0, communication: 0, digitalEtiquette: 0)) : StyleScoreService.calculate(uid: uid, analysis: result),
      builder: (context, scoreSnapshot) {
        if (scoreSnapshot.connectionState == ConnectionState.waiting) return _card(context, null, const Text('Loading today\'s challenge…', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)));
        final score = scoreSnapshot.data ?? const StyleScoreSnapshot(appearance: 0, behavior: 0, communication: 0, digitalEtiquette: 0);
        final completed = uid == null ? false : score.behavior > 0;
        return FutureBuilder<bool>(
          future: uid == null ? Future.value(false) : _isChallengeCompleted(uid, DateTime.now()),
          builder: (context, completedSnapshot) {
            final isCompleted = completedSnapshot.data ?? completed;
            return _card(context, null, Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: AppColors.lavenderMist.withOpacity(.45), borderRadius: BorderRadius.circular(18)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [const Icon(Icons.auto_awesome_rounded, color: AppColors.primaryDark, size: 20), const SizedBox(width: 9), const Expanded(child: Text('TODAY\'S CHALLENGE', style: TextStyle(color: AppColors.primaryDark, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: .8))), const Text('+10 XP', style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w800))]),
              const SizedBox(height: 12),
              Text(challenge.category, style: const TextStyle(color: AppColors.primaryDark, fontSize: 10, fontWeight: FontWeight.w800)),
              const SizedBox(height: 7),
              Text(challenge.title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
              const SizedBox(height: 5),
              Text(challenge.description, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.4)),
              const SizedBox(height: 10),
              Text(isCompleted ? 'Completed today' : 'Make one small improvement today.', style: const TextStyle(color: AppColors.textSecondary, fontSize: 10.5, fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: result == null || isCompleted ? null : () => _showChallengeDetails(context, result), icon: Icon(isCompleted ? Icons.check_rounded : Icons.auto_awesome_rounded, size: 17), label: Text(isCompleted ? 'Completed today' : 'View today\'s challenge'))),
              if (result == null) const Padding(padding: EdgeInsets.only(top: 7), child: Text('Complete your colour analysis first to unlock personalised daily challenges.', style: TextStyle(color: AppColors.textMuted, fontSize: 10))),
            ])));
          },
        );
      },
    );
  }

  Widget _card(BuildContext context, Widget? target, Widget child) => Material(color: AppColors.surface, borderRadius: BorderRadius.circular(20), child: InkWell(borderRadius: BorderRadius.circular(20), onTap: target == null ? null : () => Navigator.push(context, MaterialPageRoute(builder: (_) => target)), child: Padding(padding: const EdgeInsets.fromLTRB(16, 16, 14, 17), child: child)));
}

class _DailyChallenge {
  final String category;
  final String title;
  final String description;
  final String howTo;
  final IconData icon;

  const _DailyChallenge(this.category, this.title, this.description, this.howTo, this.icon);
}
