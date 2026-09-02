import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';

class StaffManagementScreen extends StatefulWidget {
  const StaffManagementScreen({super.key});

  @override
  State<StaffManagementScreen> createState() => _StaffManagementScreenState();
}

class _StaffManagementScreenState extends State<StaffManagementScreen> {
  final TextEditingController searchController = TextEditingController();
  List<QueryDocumentSnapshot<Map<String, dynamic>>> staff = [];
  List<QueryDocumentSnapshot<Map<String, dynamic>>> filteredStaff = [];
  bool isLoading = true;
  bool isSaving = false;
  String selectedStatus = 'All';

  @override
  void initState() {
    super.initState();
    loadStaff();
    searchController.addListener(filterStaff);
  }

  @override
  void dispose() {
    searchController.removeListener(filterStaff);
    searchController.dispose();
    super.dispose();
  }

  Future<void> loadStaff() async {
    try {
      if (mounted) setState(() => isLoading = true);
      final snapshot = await FirebaseFirestore.instance.collection('users').get();
      if (!mounted) return;

      final staffDocs = snapshot.docs.where((document) {
        final role = (document.data()['role'] as String? ?? 'customer').toLowerCase();
        return role == 'consultant' || role == 'staff' || role == 'admin';
      }).toList()
        ..sort((a, b) {
          final aName = (a.data()['name'] as String? ?? '').toLowerCase();
          final bName = (b.data()['name'] as String? ?? '').toLowerCase();
          return aName.compareTo(bName);
        });

      setState(() {
        staff = staffDocs;
        isLoading = false;
      });
      filterStaff();
    } catch (_) {
      if (!mounted) return;
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Couldn’t load staff. Please try again.')),
      );
    }
  }

  void filterStaff() {
    if (!mounted) return;
    final query = searchController.text.trim().toLowerCase();
    final filtered = staff.where((document) {
      final data = document.data();
      final name = (data['name'] as String? ?? '').toLowerCase();
      final email = (data['email'] as String? ?? '').toLowerCase();
      final role = (data['role'] as String? ?? '').toLowerCase();
      final uid = document.id.toLowerCase();
      final active = data['isActive'] as bool? ?? true;

      final matchesSearch = query.isEmpty ||
          name.contains(query) ||
          email.contains(query) ||
          role.contains(query) ||
          uid.contains(query);
      final matchesStatus = selectedStatus == 'All' ||
          (selectedStatus == 'Active' && active) ||
          (selectedStatus == 'Inactive' && !active);
      return matchesSearch && matchesStatus;
    }).toList();

    setState(() => filteredStaff = filtered);
  }

  Future<void> toggleActive(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (document.id == currentUserId && (document.data()['role'] ?? '') == 'admin') {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You cannot deactivate your own administrator account.')),
      );
      return;
    }

    final data = document.data();
    final current = data['isActive'] as bool? ?? true;
    try {
      await document.reference.update({
        'isActive': !current,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      await loadStaff();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(!current ? 'Staff account activated.' : 'Staff account deactivated.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not update this staff account.')),
      );
    }
  }

  Future<void> sendPasswordReset(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) async {
    final email = (document.data()['email'] as String? ?? '').trim();
    final name = document.data()['name'] as String? ?? 'this staff member';
    if (email.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This staff account has no email address.')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Send Password Reset?'),
        content: Text('A password reset link will be sent to $email for $name.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Send Email'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Password reset email sent to $email.')),
      );
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not send reset email: ${error.message ?? error.code}.')),
      );
    }
  }

  Future<void> editStaff(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) async {
    final data = document.data();
    final nameController = TextEditingController(text: data['name'] as String? ?? '');
    final emailController = TextEditingController(text: data['email'] as String? ?? '');
    var selectedRole = ((data['role'] as String?) ?? 'consultant').toLowerCase();
    if (selectedRole == 'staff') selectedRole = 'consultant';

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Edit Staff'),
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
                    initialValue: selectedRole,
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
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  final name = nameController.text.trim();
                  final email = emailController.text.trim();
                  if (name.isEmpty || email.isEmpty) return;
                  Navigator.pop(dialogContext, {
                    'name': name,
                    'email': email,
                    'role': selectedRole,
                  });
                },
                child: const Text('Save'),
              ),
            ],
          ),
        );
      },
    );

    nameController.dispose();
    emailController.dispose();
    if (result == null) return;

    final name = result['name'] ?? '';
    final email = result['email'] ?? '';
    final role = result['role'] ?? 'consultant';
    final currentEmail = (data['email'] as String? ?? '').trim();

    if (name.isEmpty || email.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name and email are required.')),
      );
      return;
    }

    setState(() => isSaving = true);
    try {
      await document.reference.update({
        'name': name,
        'role': role,
        'updatedAt': FieldValue.serverTimestamp(),
        if (email != currentEmail) 'email': email,
      });

      if (email != currentEmail && document.id == FirebaseAuth.instance.currentUser?.uid) {
        await FirebaseAuth.instance.currentUser!.verifyBeforeUpdateEmail(email);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Verification email sent. Verify the new email to complete the change.')),
        );
      } else if (email != currentEmail) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile email updated in Firestore. Firebase Auth email for another account requires privileged server-side access.')),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Staff profile updated.')),
        );
      }

      await loadStaff();
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update authentication email: ${error.message ?? error.code}.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save the staff profile.')),
      );
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  Widget _chip(String label, Color background, Color foreground) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foreground,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _buildCard(QueryDocumentSnapshot<Map<String, dynamic>> document) {
    final data = document.data();
    final name = data['name'] as String? ?? 'Unnamed Staff';
    final email = data['email'] as String? ?? 'No email';
    final role = (data['role'] as String? ?? 'consultant').toLowerCase();
    final active = data['isActive'] as bool? ?? true;
    final photoUrl = data['photoUrl'] as String?;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: AppColors.secondary,
              backgroundImage: photoUrl != null && photoUrl.isNotEmpty
                  ? NetworkImage(photoUrl)
                  : null,
              child: photoUrl == null || photoUrl.isEmpty
                  ? const Icon(Icons.person_outline_rounded, color: AppColors.primary)
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
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                  ),
                  const SizedBox(height: 9),
                  Wrap(
                    spacing: 6,
                    runSpacing: 5,
                    children: [
                      _chip(
                        role == 'admin' ? 'ADMIN' : 'CONSULTANT / STAFF',
                        AppColors.surfaceMuted,
                        AppColors.primaryDark,
                      ),
                      _chip(
                        active ? 'ACTIVE' : 'INACTIVE',
                        active
                            ? AppColors.success.withValues(alpha: .12)
                            : AppColors.error.withValues(alpha: .12),
                        active ? AppColors.success : AppColors.error,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              tooltip: 'Staff actions',
              onSelected: (value) {
                if (value == 'edit') editStaff(document);
                if (value == 'reset') sendPasswordReset(document);
                if (value == 'toggle') toggleActive(document);
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'edit', child: Text('Edit Profile')),
                const PopupMenuItem(value: 'reset', child: Text('Send Password Reset')),
                PopupMenuItem(
                  value: 'toggle',
                  child: Text(active ? 'Deactivate' : 'Activate'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  int _countActive() => staff.where((doc) => doc.data()['isActive'] as bool? ?? true).length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Staff Management'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: isLoading ? null : loadStaff,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: AbsorbPointer(
        absorbing: isSaving,
        child: RefreshIndicator(
          onRefresh: loadStaff,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                child: Row(
                  children: [
                    Expanded(child: _statCard('All', staff.length.toString(), Icons.groups_outlined)),
                    const SizedBox(width: 10),
                    Expanded(child: _statCard('Active', _countActive().toString(), Icons.verified_user_outlined)),
                    const SizedBox(width: 10),
                    Expanded(child: _statCard('Inactive', (staff.length - _countActive()).toString(), Icons.person_off_outlined)),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: TextField(
                  controller: searchController,
                  decoration: InputDecoration(
                    hintText: 'Search name, email, role or UID',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: searchController.text.isNotEmpty
                        ? IconButton(
                            onPressed: searchController.clear,
                            icon: const Icon(Icons.clear),
                          )
                        : null,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Row(
                  children: [
                    for (final status in const ['All', 'Active', 'Inactive']) ...[
                      FilterChip(
                        label: Text(status),
                        showCheckmark: false,
                        selected: selectedStatus == status,
                        onSelected: (_) {
                          setState(() => selectedStatus = status);
                          filterStaff();
                        },
                      ),
                      const SizedBox(width: 8),
                    ],
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${filteredStaff.length} staff member${filteredStaff.length == 1 ? '' : 's'}',
                    style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              Expanded(
                child: isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : filteredStaff.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: [
                              const SizedBox(height: 120),
                              Center(
                                child: Column(
                                  children: [
                                    Icon(Icons.groups_outlined, size: 56, color: AppColors.textSecondary),
                                    const SizedBox(height: 12),
                                    Text(
                                      'No staff found',
                                      style: TextStyle(
                                        color: AppColors.textSecondary,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          )
                        : ListView.builder(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                            itemCount: filteredStaff.length,
                            itemBuilder: (_, index) => _buildCard(filteredStaff[index]),
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statCard(String title, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 19, color: AppColors.primary),
          const SizedBox(height: 7),
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(title, style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}
