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
      // The live stream will surface the error state when the connection fails.
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
    setState(() => _sending = true);
    _composer.clear();
    try {
      await LiveConsultancyService.sendUserMessage(text);
      final uid = LiveConsultancyService.currentUid;
      if (uid != null) {
        await LiveConsultancyService.markMessagesRead(uid, by: 'customer');
      }
      if (!mounted || !_scroll.hasClients) return;
      await _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not send message: $error')),
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
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save rating: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _ratingSending = false);
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
              child: Icon(
                Icons.support_agent_rounded,
                color: AppColors.primary,
                size: 21,
              ),
            ),
            SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Live Consultancy',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
                Text(
                  'Real TiB consultant',
                  style: TextStyle(fontSize: 10, color: AppColors.textMuted),
                ),
              ],
            ),
          ],
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 900;
          final contentWidth = wide ? 900.0 : constraints.maxWidth;
          return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: LiveConsultancyService.conversationStream(),
            builder: (context, conversationSnapshot) {
              final data = conversationSnapshot.data?.data();
              final status = data?['status'] as String?;
              final consultantName = data?['assignedConsultantName'] as String?;
              final unread = (data?['unreadForUser'] as num?)?.toInt() ?? 0;
              final responseSeconds = (data?['responseTimeSeconds'] as num?)?.toInt();
              final rating = (data?['rating'] as num?)?.toInt();
              final waiting = status == 'waiting_for_consultant' || status == 'open';

              return Center(
                child: SizedBox(
                  width: contentWidth,
                  child: Column(
                    children: [
                      if (conversationSnapshot.hasError)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                          child: _infoCard('We could not sync your consultation right now. You can try again shortly.'),
                        ),
                      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: LiveConsultancyService.onlineConsultantsStream(),
                        builder: (context, presenceSnapshot) {
                          final onlineCount = presenceSnapshot.data?.docs.length ?? 0;
                          final label = consultantName ?? _statusLabel(status);
                          return Semantics(
                            container: true,
                            liveRegion: true,
                            label: 'Consultation status: $label. $onlineCount consultants online.',
                            child: Container(
                              margin: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                              padding: const EdgeInsets.all(13),
                              decoration: BoxDecoration(
                                color: AppColors.secondary.withValues(alpha: .5),
                                borderRadius: BorderRadius.circular(17),
                                border: Border.all(color: AppColors.primary.withValues(alpha: .12)),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.circle, size: 9, color: onlineCount > 0 ? Colors.green : AppColors.textMuted),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                                        const SizedBox(height: 3),
                                        Text(
                                          onlineCount > 0
                                              ? '$onlineCount consultant${onlineCount == 1 ? '' : 's'} online · ${_statusLabel(status)}'
                                              : 'No consultant is online right now · ${_statusLabel(status)}',
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (unread > 0)
                                    Semantics(
                                      label: '$unread unread consultant messages',
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                                        decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(10)),
                                        child: Text('$unread new', style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800)),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                      if (responseSeconds != null)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(18, 0, 18, 8),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Semantics(
                              label: _responseLabel(responseSeconds),
                              child: Text(_responseLabel(responseSeconds), style: const TextStyle(fontSize: 10.5, color: AppColors.textMuted)),
                            ),
                          ),
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
                                  child: Text('Unable to load your consultation.\n${snapshot.error}', textAlign: TextAlign.center),
                                ),
                              );
                            }
                            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
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
                            return ListView.builder(
                              controller: _scroll,
                              padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
                              itemCount: messages.length,
                              itemBuilder: (_, index) {
                                final message = messages[index].data();
                                final consultant = message['senderType'] == 'consultant';
                                final sender = message['senderName'] as String? ?? 'TiB Consultant';
                                final text = message['text'] as String? ?? '';
                                return Align(
                                  alignment: consultant ? Alignment.centerLeft : Alignment.centerRight,
                                  child: Semantics(
                                    container: true,
                                    label: consultant ? 'Consultant $sender says: $text' : 'You said: $text',
                                    child: Container(
                                      constraints: BoxConstraints(maxWidth: wide ? 620 : 310),
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
                                            Text(sender, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.primary)),
                                            const SizedBox(height: 3),
                                          ],
                                          Text(text, style: TextStyle(fontSize: 12.5, height: 1.4, color: consultant ? AppColors.textPrimary : Colors.white)),
                                        ],
                                      ),
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
                          child: Semantics(
                            container: true,
                            label: 'Rate your consultation',
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
                                  Wrap(
                                    spacing: 2,
                                    children: List.generate(5, (index) {
                                      final ratingValue = index + 1;
                                      return Semantics(
                                        button: true,
                                        label: 'Rate $ratingValue out of 5',
                                        child: IconButton(
                                          tooltip: 'Rate $ratingValue out of 5',
                                          onPressed: _ratingSending ? null : () => _rate(ratingValue),
                                          icon: const Icon(Icons.star_border_rounded),
                                          color: AppColors.primary,
                                        ),
                                      );
                                    }),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      SafeArea(
                        top: false,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(15, 7, 15, 12),
                          child: LayoutBuilder(
                            builder: (context, composerConstraints) {
                              final compact = composerConstraints.maxWidth < 520;
                              final composer = TextField(
                                controller: _composer,
                                minLines: 1,
                                maxLines: 4,
                                maxLength: 1500,
                                textInputAction: TextInputAction.send,
                                onSubmitted: (_) => _send(),
                                decoration: const InputDecoration(hintText: 'Message your consultant…', counterText: '', filled: true, fillColor: AppColors.surface, border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(18)), borderSide: BorderSide(color: AppColors.border)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(18)), borderSide: BorderSide(color: AppColors.border))),
                              );
                              final sendButton = Semantics(
                                button: true,
                                enabled: !_sending,
                                label: _sending ? 'Sending message' : 'Send message',
                                child: SizedBox(
                                  width: 50,
                                  height: 52,
                                  child: Material(
                                    color: _sending ? AppColors.primary.withValues(alpha: .45) : AppColors.primary,
                                    borderRadius: BorderRadius.circular(18),
                                    child: InkWell(
                                      onTap: _sending ? null : _send,
                                      borderRadius: BorderRadius.circular(18),
                                      child: _sending
                                          ? const Padding(padding: EdgeInsets.all(17), child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                          : const Icon(Icons.send_rounded, color: Colors.white),
                                    ),
                                  ),
                                ),
                              );
                              return compact
                                  ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [composer, const SizedBox(height: 7), Align(alignment: Alignment.centerRight, child: sendButton)])
                                  : Row(children: [Expanded(child: composer), const SizedBox(width: 8), sendButton]);
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      );
    }
}
