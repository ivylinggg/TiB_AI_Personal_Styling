import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';

class StaffManagementScreen extends StatefulWidget {
  const StaffManagementScreen({super.key});

  @override
  State<StaffManagementScreen> createState() => _StaffManagementScreenState();
}

class _StaffManagementScreenState extends State<StaffManagementScreen> {
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _busyIds = <String>{};

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _staff = const [];
  bool _isLoading = true;
  String _selectedStatus = 'All';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_refresh);
    _loadStaff();
  }

  @override
  void dispose() {
    _searchController.removeListener(_refresh);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadStaff() async {
    if (mounted) setState(() => _isLoading = true);
    try {
      final snapshot = await FirebaseFirestore.instance.collection('users').get();
      final staff = snapshot.docs.where((doc) {
        final role = (doc.data()['role'] as String? ?? 'customer').toLowerCase();
        return role == 'admin' || role == 'consultant' || role == 'staff';
      }).toList()
        ..sort((a, b) {
          final aName = (a.data()['name'] as String? ?? '').toLowerCase();
          final bName = (b.data()['name'] as String? ?? '').toLowerCase();
          return aName.compareTo(bName);
        });

      if (!mounted) return;
      setState(() {
        _staff = staff;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not load staff accounts. Please try again.')),
      );
    }
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> get _filteredStaff {
    final query = _searchController.text.trim().toLowerCase();
    return _staff.where((document) {
      final data = document.data();
      final name = (data['name'] as String? ?? '').toLowerCase();
      final email = (data['email'] as String? ?? '').toLowerCase();
      final uid = document.id.toLowerCase();
      final rawRole = (data['role'] as String? ?? 'consultant').toLowerCase();
      final role = rawRole == 'staff' ? 'consultant' : rawRole;
      final isActive = data['isActive'] as bool? ?? true;

      final matchesSearch = query.isEmpty ||
          name.contains(query) ||
          email.contains(query) ||
          uid.contains(query) ||
          role.contains(query);
      final matchesStatus = _selectedStatus == 'All' ||
          (_selectedStatus == 'Active' && isActive) ||
          (_selectedStatus == 'Inactive' && !isActive);
      return matchesSearch && matchesStatus;
    }).toList();
  }

  Future<void> _toggleStatus(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) async {
    final uid = document.id;
    if (_busyIds.contains(uid)) return;

    final current = document.data()['isActive'] as bool? ?? true;
    setState(() => _busyIds.add(uid));
    try {
      await document.reference.update({
        'isActive': !current,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      await _loadStaff();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(!current ? 'Staff account activated.' : 'Staff account deactivated.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not update this staff account.')),
      );
    } finally {
      if (mounted) setState(() => _busyIds.remove(uid));
    }
  }

  Future<void> _editStaff(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) async {
    final data = document.data();
    final nameController = TextEditingController(text: data['name'] as String? ?? '');
    final emailController = TextEditingController(text: data['email'] as String? ?? '');
    String selectedRole = (data['role'] as String? ?? 'consultant').toLowerCase();
    if (selectedRole == 'staff') selectedRole = 'consultant';

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit Staff Profile'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Name'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedRole,
                  decoration: const InputDecoration(labelText: 'Role'),
                  items: const [
                    DropdownMenuItem(value: 'consultant', child: Text('Consultant / Staff')),
                    DropdownMenuItem(value: 'admin', child: Text('Administrator')),
                  ],
                  onChanged: (value) {
                    if (value != null) setDialogState(() => selectedRole = value);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, {
                'name': nameController.text.trim(),
                'email': emailController.text.trim(),
                'role': selectedRole,
              }),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    nameController.dispose();
    emailController.dispose();
    if (result == null || !mounted) return;

    final name = result['name'] ?? '';
    final email = result['email'] ?? '';
    if (name.isEmpty || email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name and email cannot be empty.')),
      );
      return;
    }

    final uid = document.id;
    setState(() => _busyIds.add(uid));
    try {
      await document.reference.update({
        'name': name,
        'email': email,
        'role': result['role'] ?? 'consultant',
        'updatedAt': FieldValue.serverTimestamp(),
      });
      await _loadStaff();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Staff profile updated.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save the staff profile.')),
      );
    } finally {
      if (mounted) setState(() => _busyIds.remove(uid));
    }
  }

  void _showStaffDetails(QueryDocumentSnapshot<Map<String, dynamic>> document) {
    final data = document.data();
    final role = (data['role'] as String? ?? 'consultant').toLowerCase();
    final isActive = data['isActive'] as bool? ?? true;
    final createdAt = data['createdAt'];
    final date = createdAt is Timestamp ? createdAt.toDate() : null;

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(data['name'] as String? ?? 'Unnamed Staff', style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text(data['email'] as String? ?? 'No email', style: TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: 16),
              _detailTile('Role', role == 'admin' ? 'Administrator' : 'Consultant / Staff'),
              _detailTile('Status', isActive ? 'Active' : 'Inactive'),
              _detailTile('Staff UID', document.id),
              if (date != null) _detailTile('Joined', '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailTile(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
            const SizedBox(height: 3),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }

  Widget _roleChip(String role) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        role == 'admin' ? 'ADMIN' : 'STAFF',
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredStaff;
    final activeCount = _staff.where((d) => d.data()['isActive'] as bool? ?? true).length;
    final inactiveCount = _staff.length - activeCount;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Staff Management'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _isLoading ? null : _loadStaff,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadStaff,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          children: [
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: const BorderSide(color: AppColors.border)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(child: _stat('Total Staff', _staff.length.toString())),
                    Expanded(child: _stat('Active', activeCount.toString())),
                    Expanded(child: _stat('Inactive', inactiveCount.toString())),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search name, email or UID',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(onPressed: _searchController.clear, icon: const Icon(Icons.clear_rounded))
                    : null,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final status in const ['All', 'Active', 'Inactive']) ...[
                    FilterChip(
                      label: Text(status),
                      selected: _selectedStatus == status,
                      showCheckmark: false,
                      onSelected: (_) => setState(() => _selectedStatus = status),
                    ),
                    const SizedBox(width: 8),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 8),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.only(top: 100),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (filtered.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 100),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.badge_outlined, size: 48, color: AppColors.textSecondary),
                      const SizedBox(height: 12),
                      const Text('No staff accounts found', style: TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text('Try another search or status filter.', style: TextStyle(color: AppColors.textSecondary)),
                    ],
                  ),
                ),
              )
            else
              for (final document in filtered) _buildStaffCard(document),
          ],
        ),
      ),
    );
  }

  Widget _buildStaffCard(QueryDocumentSnapshot<Map<String, dynamic>> document) {
    final data = document.data();
    final uid = document.id;
    final role = (data['role'] as String? ?? 'consultant').toLowerCase();
    final isActive = data['isActive'] as bool? ?? true;
    final photoUrl = data['photoUrl'] as String?;
    final busy = _busyIds.contains(uid);

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(top: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: const BorderSide(color: AppColors.border)),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _showStaffDetails(document),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              CircleAvatar(
                radius: 25,
                backgroundImage: photoUrl != null && photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                child: photoUrl == null || photoUrl.isEmpty ? const Icon(Icons.person_outline_rounded) : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(data['name'] as String? ?? 'Unnamed Staff', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 3),
                    Text(data['email'] as String? ?? 'No email', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 5,
                      children: [
                        _roleChip(role),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                          decoration: BoxDecoration(
                            color: isActive ? AppColors.success.withValues(alpha: .12) : AppColors.error.withValues(alpha: .12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(isActive ? 'ACTIVE' : 'INACTIVE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: isActive ? AppColors.success : AppColors.error)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (busy)
                const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
              else
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'view') _showStaffDetails(document);
                    if (value == 'edit') _editStaff(document);
                    if (value == 'toggle') _toggleStatus(document);
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'view', child: Text('View Profile')),
                    const PopupMenuItem(value: 'edit', child: Text('Edit Profile')),
                    PopupMenuItem(value: 'toggle', child: Text(isActive ? 'Deactivate' : 'Activate')),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stat(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 3),
        Text(label, textAlign: TextAlign.center, style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
      ],
    );
  }
}
