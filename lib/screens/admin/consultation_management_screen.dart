import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../services/live_consultancy_service.dart';

class ConsultationManagementScreen extends StatelessWidget {
  const ConsultationManagementScreen({super.key});

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
              return Card(
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17), side: const BorderSide(color: AppColors.border)),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 7),
                  leading: const CircleAvatar(backgroundColor: AppColors.secondary, child: Icon(Icons.person_outline_rounded, color: AppColors.primary)),
                  title: Text(data['userName'] as String? ?? 'TiB User', style: const TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: Text(data['lastMessage'] as String? ?? data['email'] as String? ?? 'New consultation', maxLines: 2, overflow: TextOverflow.ellipsis),
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
      await LiveConsultancyService.sendConsultantMessage(uid: widget.uid, text: text, consultantName: FirebaseAuth.instance.currentUser?.displayName ?? 'TiB Consultant');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final messages = FirebaseFirestore.instance.collection('consultations').doc(widget.uid).collection('messages').orderBy('createdAt').snapshots();
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(widget.userName)),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: messages,
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final docs = snapshot.data!.docs;
                return ListView.builder(
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
                        child: Text(data['text'] as String? ?? '', style: TextStyle(color: consultant ? Colors.white : AppColors.textPrimary, fontSize: 12.5, height: 1.4)),
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
                  Expanded(child: TextField(controller: _composer, maxLines: 4, minLines: 1, textInputAction: TextInputAction.send, onSubmitted: (_) => _send(), decoration: InputDecoration(hintText: 'Reply to customer…', filled: true, fillColor: AppColors.surface, border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: AppColors.border))))),
                  const SizedBox(width: 8),
                  Material(color: AppColors.primary, borderRadius: BorderRadius.circular(18), child: InkWell(onTap: _sending ? null : _send, borderRadius: BorderRadius.circular(18), child: const SizedBox(width: 50, height: 52, child: Icon(Icons.send_rounded, color: Colors.white))),),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
