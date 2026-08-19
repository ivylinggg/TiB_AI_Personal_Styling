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

  // ============================================================
  // LOAD USERS
  // ============================================================

  Future<void> loadUsers() async {
    try {
      if (mounted) {
        setState(() {
          isLoading = true;
        });
      }

      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .orderBy('createdAt', descending: true)
          .get();

      if (!mounted) {
      return;
    }

      setState(() {
        users = snapshot.docs;
        isLoading = false;
      });

      filterUsers();
    } catch (e) {
      if (!mounted) {
      return;
    }

      setState(() {
        isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'We couldn’t load the users. Please try again.',
          ),
        ),
      );
    }
  }

  // ============================================================
  // SEARCH + FILTER
  // ============================================================

  void filterUsers() {
    final query = searchController.text.trim().toLowerCase();

    if (!mounted) {
      return;
    }

    setState(() {
      filteredUsers = users.where((document) {
        final data = document.data();

        final name = (data['name'] as String? ?? '').toLowerCase();

        final email = (data['email'] as String? ?? '').toLowerCase();

        final role = (data['role'] as String? ?? '').toLowerCase();

        final isActive = data['isActive'] as bool? ?? true;

        final matchesSearch =
            query.isEmpty ||
            name.contains(query) ||
            email.contains(query) ||
            role.contains(query);

        bool matchesStatus = true;

        if (selectedStatus == 'Active') {
          matchesStatus = isActive;
        } else if (selectedStatus == 'Inactive') {
          matchesStatus = !isActive;
        }

        return matchesSearch && matchesStatus;
      }).toList();
    });
  }

  // ============================================================
  // STATUS FILTER
  // ============================================================

  void changeStatusFilter(String status) {
    setState(() {
      selectedStatus = status;
    });

    filterUsers();
  }

  // ============================================================
  // TOGGLE USER STATUS
  // ============================================================

  Future<void> toggleUserStatus(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) async {
    final data = document.data();

    final currentStatus = data['isActive'] as bool? ?? true;

    final newStatus = !currentStatus;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(document.id)
          .update({
            'isActive': newStatus,
            'updatedAt': FieldValue.serverTimestamp(),
          });

      if (!mounted) {
      return;
    }

      await loadUsers();

      if (!mounted) {
      return;
    }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            newStatus ? 'User account activated.' : 'User account deactivated.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) {
      return;
    }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not update this user. Please try again.',
          ),
        ),
      );
    }
  }

  // ============================================================
  // OPEN CUSTOMER DETAIL
  // ============================================================

  Future<void> showUserDetails(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CustomerDetailScreen(userDocument: document),
      ),
    );

    if (!mounted) {
      return;
    }

    await loadUsers();
  }

  // ============================================================
  // DELETE CUSTOMER DATA
  // ============================================================

  Future<void> deleteCustomer(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) async {
    // Guard against a second delete being triggered while one is
    // already running (e.g. a fast double-tap on the delete icon).
    if (isDeleting) {
      return;
    }

    final data = document.data();

    final name = data['name'] as String? ?? 'Unknown User';

    final email = data['email'] as String? ?? 'No email';

    // ------------------------------------------------------------
    // Prevent accidental self-delete if current user's UID
    // is stored in the document.
    // ------------------------------------------------------------

    // The check above only obtains project information.
    // The actual Auth UID is checked through the document field
    // below where available.

    final userId = data['uid'] as String? ?? document.id;

    // Never allow the currently signed-in admin to delete their own
    // Firestore profile from User Management.
    if (FirebaseAuth.instance.currentUser?.uid == userId) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'You cannot delete your own admin account here.',
          ),
        ),
      );
      return;
    }

    // ------------------------------------------------------------
    // Confirmation dialog
    // ------------------------------------------------------------
    //
    // Wording is deliberately specific about what this permanently
    // removes (their profile, wardrobe, preferences and analysis
    // records) and does not claim their Firebase Auth login credential
    // is removed, since this action cannot do that — see the
    // "Delete Permanently" flow below.

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete Customer?'),
          content: Text(
            'This permanently removes this customer\'s account data — '
            'their profile, wardrobe, style preferences, analysis '
            'records, and any stored photos — for:\n\n'
            '$name\n$email\n\n'
            'This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.error),
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Delete Permanently'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    if (!mounted) {
      return;
    }

    setState(() {
      isDeleting = true;
    });

    // ------------------------------------------------------------
    // Loading state: a non-dismissible dialog so the admin can see
    // deletion is in progress and cannot trigger it again while it
    // runs (the delete/disable buttons are also already disabled via
    // `isDeleting` above, but this adds a visible, explicit state).
    // ------------------------------------------------------------

    if (mounted) {
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
    }

    CustomerDeletionResult? result;
    Object? deletionError;

    try {
      // ----------------------------------------------------------
      // Delete every Firestore document this customer owns —
      // wardrobe, preferences, analysis, then their profile itself.
      // This is the step that must succeed for the customer to be
      // considered deleted.
      // ----------------------------------------------------------
      result = await FirestoreService.deleteCustomerData(userId);
    } catch (e) {
      deletionError = e;
    }

    // ----------------------------------------------------------
    // Best-effort Google Drive cleanup. This runs only if the
    // Firestore deletion above actually succeeded, and never blocks
    // or overrides the Firestore outcome: a Drive failure here does
    // not mean the customer's account data still exists.
    // ----------------------------------------------------------
    if (result != null && result.imageUrls.isNotEmpty) {
      await Future.wait(
        result.imageUrls.map(StorageService.deleteImageByUrl),
      );
    }

    if (mounted) {
      // Dismiss the "Deleting customer..." dialog.
      Navigator.of(context, rootNavigator: true).pop();
    }

    if (result != null) {
      if (!mounted) {
        return;
      }

      await loadUsers();

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Customer deleted: ${result.wardrobeItemsDeleted} wardrobe '
            'item(s), ${result.preferencesDeleted} preference record(s) '
            'and ${result.analysisRecordsDeleted} analysis record(s) '
            'removed.',
          ),
        ),
      );
    } else {
      if (!mounted) {
        return;
      }

      // Never claim success when the Firestore deletion failed or only
      // partially completed. `deleteCustomerData` deletes in chunked
      // batches, so on failure some chunks may already be committed —
      // report this honestly rather than silently swallowing it.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not fully delete this customer. Some data may have '
            'already been removed — please refresh and try again. '
            '(${deletionError ?? 'Unknown error'})',
          ),
        ),
      );
    }

    if (mounted) {
      setState(() {
        isDeleting = false;
      });
    }
  }

  // ============================================================
  // STATUS CHIP
  // ============================================================

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

  // ============================================================
  // FILTER CHIP
  // ============================================================

  Widget _filterChip(String label) {
    final isSelected = selectedStatus == label;

    return FilterChip(
      label: Text(label),
      showCheckmark: false,
      selected: isSelected,
      onSelected: (_) {
        changeStatusFilter(label);
      },
    );
  }

  // ============================================================
  // USER CARD
  // ============================================================

  Widget _buildUserCard(QueryDocumentSnapshot<Map<String, dynamic>> document) {
    final data = document.data();

    final name = data['name'] as String? ?? 'Unknown User';

    final email = data['email'] as String? ?? 'No email';

    final role = data['role'] as String? ?? 'customer';

    final isActive = data['isActive'] as bool? ?? true;
    final isPremium = data['isPremium'] as bool? ?? false;

    final colourSeason = data['colourSeason'] as String? ?? 'Not analysed';

    final skinTone = data['skinTone'] as String? ?? 'Not analysed';

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(
          color: AppColors.border,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          showUserDetails(document);
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  // ==================================================
                  // AVATAR
                  // ==================================================
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: AppColors.secondary,
                    child: const Icon(
                      Icons.person,
                      color: AppColors.primary,
                      size: 28,
                    ),
                  ),

                  const SizedBox(width: 14),

                  // ==================================================
                  // BASIC INFORMATION
                  // ==================================================
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

                        const SizedBox(height: 8),

                        Wrap(
                          spacing: 6,
                          runSpacing: 5,
                          children: [
                            _statusChip(
                              role.toUpperCase(),
                              AppColors.surfaceMuted,
                              AppColors.primaryDark,
                            ),
                            _statusChip(
                              isActive ? 'ACTIVE' : 'INACTIVE',
                              isActive
                                  ? AppColors.success.withValues(alpha: 0.12)
                                  : AppColors.error.withValues(alpha: 0.12),
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

                  const SizedBox(width: 8),

                  const Icon(Icons.arrow_forward_ios, size: 15),
                ],
              ),

              const SizedBox(height: 16),

              // ==================================================
              // COLOUR SUMMARY
              // ==================================================
              Row(
                children: [
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
                ],
              ),

              const SizedBox(height: 14),

              const Divider(height: 1),

              const SizedBox(height: 10),

              // ==================================================
              // ACTIONS
              // ==================================================
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        showUserDetails(document);
                      },
                      icon: const Icon(Icons.visibility_outlined, size: 18),
                      label: const Text('View'),
                    ),
                  ),

                  const SizedBox(width: 8),

                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: isDeleting
                          ? null
                          : () {
                              toggleUserStatus(document);
                            },
                      icon: Icon(
                        isActive ? Icons.block : Icons.check_circle_outline,
                        size: 18,
                      ),
                      label: Text(isActive ? 'Disable' : 'Activate'),
                    ),
                  ),

                  const SizedBox(width: 8),

                  IconButton(
                    tooltip: 'Delete customer data',
                    onPressed: isDeleting
                        ? null
                        : () {
                            deleteCustomer(document);
                          },
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

  // ============================================================
  // SMALL INFORMATION CARD
  // ============================================================

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
                  style: TextStyle(fontSize: 10, color: AppColors.textSecondary),
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

  // ============================================================
  // BUILD
  // ============================================================

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
            // ======================================================
            // SEARCH
            // ======================================================
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
              child: TextField(
                controller: searchController,

                decoration: InputDecoration(
                  hintText: 'Search by name, email or role',

                  prefixIcon: const Icon(Icons.search),

                  suffixIcon: searchController.text.isNotEmpty
                      ? IconButton(
                          onPressed: () {
                            searchController.clear();
                          },
                          icon: const Icon(Icons.clear),
                        )
                      : null,

                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),

            // ======================================================
            // STATUS FILTERS
            // ======================================================
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
                ],
              ),
            ),

            // ======================================================
            // USER COUNT
            // ======================================================
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Row(
                children: [
                  Text(
                    '${filteredUsers.length} '
                    '${filteredUsers.length == 1 ? 'user' : 'users'}',

                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),

                  const Spacer(),

                  Text(
                    'Total: ${users.length}',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),

            // ======================================================
            // USER LIST
            // ======================================================
            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : filteredUsers.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        const SizedBox(height: 180),
                        Center(
                          child: Column(
                            children: [
                              const Icon(
                                Icons.people_outline,
                                size: 70,
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'No users found',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                searchController.text.trim().isEmpty
                                    ? 'There are no users in this filter yet.'
                                    : 'Try a different name, email or role.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                      itemCount: filteredUsers.length,
                      itemBuilder: (context, index) {
                        return _buildUserCard(filteredUsers[index]);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
