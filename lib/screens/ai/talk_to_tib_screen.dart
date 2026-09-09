import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../services/talk_to_tib_bot_service.dart';
import 'ai_stylist_screen.dart';
import 'live_consultancy_screen.dart';

class TalkToTibScreen extends StatefulWidget {
  const TalkToTibScreen({super.key});

  @override
  State<TalkToTibScreen> createState() => _TalkToTibScreenState();
}

class _TalkToTibScreenState extends State<TalkToTibScreen> {
  final TextEditingController _composer = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final List<_ChatMessage> _messages = [
    const _ChatMessage(
      text: 'Hi! I’m VYEA. Ask me about your colours, wardrobe, proportions or what to wear next.',
      fromUser: false,
    ),
  ];
  bool _sending = false;

  static const _prompts = [
    'What colours suit me?',
    'Style my wardrobe for work',
    'What suits my proportions?',
    'Build me a date look',
  ];

  @override
  void dispose() {
    _composer.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send([String? preset]) async {
    final text = (preset ?? _composer.text).trim();
    if (text.isEmpty || _sending) return;

    _composer.clear();
    FocusScope.of(context).unfocus();
    setState(() {
      _messages.add(_ChatMessage(text: text, fromUser: true));
      _sending = true;
    });
    _scrollToBottom();

    final reply = await TalkToTibBotService.reply(text);

    if (!mounted) return;
    setState(() {
      _messages.add(
        _ChatMessage(
          text: reply.text,
          fromUser: false,
          aiGenerated: reply.isAiGenerated,
          escalated: reply.shouldEscalate,
        ),
      );
      _sending = false;
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
      );
    });
  }

  void _openLiveConsultancy() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LiveConsultancyScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: 20,
        title: const Row(
          children: [
            Text(
              'VYEA',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 2.8,
                color: AppColors.brown,
              ),
            ),
            SizedBox(width: 9),
            Text(
              'Talk to VYEA',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 10),
            child: _availabilityCard(),
          ),
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(20, 7, 20, 16),
              itemCount: _messages.length,
              itemBuilder: (_, index) => _messageBubble(_messages[index]),
            ),
          ),
          _quickPrompts(),
          _composerArea(),
        ],
      ),
    );
  }

  Widget _availabilityCard() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.primaryDark,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: const BoxDecoration(
              color: AppColors.peach,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              color: AppColors.primaryDark,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PERSONAL STYLE CHAT',
                  style: TextStyle(
                    color: AppColors.peach,
                    fontSize: 8.8,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.15,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Ask first. Style when you’re ready.',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'VYEA can now use your saved styling context when it is available.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 10.5,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .10),
              borderRadius: BorderRadius.circular(9),
            ),
            child: const Text(
              'AI',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 7.5,
                fontWeight: FontWeight.w900,
                letterSpacing: .7,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _messageBubble(_ChatMessage message) {
    final isUser = message.fromUser;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 340),
        margin: const EdgeInsets.only(bottom: 11),
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
        decoration: BoxDecoration(
          color: isUser ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(19),
            topRight: const Radius.circular(19),
            bottomLeft: Radius.circular(isUser ? 19 : 7),
            bottomRight: Radius.circular(isUser ? 7 : 19),
          ),
          border: isUser ? null : Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isUser)
              Row(
                children: [
                  const Text(
                    'VYEA',
                    style: TextStyle(
                      color: AppColors.brown,
                      fontSize: 8.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.1,
                    ),
                  ),
                  if (message.aiGenerated) ...[
                    const SizedBox(width: 7),
                    const Text(
                      'PERSONALISED',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 7.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: .8,
                      ),
                    ),
                  ],
                ],
              ),
            if (!isUser) const SizedBox(height: 5),
            Text(
              message.text,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.47,
                color: isUser ? Colors.white : AppColors.textPrimary,
              ),
            ),
            if (message.escalated) ...[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _openLiveConsultancy,
                icon: const Icon(Icons.support_agent_rounded, size: 16),
                label: const Text('Chat with a Live Consultant'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primarySoft),
                  padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
                  visualDensity: VisualDensity.compact,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _quickPrompts() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border.withValues(alpha: .7))),
      ),
      child: SizedBox(
        height: 36,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: _prompts.length,
          separatorBuilder: (_, __) => const SizedBox(width: 7),
          itemBuilder: (_, index) => ActionChip(
            label: Text(
              _prompts[index],
              style: const TextStyle(fontSize: 9.7, fontWeight: FontWeight.w700),
            ),
            onPressed: _sending ? null : () => _send(_prompts[index]),
            side: const BorderSide(color: AppColors.border),
            backgroundColor: AppColors.background,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      ),
    );
  }

  Widget _composerArea() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _openLiveConsultancy,
                icon: const Icon(Icons.support_agent_rounded, size: 18),
                label: const Text('Chat with a Live Consultant'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primarySoft),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _composer,
                    minLines: 1,
                    maxLines: 3,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _send(),
                    decoration: InputDecoration(
                      hintText: 'Ask VYEA anything…',
                      filled: true,
                      fillColor: AppColors.background,
                      prefixIcon: const Icon(Icons.edit_note_rounded, size: 18),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(17),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(17),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(17),
                        borderSide: const BorderSide(color: AppColors.brown, width: 1.2),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Material(
                  color: _sending ? AppColors.primary.withValues(alpha: .45) : AppColors.primary,
                  borderRadius: BorderRadius.circular(17),
                  child: InkWell(
                    onTap: _sending ? null : _send,
                    borderRadius: BorderRadius.circular(17),
                    child: SizedBox(
                      width: 50,
                      height: 52,
                      child: Icon(
                        _sending ? Icons.hourglass_top_rounded : Icons.arrow_upward_rounded,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            TextButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AIStylistScreen()),
              ),
              icon: const Icon(Icons.auto_awesome_rounded, size: 15),
              label: const Text('Build a wardrobe look with VYEA'),
              style: TextButton.styleFrom(foregroundColor: AppColors.brown),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatMessage {
  final String text;
  final bool fromUser;
  final bool aiGenerated;
  final bool escalated;

  const _ChatMessage({
    required this.text,
    required this.fromUser,
    this.aiGenerated = false,
    this.escalated = false,
  });
}
