import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../services/live_consultancy_service.dart';

class LiveConsultancyScreen extends StatefulWidget {
  const LiveConsultancyScreen({super.key});

  @override
  State<LiveConsultancyScreen> createState() => _LiveConsultancyScreenState();
}

class _LiveConsultancyScreenState extends State<LiveConsultancyScreen> {
  final TextEditingController _composer = TextEditingController();
  final ScrollController _scroll = ScrollController();
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    LiveConsultancyService.ensureConversation();
  }

  @override
  void dispose() {
    _composer.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _composer.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    _composer.clear();
    try {
      await LiveConsultancyService.sendUserMessage(text);
      await Future<void>.delayed(const Duration(milliseconds: 80));
      if (mounted && _scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  String _statusLabel(String? status) {
    switch (status) {
      case 'waiting_for_consultant':
        return 'Waiting for a consultant';
      case 'assigned':
        return 'Consultant assigned';
      case 'consultant_replied':
        return 'Consultant replied';
      case 'resolved':
        return 'Consultation resolved';
      default:
        return 'Ready for consultation';
    }
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
            CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.secondary,
              child: Icon(Icons.support_agent_rounded, color: AppColors.primary, size: 21),
            ),
            SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Live Consultancy', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                Text('Real TiB consultant', style: TextStyle(fontSize: 10, color: AppColors.textMuted)),
              ],
            ),
          ],
        ),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: LiveConsultancyService.conversationStream(),
        builder: (context, conversationSnapshot) {
          final data = conversationSnapshot.data?.data();
          final status = data?['status'] as String?;
          final consultantName = data?['assignedConsultantName'] as String?;

          return Column(
            children: [
              Container(
                margin: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: AppColors.secondary.withValues(alpha: .5),
                  borderRadius: BorderRadius.circular(17),
                  border: Border.all(color: AppColors.primary.withValues(alpha: .12)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.support_agent_rounded, color: AppColors.primary, size: 19),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            consultantName ?? _statusLabel(status),
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            status == 'resolved'
                                ? 'This consultation has been closed. Start a new conversation by sending a message.'
                                : status == 'consultant_replied'
                                    ? 'Your TiB consultant has replied. You can continue the conversation below.'
                                    : 'Tell us what you need help with. A real TiB consultant can reply here.',
                            style: const TextStyle(fontSize: 11.5, height: 1.4, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: LiveConsultancyService.messagesStream(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return const Center(child: Text('Unable to load your consultation.'));
                    }
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final messages = snapshot.data!.docs;
                    if (messages.isEmpty) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(35),
                          child: Text(
                            'Your consultation is ready.\nSend your question and our TiB consultancy team will take it from there.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppColors.textSecondary, height: 1.5),
                          ),
                        ),
                      );
                    }
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (_scroll.hasClients) {
                        _scroll.jumpTo(_scroll.position.maxScrollExtent);
                      }
                    });
                    return ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
                      itemCount: messages.length,
                      itemBuilder: (_, index) {
                        final message = messages[index].data();
                        final consultant = message['senderType'] == 'consultant';
                        return Align(
                          alignment: consultant ? Alignment.centerLeft : Alignment.centerRight,
                          child: Container(
                            constraints: const BoxConstraints(maxWidth: 310),
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                            decoration: BoxDecoration(
                              color: consultant ? AppColors.surface : AppColors.primary,
                              borderRadius: BorderRadius.circular(17),
                              border: consultant ? Border.all(color: AppColors.border) : null,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (consultant) ...[
                                  Text(
                                    message['senderName'] as String? ?? 'TiB Consultant',
                                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.primary),
                                  ),
                                  const SizedBox(height: 3),
                                ],
                                Text(
                                  message['text'] as String? ?? '',
                                  style: TextStyle(fontSize: 12.5, height: 1.4, color: consultant ? AppColors.textPrimary : Colors.white),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(15, 7, 15, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _composer,
                          minLines: 1,
                          maxLines: 4,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _send(),
                          decoration: InputDecoration(
                            hintText: 'Message your consultant…',
                            filled: true,
                            fillColor: AppColors.surface,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: AppColors.border)),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: AppColors.border)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Material(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(18),
                        child: InkWell(
                          onTap: _sending ? null : _send,
                          borderRadius: BorderRadius.circular(18),
                          child: const SizedBox(width: 50, height: 52, child: Icon(Icons.send_rounded, color: Colors.white)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
