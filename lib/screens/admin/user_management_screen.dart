import 'package:cloud_firestore/cloud_firestore.dart';
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

class _AdminUser {
  final String documentId;
  final String uid;
  final String name;
  final String email;
  final String role;
  final String staffId;
  final String colourSeason;
  final String skinTone;
  final String photoUrl;
  final bool isActive;
  final bool isPremium;
  final DateTime? createdAt;

  const _AdminUser({
    required this.documentId,
    required this.uid,
    required this.name,
    required this.email,
    required this.role,
    required this.staffId,
    required this.colourSeason,
    required this.skinTone,
    required this.photoUrl,
    required this.isActive,
    required this.isPremium,
    required this.createdAt,
  });

  factory _AdminUser.fromDocument(DocumentSnapshot<Map<String, dynamic>> document) {
    final data = document.data() ?? const <String, dynamic>{};
    final rawRole = (data['role'] ?? 'customer').toString().trim().toLowerCase();
    final role = rawRole == 'staff' ? 'consultant' : rawRole;
    final created = data['createdAt'];

    return _AdminUser(
      documentId: document.id,
      uid: (data['uid'] ?? document.id).toString(),
      name: (data['name'] ?? 'Unknown User').toString(),
      email: (data['email'] ?? 'No email').toString(),
      role: role,
      staffId: (data['staffId'] ?? '').toString(),
      colourSeason: (data['colourSeason'] ?? 'Not analysed').toString(),
      skinTone: (data['skinTone'] ?? 'Not analysed').toString(),
      photoUrl: (data['photoUrl'] ?? '').toString(),
      isActive: data['isActive'] is bool ? data['isActive'] as bool : true,
      isPremium: data['isPremium'] is bool ? data['isPremium'] as bool : false,
      createdAt: created is Timestamp ? created.toDate() : null,
    );
  }
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final TextEditingController searchController = TextEditingController();
  List<_AdminUser> users = const [];
  bool isLoading = true;
  bool isDeleting = false;
  String? loadError;
  String selectedStatus = 'All';
  String selectedRole = 'All';

  @override
  void initState() {
    super.initState();
    searchController.addListener(_refreshSearch);
    loadUsers();
  }

  @override
  void dispose() {
    searchController.removeListener(_refreshSearch);
    searchController.dispose();
    super.dispose();
  }

  void _refreshSearch() {
    if (mounted) setState(() {});
  }

  List<_AdminUser> get filteredUsers {
    final query = searchController.text.trim().toLowerCase();
    final roleFilter = selectedRole.toLowerCase() == 'staff' ? 'consultant' : selectedRole.toLowerCase();

    return users.where((user) {
      final matchesSearch = query.isEmpty ||
          user.name.toLowerCase().contains(query) ||
          user.email.toLowerCase().contains(query) ||
          user.role.toLowerCase().contains(query) ||
          user.uid.toLowerCase().contains(query) ||
          user.staffId.toLowerCase().contains(query);
      final matchesStatus = selectedStatus == 'All' ||
          (selectedStatus == 'Active' && user.isActive) ||
          (selectedStatus == 'Inactive' && !user.isActive);
      final matchesRole = selectedRole == 'All' || user.role == roleFilter;
      return matchesSearch && matchesStatus && matchesRole;
    }).toList(growable: false);
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
          .get(const GetOptions(source: Source.server));

      final loadedUsers = snapshot.docs.map(_AdminUser.fromDocument).toList(growable: true)
        ..sort((a, b) {
          final aDate = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          final bDate = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          return bDate.compareTo(aDate);
        });

      if (!mounted) return;
      setState(() {
        users = loadedUsers;
        isLoading = false;
      });
    } on FirebaseException catch (error) {
      if (!mounted) return;
      setState(() {
        isLoading = false;
        loadError = '${error.code}: ${error.message ?? 'Unable to load users.'}';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        isLoading = false;
        loadError = error.toString();
      });
    }
  }

  void changeStatusFilter(String value) => setState(() => selectedStatus = value);
  void changeRoleFilter(String value) => setState(() => selectedRole = value);

  Future<void> toggleUserStatus(_AdminUser user) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(user.documentId).update({
        'isActive': !user.isActive,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      await loadUsers();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(user.isActive ? 'User account deactivated.' : 'User account activated.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update user: $error')),
      );
    }
  }

  Future<void> showUserDetails(_AdminUser user) async {
    final document = await FirebaseFirestore.instance.collection('users').doc(user.documentId).get();
    if (!mounted || !document.exists) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CustomerDetailScreen(userDocument: document)),
    );
    if (mounted) await loadUsers();
  }

  Future<void> deleteCustomer(_AdminUser user) async {
    if (isDeleting || user.role != 'customer') return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Customer?'),
        content: Text('This permanently removes the customer Firebase data.\n\n${user.name}\n${user.email}'),
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
    try {
      final result = await FirestoreService.deleteCustomerData(user.documentId);
      if (result.imageUrls.isNotEmpty) {
        await Future.wait(
          result.imageUrls.map((url) async {
            try {
              await StorageService.deleteImageByUrl(url);
            } catch (_) {}
          }),
        );
      }
      await loadUsers();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Deleted ${result.wardrobeItemsDeleted} wardrobe, ${result.preferencesDeleted} preference and ${result.analysisRecordsDeleted} analysis record(s).')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not delete customer: $error')));
    } finally {
      if (mounted) setState(() => isDeleting = false);
    }
  }

  Widget _statusChip(String text, Color background, Color foreground) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(20)),
      child: Text(text, style: TextStyle(color: foreground, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  Widget _userCard(_AdminUser user) {
    final isCustomer = user.role == 'customer';

    return Card(
      elevation: 0,
      color: AppColors.surface,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: AppColors.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => showUserDetails(user),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: AppColors.secondary,
                    child: user.photoUrl.isEmpty
                        ? const Icon(Icons.person, color: AppColors.primary, size: 28)
                        : ClipOval(
                            child: Image.network(
                              user.photoUrl,
                              width: 56,
                              height: 56,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Icon(Icons.person, color: AppColors.primary, size: 28),
                            ),
                          ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(user.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 4),
                        Text(user.email, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 5,
                          children: [
                            _statusChip(user.role.toUpperCase(), AppColors.surfaceMuted, AppColors.primaryDark),
                            _statusChip(
                              user.isActive ? 'ACTIVE' : 'INACTIVE',
                              user.isActive ? AppColors.success.withValues(alpha: .12) : AppColors.error.withValues(alpha: .12),
                              user.isActive ? AppColors.success : AppColors.error,
                            ),
                            if (user.isPremium) _statusChip('PREMIUM', AppColors.premiumAccentLight, AppColors.premiumAccentDark),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: AppColors.surfaceMuted, borderRadius: BorderRadius.circular(12)),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        isCustomer ? 'Season: ${user.colourSeason}' : 'Role: ${user.role == 'admin' ? 'Administrator' : 'Staff'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        isCustomer ? 'Skin: ${user.skinTone}' : (user.isActive ? 'Active' : 'Inactive'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.end,
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      user.createdAt == null
                          ? 'Created date unavailable'
                          : 'Joined ${user.createdAt!.day.toString().padLeft(2, '0')}/${user.createdAt!.month.toString().padLeft(2, '0')}/${user.createdAt!.year}',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => showUserDetails(user),
                    icon: const Icon(Icons.visibility_outlined, size: 17),
                    label: const Text('View'),
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    tooltip: user.isActive ? 'Deactivate account' : 'Activate account',
                    onPressed: isDeleting ? null : () => toggleUserStatus(user),
                    icon: Icon(user.isActive ? Icons.block_outlined : Icons.check_circle_outline, color: user.isActive ? AppColors.error : AppColors.success),
                  ),
                  if (isCustomer)
                    IconButton(
                      tooltip: 'Delete customer data',
                      onPressed: isDeleting ? null : () => deleteCustomer(user),
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

  Widget _emptyState() {
    final hasFilters = searchController.text.trim().isNotEmpty || selectedStatus != 'All' || selectedRole != 'All';
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 90, 20, 24),
      children: [
        Icon(hasFilters ? Icons.search_off_rounded : Icons.people_outline_rounded, size: 64, color: AppColors.textSecondary),
        const SizedBox(height: 16),
        Center(child: Text(hasFilters ? 'No matching users' : 'No users found', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800))),
        const SizedBox(height: 6),
        Center(child: Text(hasFilters ? 'Try changing the search or filters.' : 'No user documents were returned from Firestore.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary))),
      ],
    );
  }

  Widget _errorState() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 80),
        const Icon(Icons.cloud_off_rounded, size: 64),
        const SizedBox(height: 16),
        const Center(child: Text('Unable to load users', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800))),
        const SizedBox(height: 8),
        Text(loadError ?? 'Unknown Firestore error.', textAlign: TextAlign.center),
        const SizedBox(height: 18),
        Center(child: FilledButton.icon(onPressed: loadUsers, icon: const Icon(Icons.refresh_rounded), label: const Text('Retry'))),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final results = filteredUsers;
    return Scaffold(
      appBar: AppBar(
        title: const Text('User Management'),
        actions: [
          IconButton(tooltip: 'Refresh', onPressed: isLoading ? null : loadUsers, icon: const Icon(Icons.refresh)),
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
                  suffixIcon: searchController.text.isNotEmpty ? IconButton(onPressed: searchController.clear, icon: const Icon(Icons.clear)) : null,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              child: Row(
                children: [
                  _filterChip('All'), const SizedBox(width: 8),
                  _filterChip('Active'), const SizedBox(width: 8),
                  _filterChip('Inactive'), const SizedBox(width: 18),
                  const Text('Role:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)), const SizedBox(width: 8),
                  _roleFilterChip('All'), const SizedBox(width: 8),
                  _roleFilterChip('customer'), const SizedBox(width: 8),
                  _roleFilterChip('staff'), const SizedBox(width: 8),
                  _roleFilterChip('admin'),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Row(
                children: [
                  Text('${results.length} shown', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                  const Spacer(),
                  Text('Total: ${users.length}', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                ],
              ),
            ),
            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : loadError != null
                      ? _errorState()
                      : results.isEmpty
                          ? _emptyState()
                          : ListView.separated(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                              itemCount: results.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 2),
                              itemBuilder: (context, index) => _userCard(results[index]),
                            ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterChip(String label) {
    return FilterChip(
      label: Text(label),
      showCheckmark: false,
      selected: selectedStatus == label,
      onSelected: (_) => changeStatusFilter(label),
    );
  }

  Widget _roleFilterChip(String label) {
    return FilterChip(
      label: Text(label),
      showCheckmark: false,
      selected: selectedRole == label,
      onSelected: (_) => changeRoleFilter(label),
    );
  }
}
