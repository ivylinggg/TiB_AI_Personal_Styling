import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../main/main_screen.dart';
import 'admin_dashboard_screen.dart';
import 'admin_profile_screen.dart';
import 'analysis_management_screen.dart';
import 'consultation_management_screen.dart';
import 'content_management_screen.dart';
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
    if (mounted) {
      setState(() => _isCheckingAccess = true);
    }

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

      final document = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final data = document.data();
      final role = (data?['role'] as String? ?? '').trim().toLowerCase();
      final isActive = data?['isActive'] as bool? ?? true;
      final isAdmin = role == 'admin';

      if (!mounted) return;
      setState(() {
        _isCheckingAccess = false;
        _hasAdminAccess = isAdmin && isActive;
        _accessError = !isAdmin
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

  String get _modeLabel {
    switch (_mode) {
      case AdminMode.administrator:
        return 'Administrator';
      case AdminMode.consultantPreview:
        return 'Consultant Console';
      case AdminMode.customerPreview:
        return 'Customer Preview';
    }
  }

  String get _modeDescription {
    switch (_mode) {
      case AdminMode.administrator:
        return 'Full administration access';
      case AdminMode.consultantPreview:
        return 'Respond to live customer consultations';
      case AdminMode.customerPreview:
        return 'Preview the complete customer dashboard';
    }
  }

  IconData get _modeIcon {
    switch (_mode) {
      case AdminMode.administrator:
        return Icons.admin_panel_settings_outlined;
      case AdminMode.consultantPreview:
        return Icons.support_agent_rounded;
      case AdminMode.customerPreview:
        return Icons.person_outline_rounded;
    }
  }

  void _setMode(AdminMode mode) {
    if (_mode == mode) return;
    setState(() {
      _mode = mode;
      _selectedIndex = 0;
    });
  }

  void _resetAdministratorMode() {
    if (_mode == AdminMode.administrator && _selectedIndex == 0) return;
    setState(() {
      _mode = AdminMode.administrator;
      _selectedIndex = 0;
    });
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
              const ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('Switch Role Dashboard'),
                subtitle: Text(
                  'Preview another role without changing your real Firebase role.',
                ),
              ),
              _ModeTile(
                title: 'Administrator',
                subtitle: 'Manage users, content, premium, staff and analytics',
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
                subtitle: 'Open the complete customer dashboard and features',
                icon: Icons.person_outline_rounded,
                selected: _mode == AdminMode.customerPreview,
                onTap: () {
                  Navigator.pop(sheetContext);
                  _setMode(AdminMode.customerPreview);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> get _pages {
    switch (_mode) {
      case AdminMode.administrator:
        return [
          AdminDashboardScreen(onNavigate: _navigateTo),
          const UserManagementScreen(),
          const AnalysisManagementScreen(),
          const ContentManagementScreen(),
          const PremiumManagementScreen(),
          const AdminProfileScreen(),
          const ConsultationManagementScreen(),
          const StaffManagementScreen(),
        ];
      case AdminMode.consultantPreview:
        return [
          const ConsultationManagementScreen(),
          const AdminProfileScreen(),
        ];
      case AdminMode.customerPreview:
        return [
          const MainScreen(adminPreview: true),
          const AdminProfileScreen(),
        ];
    }
  }

  List<NavigationDestination> get _destinations {
    switch (_mode) {
      case AdminMode.administrator:
        return const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'Dashboard'),
          NavigationDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people), label: 'Users'),
          NavigationDestination(icon: Icon(Icons.analytics_outlined), selectedIcon: Icon(Icons.analytics), label: 'Analysis'),
          NavigationDestination(icon: Icon(Icons.library_books_outlined), selectedIcon: Icon(Icons.library_books), label: 'Content'),
          NavigationDestination(icon: Icon(Icons.workspace_premium_outlined), selectedIcon: Icon(Icons.workspace_premium), label: 'Premium'),
          NavigationDestination(icon: Icon(Icons.admin_panel_settings_outlined), selectedIcon: Icon(Icons.admin_panel_settings), label: 'Admin'),
          NavigationDestination(icon: Icon(Icons.support_agent_outlined), selectedIcon: Icon(Icons.support_agent), label: 'Consult'),
          NavigationDestination(icon: Icon(Icons.badge_outlined), selectedIcon: Icon(Icons.badge_rounded), label: 'Staff'),
        ];
      case AdminMode.consultantPreview:
        return const [
          NavigationDestination(icon: Icon(Icons.support_agent_outlined), selectedIcon: Icon(Icons.support_agent), label: 'Live Consultancy'),
          NavigationDestination(icon: Icon(Icons.admin_panel_settings_outlined), selectedIcon: Icon(Icons.admin_panel_settings), label: 'Admin'),
        ];
      case AdminMode.customerPreview:
        return const [
          NavigationDestination(icon: Icon(Icons.person_outline_rounded), selectedIcon: Icon(Icons.person_rounded), label: 'Customer'),
          NavigationDestination(icon: Icon(Icons.admin_panel_settings_outlined), selectedIcon: Icon(Icons.admin_panel_settings), label: 'Admin'),
        ];
    }
  }

  void _navigateTo(int index) {
    if (index < 0) return;
    if ((_mode == AdminMode.consultantPreview || _mode == AdminMode.customerPreview) && index == 1) {
      _resetAdministratorMode();
      return;
    }
    if (index >= _pages.length) return;
    setState(() => _selectedIndex = index);
  }

  Widget _buildAccessDenied() {
    return Scaffold(
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
              Text(
                _accessError ?? 'Administrator access is required.',
                textAlign: TextAlign.center,
              ),
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
  }

  @override
  Widget build(BuildContext context) {
    if (_isCheckingAccess) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (!_hasAdminAccess) {
      return _buildAccessDenied();
    }

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
                      if (_mode != AdminMode.administrator) ...[
                        const SizedBox(width: 7),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.secondaryContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'PREVIEW',
                            style: TextStyle(fontSize: 8, fontWeight: FontWeight.w800),
                          ),
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
          IconButton(
            tooltip: 'Switch Role Dashboard',
            onPressed: _showModeSelector,
            icon: const Icon(Icons.swap_horiz_rounded),
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
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(subtitle),
        trailing: selected ? const Icon(Icons.check_circle_rounded) : const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
      ),
    );
  }
}
