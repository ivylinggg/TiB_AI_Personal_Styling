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
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Live Consultancy')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: LiveConsultancyService.consultationsStream(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text('Unable to load consultations: ${snapshot.error}'));
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final docs = snapshot.data!.docs;
          if (docs.isEmpty) return const Center(child: Text('No live consultations yet.'));

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, index) {
              final data = docs[index].data();
              final status = data['status'] as String? ?? 'open';
              final assigned = data['assignedConsultantName'] as String?;
              final unread = (data['unreadForConsultant'] as num?)?.toInt() ?? 0;
              final responseSeconds = (data['responseTimeSeconds'] as num?)?.toInt();
              final rating = (data['rating'] as num?)?.toInt();
              return Card(
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17), side: const BorderSide(color: AppColors.border)),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 7),
                  leading: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      CircleAvatar(
                        backgroundColor: status == 'waiting_for_consultant' ? AppColors.secondary : AppColors.surfaceMuted,
                        child: const Icon(Icons.person_outline_rounded, color: AppColors.primary),
                      ),
                      if (unread > 0)
                        Positioned(
                          right: -5,
                          top: -5,
                          child: Container(
                            padding: const EdgeInsets.all(5),
                            decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                            child: Text('$unread', style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w800)),
                          ),
                        ),
                    ],
                  ),
                  title: Row(
                    children: [
                      Expanded(child: Text(data['userName'] as String? ?? 'TiB User', style: const TextStyle(fontWeight: FontWeight.w800))),
                      if (rating != null) ...[
                        const Icon(Icons.star_rounded, size: 15, color: AppColors.primary),
                        Text('$rating', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800)),
                      ],
                    ],
                  ),
                  subtitle: Text(
                    [
                      assigned ?? (data['lastMessage'] as String? ?? data['email'] as String? ?? 'New consultation'),
                      if (responseSeconds != null) 'First response ${responseSeconds < 60 ? '${responseSeconds}s' : '${responseSeconds ~/ 60}m'}',
                    ].join(' · '),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                    decoration: BoxDecoration(color: status == 'waiting_for_consultant' ? AppColors.secondary : AppColors.surfaceMuted, borderRadius: BorderRadius.circular(12)),
                    child: Text(status.replaceAll('_', ' '), style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800)),
                  ),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ConsultantChatScreen(uid: docs[index].id, userName: data['userName'] as String? ?? 'TiB User'))),
                ),
              );
            },
          );
        },
      ),
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
  final ScrollController _scroll = ScrollController();
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    LiveConsultancyService.setConsultantPresence(true);
    LiveConsultancyService.assignToCurrentConsultant(widget.uid);
    LiveConsultancyService.markMessagesRead(widget.uid, by: 'consultant');
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
    final name = FirebaseAuth.instance.currentUser?.displayName?.trim();
    setState(() => _sending = true);
    _composer.clear();
    try {
      await LiveConsultancyService.sendConsultantMessage(uid: widget.uid, text: text, consultantName: name == null || name.isEmpty ? 'TiB Consultant' : name);
      await LiveConsultancyService.markMessagesRead(widget.uid, by: 'consultant');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _resolve() async {
    await LiveConsultancyService.setStatus(widget.uid, 'resolved');
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(widget.userName),
        actions: [IconButton(tooltip: 'Resolve consultation', onPressed: _resolve, icon: const Icon(Icons.check_circle_outline_rounded))],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: LiveConsultancyService.conversationMessages(widget.uid),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text('Unable to load messages: ${snapshot.error}'));
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final docs = snapshot.data!.docs;
          return Column(
            children: [
              Expanded(
                child: docs.isEmpty
                    ? const Center(child: Text('Customer has not sent a message yet.'))
                    : ListView.builder(
                        controller: _scroll,
                        padding: const EdgeInsets.all(16),
                        itemCount: docs.length,
                        itemBuilder: (_, index) {
                          final data = docs[index].data();
                          final consultant = data['senderType'] == 'consultant';
                          return Align(
                            alignment: consultant ? Alignment.centerRight : Alignment.centerLeft,
                            child: Container(
                              constraints: const BoxConstraints(maxWidth: 330),
                              margin: const EdgeInsets.only(bottom: 9),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                              decoration: BoxDecoration(color: consultant ? AppColors.primary : AppColors.surface, borderRadius: BorderRadius.circular(17), border: consultant ? null : Border.all(color: AppColors.border)),
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                if (consultant) Text(data['senderName'] as String? ?? 'TiB Consultant', style: const TextStyle(fontSize: 9.5, color: Colors.white70, fontWeight: FontWeight.w700)),
                                Text(data['text'] as String? ?? '', style: TextStyle(color: consultant ? Colors.white : AppColors.textPrimary, fontSize: 12.5, height: 1.4)),
                              ]),
                            ),
                          );
                        },
                      ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(15, 7, 15, 12),
                  child: Row(children: [
                    Expanded(child: TextField(controller: _composer, maxLines: 4, minLines: 1, textInputAction: TextInputAction.send, onSubmitted: (_) => _send(), decoration: InputDecoration(hintText: 'Reply to customer…', filled: true, fillColor: AppColors.surface, border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: AppColors.border))))),
                    const SizedBox(width: 8),
                    Material(color: AppColors.primary, borderRadius: BorderRadius.circular(18), child: InkWell(onTap: _sending ? null : _send, borderRadius: BorderRadius.circular(18), child: const SizedBox(width: 50, height: 52, child: Icon(Icons.send_rounded, color: Colors.white))),
                  ]),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
