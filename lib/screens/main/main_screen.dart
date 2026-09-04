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
import '../forum/customer_forum_screen.dart';
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
  int _previousIndex = 0;

  final List<Widget> _pages = const [
    DashboardDesignedScreen(),
    AnalysisScreen(),
    AIHubScreen(),
    WardrobeScreen(),
    CustomerForumScreen(),
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
    setState(() {
      _previousIndex = _selectedIndex;
      _selectedIndex = index;
    });
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
          'title': 'Welcome to VYEA',
          'body': 'Your personal styling space is ready. Explore your wardrobe and discover a look that feels like you.',
          'type': 'system',
          'read': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (_) {}

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
                          const Expanded(child: Text('Notifications', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900))),
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
                              final title = data['title'] as String? ?? 'VYEA update';
                              final body = data['body'] as String? ?? '';
                              final createdAt = data['createdAt'];

                              return Card(
                                elevation: 0,
                                color: read ? AppColors.surface : AppColors.secondary.withValues(alpha: .42),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17), side: const BorderSide(color: AppColors.border)),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                                  leading: CircleAvatar(
                                    backgroundColor: AppColors.surfaceMuted,
                                    child: Icon(read ? Icons.notifications_none_rounded : Icons.notifications_active_rounded, color: AppColors.primary),
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not log out: ${error.message ?? 'Please try again.'}')));
    }
  }

  Widget _dashboardHeader() {
    final user = FirebaseAuth.instance.currentUser;
    final displayName = user?.displayName?.trim();
    final greeting = displayName?.isNotEmpty == true ? 'Hi, $displayName' : 'Welcome back';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 13, 10, 13),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: const BoxDecoration(
                color: AppColors.secondary,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.auto_awesome_rounded, color: AppColors.primary, size: 19),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('VYEA', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w900, letterSpacing: 2.6, color: AppColors.brown)),
                  const SizedBox(height: 2),
                  Text(greeting, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 19, height: 1.1, fontWeight: FontWeight.w800, color: AppColors.textPrimary, letterSpacing: -0.3)),
                ],
              ),
            ),
            if (widget.adminPreview) ...[
              _topActionButton(icon: Icons.admin_panel_settings_outlined, tooltip: 'Return to Admin', onTap: _returnToAdmin),
              const SizedBox(width: 6),
            ],
            _topActionButton(icon: Icons.notifications_none_rounded, tooltip: 'Notifications', onTap: _showNotifications),
            const SizedBox(width: 6),
            _topActionButton(icon: Icons.logout_rounded, tooltip: 'Log out', onTap: _logout),
          ],
        ),
      ),
    );
  }

  Widget _topActionButton({required IconData icon, required String tooltip, required VoidCallback onTap}) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: AppColors.surfaceMuted,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: 39,
            height: 39,
            child: Icon(icon, color: AppColors.primary, size: 18),
          ),
        ),
      ),
    );
  }

  Widget _tabTransition({required Widget child, required bool selected}) {
    return AnimatedScale(
      duration: const Duration(milliseconds: 180),
      scale: selected ? 1.0 : .94,
      curve: Curves.easeOut,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 180),
        opacity: selected ? 1 : .84,
        child: child,
      ),
    );
  }

  NavigationDestination _destination({required IconData icon, required IconData selectedIcon, required String label, required int index}) {
    final selected = _selectedIndex == index;
    return NavigationDestination(
      icon: _tabTransition(selected: false, child: Icon(icon)),
      selectedIcon: _tabTransition(selected: selected, child: Icon(selectedIcon)),
      label: label,
    );
  }

  @override
  Widget build(BuildContext context) {
    final direction = _selectedIndex >= _previousIndex ? 1 : -1;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            if (_selectedIndex == 0) _dashboardHeader(),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                reverseDuration: const Duration(milliseconds: 180),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, animation) {
                  final offsetTween = Tween<Offset>(
                    begin: Offset(direction * .035, .012),
                    end: Offset.zero,
                  ).chain(CurveTween(curve: Curves.easeOutCubic));
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(position: animation.drive(offsetTween), child: child),
                  );
                },
                child: KeyedSubtree(key: ValueKey(_selectedIndex), child: _pages[_selectedIndex]),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(12, 0, 12, 10),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surface.withValues(alpha: .98),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.border),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .045), blurRadius: 18, offset: const Offset(0, 6))],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: NavigationBar(
              selectedIndex: _selectedIndex,
              backgroundColor: Colors.transparent,
              elevation: 0,
              height: 70,
              labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
              indicatorColor: AppColors.primarySoft,
              onDestinationSelected: _selectTab,
              destinations: [
                _destination(icon: Icons.home_outlined, selectedIcon: Icons.home_rounded, label: 'Home', index: 0),
                _destination(icon: Icons.palette_outlined, selectedIcon: Icons.palette_rounded, label: 'Colour', index: 1),
                NavigationDestination(icon: _aiIcon(false), selectedIcon: _aiIcon(true), label: 'Style'),
                _destination(icon: Icons.checkroom_outlined, selectedIcon: Icons.checkroom_rounded, label: 'Wardrobe', index: 3),
                _destination(icon: Icons.forum_outlined, selectedIcon: Icons.forum_rounded, label: 'Forum', index: 4),
                _destination(icon: Icons.person_outline_rounded, selectedIcon: Icons.person_rounded, label: 'Profile', index: 5),
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
      width: selected ? 38 : 32,
      height: selected ? 38 : 32,
      decoration: BoxDecoration(
        gradient: selected ? AppGradients.primary : null,
        color: selected ? null : AppColors.surfaceMuted,
        shape: BoxShape.circle,
      ),
      child: Icon(Icons.auto_awesome_rounded, size: selected ? 19 : 17, color: selected ? Colors.white : AppColors.primary),
    );
  }
}
