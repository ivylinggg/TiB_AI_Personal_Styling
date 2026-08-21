import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../models/colour_analysis_result.dart';
import '../../providers/analysis_provider.dart';
import '../../widgets/colour_swatch.dart';
import '../analysis/analysis_result_screen.dart';
import '../analysis/analysis_screen.dart';

class DashboardDesignedScreen extends StatelessWidget {
  const DashboardDesignedScreen({super.key});

  int _dayOfYear(DateTime date) {
    return date.difference(DateTime(date.year, 1, 1)).inDays + 1;
  }

  String _normaliseColour(String value) {
    return value.toLowerCase().replaceAll('-', ' ').replaceAll('_', ' ').trim();
  }

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
      'orange': '今天很适合主动一点，好事可能就在你开口以后发生 🧡',
      'apricot': '今天的气氛会轻松一点，带着你的亲和力走出去吧 🍑',
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

  @override
  Widget build(BuildContext context) {
    final result = context.watch<AnalysisProvider>().result;
    final todayColour = _todayColourName(result);
    final message = _todayColourMessage(todayColour);
    final userName = FirebaseAuth.instance.currentUser?.displayName?.trim();
    final greeting = userName?.isNotEmpty == true ? 'Hi, $userName' : 'Welcome back';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            final uid = FirebaseAuth.instance.currentUser?.uid;
            if (uid != null) {
              await context.read<AnalysisProvider>().loadLatestResult(uid);
            }
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
            children: [
              Text(greeting, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
              const SizedBox(height: 5),
              const Text('Your personal styling space', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              const SizedBox(height: 18),
              _todayColourCard(context, result, todayColour, message),
              const SizedBox(height: 14),
              _seasonCard(context, result),
            ],
          ),
        ),
      ),
    );
  }

  Widget _todayColourCard(
    BuildContext context,
    ColourAnalysisResult? result,
    String colour,
    String message,
  ) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          if (result == null) {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const AnalysisScreen()));
          } else {
            Navigator.push(context, MaterialPageRoute(builder: (_) => AnalysisResultScreen(result: result)));
          }
        },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 14, 17),
          child: result == null
              ? Row(
                  children: [
                    Container(
                      width: 58,
                      height: 58,
                      decoration: const BoxDecoration(color: AppColors.primarySoft, shape: BoxShape.circle),
                      child: const Icon(Icons.palette_outlined, color: AppColors.primaryDark, size: 27),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("TODAY'S COLOUR", style: TextStyle(color: AppColors.textMuted, fontSize: 9.5, fontWeight: FontWeight.w900, letterSpacing: .7)),
                          SizedBox(height: 5),
                          Text('Complete your colour analysis to unlock your daily colour.', style: TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.35)),
                        ],
                      ),
                    ),
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    ColourSwatch(name: colour, size: 62),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Expanded(child: Text("TODAY'S COLOUR", style: TextStyle(color: AppColors.textMuted, fontSize: 9.5, fontWeight: FontWeight.w900, letterSpacing: .7))),
                              Text('${DateTime.now().day}/${DateTime.now().month}', style: const TextStyle(color: AppColors.textMuted, fontSize: 9.5, fontWeight: FontWeight.w700)),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(colour, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
                          const SizedBox(height: 4),
                          const Text('From your personal best-colour palette', style: TextStyle(color: AppColors.primaryDark, fontSize: 10, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 5),
                          Text(message, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11, height: 1.4)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 5),
                    const Icon(Icons.chevron_right_rounded, color: AppColors.primary, size: 20),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _seasonCard(BuildContext context, ColourAnalysisResult? result) {
    if (result == null) {
      return Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AnalysisScreen())),
          child: const Padding(
            padding: EdgeInsets.all(17),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('YOUR COLOUR SEASON', style: TextStyle(color: AppColors.textMuted, fontSize: 9.5, fontWeight: FontWeight.w900, letterSpacing: .7)),
              SizedBox(height: 7),
              Text('Discover your season', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
              SizedBox(height: 5),
              Text('Start your face scan to unlock your personal colour profile.', style: TextStyle(color: AppColors.textSecondary, fontSize: 11.5, height: 1.35)),
            ]),
          ),
        ),
      );
    }

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AnalysisResultScreen(result: result))),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(17, 16, 14, 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Expanded(child: Text('YOUR COLOUR SEASON', style: TextStyle(color: AppColors.textMuted, fontSize: 9.5, fontWeight: FontWeight.w900, letterSpacing: .7))),
              const Text('PERSONALISED', style: TextStyle(color: AppColors.primaryDark, fontSize: 8.5, fontWeight: FontWeight.w900)),
            ]),
            const SizedBox(height: 7),
            Text(result.season, style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text('${result.undertone} • ${result.brightness} • ${result.contrast}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
            const SizedBox(height: 11),
            SizedBox(
              height: 42,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: result.colours.length > 7 ? 7 : result.colours.length,
                separatorBuilder: (_, __) => const SizedBox(width: 7),
                itemBuilder: (_, index) => ColourSwatch(name: result.colours[index], size: 42, showLabel: true),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
