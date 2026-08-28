import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../services/live_consultancy_service.dart';

class ConsultationManagementScreen extends StatefulWidget {
  const ConsultationManagementScreen({super.key});

  @override
  State<ConsultationManagementScreen> createState() => _ConsultationManagementScreenState();
}

class _ConsultationManagementScreenState extends State<ConsultationManagementScreen> {
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    LiveConsultancyService.setConsultantPresence(true);
  }

  @override
  void dispose() {
    LiveConsultancyService.setConsultantPresence(false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const filters = <String, String>{
      'all': 'All',
      'waiting_for_consultant': 'Waiting',
      'assigned': 'Assigned',
      'consultant_replied': 'Replied',
      'resolved': 'Resolved',
    };

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Live Consultancy')),
      body: Column(
        children: [
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: LiveConsultancyService.onlineConsultantsStream(),
            builder: (context, snapshot) {
              final onlineCount = snapshot.data?.docs.length ?? 0;
              final currentUid = FirebaseAuth.instance.currentUser?.uid;
              final meOnline = currentUid != null &&
                  snapshot.data?.docs.any((doc) => doc.id == currentUid) == true;
              return Container(
                margin: const EdgeInsets.fromLTRB(16, 8, 16, 6),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.secondary.withValues(alpha: .55),
                  borderRadius: BorderRadius.circular(17),
                ),
                child: Row(
                  children: [
                    Icon(Icons.circle, size: 9, color: meOnline ? Colors.green : AppColors.textMuted),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        meOnline
                            ? 'You are online · $onlineCount consultant${onlineCount == 1 ? '' : 's'} available'
                            : 'Consultant offline · $onlineCount available',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                      ),
                    ),
                    const Text('LIVE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: AppColors.primary)),
                  ],
                ),
              );
            },
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
            child: Row(
              children: filters.entries.map((entry) {
                return Padding(
                  padding: const EdgeInsets.only(right: 7),
                  child: ChoiceChip(
                    selected: _filter == entry.key,
                    label: Text(entry.value, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700)),
                    onSelected: (_) => setState(() => _filter = entry.key),
                  ),
                );
              }).toList(),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: LiveConsultancyService.consultationsStream(status: _filter == 'all' ? null : _filter),
              builder: (context, snapshot) {
                if (snapshot.hasError) return Center(child: Text('Unable to load consultations: ${snapshot.error}'));
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

                final docs = snapshot.data!.docs;
                if (docs.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.mark_chat_unread_outlined, size: 42, color: AppColors.primary.withValues(alpha: .55)),
                          const SizedBox(height: 10),
                          Text(_filter == 'waiting_for_consultant' ? 'No waiting requests' : 'No consultations found.', style: const TextStyle(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 4),
                          const Text('New customer requests will appear here in real time.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textMuted, fontSize: 11.5)),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final data = docs[index].data();
                    final unread = (data['unreadForConsultant'] as num?)?.toInt() ?? 0;
                    final assigned = data['assignedConsultantName'] as String?;
                    final lastMessage = data['lastMessage'] as String?;
                    final email = data['email'] as String?;
                    final userName = data['userName'] as String? ?? 'TiB User';
                    final status = data['status'] as String? ?? 'open';
                    final isWaiting = status == 'waiting_for_consultant';
                    final isMine = data['assignedConsultantId'] == FirebaseAuth.instance.currentUser?.uid;
                    final subtitle = lastMessage ?? email ?? 'New consultation';

                    return Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17), side: const BorderSide(color: AppColors.border)),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(17),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => ConsultantChatScreen(uid: docs[index].id, userName: userName)),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(15, 13, 12, 13),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: AppColors.secondary,
                                    child: const Icon(Icons.person_outline_rounded, color: AppColors.primary),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(child: Text(userName, style: const TextStyle(fontWeight: FontWeight.w800))),
                                            if (unread > 0)
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                                                decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(9)),
                                                child: Text('$unread new', style: const TextStyle(color: Colors.white, fontSize: 8.5, fontWeight: FontWeight.w800)),
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 3),
                                        Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 11),
                              Row(
                                children: [
                                  _StatusPill(status: status),
                                  const Spacer(),
                                  if (isMine)
                                    const Text('Assigned to you', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: AppColors.primary)),
                                  if (isWaiting)
                                    FilledButton.icon(
                                      onPressed: () async {
                                        final accepted = await LiveConsultancyService.acceptConsultation(docs[index].id);
                                        if (!context.mounted) return;
                                        if (!accepted) {
                                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('This request was already accepted by another consultant.')));
                                        }
                                      },
                                      icon: const Icon(Icons.check_rounded, size: 15),
                                      label: const Text('Accept'),
                                      style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), textStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800)),
                                    )
                                  else
                                    const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
                                ],
                              ),
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
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String status;

  const _StatusPill({required this.status});

  @override
  Widget build(BuildContext context) {
    final label = status.replaceAll('_', ' ');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.secondary.withValues(alpha: .7),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: AppColors.textSecondary)),
    );
  }
}

class ConsultantChatScreen extends StatefulWidget {
  final String uid;
  final String userName;

  const ConsultantChatScreen({super.key, required this.uid, required this.userName});

  @override
  State<ConsultantChatScreen> createState() => _ConsultantChatScreenState();
}

class _ConsultantChatScreenState extends State<ConsultantChatScreen> {
  final TextEditingController _composer = TextEditingController();
  bool _sending = false;
  bool _accepting = false;
  bool _assignedToMe = false;
  String _status = 'open';

  @override
  void initState() {
    super.initState();
    LiveConsultancyService.setConsultantPresence(true);
    _loadConsultationState();
  }

  Future<void> _loadConsultationState() async {
    final snapshot = await FirebaseFirestore.instance.collection('consultations').doc(widget.uid).get();
    final data = snapshot.data();
    if (!mounted || data == null) return;
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    setState(() {
      _status = data['status'] as String? ?? 'open';
      _assignedToMe = data['assignedConsultantId'] == currentUid;
    });
    if (_assignedToMe) {
      await LiveConsultancyService.markMessagesRead(widget.uid, by: 'consultant');
    }
  }

  @override
  void dispose() {
    _composer.dispose();
    super.dispose();
  }

  Future<void> _accept() async {
    if (_accepting) return;
    setState(() => _accepting = true);
    final accepted = await LiveConsultancyService.acceptConsultation(widget.uid);
    if (!mounted) return;
    if (accepted) {
      setState(() {
        _assignedToMe = true;
        _status = 'assigned';
      });
      await LiveConsultancyService.markMessagesRead(widget.uid, by: 'consultant');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('This consultation is no longer available.')));
      await _loadConsultationState();
    }
    if (mounted) setState(() => _accepting = false);
  }

  Future<void> _send() async {
    final text = _composer.text.trim();
    if (text.isEmpty || _sending || !_assignedToMe) return;

    final consultant = FirebaseAuth.instance.currentUser;
    final displayName = consultant?.displayName?.trim().isNotEmpty == true
        ? consultant!.displayName!.trim()
        : 'TiB Consultant';

    setState(() => _sending = true);
    _composer.clear();
    try {
      await LiveConsultancyService.sendConsultantMessage(uid: widget.uid, text: text, consultantName: displayName);
      await LiveConsultancyService.markMessagesRead(widget.uid, by: 'consultant');
      if (mounted) setState(() => _status = 'consultant_replied');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _resolve() async {
    if (!_assignedToMe) return;
    await LiveConsultancyService.setStatus(widget.uid, 'resolved');
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.userName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            Text(_assignedToMe ? 'Assigned to you' : _status.replaceAll('_', ' '), style: const TextStyle(fontSize: 9.5, color: AppColors.textMuted)),
          ],
        ),
        actions: [
          if (!_assignedToMe && (_status == 'waiting_for_consultant' || _status == 'open'))
            TextButton.icon(
              onPressed: _accepting ? null : _accept,
              icon: const Icon(Icons.check_rounded, size: 17),
              label: const Text('Accept'),
            ),
          if (_assignedToMe)
            IconButton(
              tooltip: 'Resolve consultation',
              onPressed: _resolve,
              icon: const Icon(Icons.check_circle_outline_rounded),
            ),
        ],
      ),
      body: Column(
        children: [
          if (!_assignedToMe)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(15, 8, 15, 4),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.secondary.withValues(alpha: .55), borderRadius: BorderRadius.circular(15)),
              child: const Text('This conversation is read-only until you accept it.', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700)),
            ),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: LiveConsultancyService.conversationMessages(widget.uid),
              builder: (context, snapshot) {
                if (snapshot.hasError) return Center(child: Text('Unable to load messages: ${snapshot.error}'));
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final docs = snapshot.data!.docs;
                if (docs.isEmpty) return const Center(child: Text('No messages yet.'));

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data();
                    final consultant = data['senderType'] == 'consultant';
                    final text = data['text'] as String? ?? '';
                    return Align(
                      alignment: consultant ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 330),
                        margin: const EdgeInsets.only(bottom: 9),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                        decoration: BoxDecoration(
                          color: consultant ? AppColors.primary : AppColors.surface,
                          borderRadius: BorderRadius.circular(17),
                          border: consultant ? null : Border.all(color: AppColors.border),
                        ),
                        child: Text(text, style: TextStyle(color: consultant ? Colors.white : AppColors.textPrimary, fontSize: 12.5, height: 1.4)),
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
                      enabled: _assignedToMe,
                      maxLines: 4,
                      minLines: 1,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: InputDecoration(
                        hintText: _assignedToMe ? 'Reply to customer…' : 'Accept this consultation to reply…',
                        filled: true,
                        fillColor: AppColors.surface,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(18)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _sending || !_assignedToMe ? null : _send,
                    icon: const Icon(Icons.send_rounded),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
