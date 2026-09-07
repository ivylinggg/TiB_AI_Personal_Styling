import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../services/notification_service.dart';
import '../../services/preview_context.dart';
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

  late final List<Widget> _pages = [
    const DashboardDesignedScreen(),
    const AnalysisScreen(),
    const AIHubScreen(),
    const WardrobeScreen(),
    const CustomerForumScreen(),
    const ProfileScreen(),
  ];

  String? get _authUid => FirebaseAuth.instance.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    final uid = _authUid;
    if (uid != null && !widget.adminPreview) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        NotificationService.ensureWelcomeNotification(uid);
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
    context.read<PreviewContext>().clear();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AdminMainScreen()),
      (_) => false,
    );
  }

  Future<void> _logout() async {
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
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  Future<void> _showNotifications() async {
    final uid = _authUid;
    if (uid == null || widget.adminPreview) return;
    await NotificationService.ensureWelcomeNotification(uid);
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: StreamBuilder<List<VyeaNotification>>(
          stream: NotificationService.stream(uid),
          builder: (context, snapshot) {
            final items = snapshot.data ?? const <VyeaNotification>[];
            return SizedBox(
              height: MediaQuery.sizeOf(context).height * .7,
              child: items.isEmpty
                  ? const Center(child: Text('No notifications yet'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(20),
                      itemCount: items.length,
                      itemBuilder: (_, index) {
                        final item = items[index];
                        return ListTile(
                          leading: const Icon(Icons.notifications_none_rounded),
                          title: Text(item.title),
                          subtitle: Text(item.body),
                          onTap: item.read ? null : () => NotificationService.markRead(uid, item.id),
                        );
                      },
                    ),
            );
          },
        ),
      ),
    );
  }

  Widget _header() {
    final user = FirebaseAuth.instance.currentUser;
    final name = user?.displayName?.trim();
    final greeting = name?.isNotEmpty == true ? 'Hi, $name' : 'Welcome back';
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
              decoration: const BoxDecoration(color: AppColors.secondary, shape: BoxShape.circle),
              child: const Icon(Icons.auto_awesome_rounded, color: AppColors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('VYEA', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w900, letterSpacing: 2.6, color: AppColors.brown)),
                  const SizedBox(height: 2),
                  Text(greeting, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
                ],
              ),
            ),
            if (widget.adminPreview)
              IconButton(onPressed: _returnToAdmin, tooltip: 'Return to Admin', icon: const Icon(Icons.admin_panel_settings_outlined)),
            if (!widget.adminPreview) ...[
              IconButton(onPressed: _showNotifications, tooltip: 'Notifications', icon: const Icon(Icons.notifications_none_rounded)),
              IconButton(onPressed: _logout, tooltip: 'Log out', icon: const Icon(Icons.logout_rounded)),
            ],
          ],
        ),
      ),
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
            if (_selectedIndex == 0) _header(),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: animation.drive(
                      Tween<Offset>(begin: Offset(direction * .03, .01), end: Offset.zero)
                          .chain(CurveTween(curve: Curves.easeOutCubic)),
                    ),
                    child: child,
                  ),
                ),
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
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.border),
          ),
          child: NavigationBar(
            selectedIndex: _selectedIndex,
            height: 70,
            backgroundColor: Colors.transparent,
            indicatorColor: AppColors.primarySoft,
            onDestinationSelected: _selectTab,
            destinations: const [
              NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'Home'),
              NavigationDestination(icon: Icon(Icons.palette_outlined), selectedIcon: Icon(Icons.palette_rounded), label: 'Colour'),
              NavigationDestination(icon: Icon(Icons.auto_awesome_outlined), selectedIcon: Icon(Icons.auto_awesome_rounded), label: 'Style'),
              NavigationDestination(icon: Icon(Icons.checkroom_outlined), selectedIcon: Icon(Icons.checkroom_rounded), label: 'Wardrobe'),
              NavigationDestination(icon: Icon(Icons.forum_outlined), selectedIcon: Icon(Icons.forum_rounded), label: 'Forum'),
              NavigationDestination(icon: Icon(Icons.person_outline_rounded), selectedIcon: Icon(Icons.person_rounded), label: 'Profile'),
            ],
          ),
        ),
      ),
    );
  }
}
