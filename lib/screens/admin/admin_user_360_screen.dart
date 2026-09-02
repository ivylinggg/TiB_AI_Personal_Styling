import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';

/// Read-only 360° view for administrators.
/// Every section is scoped to the selected customer's UID.
class AdminUser360Screen extends StatelessWidget {
  final String userId;
  final Map<String, dynamic> userData;

  const AdminUser360Screen({
    super.key,
    required this.userId,
    required this.userData,
  });

  String _text(String key, [String fallback = 'Not available']) {
    final value = userData[key];
    return value is String && value.trim().isNotEmpty ? value.trim() : fallback;
  }

  DateTime? _date(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    return null;
  }

  String _formatDate(DateTime? value) {
    if (value == null) return 'Date unavailable';
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    return '$day/$month/${value.year}';
  }

  Future<void> _refresh(BuildContext context) async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
  }

  @override
  Widget build(BuildContext context) {
    final name = _text('name', 'Customer');
    final isPremium = userData['isPremium'] as bool? ?? false;
    final isActive = userData['isActive'] as bool? ?? true;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Customer 360'),
        actions: [
          IconButton(
            tooltip: 'Refresh customer data',
            onPressed: () => _refresh(context),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _refresh(context),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 30),
          children: [
            _header(name, isActive, isPremium),
            const SizedBox(height: 16),
            _section('Account', [
              _item('Email', _text('email')),
              _item('Role', _text('role', 'customer').toUpperCase()),
              _item('Status', isActive ? 'Active' : 'Inactive'),
              _item('Membership', isPremium ? 'Premium' : 'Free'),
              _item('Created', _formatDate(_date(userData['createdAt']))),
              _item('Updated', _formatDate(_date(userData['updatedAt']))),
            ]),
            const SizedBox(height: 12),
            _section('Personal & Colour Profile', [
              _item('Colour Season', _text('colourSeason')),
              _item('Skin Tone', _text('skinTone')),
              _item('Undertone', _text('undertone')),
              _item('Face Shape', _text('faceShape')),
              _item('Body Shape', _text('bodyShape')),
              _item('Style Preference', _text('stylePreference')),
            ]),
            const SizedBox(height: 12),
            _collectionSection(
              title: 'TiB Model',
              collection: 'tib_models',
              emptyText: 'No TiB Model record found.',
              builder: (data) => _item(
                'Model',
                data['name'] as String? ?? 'Personal TiB Model',
              ),
            ),
            const SizedBox(height: 12),
            _collectionSection(
              title: 'Colour Analysis History',
              collection: 'analysis',
              emptyText: 'No colour analysis records found.',
              builder: (data) => _analysisItem(data),
            ),
            const SizedBox(height: 12),
            _collectionSection(
              title: 'Saved Looks',
              collection: 'savedLooks',
              emptyText: 'No saved outfit looks found.',
              builder: (data) => _item(
                data['occasion'] as String? ?? 'Saved look',
                'Score ${data['matchScore'] ?? '--'} • ${data['season'] ?? 'Season not recorded'}',
              ),
            ),
            const SizedBox(height: 12),
            _collectionSection(
              title: 'Wardrobe',
              collection: 'wardrobe',
              emptyText: 'No wardrobe items found.',
              builder: (data) => _item(
                data['name'] as String? ?? 'Wardrobe item',
                '${data['category'] ?? 'Uncategorised'} • ${data['colour'] ?? data['color'] ?? 'Colour not specified'}',
              ),
            ),
            const SizedBox(height: 12),
            _consultationSection(),
          ],
        ),
      ),
    );
  }

  Widget _header(String name, bool isActive, bool isPremium) => Card(
        elevation: 0,
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.border),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: AppColors.secondary,
                child: const Icon(Icons.person, color: AppColors.primary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _text('email'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _badge(isActive ? 'ACTIVE' : 'INACTIVE', isActive ? AppColors.success : AppColors.error),
                        _badge(isPremium ? 'PREMIUM' : 'FREE', AppColors.primary),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );

  Widget _badge(String label, Color foreground) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: foreground.withValues(alpha: .12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: foreground),
        ),
      );

  Widget _section(String title, List<Widget> children) => Card(
        elevation: 0,
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: AppColors.border),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              ...children,
            ],
          ),
        ),
      );

  Widget _item(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 130,
              child: Text(label, style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            ),
            Expanded(
              child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      );

  Widget _collectionSection({
    required String title,
    required String collection,
    required String emptyText,
    required Widget Function(Map<String, dynamic>) builder,
  }) {
    final stream = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection(collection)
        .snapshots();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _section(title, [
            _item('Status', 'Unable to load this section.'),
          ]);
        }
        if (!snapshot.hasData) {
          return _section(title, [
            const Center(
              child: Padding(
                padding: EdgeInsets.all(12),
                child: CircularProgressIndicator(),
              ),
            ),
          ]);
        }

        final docs = [...snapshot.data!.docs]
          ..sort((a, b) {
            final aDate = _date(a.data()['createdAt'] ?? a.data()['updatedAt']);
            final bDate = _date(b.data()['createdAt'] ?? b.data()['updatedAt']);
            if (aDate == null && bDate == null) return 0;
            if (aDate == null) return 1;
            if (bDate == null) return -1;
            return bDate.compareTo(aDate);
          });

        if (docs.isEmpty) {
          return _section(title, [_item('Status', emptyText)]);
        }

        final visible = docs.take(10).map((doc) => builder(doc.data())).toList();
        return _section(title, [
          Row(
            children: [
              Text('${docs.length} record(s)', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              const Spacer(),
              if (docs.length > 10)
                Text('Showing latest 10', style: TextStyle(fontSize: 10, color: AppColors.textMuted)),
            ],
          ),
          const SizedBox(height: 4),
          ...visible,
        ]);
      },
    );
  }

  Widget _analysisItem(Map<String, dynamic> data) => _item(
        data['season'] as String? ?? 'Analysis',
        '${data['undertone'] ?? 'Unknown undertone'} • ${data['brightness'] ?? 'Unknown brightness'} • ${data['contrast'] ?? 'Unknown contrast'}',
      );

  Widget _consultationSection() {
    final stream = FirebaseFirestore.instance
        .collection('consultations')
        .doc(userId)
        .snapshots();

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _section('Consultation', [_item('Status', 'Unable to load consultation.')]);
        }
        if (!snapshot.hasData) {
          return _section('Consultation', [const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator()))]);
        }
        final data = snapshot.data!.data();
        if (data == null) {
          return _section('Consultation', [_item('Status', 'No consultation history found.')]);
        }
        final assigned = data['assignedConsultantName'] as String?;
        return _section('Consultation', [
          _item('Status', (data['status'] as String? ?? 'unknown').replaceAll('_', ' ')),
          _item('Assigned Consultant', assigned?.isNotEmpty == true ? assigned! : 'Unassigned'),
          _item('Messages', '${data['messageCount'] ?? data['messagesCount'] ?? '--'}'),
          _item('Last Message', data['lastMessage'] as String? ?? 'No message yet'),
          _item('Updated', _formatDate(_date(data['updatedAt'] ?? data['lastMessageAt']))),
        ]);
      },
    );
  }
}
