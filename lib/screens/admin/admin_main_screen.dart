import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../main/main_screen.dart';
import '../../services/preview_context.dart';
import 'admin_dashboard_screen.dart';
import 'admin_profile_screen.dart';
import 'analysis_management_screen.dart';
import 'consultation_management_screen.dart';
import 'content_forum_hub_screen.dart';
import 'premium_management_screen.dart';
import 'staff_management_screen.dart';
import 'user_management_screen.dart';

class AdminMainScreen extends StatefulWidget {
  const AdminMainScreen({super.key});

  @override
  State<AdminMainScreen> createState() => _AdminMainScreenState();
}

enum AdminMode { administrator, consultantPreview, customerPreview }

class _AdminMainScreenState extends State<AdminMainScreen> {
  int _selectedIndex = 0;
  AdminMode _mode = AdminMode.administrator;
  bool _isCheckingAccess = true;
  bool _hasAdminAccess = false;
  String? _accessError;

  @override
  void initState() {
    super.initState();
    _verifyAdministratorAccess();
  }

  Future<void> _verifyAdministratorAccess() async {
    if (mounted) setState(() => _isCheckingAccess = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (!mounted) return;
        setState(() {
          _isCheckingAccess = false;
          _hasAdminAccess = false;
          _accessError = 'Your session has expired. Please sign in again.';
        });
        return;
      }

      final document = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final data = document.data();
      final role = (data?['role'] as String? ?? '').trim().toLowerCase();
      final isActive = data?['isActive'] as bool? ?? true;

      if (!mounted) return;
      setState(() {
        _isCheckingAccess = false;
        _hasAdminAccess = role == 'admin' && isActive;
        _accessError = role != 'admin'
            ? 'Administrator access is required for this dashboard.'
            : (!isActive ? 'This administrator account is inactive.' : null);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isCheckingAccess = false;
        _hasAdminAccess = false;
        _accessError = 'We could not verify administrator access. Please try again.';
      });
    }
  }

  String get _modeLabel => switch (_mode) {
        AdminMode.administrator => 'Administrator',
        AdminMode.consultantPreview => 'Consultant Console',
        AdminMode.customerPreview => 'Customer Preview',
      };

  String get _modeDescription => switch (_mode) {
        AdminMode.administrator => 'Full administration access',
        AdminMode.consultantPreview => 'Respond to live customer consultations',
        AdminMode.customerPreview => 'Preview a real customer account without changing your admin session',
      };

  IconData get _modeIcon => switch (_mode) {
        AdminMode.administrator => Icons.admin_panel_settings_outlined,
        AdminMode.consultantPreview => Icons.support_agent_rounded,
        AdminMode.customerPreview => Icons.person_outline_rounded,
      };

  bool get _isPreviewMode => _mode != AdminMode.administrator;

  void _setMode(AdminMode mode) {
    if (_mode == mode) return;
    if (mode != AdminMode.customerPreview) {
      context.read<PreviewContext>().clear();
    }
    setState(() {
      _mode = mode;
      _selectedIndex = 0;
    });
  }

  void _resetAdministratorMode() {
    context.read<PreviewContext>().clear();
    if (_mode == AdminMode.administrator && _selectedIndex == 0) return;
    setState(() {
      _mode = AdminMode.administrator;
      _selectedIndex = 0;
    });
  }

  Future<void> _selectCustomerPreview() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'customer')
          .get();
      if (!mounted) return;

      final customers = [...snapshot.docs]
        ..sort(
          (a, b) => (a.data()['name'] ?? '')
              .toString()
              .toLowerCase()
              .compareTo((b.data()['name'] ?? '').toString().toLowerCase()),
        );

      if (customers.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No customer accounts are available to preview.')),
        );
        return;
      }

      await showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (sheetContext) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(child: Icon(_modeIcon)),
                  title: const Text('Choose a Customer'),
                  subtitle: const Text(
                    'Preview this customer using their real saved style data. Your admin session stays unchanged.',
                  ),
                ),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: customers.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, index) {
                      final document = customers[index];
                      final data = document.data();
                      final name = (data['name'] ?? 'Customer').toString();
                      final email = (data['email'] ?? '').toString();
                      final selected = context.read<PreviewContext>().customerUid == document.id;

                      return Card(
                        margin: EdgeInsets.zero,
                        color: selected ? Theme.of(context).colorScheme.secondaryContainer : null,
                        child: ListTile(
                          leading: CircleAvatar(
                            child: Text(
                              name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase(),
                            ),
                          ),
                          title: Text(name, style: const TextStyle(fontWeight: FontWeight.w800)),
                          subtitle: Text(email.isEmpty ? document.id : email),
                          trailing: selected
                              ? const Icon(Icons.check_circle_rounded)
                              : const Icon(Icons.chevron_right_rounded),
                          onTap: () {
                            context.read<PreviewContext>().setCustomerUid(document.id);
                            Navigator.pop(sheetContext);
                            _setMode(AdminMode.customerPreview);
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } on FirebaseException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not load customer list: ${error.message ?? error.code}')),
      );
    }
  }

  void _showModeSelector() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(child: Icon(_modeIcon)),
                title: const Text('Switch Role Dashboard'),
                subtitle: Text(
                  _isPreviewMode
                      ? 'Preview mode is active. Your real Firebase role remains Administrator.'
                      : 'Open a preview dashboard without changing your real Firebase role.',
                ),
              ),
              _ModeTile(
                title: 'Administrator',
                subtitle: 'Manage users, content, forum, premium, staff and analytics',
                icon: Icons.admin_panel_settings_outlined,
                selected: _mode == AdminMode.administrator,
                onTap: () {
                  Navigator.pop(sheetContext);
                  _setMode(AdminMode.administrator);
                },
              ),
              _ModeTile(
                title: 'Consultant',
                subtitle: 'Accept and answer live customer requests',
                icon: Icons.support_agent_outlined,
                selected: _mode == AdminMode.consultantPreview,
                onTap: () {
                  Navigator.pop(sheetContext);
                  _setMode(AdminMode.consultantPreview);
                },
              ),
              _ModeTile(
                title: 'Customer Dashboard',
                subtitle: 'Choose a customer and open their complete dashboard',
                icon: Icons.person_outline_rounded,
                selected: _mode == AdminMode.customerPreview,
                onTap: () {
                  Navigator.pop(sheetContext);
                  _selectCustomerPreview();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> get _pages => switch (_mode) {
        AdminMode.administrator => [
            AdminDashboardScreen(onNavigate: _navigateTo),
            const UserManagementScreen(),
            const AnalysisManagementScreen(),
            const ContentForumHubScreen(),
            const PremiumManagementScreen(),
            const AdminProfileScreen(),
            const ConsultationManagementScreen(),
            const StaffManagementScreen(),
          ],
        AdminMode.consultantPreview => [
            const ConsultationManagementScreen(),
            const AdminProfileScreen(),
          ],
        AdminMode.customerPreview => [
            const MainScreen(adminPreview: true),
            const AdminProfileScreen(),
          ],
      };

  List<NavigationDestination> get _destinations => switch (_mode) {
        AdminMode.administrator => const [
            NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'Dashboard'),
            NavigationDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people), label: 'Users'),
            NavigationDestination(icon: Icon(Icons.analytics_outlined), selectedIcon: Icon(Icons.analytics), label: 'Analysis'),
            NavigationDestination(icon: Icon(Icons.forum_outlined), selectedIcon: Icon(Icons.forum_rounded), label: 'Forum'),
            NavigationDestination(icon: Icon(Icons.workspace_premium_outlined), selectedIcon: Icon(Icons.workspace_premium), label: 'Premium'),
            NavigationDestination(icon: Icon(Icons.admin_panel_settings_outlined), selectedIcon: Icon(Icons.admin_panel_settings), label: 'Admin'),
            NavigationDestination(icon: Icon(Icons.support_agent_outlined), selectedIcon: Icon(Icons.support_agent), label: 'Consult'),
            NavigationDestination(icon: Icon(Icons.badge_outlined), selectedIcon: Icon(Icons.badge_rounded), label: 'Staff'),
          ],
        AdminMode.consultantPreview => const [
            NavigationDestination(icon: Icon(Icons.support_agent_outlined), selectedIcon: Icon(Icons.support_agent), label: 'Live Consultancy'),
            NavigationDestination(icon: Icon(Icons.admin_panel_settings_outlined), selectedIcon: Icon(Icons.admin_panel_settings), label: 'Admin'),
          ],
        AdminMode.customerPreview => const [
            NavigationDestination(icon: Icon(Icons.person_outline_rounded), selectedIcon: Icon(Icons.person_rounded), label: 'Customer'),
            NavigationDestination(icon: Icon(Icons.admin_panel_settings_outlined), selectedIcon: Icon(Icons.admin_panel_settings), label: 'Admin'),
          ],
      };

  void _navigateTo(int index) {
    if (index < 0) return;
    if ((_mode == AdminMode.consultantPreview || _mode == AdminMode.customerPreview) && index == 1) {
      _resetAdministratorMode();
      return;
    }
    if (index >= _pages.length) return;
    setState(() => _selectedIndex = index);
  }

  Widget _buildAccessDenied() => Scaffold(
        appBar: AppBar(title: const Text('Administrator Access')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_outline_rounded, size: 64),
                const SizedBox(height: 18),
                const Text(
                  'Access Restricted',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(_accessError ?? 'Administrator access is required.', textAlign: TextAlign.center),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: _isCheckingAccess ? null : _verifyAdministratorAccess,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Check Again'),
                ),
              ],
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    if (_isCheckingAccess) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (!_hasAdminAccess) return _buildAccessDenied();

    final pages = _pages;
    final destinations = _destinations;
    final safeIndex = _selectedIndex < pages.length ? _selectedIndex : 0;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
              child: Icon(_modeIcon, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          _modeLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                        ),
                      ),
                      if (_isPreviewMode) ...[
                        const SizedBox(width: 7),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.secondaryContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text('PREVIEW', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w800)),
                        ),
                      ],
                    ],
                  ),
                  Text(
                    _modeDescription,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh administrator access',
            onPressed: _isCheckingAccess ? null : _verifyAdministratorAccess,
            icon: const Icon(Icons.refresh_rounded),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IconButton.filledTonal(
              tooltip: 'Switch Role Dashboard',
              onPressed: _showModeSelector,
              icon: const Icon(Icons.swap_horiz_rounded),
            ),
          ),
        ],
      ),
      body: IndexedStack(index: safeIndex, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: safeIndex,
        onDestinationSelected: _navigateTo,
        destinations: destinations,
      ),
    );
  }
}

class _ModeTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _ModeTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: selected ? 1 : 0,
      color: selected ? colorScheme.secondaryContainer : null,
      child: ListTile(
        leading: CircleAvatar(child: Icon(icon)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text(subtitle),
        trailing: selected ? const Icon(Icons.check_circle_rounded) : const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
      ),
    );
  }
}
