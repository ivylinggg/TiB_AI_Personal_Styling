import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_gradients.dart';
import '../../providers/analysis_provider.dart';
import '../admin/admin_main_screen.dart';
import '../ai/ai_hub_screen.dart';
import '../analysis/analysis_screen.dart';
import '../auth/login_screen.dart';
import '../dashboard/dashboard_designed_screen.dart';
import '../profile/profile_screen.dart';
import '../wardrobe/wardrobe_screen.dart';

class MainScreen extends StatefulWidget {
  final bool adminPreview;

  const MainScreen({super.key, this.adminPreview = false});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  final List<Widget> _pages = const [
    DashboardDesignedScreen(),
    AnalysisScreen(),
    AIHubScreen(),
    WardrobeScreen(),
    ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.read<AnalysisProvider>().loadLatestResult(uid);
      });
    }
  }

  void _selectTab(int index) {
    if (index == _selectedIndex) return;
    HapticFeedback.selectionClick();
    setState(() => _selectedIndex = index);
  }

  void _returnToAdmin() {
    if (!widget.adminPreview || !mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AdminMainScreen()),
      (_) => false,
    );
  }

  Future<void> _showNotifications() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    HapticFeedback.lightImpact();

    if (uid == null) return;

    final notificationRef = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('notifications');

    try {
      final snapshot = await notificationRef.limit(50).get();
      if (snapshot.docs.isEmpty) {
        await notificationRef.add({
          'title': 'Welcome to TiB',
          'body': 'Your personal styling space is ready. Explore your wardrobe and discover a look that feels like you.',
          'type': 'system',
          'read': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (_) {
      // The empty-state UI below remains usable even when the first write is unavailable.
    }

    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: AppColors.background,
      builder: (sheetContext) {
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.sizeOf(sheetContext).height * 0.72,
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: notificationRef.limit(50).snapshots(),
              builder: (context, snapshot) {
                final docs = [...?snapshot.data?.docs];
                docs.sort((a, b) {
                  final aValue = a.data()['createdAt'];
                  final bValue = b.data()['createdAt'];
                  final aDate = aValue is Timestamp ? aValue.toDate() : DateTime.fromMillisecondsSinceEpoch(0);
                  final bDate = bValue is Timestamp ? bValue.toDate() : DateTime.fromMillisecondsSinceEpoch(0);
                  return bDate.compareTo(aDate);
                });

                return Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Notifications',
                              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                            ),
                          ),
                          if (docs.isNotEmpty)
                            TextButton(
                              onPressed: () async {
                                final batch = FirebaseFirestore.instance.batch();
                                for (final doc in docs) {
                                  if (doc.data()['read'] != true) {
                                    batch.update(doc.reference, {'read': true});
                                  }
                                }
                                await batch.commit();
                              },
                              child: const Text('Mark all read'),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData)
                        const Expanded(child: Center(child: CircularProgressIndicator()))
                      else if (docs.isEmpty)
                        const Expanded(
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.notifications_none_rounded, size: 52, color: AppColors.primary),
                                SizedBox(height: 12),
                                Text('No notifications yet', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                                SizedBox(height: 6),
                                Text('We’ll keep important styling updates here.', textAlign: TextAlign.center),
                              ],
                            ),
                          ),
                        )
                      else
                        Expanded(
                          child: ListView.separated(
                            itemCount: docs.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final doc = docs[index];
                              final data = doc.data();
                              final read = data['read'] == true;
                              final title = data['title'] as String? ?? 'TiB update';
                              final body = data['body'] as String? ?? '';
                              final createdAt = data['createdAt'];

                              return Card(
                                elevation: 0,
                                color: read ? AppColors.surface : AppColors.secondary.withValues(alpha: .42),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(17),
                                  side: const BorderSide(color: AppColors.border),
                                ),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                                  leading: CircleAvatar(
                                    backgroundColor: AppColors.surfaceMuted,
                                    child: Icon(
                                      read ? Icons.notifications_none_rounded : Icons.notifications_active_rounded,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                  title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
                                  subtitle: Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text('$body\n${_formatNotificationDate(createdAt)}'),
                                  ),
                                  isThreeLine: true,
                                  onTap: () async {
                                    if (!read) await doc.reference.update({'read': true});
                                  },
                                ),
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  String _formatNotificationDate(dynamic value) {
    if (value is! Timestamp) return 'Just now';
    final date = value.toDate();
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$day/$month/${date.year} · $hour:$minute';
  }

  Future<void> _logout() async {
    HapticFeedback.mediumImpact();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text('You can sign back in anytime to continue your styling journey.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Log out')),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await FirebaseAuth.instance.signOut();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not log out: ${error.message ?? 'Please try again.'}')),
      );
    }
  }

  Widget _dashboardHeader() {
    final user = FirebaseAuth.instance.currentUser;
    final displayName = user?.displayName?.trim();
    final greeting = displayName?.isNotEmpty == true ? 'Hi, $displayName' : 'Welcome back';

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  greeting,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 30,
                    height: 1.12,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.7,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  widget.adminPreview ? 'Customer dashboard preview' : 'Your personal styling space',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 18,
                    height: 1.2,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          if (widget.adminPreview) ...[
            _topActionButton(
              icon: Icons.admin_panel_settings_outlined,
              tooltip: 'Return to Admin',
              onTap: _returnToAdmin,
            ),
            const SizedBox(width: 12),
          ],
          _topActionButton(
            icon: Icons.notifications_none_rounded,
            tooltip: 'Notifications',
            onTap: _showNotifications,
          ),
          const SizedBox(width: 12),
          _topActionButton(
            icon: Icons.logout_rounded,
            tooltip: 'Log out',
            onTap: _logout,
          ),
        ],
      ),
    );
  }

  Widget _topActionButton({required IconData icon, required String tooltip, required VoidCallback onTap}) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: AppColors.surface,
        elevation: 1.5,
        shadowColor: Colors.black.withValues(alpha: .08),
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.border),
            ),
            child: Icon(icon, color: AppColors.primary, size: 29),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            if (_selectedIndex == 0) _dashboardHeader(),
            Expanded(child: IndexedStack(index: _selectedIndex, children: _pages)),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surface.withValues(alpha: .97),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: AppColors.border),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .06), blurRadius: 24, offset: const Offset(0, 8))],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(26),
            child: NavigationBar(
              selectedIndex: _selectedIndex,
              backgroundColor: Colors.transparent,
              elevation: 0,
              height: 72,
              labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
              indicatorColor: AppColors.primarySoft,
              onDestinationSelected: _selectTab,
              destinations: [
                const NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'Home'),
                const NavigationDestination(icon: Icon(Icons.palette_outlined), selectedIcon: Icon(Icons.palette_rounded), label: 'Colour'),
                NavigationDestination(icon: _aiIcon(false), selectedIcon: _aiIcon(true), label: 'Style'),
                const NavigationDestination(icon: Icon(Icons.checkroom_outlined), selectedIcon: Icon(Icons.checkroom_rounded), label: 'Wardrobe'),
                const NavigationDestination(icon: Icon(Icons.person_outline_rounded), selectedIcon: Icon(Icons.person_rounded), label: 'Profile'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _aiIcon(bool selected) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: selected ? 43 : 35,
      height: selected ? 43 : 35,
      decoration: BoxDecoration(
        gradient: selected ? AppGradients.primary : null,
        color: selected ? null : AppColors.surfaceMuted,
        shape: BoxShape.circle,
        boxShadow: selected ? [BoxShadow(color: AppColors.primary.withValues(alpha: .20), blurRadius: 12, offset: const Offset(0, 4))] : null,
      ),
      child: Icon(Icons.auto_awesome_rounded, size: selected ? 21 : 18, color: selected ? Colors.white : AppColors.primary),
    );
  }
}
