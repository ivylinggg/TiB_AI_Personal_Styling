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

  @override
  void initState() {
    super.initState();
    loadUsers();
    searchController.addListener(_applyFilters);
  }

  @override
  void dispose() {
    searchController.removeListener(_applyFilters);
    searchController.dispose();
    super.dispose();
  }

  Future<void> loadUsers() async {
    if (mounted) setState(() => isLoading = true);
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .get(const GetOptions(source: Source.server));

      final documents = snapshot.docs.toList()
        ..sort((a, b) {
          final aValue = a.data()['createdAt'];
          final bValue = b.data()['createdAt'];
          final aDate = aValue is Timestamp
              ? aValue.toDate()
              : DateTime.fromMillisecondsSinceEpoch(0);
          final bDate = bValue is Timestamp
              ? bValue.toDate()
              : DateTime.fromMillisecondsSinceEpoch(0);
          return bDate.compareTo(aDate);
        });

      if (!mounted) return;
      final results = _filterDocuments(documents);
      setState(() {
        users = documents;
        filteredUsers = results;
        isLoading = false;
      });
    } on FirebaseException catch (error) {
      if (!mounted) return;
      setState(() {
        isLoading = false;
        filteredUsers = [];
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'We couldn’t load users: ${error.message ?? error.code}',
          ),
          action: SnackBarAction(label: 'Retry', onPressed: loadUsers),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        isLoading = false;
        filteredUsers = [];
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('We couldn’t load the users: $error'),
          action: SnackBarAction(label: 'Retry', onPressed: loadUsers),
        ),
      );
    }
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _filterDocuments(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> source,
  ) {
    final query = searchController.text.trim().toLowerCase();

    return source.where((document) {
      final data = document.data();
      final name = (data['name'] ?? '').toString().toLowerCase();
      final email = (data['email'] ?? '').toString().toLowerCase();
      final role = (data['role'] ?? 'customer').toString().toLowerCase();
      final uid = (data['uid'] ?? document.id).toString().toLowerCase();
      final staffId = (data['staffId'] ?? '').toString().toLowerCase();
      final isActive = data['isActive'] is bool ? data['isActive'] as bool : true;

      final normalizedRole = role == 'staff' ? 'consultant' : role;
      final selectedNormalizedRole = selectedRole.toLowerCase() == 'staff'
          ? 'consultant'
          : selectedRole.toLowerCase();

      final matchesSearch = query.isEmpty ||
          name.contains(query) ||
          email.contains(query) ||
          role.contains(query) ||
          normalizedRole.contains(query) ||
          uid.contains(query) ||
          staffId.contains(query);

      final matchesStatus = selectedStatus == 'All' ||
          (selectedStatus == 'Active' && isActive) ||
          (selectedStatus == 'Inactive' && !isActive);

      final matchesRole = selectedRole == 'All' ||
          normalizedRole == selectedNormalizedRole;

      return matchesSearch && matchesStatus && matchesRole;
    }).toList();
  }

  void _applyFilters() {
    if (!mounted) return;
    final results = _filterDocuments(users);
    setState(() => filteredUsers = results);
  }

  void changeStatusFilter(String status) {
    if (selectedStatus == status) return;
    setState(() => selectedStatus = status);
    _applyFilters();
  }

  void changeRoleFilter(String role) {
    if (selectedRole == role) return;
    setState(() => selectedRole = role);
    _applyFilters();
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
      if (!mounted) return;
      await loadUsers();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            newStatus
                ? 'User account activated.'
                : 'User account deactivated.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update this user: $error')),
      );
    }
  }

  Future<void> showUserDetails(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CustomerDetailScreen(userDocument: document),
      ),
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

    if (role != 'customer') {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Only customer accounts can be deleted from this page.',
          ),
        ),
      );
      return;
    }

    if (FirebaseAuth.instance.currentUser?.uid == userId) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You cannot delete your own admin account here.'),
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Customer?'),
        content: Text(
          'This permanently removes the customer’s Firebase data, including profile, wardrobe, preferences, saved looks, analysis history and consultation history.\n\n$name\n$email',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
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
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
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

    if (mounted) {
      Navigator.of(context, rootNavigator: true).pop();
    }

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
        SnackBar(
          content: Text(
            'Could not fully delete this customer. Please refresh and try again. (${deletionError ?? 'Unknown error'})',
          ),
        ),
      );
    }

    if (mounted) setState(() => isDeleting = false);
  }

  Widget _statusChip(String text, Color background, Color foreground) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: foreground,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
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

  Widget _buildUserCard(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();
    final name = data['name'] as String? ?? 'Unknown User';
    final email = data['email'] as String? ?? 'No email';
    final role = data['role'] as String? ?? 'customer';
    final normalizedRole = role.toLowerCase() == 'staff'
        ? 'consultant'
        : role.toLowerCase();
    final isActive = data['isActive'] as bool? ?? true;
    final isPremium = data['isPremium'] as bool? ?? false;
    final colourSeason = data['colourSeason'] as String? ?? 'Not analysed';
    final skinTone = data['skinTone'] as String? ?? 'Not analysed';
    final staffId = data['staffId'] as String? ?? '';
    final createdAt = data['createdAt'];
    final photoUrl = data['photoUrl'] as String? ?? '';
    final isCustomer = normalizedRole == 'customer';

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: AppColors.border),
      ),
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
                    backgroundImage:
                        photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                    child: photoUrl.isEmpty
                        ? const Icon(
                            Icons.person,
                            color: AppColors.primary,
                            size: 28,
                          )
                        : null,
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
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          email,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                        if (staffId.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Staff ID: $staffId',
                            style: TextStyle(
                              color: AppColors.primaryDark,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 5,
                          children: [
                            _statusChip(
                              normalizedRole.toUpperCase(),
                              AppColors.surfaceMuted,
                              AppColors.primaryDark,
                            ),
                            _statusChip(
                              isActive ? 'ACTIVE' : 'INACTIVE',
                              isActive
                                  ? AppColors.success.withValues(alpha: .12)
                                  : AppColors.error.withValues(alpha: .12),
                              isActive ? AppColors.success : AppColors.error,
                            ),
                            if (isPremium)
                              _statusChip(
                                'PREMIUM',
                                AppColors.premiumAccentLight,
                                AppColors.premiumAccentDark,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios, size: 15),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  if (isCustomer) ...[
                    Expanded(
                      child: _smallInfo(
                        Icons.palette_outlined,
                        'Colour Season',
                        colourSeason,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _smallInfo(
                        Icons.face_outlined,
                        'Skin Tone',
                        skinTone,
                      ),
                    ),
                  ] else ...[
                    Expanded(
                      child: _smallInfo(
                        Icons.badge_outlined,
                        'Role',
                        normalizedRole == 'admin' ? 'Administrator' : 'Staff',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _smallInfo(
                        Icons.verified_user_outlined,
                        'Status',
                        isActive ? 'Active' : 'Inactive',
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _formatCreatedAt(createdAt),
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => showUserDetails(document),
                    icon: const Icon(Icons.visibility_outlined, size: 17),
                    label: const Text('View'),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip:
                        isActive ? 'Disable account' : 'Activate account',
                    onPressed:
                        isDeleting ? null : () => toggleUserStatus(document),
                    icon: Icon(
                      isActive
                          ? Icons.block_outlined
                          : Icons.check_circle_outline,
                      color: isActive
                          ? AppColors.error
                          : AppColors.success,
                    ),
                  ),
                  if (isCustomer)
                    IconButton(
                      tooltip: 'Delete customer data',
                      onPressed:
                          isDeleting ? null : () => deleteCustomer(document),
                      icon: const Icon(
                        Icons.delete_outline,
                        color: AppColors.error,
                      ),
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
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 19, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState() {
    final hasFilters = searchController.text.trim().isNotEmpty ||
        selectedStatus != 'All' ||
        selectedRole != 'All';

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 90, 20, 24),
      children: [
        Icon(
          hasFilters ? Icons.search_off_rounded : Icons.people_outline_rounded,
          size: 64,
          color: AppColors.textSecondary,
        ),
        const SizedBox(height: 16),
        Center(
          child: Text(
            hasFilters ? 'No matching users' : 'No users found',
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
          ),
        ),
        const SizedBox(height: 6),
        Center(
          child: Text(
            hasFilters
                ? 'Try changing the search or filters.'
                : 'There are no user documents available in Firestore.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('User Management'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: isLoading ? null : loadUsers,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: loadUsers,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
              child: TextField(
                controller: searchController,
                decoration: InputDecoration(
                  hintText: 'Search name, email, role, UID or Staff ID',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: searchController.text.isNotEmpty
                      ? IconButton(
                          onPressed: searchController.clear,
                          icon: const Icon(Icons.clear),
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              child: Row(
                children: [
                  _filterChip('All'),
                  const SizedBox(width: 8),
                  _filterChip('Active'),
                  const SizedBox(width: 8),
                  _filterChip('Inactive'),
                  const SizedBox(width: 18),
                  const Text(
                    'Role:',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(width: 8),
                  _roleFilterChip('All'),
                  const SizedBox(width: 8),
                  _roleFilterChip('customer'),
                  const SizedBox(width: 8),
                  _roleFilterChip('staff'),
                  const SizedBox(width: 8),
                  _roleFilterChip('admin'),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Row(
                children: [
                  Text(
                    '${filteredUsers.length} shown',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Total: ${users.length}',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : filteredUsers.isEmpty
                      ? _emptyState()
                      : ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                          itemCount: filteredUsers.length,
                          itemBuilder: (context, index) =>
                              _buildUserCard(filteredUsers[index]),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
