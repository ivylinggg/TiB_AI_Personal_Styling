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
  final TextEditingController _ratingComment = TextEditingController();
  final ScrollController _scroll = ScrollController();
  bool _sending = false;
  bool _ratingSending = false;

  @override
  void initState() {
    super.initState();
    _prepareConversation();
  }

  Future<void> _prepareConversation() async {
    final uid = LiveConsultancyService.currentUid;
    if (uid == null) return;
    try {
      await LiveConsultancyService.ensureConversation();
      await LiveConsultancyService.markMessagesRead(uid, by: 'customer');
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('We could not prepare your consultation. Please try again.')),
        );
      }
    }
  }

  @override
  void dispose() {
    _composer.dispose();
    _ratingComment.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _composer.text.trim();
    if (text.isEmpty || text.length > 1500 || _sending) return;
    final uid = LiveConsultancyService.currentUid;
    setState(() {
      _sending = true;
      _composer.clear();
    });
    try {
      await LiveConsultancyService.sendUserMessage(text);
      if (uid != null) {
        await LiveConsultancyService.markMessagesRead(uid, by: 'customer');
      }
      if (!mounted || !_scroll.hasClients) return;
      await _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not send the message. Please try again.')),
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

  String _responseLabel(int? seconds) {
    if (seconds == null) return 'Response time will appear after the first reply';
    if (seconds < 60) return 'First response: ${seconds}s';
    final minutes = seconds ~/ 60;
    return 'First response: $minutes min${minutes == 1 ? '' : 's'}';
  }

  Future<void> _rate(int rating) async {
    if (_ratingSending) return;
    setState(() => _ratingSending = true);
    try {
      await LiveConsultancyService.rateConsultant(
        rating: rating,
        comment: _ratingComment.text,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Thank you for rating your consultation.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save your rating. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _ratingSending = false);
    }
  }

  void _scrollToLatest(int count) {
    if (count == 0) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      }
    });
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
          final unread = (data?['unreadForUser'] as num?)?.toInt() ?? 0;
          final responseSeconds = (data?['responseTimeSeconds'] as num?)?.toInt();
          final rating = (data?['rating'] as num?)?.toInt();
          final waiting = status == 'waiting_for_consultant' || status == 'open';

          return Column(
            children: [
              if (conversationSnapshot.hasError)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: .06),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.error.withValues(alpha: .15)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.cloud_off_rounded, color: AppColors.error, size: 18),
                        SizedBox(width: 8),
                        Expanded(child: Text('We could not sync your consultation right now. You can try again shortly.', style: TextStyle(fontSize: 11, color: AppColors.textSecondary))),
                      ],
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 390;
                    return Container(
                      padding: const EdgeInsets.all(13),
                      decoration: BoxDecoration(
                        color: AppColors.secondary.withValues(alpha: .5),
                        borderRadius: BorderRadius.circular(17),
                        border: Border.all(color: AppColors.primary.withValues(alpha: .12)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.circle, size: 9, color: conversationSnapshot.connectionState == ConnectionState.waiting ? AppColors.textMuted : AppColors.primary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(consultantName ?? _statusLabel(status), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                                const SizedBox(height: 3),
                                Text(
                                  _statusLabel(status),
                                  maxLines: compact ? 2 : 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                          if (unread > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                              decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(10)),
                              child: Text('$unread new', style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800)),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              if (responseSeconds != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 8),
                  child: Align(alignment: Alignment.centerLeft, child: Text(_responseLabel(responseSeconds), style: const TextStyle(fontSize: 10.5, color: AppColors.textMuted))),
                ),
              if (waiting)
                const Padding(
                  padding: EdgeInsets.fromLTRB(18, 0, 18, 7),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Send one clear question and a consultant can pick it up from here.', style: TextStyle(fontSize: 10.5, color: AppColors.textMuted)),
                  ),
                ),
              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: LiveConsultancyService.messagesStream(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.chat_bubble_outline_rounded, size: 38, color: AppColors.textMuted),
                              const SizedBox(height: 10),
                              const Text('Unable to load your consultation.', textAlign: TextAlign.center),
                              const SizedBox(height: 6),
                              const Text('Please check your connection and try again.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary)),
                              const SizedBox(height: 14),
                              OutlinedButton.icon(
                                onPressed: _prepareConversation,
                                icon: const Icon(Icons.refresh_rounded),
                                label: const Text('Try again'),
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                    if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                    final messages = snapshot.data!.docs;
                    _scrollToLatest(messages.length);
                    if (messages.isEmpty) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(35),
                          child: Text('Your consultation is ready.\nSend your question and our TiB consultancy team will take it from there.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary, height: 1.5)),
                        ),
                      );
                    }
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
                            constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * .78),
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
                                  Text(message['senderName'] as String? ?? 'TiB Consultant', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.primary)),
                                  const SizedBox(height: 3),
                                ],
                                Text(message['text'] as String? ?? '', style: TextStyle(fontSize: 12.5, height: 1.4, color: consultant ? AppColors.textPrimary : Colors.white)),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              if (status == 'resolved' && rating == null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('How was your consultation?', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                        const SizedBox(height: 5),
                        TextField(controller: _ratingComment, maxLines: 2, maxLength: 500, decoration: const InputDecoration(hintText: 'Optional feedback', isDense: true, counterText: '')),
                        const SizedBox(height: 7),
                        LayoutBuilder(
                          builder: (context, constraints) => Wrap(
                            alignment: WrapAlignment.start,
                            spacing: constraints.maxWidth < 300 ? 0 : 4,
                            children: List.generate(
                              5,
                              (index) => IconButton(
                                onPressed: _ratingSending ? null : () => _rate(index + 1),
                                tooltip: '${index + 1} star${index == 0 ? '' : 's'}',
                                icon: const Icon(Icons.star_border_rounded),
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(15, 7, 15, 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _composer,
                          minLines: 1,
                          maxLines: 4,
                          maxLength: 1500,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _send(),
                          decoration: InputDecoration(
                            hintText: 'Message your consultant…',
                            counterText: '',
                            filled: true,
                            fillColor: AppColors.surface,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: AppColors.border)),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: AppColors.border)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Semantics(
                        button: true,
                        label: _sending ? 'Sending message' : 'Send message',
                        child: Material(
                          color: _sending ? AppColors.primary.withValues(alpha: .5) : AppColors.primary,
                          borderRadius: BorderRadius.circular(18),
                          child: InkWell(
                            onTap: _sending ? null : _send,
                            borderRadius: BorderRadius.circular(18),
                            child: SizedBox(
                              width: 50,
                              height: 52,
                              child: _sending
                                  ? const Padding(padding: EdgeInsets.all(17), child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                  : const Icon(Icons.send_rounded, color: Colors.white),
                            ),
                          ),
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
