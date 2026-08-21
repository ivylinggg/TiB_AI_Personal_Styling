import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_gradients.dart';
import '../../core/constants/app_radius.dart';
import '../../models/colour_analysis_result.dart';
import '../../models/wardrobe_item.dart';
import '../../providers/analysis_provider.dart';
import '../../services/firestore_service.dart';
import '../../services/style_preference_service.dart';
import '../../widgets/colour_swatch.dart';
import '../ai/style_me_screen.dart';
import '../ai/style_preferences_screen.dart';
import '../analysis/analysis_result_screen.dart';
import '../analysis/analysis_screen.dart';
import '../auth/login_screen.dart';
import '../wardrobe/wardrobe_screen.dart';

/// Home dashboard built around TiB's personal-colour, wardrobe and
/// professional-image direction.
class DashboardDesignedScreen extends StatefulWidget {
  const DashboardDesignedScreen({super.key});

  @override
  State<DashboardDesignedScreen> createState() => _DashboardDesignedScreenState();
}

class _DashboardDesignedScreenState extends State<DashboardDesignedScreen> {
  String _name = '';
  String? _photoUrl;
  bool _premium = false;
  List<WardrobeItem> _wardrobe = const [];
  Map<String, dynamic>? _stylePrefs;
  List<Map<String, dynamic>> _challengeHistory = const [];
  bool _challengeCompleted = false;
  int _challengeStreak = 0;
  int _digitalChallengeCount = 0;

  static const _dailyChallenges = <_DailyChallenge>[
    _DailyChallenge('Appearance', 'Colour Confidence', 'Wear today\'s recommended colour near your face and notice how it changes your overall harmony.', 'Choose a piece from your palette and notice three things that look more balanced or brighter.', Icons.palette_outlined),
    _DailyChallenge('Appearance', 'Wardrobe Polish', 'Choose one outfit and improve one detail: fit, pressing, layering or accessories.', 'Before you leave, make one intentional adjustment that makes the outfit feel more finished.', Icons.checkroom_outlined),
    _DailyChallenge('Appearance', 'Grooming Reset', 'Give yourself five minutes for a polished grooming check before starting the day.', 'Check hair, skin, fragrance, nails and clothing finish. Pick one small improvement.', Icons.face_retouching_natural_outlined),
    _DailyChallenge('Appearance', 'Posture Presence', 'Reset your posture and stance before your next important interaction.', 'Shoulders relaxed, chin neutral, feet grounded. Hold it for three calm breaths.', Icons.accessibility_new_rounded),
    _DailyChallenge('Appearance', 'Signature Colour Look', 'Build your outfit around one of your strongest colours today.', 'Keep the rest simple so your personal colour becomes the visual focus.', Icons.auto_awesome_rounded),
    _DailyChallenge('Appearance', 'Accessory Finish', 'Add one intentional accessory that supports your outfit instead of competing with it.', 'Choose one: earrings, watch, belt, bag, scarf or another finishing piece.', Icons.watch_outlined),
    _DailyChallenge('Appearance', 'Professional Fit Check', 'Check that your outfit supports the role and setting you are entering today.', 'Ask: Is it appropriate, comfortable, polished and aligned with the impression I want to create?', Icons.business_center_outlined),
    _DailyChallenge('Behavior', 'Calm Confidence', 'Pause for one breath before reacting to a stressful moment.', 'Respond after the pause rather than from the first emotional impulse.', Icons.self_improvement_outlined),
    _DailyChallenge('Behavior', 'Warm Greeting', 'Make your next greeting warmer and more intentional.', 'Eye contact, a genuine smile and a clear greeting can change the whole interaction.', Icons.waving_hand_outlined),
    _DailyChallenge('Behavior', 'Listen First', 'In one conversation today, focus on listening without preparing your reply.', 'Ask one thoughtful follow-up question before giving your own opinion.', Icons.hearing_outlined),
    _DailyChallenge('Behavior', 'Dining Polish', 'Practise one small dining etiquette habit at your next meal.', 'Slow down, keep your posture open and use calm table manners.', Icons.restaurant_outlined),
    _DailyChallenge('Behavior', 'Grace Under Pressure', 'Handle one difficult moment with a calm voice and composed body language.', 'Your goal is not to win the moment; it is to stay professional in it.', Icons.shield_outlined),
    _DailyChallenge('Behavior', 'Respect & Awareness', 'Notice hierarchy, culture or personal-space cues in your next interaction.', 'Adjust your approach so the other person feels respected and comfortable.', Icons.diversity_3_outlined),
    _DailyChallenge('Behavior', 'Confidence Without Force', 'Let your confidence come from clarity rather than volume.', 'Speak clearly, stay grounded and allow others space to contribute.', Icons.psychology_alt_outlined),
    _DailyChallenge('Communication', 'Clear Introduction', 'Introduce yourself with your name, role and a simple value statement.', 'Keep it natural: who you are, what you do and what you can help with.', Icons.person_add_alt_1_outlined),
    _DailyChallenge('Communication', 'Voice Polish', 'Notice your speaking pace and slow down slightly in one important conversation.', 'Clear pace, comfortable pauses and a warm tone make your message easier to trust.', Icons.record_voice_over_outlined),
    _DailyChallenge('Communication', 'Body Language Check', 'Match your body language to the message you are trying to communicate.', 'Open posture, attentive eye contact and relaxed hands are today\'s focus.', Icons.pan_tool_alt_outlined),
    _DailyChallenge('Communication', 'Empathy Language', 'Replace one sharp phrase with a more constructive one.', 'Use language that acknowledges the other person before solving the problem.', Icons.favorite_border_rounded),
    _DailyChallenge('Communication', 'Name Card Confidence', 'Practise offering or receiving a name card with calm, respectful attention.', 'Use the person\'s name naturally afterwards so the interaction feels more personal.', Icons.badge_outlined),
    _DailyChallenge('Communication', 'Meeting Presence', 'Make one useful contribution in your next meeting instead of staying invisible.', 'Ask a question, summarise a point or add one concise idea.', Icons.groups_2_outlined),
    _DailyChallenge('Communication', 'Digital Message Tone', 'Before sending an important message, reread the tone from the receiver\'s point of view.', 'Remove ambiguity, unnecessary emotion and anything that could sound abrupt.', Icons.chat_bubble_outline_rounded),
    _DailyChallenge('Digital Etiquette', 'Professional Profile', 'Check that your profile photo and display name feel aligned with the professional image you want.', 'Use a clear, natural photo and a consistent name across important platforms.', Icons.account_circle_outlined),
    _DailyChallenge('Digital Etiquette', 'Email Hygiene', 'Keep one important email short, clear and easy to action today.', 'Use a useful subject, greeting, concise body and clear next step.', Icons.email_outlined),
    _DailyChallenge('Digital Etiquette', 'Camera Ready', 'Prepare your camera frame before an online meeting.', 'Good light, clean background, eye-level camera and appropriate appearance are the goal.', Icons.videocam_outlined),
    _DailyChallenge('Digital Etiquette', 'WhatsApp Polish', 'Review an important WhatsApp or chat message before sending it.', 'Check tone, timing, formatting and whether the recipient can understand the request quickly.', Icons.phone_iphone_outlined),
    _DailyChallenge('Digital Etiquette', 'Digital Boundaries', 'Choose one small digital boundary that protects your focus today.', 'Turn off one unnecessary notification or create a focused reply window.', Icons.notifications_off_outlined),
    _DailyChallenge('Digital Etiquette', 'Professional Sharing', 'Before posting or sharing something publicly, ask whether it supports the image you want to build.', 'Think about audience, context and long-term impression before you post.', Icons.public_outlined),
    _DailyChallenge('Digital Etiquette', 'Online Presence Reset', 'Take five minutes to clean one visible part of your digital presence.', 'Update a bio line, remove an outdated image or make one detail more consistent.', Icons.language_outlined),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final values = await Future.wait<dynamic>([
        FirebaseFirestore.instance.collection('users').doc(uid).get(),
        FirestoreService.getWardrobeItems(uid),
        StylePreferenceService.getStylePreferences(uid),
      ]);
      if (!mounted) return;
      final snapshot = values[0] as DocumentSnapshot<Map<String, dynamic>>;
      final user = snapshot.data();
      final rawHistory = user?['dailyChallengeHistory'];
      final history = rawHistory is List
          ? rawHistory.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
          : <Map<String, dynamic>>[];
      final now = DateTime.now();
      final currentId = _challengeId(now);
      final currentDate = _dateKey(now);
      setState(() {
        _name = (user?['name'] as String? ?? '').trim();
        _photoUrl = user?['photoUrl'] as String?;
        _premium = user?['isPremium'] == true;
        _wardrobe = values[1] as List<WardrobeItem>;
        _stylePrefs = values[2] as Map<String, dynamic>?;
        _challengeHistory = history;
        _challengeCompleted = user?['dailyChallengeDate'] == currentDate &&
            (user?['dailyChallengeId'] as num?)?.toInt() == currentId &&
            user?['dailyChallengeCompleted'] == true;
        _challengeStreak = _calculateStreak(history, now);
        _digitalChallengeCount = history.where((e) => e['category'] == 'Digital Etiquette').length;
      });
    } catch (_) {}
  }

  int _dayOfYear(DateTime date) => date.difference(DateTime(date.year, 1, 1)).inDays + 1;
  int _challengeId(DateTime date) => _dayOfYear(date) % _dailyChallenges.length;
  String _dateKey(DateTime date) => '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  int _calculateStreak(List<Map<String, dynamic>> history, DateTime now) {
    final dates = history.map((e) => e['date']).whereType<String>().toSet();
    var cursor = DateTime(now.year, now.month, now.day);
    if (!dates.contains(_dateKey(cursor))) cursor = cursor.subtract(const Duration(days: 1));
    var count = 0;
    while (dates.contains(_dateKey(cursor))) {
      count++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return count;
  }

  String _normaliseColour(String value) => value.toLowerCase().replaceAll('-', ' ').replaceAll('_', ' ').trim();

  String _todayColourName(ColourAnalysisResult? result) {
    if (result == null || result.colours.isEmpty) return '—';
    return result.colours[_dayOfYear(DateTime.now()) % result.colours.length];
  }

  String _todayColourMessage(String colour) {
    final key = _normaliseColour(colour);
    const exact = <String, String>{
      'pink': '今天的你可能会遇到一点甜甜的桃花运噢 ✨',
      'blush pink': '今天的你温柔感特别强，可能会收到一份可爱的好心情 🌸',
      'dusty rose': '今天的温柔会被看见，适合留下让人舒服的第一印象 🌹',
      'rose': '今天的你自带一点浪漫滤镜，勇敢接受新的缘分吧 🌹',
      'coral': '今天适合主动一点，好事可能就在你开口以后发生 🧡',
      'peach': '今天适合轻轻向前一步，你的亲和力会特别加分 🍑',
      'terracotta': '今天的你很有温度，稳稳的魅力会让人特别有安全感 🤎',
      'red': '今天适合大胆一点，你的自信会特别有存在感 ❤️',
      'ruby': '今天适合做一个果断的决定，你的气场值得被看见 ❤️',
      'burgundy': '今天的你有一种成熟又神秘的魅力，慢慢说也很有力量 🍷',
      'cranberry': '今天可以勇敢表达自己，你的存在感刚刚好 ❤️',
      'orange': '今天很适合主动一点，好事可能就在你开口以后发生 🧡',
      'apricot': '今天的气氛会轻松一点，带着你的亲和力走出去吧 🍑',
      'rust': '今天的你适合稳稳地做事，一点点累积就会有漂亮结果 🧡',
      'yellow': '今天带一点阳光色，灵感和好心情都会跟着来 💛',
      'mustard': '今天适合相信自己的判断，你的想法会比你想象中更有价值 💛',
      'gold': '今天的你值得被看见，记得给自己一个发光的机会 ✨',
      'green': '今天适合慢一点、稳一点，你的好状态会自然散发出来 🌿',
      'olive': '今天适合保持沉稳，越自然越显得有质感 🫒',
      'sage': '今天给自己一点呼吸空间，安静也可以很有力量 🌿',
      'mint': '今天适合保持轻盈，新的想法会从舒服的状态里出现 🍃',
      'emerald': '今天很适合展现自信，你的存在感会特别鲜明 💚',
      'teal': '今天的语言会更有感染力，保持清爽、真诚和好心情 🩵',
      'turquoise': '今天的空气会特别清爽，保持你的好心情与阳光感 ☀️',
      'cyan': '今天适合把烦恼放轻一点，用清爽的能量迎接新的可能 🩵',
      'aqua': '今天让自己轻松一点，你会发现很多事情没有想象中复杂 💧',
      'blue': '今天的沟通会更顺，把你的冷静和可靠穿出来 💙',
      'navy': '今天适合把专业感穿出来，你的可靠会让人更愿意信任你 💙',
      'cobalt': '今天适合大胆表达，你的清晰会成为一种吸引力 💙',
      'sapphire': '今天保持专注，你的稳定感会让复杂的事情变得简单 💙',
      'powder blue': '今天适合温柔地表达自己，别人会更容易听见你的心意 🩵',
      'purple': '今天很适合发挥一点创意，让别人记住你的独特感 💜',
      'lavender': '今天适合保持柔软和想象力，一点灵感就能带来惊喜 💜',
      'lilac': '今天很适合尝试一点新鲜感，你的独特会被看见 💜',
      'mauve': '今天适合慢慢说、好好感受，你的细腻会成为优势 💜',
      'plum': '今天的你有一种低调但很有份量的魅力，稳稳地做自己 🍇',
      'brown': '今天的你自带稳重魅力，温柔又让人觉得很可靠 🤎',
      'camel': '今天适合展现成熟感，你的稳定会成为别人的安心来源 🤎',
      'chocolate': '今天的你很有温度，简单踏实的魅力特别耐看 🤎',
      'tan': '今天适合自然一点，越放松越能展现真实魅力 🤎',
      'beige': '今天适合轻松一点，简单干净的状态反而最耐看 🤍',
      'cream': '今天适合温柔地照顾自己，舒服本身就是一种高级感 🤍',
      'ivory': '今天像一个新的开始，保持轻盈，你会发现更多可能 🤍',
      'taupe': '今天适合保持平衡，低调但有质感的选择会特别加分 🤍',
      'white': '今天像一个新的开始，保持轻盈，你会发现更多可能 🤍',
      'soft white': '今天适合清清爽爽地开始，简单会带来意想不到的自信 🤍',
      'black': '今天适合把气场打开一点，你会比自己想象中更有力量 🖤',
      'charcoal': '今天适合保持专业与从容，低调也可以很有存在感 🖤',
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
    if (key.contains('blue') || key.contains('navy') || key.contains('cobalt') || key.contains('sapphire')) return exact['blue']!;
    if (key.contains('purple') || key.contains('lavender') || key.contains('lilac') || key.contains('mauve') || key.contains('plum')) return exact['purple']!;
    if (key.contains('brown') || key.contains('camel') || key.contains('chocolate') || key.contains('tan')) return exact['brown']!;
    if (key.contains('beige') || key.contains('cream') || key.contains('ivory') || key.contains('taupe')) return exact['beige']!;
    if (key.contains('white')) return exact['white']!;
    if (key.contains('black') || key.contains('charcoal')) return exact['black']!;
    if (key.contains('grey') || key.contains('gray')) return exact['grey']!;
    return '今天就穿上它，让属于你的颜色陪你完成一个好日子 ✨';
  }

  List<String> _paletteMatches(ColourAnalysisResult? result) {
    if (result == null || result.colours.isEmpty) return const [];
    final palette = result.colours.map(_normaliseColour).toSet();
    return _wardrobe.where((item) {
      final colour = _normaliseColour(item.colour);
      return palette.any((wanted) => wanted.contains(colour) || colour.contains(wanted));
    }).map((item) => item.id).toList();
  }

  Map<String, int> _scoreBreakdown(ColourAnalysisResult? result) {
    if (result == null) return const {'Appearance': 0, 'Behavior': 0, 'Communication': 0, 'Digital Etiquette': 0};
    final paletteMatchPoints = (_paletteMatches(result).length * 2).clamp(0, 10).toInt();
    final wardrobePoints = (_wardrobe.length * 2).clamp(0, 10).toInt();
    final appearance = (20 + paletteMatchPoints + wardrobePoints).clamp(0, 40).toInt();
    final behaviour = (_challengeHistory.length.clamp(0, 15) + (_challengeStreak * 2).clamp(0, 10)).clamp(0, 25).toInt();
    final styles = (_stylePrefs?['styles'] as List?)?.length ?? 0;
    final preferences = (_stylePrefs?['preferences'] as List?)?.length ?? 0;
    final communication = (8 + (styles * 2) + (preferences * 2)).clamp(0, 20).toInt();
    final profilePhotoPoints = _photoUrl?.isNotEmpty == true ? 3 : 0;
    final digital = (profilePhotoPoints + (_digitalChallengeCount * 3).clamp(0, 9) + (_challengeStreak > 0 ? 3 : 0)).clamp(0, 15).toInt();
    return {'Appearance': appearance, 'Behavior': behaviour, 'Communication': communication, 'Digital Etiquette': digital};
  }

  int _styleScore(ColourAnalysisResult? result) => _scoreBreakdown(result).values.fold(0, (sum, value) => sum + value).clamp(0, 100).toInt();

  String _scoreLabel(int score) {
    if (score >= 90) return 'Signature ready';
    if (score >= 75) return 'Well styled';
    if (score >= 55) return 'Good foundation';
    if (score >= 35) return 'Building your style';
    return 'Start your style journey';
  }

  String _scoreNextStep(Map<String, int> breakdown) {
    final lowest = breakdown.entries.reduce((a, b) => a.value <= b.value ? a : b).key;
    switch (lowest) {
      case 'Appearance':
        return 'Add wardrobe pieces that match your personal palette and complete your colour analysis.';
      case 'Behavior':
        return 'Complete today\'s challenge and build a daily confidence habit.';
      case 'Communication':
        return 'Set your style preferences so TiB can understand how you like to present yourself.';
      default:
        return 'Complete a digital-presence challenge and keep your profile image professional and consistent.';
    }
  }

  Future<void> _showStyleScoreDetails(ColourAnalysisResult? result) async {
    final breakdown = _scoreBreakdown(result);
    final total = breakdown.values.fold(0, (sum, value) => sum + value).clamp(0, 100).toInt();
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [const Expanded(child: Text('Your Style Score', style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900))), Text('$total/100', style: const TextStyle(color: AppColors.primaryDark, fontSize: 17, fontWeight: FontWeight.w900))]),
            const SizedBox(height: 6),
            const Text('Built around TiB\'s Appearance, Behavior, Communication and Digital Etiquette direction.', style: TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.4)),
            const SizedBox(height: 20),
            ..._scoreDetailRows(breakdown),
            const SizedBox(height: 2),
            Container(padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: AppColors.lavenderMist, borderRadius: BorderRadius.circular(18)), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [const Icon(Icons.lightbulb_outline_rounded, color: AppColors.primaryDark), const SizedBox(width: 10), Expanded(child: Text(_scoreNextStep(breakdown), style: const TextStyle(fontSize: 12, height: 1.4, fontWeight: FontWeight.w600)))])),
          ]),
        ),
      ),
    );
  }

  List<Widget> _scoreDetailRows(Map<String, int> breakdown) {
    const maxValues = {'Appearance': 40, 'Behavior': 25, 'Communication': 20, 'Digital Etiquette': 15};
    const descriptions = {'Appearance': 'Colour harmony, wardrobe readiness and palette matches.', 'Behavior': 'Consistency with confidence and professional daily habits.', 'Communication': 'Your saved style direction and personal preferences.', 'Digital Etiquette': 'Professional digital presence and digital habits.'};
    return breakdown.entries.map((entry) {
      final max = maxValues[entry.key] ?? 100;
      return Padding(padding: const EdgeInsets.only(bottom: 16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Expanded(child: Text(entry.key, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800))), Text('${entry.value}/$max', style: const TextStyle(color: AppColors.primaryDark, fontSize: 12, fontWeight: FontWeight.w800))]), const SizedBox(height: 5), ClipRRect(borderRadius: BorderRadius.circular(99), child: LinearProgressIndicator(value: max == 0 ? 0 : entry.value / max, minHeight: 7, backgroundColor: AppColors.border, color: AppColors.primary)), const SizedBox(height: 5), Text(descriptions[entry.key] ?? '', style: const TextStyle(color: AppColors.textSecondary, fontSize: 10.5, height: 1.35))]));
    }).toList();
  }

  Future<void> _completeChallenge() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || _challengeCompleted) return;
    final now = DateTime.now();
    final id = _challengeId(now);
    final challenge = _dailyChallenges[id];
    final dateKey = _dateKey(now);
    final entry = <String, dynamic>{'date': dateKey, 'challengeId': id, 'title': challenge.title, 'category': challenge.category, 'completedAt': DateTime.now().toIso8601String()};
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).set({'dailyChallengeDate': dateKey, 'dailyChallengeId': id, 'dailyChallengeCategory': challenge.category, 'dailyChallengeCompleted': true, 'dailyChallengeHistory': FieldValue.arrayUnion([entry])}, SetOptions(merge: true));
      if (!mounted) return;
      final updated = [..._challengeHistory, entry];
      setState(() {
        _challengeCompleted = true;
        _challengeHistory = updated;
        _challengeStreak = _calculateStreak(updated, now);
        _digitalChallengeCount = updated.where((e) => e['category'] == 'Digital Etiquette').length;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Nice work — ${challenge.title} is complete! +10 XP ✨')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not save your challenge progress. Please try again.')));
    }
  }

  Future<void> _showChallengeDetails(ColourAnalysisResult? result) async {
    final challenge = _dailyChallenges[_challengeId(DateTime.now())];
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: AppColors.background,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [Container(width: 46, height: 46, decoration: const BoxDecoration(color: AppColors.lavenderMist, shape: BoxShape.circle), child: Icon(challenge.icon, color: AppColors.primaryDark)), const SizedBox(width: 11), Expanded(child: Text(challenge.title, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900)))]),
            const SizedBox(height: 7),
            Text(challenge.category.toUpperCase(), style: const TextStyle(color: AppColors.primaryDark, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: .8)),
            const SizedBox(height: 13),
            Text(challenge.description, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5, height: 1.45)),
            const SizedBox(height: 12),
            Container(padding: const EdgeInsets.all(13), decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(15), border: Border.all(color: AppColors.border)), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [const Icon(Icons.lightbulb_outline_rounded, color: AppColors.primaryDark, size: 20), const SizedBox(width: 9), Expanded(child: Text(challenge.howTo, style: const TextStyle(fontSize: 11.5, height: 1.4, fontWeight: FontWeight.w600)))])),
            const SizedBox(height: 15),
            if (result == null) const Text('Complete your colour analysis first to personalise this challenge.', style: TextStyle(color: AppColors.textMuted, fontSize: 10.5)) else SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: _challengeCompleted ? null : () { Navigator.pop(sheetContext); _completeChallenge(); }, icon: Icon(_challengeCompleted ? Icons.check_rounded : Icons.auto_awesome_rounded), label: Text(_challengeCompleted ? 'Completed today' : 'Mark as complete'))),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final result = context.watch<AnalysisProvider>().result;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: _load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            children: [
              _header(result),
              const SizedBox(height: 18),
              _seasonHero(result),
              const SizedBox(height: 12),
              _todayColour(result),
              const SizedBox(height: 12),
              _styleScoreCard(result),
              const SizedBox(height: 12),
              _challenge(result),
              const SizedBox(height: 12),
              _recentReport(result),
              const SizedBox(height: 20),
              _wardrobePreview(),
              const SizedBox(height: 20),
              _quickActions(result),
              const SizedBox(height: 8),
              if (!_premium) _upgradeHint(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(ColourAnalysisResult? result) {
    final hour = DateTime.now().hour;
    final greeting = hour < 12 ? 'Good morning' : hour < 18 ? 'Good afternoon' : 'Good evening';
    final name = _name.isEmpty ? 'there' : _name;
    return Row(children: [CircleAvatar(radius: 25, backgroundColor: AppColors.primarySoft, backgroundImage: _photoUrl?.isNotEmpty == true ? CachedNetworkImageProvider(_photoUrl!) : null, child: _photoUrl?.isNotEmpty == true ? null : const Icon(Icons.person_rounded, color: AppColors.primaryDark)), const SizedBox(width: 11), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(greeting, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)), const SizedBox(height: 1), Text('$greeting, $name! ✨', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -.5)), const SizedBox(height: 1), Text(result == null ? 'Let’s make today feel more like you.' : '${result.season} • ${result.undertone}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 11))])), _iconButton(Icons.notifications_none_rounded, () {}), const SizedBox(width: 7), _iconButton(Icons.logout_rounded, _confirmLogout)]);
  }

  Widget _iconButton(IconData icon, VoidCallback onTap) => Material(color: AppColors.surface, shape: const CircleBorder(), child: InkWell(customBorder: const CircleBorder(), onTap: onTap, child: SizedBox(width: 44, height: 44, child: Icon(icon, color: AppColors.primaryDark))));

  Widget _seasonHero(ColourAnalysisResult? result) {
    if (result == null) {
      return _card(onTap: () => _open(const AnalysisScreen()), child: Container(padding: const EdgeInsets.all(18), decoration: BoxDecoration(gradient: AppGradients.primary, borderRadius: BorderRadius.circular(22)), child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('YOUR COLOUR SEASON', style: TextStyle(color: Colors.white70, fontSize: 9.5, fontWeight: FontWeight.w800, letterSpacing: 1)), SizedBox(height: 8), Text('Discover your season', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)), SizedBox(height: 5), Text('Take the guided face scan to unlock your personal colour profile.', style: TextStyle(color: Colors.white70, fontSize: 11.5, height: 1.35)), SizedBox(height: 14), _HeroPill(label: 'Start Colour Analysis')]));
    }
    final accent = AppColors.seasonAccent(result.season);
    return _card(onTap: () => _open(AnalysisResultScreen(result: result)), child: Container(padding: const EdgeInsets.fromLTRB(18, 16, 16, 15), decoration: BoxDecoration(gradient: LinearGradient(colors: [Color.lerp(AppColors.primary, accent, .18)!, Color.lerp(AppColors.primaryDark, accent, .34)!], begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: BorderRadius.circular(22)), child: Row(children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Row(children: [Text('YOUR COLOUR SEASON', style: TextStyle(color: Colors.white70, fontSize: 9.5, fontWeight: FontWeight.w800, letterSpacing: .8)), SizedBox(width: 7), _MiniTag(label: 'PERSONALISED')]), const SizedBox(height: 8), Text(result.season, style: const TextStyle(color: Colors.white, fontSize: 25, fontWeight: FontWeight.w800)), const SizedBox(height: 2), Text('${result.undertone} • ${result.brightness} • ${result.contrast}', style: const TextStyle(color: Colors.white70, fontSize: 11.5)), const SizedBox(height: 12), Row(children: result.colours.take(7).map((name) => Padding(padding: const EdgeInsets.only(right: 5), child: ColourSwatch(name: name, size: 25))).toList())])), const SizedBox(width: 4), const Icon(Icons.chevron_right_rounded, color: Colors.white70, size: 22)])));
  }

  Widget _todayColour(ColourAnalysisResult? result) {
    final name = _todayColourName(result);
    final message = _todayColourMessage(name);
    final date = DateTime.now();
    return _card(onTap: result == null ? () => _open(const AnalysisScreen()) : () => _open(AnalysisResultScreen(result: result)), child: Container(padding: const EdgeInsets.fromLTRB(16, 15, 16, 16), decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(19), border: Border.all(color: AppColors.border)), child: result == null ? Row(children: [Container(width: 50, height: 50, decoration: const BoxDecoration(color: AppColors.primarySoft, shape: BoxShape.circle), child: const Icon(Icons.palette_outlined, color: AppColors.primaryDark)), const SizedBox(width: 11), const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text("TODAY'S COLOUR", style: TextStyle(color: AppColors.textMuted, fontSize: 9.5, fontWeight: FontWeight.w900, letterSpacing: .65)), SizedBox(height: 5), Text('Complete your colour analysis to unlock your daily shade.', style: TextStyle(color: AppColors.textSecondary, fontSize: 11, height: 1.35))]))]) : Row(crossAxisAlignment: CrossAxisAlignment.center, children: [ColourSwatch(name: name, size: 58, showLabel: false), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [const Text("TODAY'S COLOUR", style: TextStyle(color: AppColors.textMuted, fontSize: 9.5, fontWeight: FontWeight.w900, letterSpacing: .65)), const Spacer(), Text('${date.day}/${date.month}', style: const TextStyle(color: AppColors.textMuted, fontSize: 9.5, fontWeight: FontWeight.w700))]), const SizedBox(height: 3), Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)), const SizedBox(height: 4), const Text('From your personal best-colour palette', style: TextStyle(color: AppColors.primaryDark, fontSize: 10, fontWeight: FontWeight.w700)), const SizedBox(height: 4), Text(message, style: const TextStyle(color: AppColors.textSecondary, fontSize: 10.8, height: 1.35))])), const SizedBox(width: 5), const Icon(Icons.chevron_right_rounded, color: AppColors.primary, size: 19)]))));
  }

  Widget _styleScoreCard(ColourAnalysisResult? result) {
    final score = _styleScore(result);
    final breakdown = _scoreBreakdown(result);
    return _card(onTap: () => _showStyleScoreDetails(result), child: Container(padding: const EdgeInsets.fromLTRB(16, 15, 16, 15), decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(19), border: Border.all(color: AppColors.border)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [const Text('STYLE SCORE', style: TextStyle(color: AppColors.textMuted, fontSize: 9.5, fontWeight: FontWeight.w900, letterSpacing: .65)), const Spacer(), Text(_scoreLabel(score), style: const TextStyle(color: AppColors.primaryDark, fontSize: 10.5, fontWeight: FontWeight.w800)), const SizedBox(width: 4), const Icon(Icons.chevron_right_rounded, color: AppColors.primary, size: 18)]), const SizedBox(height: 10), Row(crossAxisAlignment: CrossAxisAlignment.end, children: [Text('$score', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, height: .95)), const Padding(padding: EdgeInsets.only(left: 3, bottom: 2), child: Text('/100', style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w700))), const Spacer(), SizedBox(width: 62, height: 38, child: CustomPaint(painter: _ScorePainter(score / 100)))]), const SizedBox(height: 9), ClipRRect(borderRadius: BorderRadius.circular(99), child: LinearProgressIndicator(value: score / 100, minHeight: 6, backgroundColor: AppColors.border, color: AppColors.primary)), const SizedBox(height: 10), Row(children: [_ScoreMini(label: 'A', value: breakdown['Appearance'] ?? 0, max: 40), const SizedBox(width: 5), _ScoreMini(label: 'B', value: breakdown['Behavior'] ?? 0, max: 25), const SizedBox(width: 5), _ScoreMini(label: 'C', value: breakdown['Communication'] ?? 0, max: 20), const SizedBox(width: 5), _ScoreMini(label: 'D', value: breakdown['Digital Etiquette'] ?? 0, max: 15)]), const SizedBox(height: 7), const Text('Tap to see your Appearance · Behavior · Communication · Digital Etiquette breakdown.', style: TextStyle(color: AppColors.textSecondary, fontSize: 9.8, height: 1.35))]));
  }

  Widget _challenge(ColourAnalysisResult? result) {
    final challenge = _dailyChallenges[_challengeId(DateTime.now())];
    return InkWell(onTap: () => _showChallengeDetails(result), borderRadius: BorderRadius.circular(19), child: Container(padding: const EdgeInsets.fromLTRB(15, 14, 15, 14), decoration: BoxDecoration(gradient: const LinearGradient(colors: [AppColors.lavenderMist, AppColors.background], begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: BorderRadius.circular(19), border: Border.all(color: AppColors.border)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Container(width: 42, height: 42, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle), child: Icon(challenge.icon, color: AppColors.primaryDark)), const SizedBox(width: 10), const Expanded(child: Text("TODAY'S CHALLENGE", style: TextStyle(color: AppColors.primaryDark, fontSize: 9.5, fontWeight: FontWeight.w900, letterSpacing: .7))), if (_challengeStreak > 0) ...[const Icon(Icons.local_fire_department_rounded, color: AppColors.premiumAccent, size: 16), const SizedBox(width: 2), Text('$_challengeStreak day', style: const TextStyle(color: AppColors.primaryDark, fontSize: 9.5, fontWeight: FontWeight.w800))]]), const SizedBox(height: 10), Row(children: [Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppRadius.full)), child: Text(challenge.category, style: const TextStyle(color: AppColors.primaryDark, fontSize: 9, fontWeight: FontWeight.w800))), const Spacer(), const Text('+10 XP', style: TextStyle(color: AppColors.textMuted, fontSize: 9.5, fontWeight: FontWeight.w800))]), const SizedBox(height: 8), Text(challenge.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)), const SizedBox(height: 4), Text(challenge.description, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11, height: 1.38)), const SizedBox(height: 11), SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: result == null || _challengeCompleted ? null : _completeChallenge, icon: Icon(_challengeCompleted ? Icons.check_rounded : Icons.auto_awesome_rounded, size: 17), label: Text(_challengeCompleted ? 'Completed today' : 'Accept today\'s challenge'), style: FilledButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, disabledBackgroundColor: AppColors.primarySoft, disabledForegroundColor: AppColors.primaryDark, minimumSize: const Size.fromHeight(44), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13))))), if (result == null) const Padding(padding: EdgeInsets.only(top: 7), child: Text('Complete your colour analysis first to unlock personalised daily challenges.', style: TextStyle(color: AppColors.textMuted, fontSize: 10)))])));
  }

  Widget _recentReport(ColourAnalysisResult? result) {
    return _card(onTap: result == null ? () => _open(const AnalysisScreen()) : () => _open(AnalysisResultScreen(result: result)), child: Padding(padding: const EdgeInsets.fromLTRB(15, 12, 12, 12), child: Row(children: [const Icon(Icons.picture_as_pdf_outlined, color: AppColors.primaryDark, size: 22), const SizedBox(width: 10), const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Recent Report', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)), SizedBox(height: 3), Text('Your latest colour analysis report', style: TextStyle(color: AppColors.textSecondary, fontSize: 10.5))])), const Text('View', style: TextStyle(color: AppColors.primaryDark, fontWeight: FontWeight.w800, fontSize: 11))]));
  }

  Widget _wardrobePreview() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [const Expanded(child: Text('My Wardrobe', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800))), TextButton(onPressed: () => _open(const WardrobeScreen()), child: const Text('View all'))]), const SizedBox(height: 3), Text('${_wardrobe.length} pieces • ${_wardrobe.where((item) => item.isFavourite).length} favourites', style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)), const SizedBox(height: 10), SizedBox(height: 116, child: _wardrobe.isEmpty ? _emptyWardrobe() : ListView.separated(scrollDirection: Axis.horizontal, itemCount: _wardrobe.take(5).length, separatorBuilder: (_, index) => const SizedBox(width: 9), itemBuilder: (_, index) => _wardrobeCard(_wardrobe[index])))]);
  }

  Widget _wardrobeCard(WardrobeItem item) => InkWell(onTap: () => _open(const WardrobeScreen()), borderRadius: BorderRadius.circular(18), child: Ink(width: 94, decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.border)), child: Column(children: [Expanded(child: ClipRRect(borderRadius: const BorderRadius.vertical(top: Radius.circular(18)), child: item.imageUrl.isEmpty ? Container(color: AppColors.surfaceMuted, child: const Center(child: Icon(Icons.checkroom_outlined, color: AppColors.primary))) : CachedNetworkImage(imageUrl: item.imageUrl, width: double.infinity, fit: BoxFit.cover))), Padding(padding: const EdgeInsets.fromLTRB(7, 5, 7, 6), child: Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800)))])));

  Widget _emptyWardrobe() => _card(onTap: () => _open(const WardrobeScreen()), child: const Center(child: Padding(padding: EdgeInsets.all(18), child: Text('Add a few pieces and TiB will style from what you already own.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary, fontSize: 11.5, height: 1.35))));

  Widget _quickActions(ColourAnalysisResult? result) => Row(children: [Expanded(child: _quickTile(Icons.auto_awesome_rounded, 'Style Me', () => _open(const StyleMeScreen()))), const SizedBox(width: 9), Expanded(child: _quickTile(Icons.palette_outlined, 'Colours', () => _open(const AnalysisScreen()))), const SizedBox(width: 9), Expanded(child: _quickTile(Icons.tune_rounded, 'Preferences', () => _open(const StylePreferencesScreen())))]);

  Widget _quickTile(IconData icon, String label, VoidCallback onTap) => InkWell(onTap: onTap, borderRadius: BorderRadius.circular(18), child: Ink(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 13), decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.border)), child: Column(children: [Icon(icon, color: AppColors.primary, size: 20), const SizedBox(height: 6), Text(label, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800))])));

  Widget _upgradeHint() => Container(padding: const EdgeInsets.all(13), decoration: BoxDecoration(color: AppColors.lavenderMist, borderRadius: BorderRadius.circular(16)), child: const Row(children: [Icon(Icons.auto_awesome_rounded, color: AppColors.primaryDark, size: 18), SizedBox(width: 8), Expanded(child: Text('Unlock more personalised AI styling with TiB Premium.', style: TextStyle(fontSize: 10.8, height: 1.3, fontWeight: FontWeight.w600)))]));

  Widget _card({required Widget child, VoidCallback? onTap}) => Material(color: AppColors.surface, borderRadius: BorderRadius.circular(18), child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(18), child: child));

  Future<void> _confirmLogout() async {
    final shouldLogout = await showDialog<bool>(context: context, builder: (dialogContext) => AlertDialog(title: const Text('Logout'), content: const Text('You can sign in again anytime with your account.'), actions: [TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Logout'))]));
    if (shouldLogout == true) await _logout();
  }

  Future<void> _logout() async {
    try {
      await FirebaseAuth.instance.signOut();
      if (!mounted) return;
      context.read<AnalysisProvider>().clear();
      Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginScreen()), (route) => false);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Logout failed. Please try again.')));
    }
  }

  Future<void> _open(Widget page) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => page));
    if (mounted) _load();
  }
}

class _DailyChallenge {
  final String category;
  final String title;
  final String description;
  final String howTo;
  final IconData icon;
  const _DailyChallenge(this.category, this.title, this.description, this.howTo, this.icon);
}

class _ScoreMini extends StatelessWidget {
  final String label;
  final int value;
  final int max;
  const _ScoreMini({required this.label, required this.value, required this.max});
  @override
  Widget build(BuildContext context) {
    return Expanded(child: Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 6), decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)), child: Row(children: [Container(width: 18, height: 18, decoration: const BoxDecoration(color: AppColors.primarySoft, shape: BoxShape.circle), child: Center(child: Text(label, style: const TextStyle(color: AppColors.primaryDark, fontSize: 9, fontWeight: FontWeight.w900)))), const SizedBox(width: 5), Expanded(child: Text('$value/$max', style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800), overflow: TextOverflow.ellipsis))])));
  }
}

class _HeroPill extends StatelessWidget {
  final String label;
  const _HeroPill({required this.label});
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), decoration: BoxDecoration(color: Colors.white.withValues(alpha: .16), borderRadius: BorderRadius.circular(AppRadius.full)), child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w800)));
}

class _MiniTag extends StatelessWidget {
  final String label;
  const _MiniTag({required this.label});
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4), decoration: BoxDecoration(color: AppColors.eggYolk, borderRadius: BorderRadius.circular(AppRadius.full)), child: Text(label, style: const TextStyle(color: AppColors.primaryDark, fontSize: 8, fontWeight: FontWeight.w800)));
}

class _ScorePainter extends CustomPainter {
  final double progress;
  _ScorePainter(this.progress);
  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.height * .25;
    final rect = Rect.fromLTWH(stroke, stroke, size.width - stroke * 2, size.height - stroke * 2);
    final bg = Paint()..color = AppColors.border..style = PaintingStyle.stroke..strokeWidth = stroke..strokeCap = StrokeCap.round;
    final fg = Paint()..color = AppColors.primary..style = PaintingStyle.stroke..strokeWidth = stroke..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, 3.4, 5.75, false, bg);
    canvas.drawArc(rect, 3.4, 5.75 * progress.clamp(0, 1), false, fg);
  }
  @override
  bool shouldRepaint(covariant _ScorePainter oldDelegate) => oldDelegate.progress != progress;
}
