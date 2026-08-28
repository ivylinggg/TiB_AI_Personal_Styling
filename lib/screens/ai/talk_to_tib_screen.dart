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
      text: 'Hi! I’m TiB 🤍 Ask me about your colours, body proportions, wardrobe or styling. If you want advice from a real stylist, you can also chat with a live consultant.',
      fromUser: false,
    ),
  ];
  bool _sending = false;

  static const _prompts = [
    'What colours suit me?',
    'How should I dress for work?',
    'Help me with my body proportions',
    'What can TiB do for me?',
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
    setState(() {
      _messages.add(_ChatMessage(text: text, fromUser: true));
      _sending = true;
    });
    _scrollToBottom();

    await Future<void>.delayed(const Duration(milliseconds: 350));
    final reply = TalkToTibBotService.automatedReply(text) ??
        'That’s a great question. I can help with styling, but for a recommendation that needs a human consultant’s judgement, tap “Chat with a Live Consultant” and our team can continue with you.';

    if (!mounted) return;
    setState(() {
      _messages.add(_ChatMessage(text: reply, fromUser: false));
      _sending = false;
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    });
  }

  void _openLiveConsultancy() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const LiveConsultancyScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: const Row(
          children: [
            CircleAvatar(backgroundColor: AppColors.secondary, child: Icon(Icons.auto_awesome_rounded, color: AppColors.primary)),
            SizedBox(width: 10),
            Text('Talk to TiB', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 3, 16, 10),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
                    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
                    child: const Row(
                      children: [
                        Icon(Icons.smart_toy_outlined, color: AppColors.primary, size: 18),
                        SizedBox(width: 8),
                        Expanded(child: Text('TiB automated assistant · Available now', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700))),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(16, 5, 16, 18),
              itemCount: _messages.length,
              itemBuilder: (_, index) {
                final message = _messages[index];
                return Align(
                  alignment: message.fromUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 325),
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                    decoration: BoxDecoration(
                      color: message.fromUser ? AppColors.primary : AppColors.surface,
                      borderRadius: BorderRadius.circular(17),
                      border: message.fromUser ? null : Border.all(color: AppColors.border),
                    ),
                    child: Text(message.text, style: TextStyle(fontSize: 12.5, height: 1.45, color: message.fromUser ? Colors.white : AppColors.textPrimary)),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 7),
            child: SizedBox(
              height: 36,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _prompts.length,
                separatorBuilder: (_, __) => const SizedBox(width: 7),
                itemBuilder: (_, index) => ActionChip(label: Text(_prompts[index], style: const TextStyle(fontSize: 10)), onPressed: _sending ? null : () => _send(_prompts[index]), side: const BorderSide(color: AppColors.border), backgroundColor: AppColors.surface),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(13, 9, 13, 8),
            decoration: BoxDecoration(color: AppColors.surface, border: Border(top: BorderSide(color: AppColors.border))),
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
                      style: OutlinedButton.styleFrom(foregroundColor: AppColors.primary, side: const BorderSide(color: AppColors.primarySoft), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)), padding: const EdgeInsets.symmetric(vertical: 10)),
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
                          decoration: InputDecoration(hintText: 'Ask TiB anything…', filled: true, fillColor: AppColors.background, border: OutlineInputBorder(borderRadius: BorderRadius.circular(17), borderSide: const BorderSide(color: AppColors.border)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(17), borderSide: const BorderSide(color: AppColors.border))),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Material(color: AppColors.primary, borderRadius: BorderRadius.circular(17), child: InkWell(onTap: _sending ? null : _send, borderRadius: BorderRadius.circular(17), child: const SizedBox(width: 50, height: 52, child: Icon(Icons.arrow_upward_rounded, color: Colors.white))),),
                    ],
                  ),
                  const SizedBox(height: 7),
                  TextButton.icon(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AIStylistScreen())), icon: const Icon(Icons.auto_awesome_rounded, size: 16), label: const Text('Ask TiB to build a wardrobe look'), style: TextButton.styleFrom(foregroundColor: AppColors.primary)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatMessage {
  final String text;
  final bool fromUser;

  const _ChatMessage({required this.text, required this.fromUser});
}
