import 'package:flutter/material.dart';

import '../../models/user_role.dart';
import '../ai/live_consultancy_screen.dart';
import '../ai/talk_to_tib_screen.dart';
import 'admin_dashboard_screen.dart';
import 'admin_profile_screen.dart';
import 'analysis_management_screen.dart';
import 'consultation_management_screen.dart';
import 'content_management_screen.dart';
import 'premium_management_screen.dart';
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

  String get _modeLabel {
    switch (_mode) {
      case AdminMode.administrator:
        return 'Administrator';
      case AdminMode.consultantPreview:
        return 'Consultant Preview';
      case AdminMode.customerPreview:
        return 'Customer Preview';
    }
  }

  void _setMode(AdminMode mode) {
    if (_mode == mode) return;
    setState(() {
      _mode = mode;
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
                title: Text('Admin Mode'),
                subtitle: Text(
                  'Preview another interface without changing your real account role.',
                ),
              ),
              _ModeTile(
                title: 'Administrator',
                subtitle: 'Full administration access',
                icon: Icons.admin_panel_settings_outlined,
                selected: _mode == AdminMode.administrator,
                onTap: () {
                  Navigator.pop(sheetContext);
                  _setMode(AdminMode.administrator);
                },
              ),
              _ModeTile(
                title: 'Consultant Preview',
                subtitle: 'Test the live consultant experience',
                icon: Icons.support_agent_outlined,
                selected: _mode == AdminMode.consultantPreview,
                onTap: () {
                  Navigator.pop(sheetContext);
                  _setMode(AdminMode.consultantPreview);
                },
              ),
              _ModeTile(
                title: 'Customer Preview',
                subtitle: 'Test the customer experience',
                icon: Icons.person_outline,
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
        ];
      case AdminMode.consultantPreview:
        return [const LiveConsultancyScreen()];
      case AdminMode.customerPreview:
        return [const TalkToTiBScreen()];
    }
  }

  List<NavigationDestination> get _destinations {
    switch (_mode) {
      case AdminMode.administrator:
        return const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: 'Users',
          ),
          NavigationDestination(
            icon: Icon(Icons.analytics_outlined),
            selectedIcon: Icon(Icons.analytics),
            label: 'Analysis',
          ),
          NavigationDestination(
            icon: Icon(Icons.library_books_outlined),
            selectedIcon: Icon(Icons.library_books),
            label: 'Content',
          ),
          NavigationDestination(
            icon: Icon(Icons.workspace_premium_outlined),
            selectedIcon: Icon(Icons.workspace_premium),
            label: 'Premium',
          ),
          NavigationDestination(
            icon: Icon(Icons.admin_panel_settings_outlined),
            selectedIcon: Icon(Icons.admin_panel_settings),
            label: 'Admin',
          ),
          NavigationDestination(
            icon: Icon(Icons.support_agent_outlined),
            selectedIcon: Icon(Icons.support_agent),
            label: 'Consult',
          ),
        ];
      case AdminMode.consultantPreview:
      case AdminMode.customerPreview:
        return const [
          NavigationDestination(
            icon: Icon(Icons.support_agent_outlined),
            selectedIcon: Icon(Icons.support_agent),
            label: 'Live Consultancy',
          ),
        ];
    }
  }

  void _navigateTo(int index) {
    if (index < 0 || index >= _pages.length) return;
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final pages = _pages;
    final destinations = _destinations;
    final safeIndex = _selectedIndex < pages.length ? _selectedIndex : 0;

    return Scaffold(
      appBar: AppBar(
        title: Text(_modeLabel),
        actions: [
          IconButton(
            tooltip: 'Switch Admin Mode',
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
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      child: ListTile(
        leading: CircleAvatar(
          child: Icon(icon),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text(subtitle),
        trailing: selected
            ? const Icon(Icons.check_circle_rounded)
            : const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
      ),
    );
  }
}

// The authenticated account remains an admin while preview mode changes only
// the local interface shown by the admin shell.
UserRole getAdminAccountRole() => UserRole.admin;
