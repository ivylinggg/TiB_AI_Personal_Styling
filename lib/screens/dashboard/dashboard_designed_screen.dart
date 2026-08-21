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
      'pink': '今天的你可能会遇到一点甜甜的桃花运噢 ✨',
      'rose': '今天的你自带一点浪漫滤镜，勇敢接受新的缘分吧 🌹',
      'coral': '今天适合主动一点，好事可能就在你开口以后发生 🧡',
      'red': '今天适合大胆一点，你的自信会特别有存在感 ❤️',
      'orange': '今天很适合主动一点，好事可能就在你开口以后发生 🧡',
      'yellow': '今天带一点阳光色，灵感和好心情都会跟着来 💛',
      'green': '今天适合慢一点、稳一点，你的好状态会自然散发出来 🌿',
      'teal': '今天的语言会更有感染力，保持清爽、真诚和好心情 🩵',
      'blue': '今天的沟通会更顺，把你的冷静和可靠穿出来 💙',
      'purple': '今天很适合发挥一点创意，让别人记住你的独特感 💜',
      'brown': '今天的你自带稳重魅力，温柔又让人觉得很可靠 🤎',
      'beige': '今天适合轻松一点，简单干净的状态反而最耐看 🤍',
      'white': '今天像一个新的开始，保持轻盈，你会发现更多可能 🤍',
      'black': '今天适合把气场打开一点，你会比自己想象中更有力量 🖤',
      'grey': '今天适合保持清醒与从容，低调也可以很有质感 🩶',
      'gray': '今天适合保持清醒与从容，低调也可以很有质感 🩶',
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
    return '今天就穿上它，让属于你的颜色陪你完成一个好日子 ✨';
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
              const SizedBox(height: 14),
              _seasonCard(context, result),
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
        if (snapshot.hasError || !snapshot.hasData) return _card(context, null, const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('STYLE SCORE', style: TextStyle(color: AppColors.textMuted, fontSize: 9.5, fontWeight: FontWeight.w900, letterSpacing: .7)), SizedBox(height: 8), Text('Your Style Score is temporarily unavailable.', style: TextStyle(color: AppColors.textSecondary, fontSize: 12))]));
        final score = snapshot.data!;
        return _card(context, StyleScoreDetailScreen(analysisProvider: provider), Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [const Expanded(child: Text('STYLE SCORE', style: TextStyle(color: AppColors.textMuted, fontSize: 9.5, fontWeight: FontWeight.w900, letterSpacing: .7))), Text(_scoreLabel(score.total), style: const TextStyle(color: AppColors.primaryDark, fontSize: 10.5, fontWeight: FontWeight.w800))]),
          const SizedBox(height: 8),
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [Text('${score.total}', style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900, height: .95)), const Padding(padding: EdgeInsets.only(left: 3, bottom: 3), child: Text('/100', style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w700))), const Spacer(), SizedBox(width: 78, height: 42, child: CustomPaint(painter: _ScorePainter(score.total / 100)))]),
          const SizedBox(height: 10),
          ClipRRect(borderRadius: BorderRadius.circular(99), child: LinearProgressIndicator(value: score.total / 100, minHeight: 6, backgroundColor: AppColors.border, color: AppColors.primary)),
          const SizedBox(height: 10),
          Wrap(spacing: 6, runSpacing: 6, children: <Widget>[_scoreChip('A', score.appearance, 40), _scoreChip('B', score.behavior, 25), _scoreChip('C', score.communication, 20), _scoreChip('D', score.digitalEtiquette, 15)]),
          const SizedBox(height: 7),
          const Text('Tap to see your full Style Score breakdown.', style: TextStyle(color: AppColors.textSecondary, fontSize: 9.8, height: 1.35)),
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
        final score = scoreSnapshot.data;
        final streak = score?.challengeStreak ?? 0;
        final xp = score?.challengeXp ?? 0;
        return FutureBuilder<bool>(
          future: uid == null ? Future.value(false) : _isChallengeCompleted(uid, DateTime.now()),
          builder: (context, completedSnapshot) {
            final completed = completedSnapshot.data == true;
            return Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: result == null ? null : () => _showChallengeDetails(context, result),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 15, 16, 16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [AppColors.lavenderMist, AppColors.background], begin: Alignment.topLeft, end: Alignment.bottomRight),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Container(width: 42, height: 42, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle), child: Icon(challenge.icon, color: AppColors.primaryDark)),
                        const SizedBox(width: 10),
                        const Expanded(child: Text("TODAY'S CHALLENGE", style: TextStyle(color: AppColors.primaryDark, fontSize: 9.5, fontWeight: FontWeight.w900, letterSpacing: .7))),
                        Text('+10 XP', style: const TextStyle(color: AppColors.textMuted, fontSize: 9.5, fontWeight: FontWeight.w800)),
                      ]),
                      const SizedBox(height: 9),
                      Row(children: [
                        Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(99)), child: Text(challenge.category, style: const TextStyle(color: AppColors.primaryDark, fontSize: 9, fontWeight: FontWeight.w800))),
                        const Spacer(),
                        if (streak > 0) Row(children: [const Icon(Icons.local_fire_department_rounded, color: AppColors.primaryDark, size: 16), const SizedBox(width: 3), Text('$streak day streak', style: const TextStyle(color: AppColors.primaryDark, fontSize: 9.5, fontWeight: FontWeight.w800))]),
                      ]),
                      const SizedBox(height: 8),
                      Text(challenge.title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 4),
                      Text(challenge.description, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11, height: 1.4)),
                      const SizedBox(height: 9),
                      Row(children: [
                        const Icon(Icons.bolt_rounded, color: AppColors.primaryDark, size: 15),
                        const SizedBox(width: 3),
                        Text('$xp XP earned', style: const TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.w700)),
                        const Spacer(),
                        if (completed) const Icon(Icons.check_circle_rounded, color: AppColors.primaryDark, size: 18),
                      ]),
                      const SizedBox(height: 10),
                      SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: result == null || completed ? null : () => _showChallengeDetails(context, result), icon: Icon(completed ? Icons.check_rounded : Icons.auto_awesome_rounded, size: 17), label: Text(completed ? 'Completed today' : 'View today\'s challenge'))),
                      if (result == null) const Padding(padding: EdgeInsets.only(top: 7), child: Text('Complete your colour analysis first to unlock personalised daily challenges.', style: TextStyle(color: AppColors.textMuted, fontSize: 10))),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _seasonCard(BuildContext context, ColourAnalysisResult? result) {
    if (result == null) return _card(context, const AnalysisScreen(), const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('YOUR COLOUR SEASON', style: TextStyle(color: AppColors.textMuted, fontSize: 9.5, fontWeight: FontWeight.w900, letterSpacing: .7)), SizedBox(height: 7), Text('Discover your season', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800)), SizedBox(height: 5), Text('Start your face scan to unlock your personal colour profile.', style: TextStyle(color: AppColors.textSecondary, fontSize: 11.5, height: 1.35))]));
    return _card(context, AnalysisResultScreen(result: result), Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('YOUR COLOUR SEASON', style: TextStyle(color: AppColors.textMuted, fontSize: 9.5, fontWeight: FontWeight.w900, letterSpacing: .7)), const SizedBox(height: 7), Text(result.season, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)), const SizedBox(height: 4), Text('${result.undertone} • ${result.brightness} • ${result.contrast}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)), const SizedBox(height: 10), Wrap(spacing: 7, runSpacing: 7, children: result.colours.take(7).map<Widget>((name) => ColourSwatch(name: name, size: 31, showLabel: true)).toList())]));
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

class _ScorePainter extends CustomPainter {
  final double progress;
  _ScorePainter(this.progress);
  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.height * .22;
    final rect = Rect.fromLTWH(stroke, stroke, size.width - stroke * 2, size.height - stroke * 2);
    final bg = Paint()..color = AppColors.border..style = PaintingStyle.stroke..strokeWidth = stroke..strokeCap = StrokeCap.round;
    final fg = Paint()..color = AppColors.primary..style = PaintingStyle.stroke..strokeWidth = stroke..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, 3.4, 5.75, false, bg);
    canvas.drawArc(rect, 3.4, 5.75 * progress.clamp(0, 1), false, fg);
  }
  @override
  bool shouldRepaint(covariant _ScorePainter oldDelegate) => oldDelegate.progress != progress;
}
