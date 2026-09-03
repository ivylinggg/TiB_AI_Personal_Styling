import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../services/firestore_service.dart';
import '../../services/storage_service.dart';
import 'customer_detail_screen.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final TextEditingController searchController = TextEditingController();
  List<QueryDocumentSnapshot<Map<String, dynamic>>> users = [];
  List<QueryDocumentSnapshot<Map<String, dynamic>>> filteredUsers = [];
  bool isLoading = true;
  bool isDeleting = false;
  String selectedStatus = 'All';
  String selectedRole = 'All';
  String? loadError;

  @override
  void initState() {
    super.initState();
    loadUsers();
    searchController.addListener(filterUsers);
  }

  @override
  void dispose() {
    searchController.removeListener(filterUsers);
    searchController.dispose();
    super.dispose();
  }

  Future<void> loadUsers() async {
    if (mounted) {
      setState(() {
        isLoading = true;
        loadError = null;
      });
    }

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .get();

      final documents = snapshot.docs.toList()
        ..sort((a, b) {
          final aTimestamp = a.data()['createdAt'];
          final bTimestamp = b.data()['createdAt'];
          if (aTimestamp is Timestamp && bTimestamp is Timestamp) {
            return bTimestamp.compareTo(aTimestamp);
          }
          if (aTimestamp is Timestamp) return -1;
          if (bTimestamp is Timestamp) return 1;
          return 0;
        });

      if (!mounted) return;
      setState(() {
        users = documents;
        isLoading = false;
      });
      filterUsers();
    } on FirebaseException catch (error) {
      if (!mounted) return;
      setState(() {
        isLoading = false;
        loadError = error.message ?? 'We could not load the users.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        isLoading = false;
        loadError = 'We could not load the users. Please try again.';
      });
    }
  }

  void filterUsers() {
    if (!mounted) return;
    final query = searchController.text.trim().toLowerCase();
    final result = users.where((document) {
      final data = document.data();
      final name = (data['name'] as String? ?? '').toLowerCase();
      final email = (data['email'] as String? ?? '').toLowerCase();
      final role = (data['role'] as String? ?? 'customer').toLowerCase();
      final uid = (data['uid'] as String? ?? document.id).toLowerCase();
      final staffId = (data['staffId'] as String? ?? '').toLowerCase();
      final isActive = data['isActive'] as bool? ?? true;

      final matchesSearch = query.isEmpty ||
          name.contains(query) ||
          email.contains(query) ||
          role.contains(query) ||
          uid.contains(query) ||
          staffId.contains(query);
      final matchesStatus = selectedStatus == 'All' ||
          (selectedStatus == 'Active' && isActive) ||
          (selectedStatus == 'Inactive' && !isActive);
      final normalizedRole = role == 'staff' ? 'staff' : role;
      final matchesRole = selectedRole == 'All' ||
          normalizedRole == selectedRole.toLowerCase();

      return matchesSearch && matchesStatus && matchesRole;
    }).toList();

    setState(() => filteredUsers = result);
  }

  void changeStatusFilter(String status) {
    setState(() => selectedStatus = status);
    filterUsers();
  }

  void changeRoleFilter(String role) {
    setState(() => selectedRole = role);
    filterUsers();
  }

  Future<void> toggleUserStatus(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) async {
    final currentStatus = document.data()['isActive'] as bool? ?? true;
    final newStatus = !currentStatus;
    try {
      await document.reference.update({
        'isActive': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      await loadUsers();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(newStatus ? 'User account activated.' : 'User account deactivated.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not update this user. Please try again.')),
      );
    }
  }

  Future<void> showUserDetails(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CustomerDetailScreen(userDocument: document)),
    );
    if (mounted) await loadUsers();
  }

  Future<void> deleteCustomer(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) async {
    if (isDeleting) return;

    final data = document.data();
    final name = data['name'] as String? ?? 'Unknown User';
    final email = data['email'] as String? ?? 'No email';
    final userId = data['uid'] as String? ?? document.id;
    final role = (data['role'] as String? ?? 'customer').toLowerCase();

    if (FirebaseAuth.instance.currentUser?.uid == userId) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You cannot delete your own administrator account here.')),
      );
      return;
    }

    if (role != 'customer') {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Staff and administrator accounts cannot be deleted from User Management.')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Customer?'),
        content: Text(
          'This permanently removes the customer data stored in Firestore, including profile, wardrobe, preferences, saved looks, analysis history and consultation history.\n\n$name\n$email',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete Permanently'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => isDeleting = true);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(
          children: [
            SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5)),
            SizedBox(width: 20),
            Expanded(child: Text('Deleting customer...')),
          ],
        ),
      ),
    );

    CustomerDeletionResult? result;
    Object? deletionError;
    try {
      result = await FirestoreService.deleteCustomerData(userId);
    } catch (e) {
      deletionError = e;
    }

    if (result != null && result.imageUrls.isNotEmpty) {
      await Future.wait(
        result.imageUrls.map((url) async {
          try {
            await StorageService.deleteImageByUrl(url);
          } catch (_) {}
        }),
      );
    }

    if (mounted) Navigator.of(context, rootNavigator: true).pop();

    if (result != null) {
      if (!mounted) return;
      await loadUsers();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Customer deleted: ${result.wardrobeItemsDeleted} wardrobe, ${result.preferencesDeleted} preference and ${result.analysisRecordsDeleted} analysis record(s) removed.',
          ),
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not fully delete this customer. Please refresh and try again. ${deletionError ?? ''}')),
      );
    }

    if (mounted) setState(() => isDeleting = false);
  }

  Widget _statusChip(String text, Color background, Color foreground) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(20)),
      child: Text(text, style: TextStyle(color: foreground, fontSize: 10, fontWeight: FontWeight.w800)),
    );
  }

  Widget _filterChip(String label) {
    final isSelected = selectedStatus == label;
    return FilterChip(
      label: Text(label),
      showCheckmark: false,
      selected: isSelected,
      onSelected: (_) => changeStatusFilter(label),
    );
  }

  Widget _roleFilterChip(String label) {
    final isSelected = selectedRole == label;
    return FilterChip(
      label: Text(label),
      showCheckmark: false,
      selected: isSelected,
      onSelected: (_) => changeRoleFilter(label),
    );
  }

  Widget _buildUserCard(QueryDocumentSnapshot<Map<String, dynamic>> document) {
    final data = document.data();
    final name = data['name'] as String? ?? 'Unknown User';
    final email = data['email'] as String? ?? 'No email';
    final role = (data['role'] as String? ?? 'customer').toLowerCase();
    final isActive = data['isActive'] as bool? ?? true;
    final isPremium = data['isPremium'] as bool? ?? false;
    final colourSeason = data['colourSeason'] as String? ?? 'Not analysed';
    final skinTone = data['skinTone'] as String? ?? 'Not analysed';
    final photoUrl = data['photoUrl'] as String? ?? '';
    final staffId = data['staffId'] as String? ?? '';
    final createdAt = data['createdAt'];
    final isCustomer = role == 'customer';

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: const BorderSide(color: AppColors.border)),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => showUserDetails(document),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: AppColors.secondary,
                    backgroundImage: photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                    child: photoUrl.isEmpty ? Icon(isCustomer ? Icons.person : Icons.badge_outlined, color: AppColors.primary, size: 28) : null,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 4),
                        Text(email, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                        if (staffId.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text('Staff ID: $staffId', style: TextStyle(color: AppColors.primaryDark, fontSize: 11, fontWeight: FontWeight.w700)),
                        ],
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 5,
                          children: [
                            _statusChip(role == 'consultant' || role == 'staff' ? 'STAFF' : role.toUpperCase(), AppColors.surfaceMuted, AppColors.primaryDark),
                            _statusChip(isActive ? 'ACTIVE' : 'INACTIVE', isActive ? AppColors.success.withValues(alpha: .12) : AppColors.error.withValues(alpha: .12), isActive ? AppColors.success : AppColors.error),
                            if (isPremium) _statusChip('PREMIUM', AppColors.premiumAccentLight, AppColors.premiumAccentDark),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios_rounded, size: 15),
                ],
              ),
              if (isCustomer) ...[
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(child: _smallInfo(Icons.palette_outlined, 'Colour Season', colourSeason)),
                    const SizedBox(width: 12),
                    Expanded(child: _smallInfo(Icons.face_outlined, 'Skin Tone', skinTone)),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: Text(_formatCreatedAt(createdAt), style: TextStyle(color: AppColors.textSecondary, fontSize: 11))),
                  OutlinedButton.icon(onPressed: () => showUserDetails(document), icon: const Icon(Icons.visibility_outlined, size: 17), label: const Text('View')),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: isActive ? 'Disable account' : 'Activate account',
                    onPressed: isDeleting ? null : () => toggleUserStatus(document),
                    icon: Icon(isActive ? Icons.block_outlined : Icons.check_circle_outline, color: isActive ? AppColors.error : AppColors.success),
                  ),
                  if (isCustomer)
                    IconButton(
                      tooltip: 'Delete customer data',
                      onPressed: isDeleting ? null : () => deleteCustomer(document),
                      icon: const Icon(Icons.delete_outline, color: AppColors.error),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatCreatedAt(dynamic value) {
    DateTime? date;
    if (value is Timestamp) date = value.toDate();
    if (value is DateTime) date = value;
    if (date == null) return 'Created date unavailable';
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return 'Joined $day/$month/${date.year}';
  }

  Widget _smallInfo(IconData icon, String title, String value) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: AppColors.surfaceMuted, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Icon(icon, size: 19, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                const SizedBox(height: 2),
                Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummary() {
    final activeCount = users.where((doc) => doc.data()['isActive'] as bool? ?? true).length;
    final customerCount = users.where((doc) => (doc.data()['role'] as String? ?? 'customer').toLowerCase() == 'customer').length;
    final staffCount = users.where((doc) {
      final role = (doc.data()['role'] as String? ?? '').toLowerCase();
      return role == 'staff' || role == 'consultant';
    }).length;

    return Row(
      children: [
        Expanded(child: _summaryCard('Customers', '$customerCount', Icons.people_outline)),
        const SizedBox(width: 8),
        Expanded(child: _summaryCard('Staff', '$staffCount', Icons.badge_outlined)),
        const SizedBox(width: 8),
        Expanded(child: _summaryCard('Active', '$activeCount', Icons.verified_user_outlined)),
      ],
    );
  }

  Widget _summaryCard(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 13),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Icon(icon, size: 20, color: AppColors.primary),
          const SizedBox(height: 5),
          Text(value, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
          Text(label, style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final showingFiltered = selectedStatus != 'All' || selectedRole != 'All' || searchController.text.trim().isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('User Management'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: isLoading ? null : loadUsers,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _loadingBody(showingFiltered),
    );
  }

  Widget _loadingBody(bool showingFiltered) {
    if (isLoading && users.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (loadError != null && users.isEmpty) {
      return _buildError();
    }

    return RefreshIndicator(
      onRefresh: loadUsers,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        children: [
          _buildSummary(),
          const SizedBox(height: 14),
          TextField(
            controller: searchController,
            decoration: InputDecoration(
              hintText: 'Search name, email, role, Staff ID or UID',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: searchController.text.isEmpty
                  ? null
                  : IconButton(onPressed: searchController.clear, icon: const Icon(Icons.clear_rounded)),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _filterChip('All'), const SizedBox(width: 8),
                _filterChip('Active'), const SizedBox(width: 8),
                _filterChip('Inactive'),
                const SizedBox(width: 18),
                const Text('Role:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                const SizedBox(width: 8),
                _roleFilterChip('All'), const SizedBox(width: 8),
                _roleFilterChip('customer'), const SizedBox(width: 8),
                _roleFilterChip('staff'), const SizedBox(width: 8),
                _roleFilterChip('admin'),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Text(showingFiltered ? 'Matching users' : 'All users', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
              const Spacer(),
              Text('${filteredUsers.length} of ${users.length}', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 10),
          if (filteredUsers.isEmpty)
            _buildEmptyState()
          else
            ...filteredUsers.map(_buildUserCard),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    final hasUsers = users.isNotEmpty;
    return Container(
      margin: const EdgeInsets.only(top: 30),
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(color: AppColors.surfaceMuted, borderRadius: BorderRadius.circular(18)),
      child: Column(
        children: [
          const Icon(Icons.people_outline_rounded, size: 50, color: AppColors.primary),
          const SizedBox(height: 12),
          Text(hasUsers ? 'No users match these filters' : 'No users found', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800), textAlign: TextAlign.center),
          const SizedBox(height: 6),
          Text(hasUsers ? 'Try another search or filter.' : 'Users will appear here once a customer or staff profile exists.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5)),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 48),
            const SizedBox(height: 12),
            const Text('Unable to load users', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(loadError ?? 'Please check your connection and try again.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 16),
            FilledButton.icon(onPressed: loadUsers, icon: const Icon(Icons.refresh_rounded), label: const Text('Try Again')),
          ],
        ),
      ),
    );
  }
}