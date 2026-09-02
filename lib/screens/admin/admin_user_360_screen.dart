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
    return value is String && value.trim().isNotEmpty ? value : fallback;
  }

  @override
  Widget build(BuildContext context) {
    final name = _text('name', 'Customer');
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Customer 360')),
      body: RefreshIndicator(
        onRefresh: () async => Future<void>.delayed(const Duration(milliseconds: 300)),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _header(name),
            const SizedBox(height: 16),
            _section('Account', [
              _item('Email', _text('email')),
              _item('Role', _text('role', 'customer').toUpperCase()),
              _item('Status', (userData['isActive'] as bool? ?? true) ? 'Active' : 'Inactive'),
              _item('Membership', (userData['isPremium'] as bool? ?? false) ? 'Premium' : 'Free'),
            ]),
            const SizedBox(height: 12),
            _section('Personal & Colour Profile', [
              _item('Colour Season', _text('colourSeason')),
              _item('Skin Tone', _text('skinTone')),
              _item('Undertone', _text('undertone')),
              _item('Face Shape', _text('faceShape')),
              _item('Body Shape', _text('bodyShape')),
            ]),
            const SizedBox(height: 12),
            _collectionSection(
              title: 'TiB Model',
              collection: 'tib_models',
              emptyText: 'No TiB Model record found.',
              builder: (data) => _item('Model', data['name'] as String? ?? 'Personal TiB Model'),
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
              title: 'Wardrobe',
              collection: 'wardrobe',
              emptyText: 'No wardrobe items found.',
              builder: (data) => _item(
                data['name'] as String? ?? 'Wardrobe item',
                '${data['category'] ?? 'Uncategorised'} • ${data['colour'] ?? 'Colour not specified'}',
              ),
            ),
            const SizedBox(height: 12),
            _collectionSection(
              title: 'Consultation History',
              collection: 'consultations',
              emptyText: 'No consultation records found.',
              builder: (data) => _item(
                'Consultation',
                '${data['status'] ?? 'Unknown status'}${data['subject'] == null ? '' : ' • ${data['subject']}'}',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(String name) => Card(
        elevation: 0,
        color: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: AppColors.border)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(children: [
            CircleAvatar(radius: 30, backgroundColor: AppColors.secondary, child: const Icon(Icons.person, color: AppColors.primary)),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text('UID: $userId', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            ])),
          ]),
        ),
      );

  Widget _section(String title, List<Widget> children) => Card(
        elevation: 0,
        color: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: const BorderSide(color: AppColors.border)),
        child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          ...children,
        ])),
      );

  Widget _item(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 130, child: Text(label, style: TextStyle(color: AppColors.textSecondary, fontSize: 13))),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600))),
        ]),
      );

  Widget _collectionSection({required String title, required String collection, required String emptyText, required Widget Function(Map<String, dynamic>) builder}) {
    final stream = FirebaseFirestore.instance.collection('users').doc(userId).collection(collection).snapshots();
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) return _section(title, [_item('Status', 'Unable to load this section.')]);
        if (!snapshot.hasData) return _section(title, [const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator()))]);
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) return _section(title, [_item('Status', emptyText)]);
        return _section(title, docs.take(10).map((doc) => builder(doc.data())).toList());
      },
    );
  }

  Widget _analysisItem(Map<String, dynamic> data) => _item(
        data['season'] as String? ?? 'Analysis',
        '${data['undertone'] ?? 'Unknown undertone'} • ${data['brightness'] ?? 'Unknown brightness'} • ${data['contrast'] ?? 'Unknown contrast'}',
      );
}