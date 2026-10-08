import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../models/wardrobe_item.dart';
import '../../services/firestore_service.dart';
import '../../services/style_feedback_service.dart';
import '../ai/ai_outfit_screen.dart';

class StylingHistoryScreen extends StatefulWidget {
  const StylingHistoryScreen({super.key});

  @override
  State<StylingHistoryScreen> createState() => _StylingHistoryScreenState();
}

class _StylingHistoryScreenState extends State<StylingHistoryScreen> {
  bool _loading = true;
  List<_HistoryLook> _looks = const [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    try {
      final feedback = await StyleFeedbackService.getRecentFeedback(limit: 100);
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null || uid.isEmpty) {
        if (mounted) setState(() => _loading = false);
        return;
      }

      final wardrobe = await FirestoreService.getWardrobeItems(uid);
      final byId = <String, WardrobeItem>{for (final item in wardrobe) item.id: item};
      final looks = <_HistoryLook>[];
      final seen = <String>{};

      for (final entry in feedback) {
        final type = entry['type']?.toString();
        if (type != 'generated' && type != 'action') continue;

        final rawIds = entry['itemIds'];
        if (rawIds is! List) continue;
        final ids = rawIds.map((item) => item.toString().trim()).where((id) => id.isNotEmpty).toList();
        if (ids.isEmpty) continue;

        final key = ids.toSet().toList()..sort();
        final uniqueKey = key.join('|');
        if (!seen.add(uniqueKey)) continue;

        final items = ids.map((id) => byId[id]).whereType<WardrobeItem>().toList();
        if (items.isEmpty) continue;

        looks.add(
          _HistoryLook(
            items: items,
            occasion: entry['occasion']?.toString().trim().isNotEmpty == true
                ? entry['occasion'].toString()
                : 'Saved look',
            action: type == 'generated'
                ? 'AI generated'
                : (entry['action']?.toString() ?? 'Styling activity'),
          ),
        );

        if (looks.length >= 30) break;
      }

      if (mounted) {
        setState(() {
          _looks = looks;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: const Text(
          'Styling History',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadHistory,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _looks.isEmpty
                ? ListView(
                    children: const [
                      SizedBox(height: 140),
                      Icon(Icons.history_rounded, size: 52, color: AppColors.textSecondary),
                      SizedBox(height: 14),
                      Center(
                        child: Text(
                          'No styling history yet.',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      SizedBox(height: 6),
                      Center(
                        child: Text(
                          'Generate and save outfits to see them here.',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      ),
                    ],
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                    itemCount: _looks.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 14),
                    itemBuilder: (_, index) => _HistoryCard(look: _looks[index]),
                  ),
      ),
    );
  }
}

class _HistoryLook {
  final List<WardrobeItem> items;
  final String occasion;
  final String action;

  const _HistoryLook({
    required this.items,
    required this.occasion,
    required this.action,
  });
}

class _HistoryCard extends StatelessWidget {
  final _HistoryLook look;

  const _HistoryCard({required this.look});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  look.occasion,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                ),
              ),
              Text(
                look.action,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 116,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: look.items.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, index) {
                final item = look.items[index];
                return ClipRRect(
                  borderRadius: BorderRadius.circular(15),
                  child: SizedBox(
                    width: 92,
                    child: CachedNetworkImage(
                      imageUrl: item.imageUrl,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => Container(
                        color: AppColors.surface,
                        child: const Icon(Icons.checkroom_outlined),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => AIOutfitScreen(
                      initialItems: look.items,
                      initialOccasion: look.occasion,
                    ),
                  ),
                );
              },
              child: const Text('Reuse Look'),
            ),
          ),
        ],
      ),
    );
  }
}
