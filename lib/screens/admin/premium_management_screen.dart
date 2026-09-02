import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';

class PremiumManagementScreen extends StatefulWidget {
  const PremiumManagementScreen({super.key});

  @override
  State<PremiumManagementScreen> createState() => _PremiumManagementScreenState();
}

class _PremiumManagementScreenState extends State<PremiumManagementScreen> {
  final _searchController = TextEditingController();
  String _filter = 'All';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _users() {
    return FirebaseFirestore.instance
        .collection('users')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  bool _matches(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final query = _searchController.text.trim().toLowerCase();
    final name = (data['name'] as String? ?? '').toLowerCase();
    final email = (data['email'] as String? ?? '').toLowerCase();
    final uid = (data['uid'] as String? ?? doc.id).toLowerCase();
    final premium = data['isPremium'] as bool? ?? false;
    final active = data['isActive'] as bool? ?? true;

    final searchMatch = query.isEmpty ||
        name.contains(query) ||
        email.contains(query) ||
        uid.contains(query);

    final filterMatch = switch (_filter) {
      'Premium' => premium,
      'Free' => !premium,
      'Active' => active,
      'Inactive' => !active,
      _ => true,
    };

    return searchMatch && filterMatch;
  }

  String _formatDate(dynamic value) {
    DateTime? date;
    if (value is Timestamp) date = value.toDate();
    if (value is DateTime) date = value;
    if (date == null) return 'No date';
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }

  Future<void> _showUserAccessDetails(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final data = doc.data();
    final name = data['name'] as String? ?? 'Unknown User';
    final email = data['email'] as String? ?? 'No email';
    final uid = data['uid'] as String? ?? doc.id;
    final premium = data['isPremium'] as bool? ?? false;
    final active = data['isActive'] as bool? ?? true;
    final createdAt = _formatDate(data['createdAt']);
    final updatedAt = _formatDate(data['updatedAt']);

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Premium Access Details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _detailRow('Name', name),
              _detailRow('Email', email),
              _detailRow('UID', uid),
              _detailRow('Membership', premium ? 'Premium' : 'Free'),
              _detailRow('Account Status', active ? 'Active' : 'Inactive'),
              _detailRow('Created', createdAt),
              _detailRow('Last Updated', updatedAt),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _togglePremium(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final data = doc.data();
    final current = data['isPremium'] as bool? ?? false;
    final name = data['name'] as String? ?? 'this user';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(current ? 'Remove Premium?' : 'Grant Premium?'),
        content: Text(
          current
              ? 'Premium access will be removed from $name.'
              : '$name will receive Premium access immediately.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(current ? 'Remove' : 'Grant'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await doc.reference.update({
        'isPremium': !current,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(!current ? 'Premium access granted.' : 'Premium access removed.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to update premium status: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Premium Management'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () => setState(() {}),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _users(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.cloud_off_outlined, size: 44),
                    const SizedBox(height: 12),
                    const Text(
                      'We couldn’t load the premium list.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Please check your connection and try again.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            );
          }

          final all = snapshot.data?.docs ?? const [];
          final premiumCount = all.where((d) => d.data()['isPremium'] as bool? ?? false).length;
          final freeCount = all.length - premiumCount;
          final activeCount = all.where((d) => d.data()['isActive'] as bool? ?? true).length;
          final inactiveCount = all.length - activeCount;
          final visible = all.where(_matches).toList();

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Row(
                  children: [
                    Expanded(child: _stat('Premium', premiumCount, Icons.workspace_premium_outlined)),
                    const SizedBox(width: 10),
                    Expanded(child: _stat('Free', freeCount, Icons.person_outline)),
                    const SizedBox(width: 10),
                    Expanded(child: _stat('Active', activeCount, Icons.check_circle_outline)),
                    const SizedBox(width: 10),
                    Expanded(child: _stat('Inactive', inactiveCount, Icons.person_off_outlined)),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
                child: Text(
                  'Manage premium access and review each customer’s membership record.',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                child: TextField(
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Search name, email or UID',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isEmpty
                        ? null
                        : IconButton(
                            onPressed: () {
                              _searchController.clear();
                              setState(() {});
                            },
                            icon: const Icon(Icons.clear),
                          ),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                child: Row(
                  children: ['All', 'Premium', 'Free', 'Active', 'Inactive'].map((value) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(value),
                      selected: _filter == value,
                      onSelected: (_) => setState(() => _filter = value),
                    ),
                  )).toList(),
                ),
              ),
              Expanded(
                child: visible.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.people_outline, size: 44),
                              const SizedBox(height: 12),
                              const Text(
                                'No users found',
                                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Try another search or membership filter.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
                        itemCount: visible.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final doc = visible[index];
                          final data = doc.data();
                          final isPremium = data['isPremium'] as bool? ?? false;
                          final isActive = data['isActive'] as bool? ?? true;
                          final name = data['name'] as String? ?? 'Unknown User';
                          final email = data['email'] as String? ?? 'No email';
                          final updated = _formatDate(data['updatedAt']);
                          return Card(
                            elevation: 0,
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              leading: CircleAvatar(
                                backgroundColor: isPremium ? AppColors.secondary : AppColors.surfaceMuted,
                                child: Icon(
                                  isPremium ? Icons.workspace_premium : Icons.person_outline,
                                  color: isPremium ? AppColors.primary : AppColors.textMuted,
                                ),
                              ),
                              title: Row(
                                children: [
                                  Expanded(child: Text(name, style: const TextStyle(fontWeight: FontWeight.w600))),
                                  if (!isActive)
                                    const Padding(
                                      padding: EdgeInsets.only(left: 6),
                                      child: Icon(Icons.block, size: 16),
                                    ),
                                ],
                              ),
                              subtitle: Text('$email\nUpdated: $updated', maxLines: 2, overflow: TextOverflow.ellipsis),
                              onTap: () => _showUserAccessDetails(doc),
                              trailing: Switch(
                                value: isPremium,
                                onChanged: isActive ? (_) => _togglePremium(doc) : null,
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 105,
            child: Text(label, style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }

  Widget _stat(String title, int value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primary, size: 20),
          const SizedBox(height: 8),
          Text('$value', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          Text(title, style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}
