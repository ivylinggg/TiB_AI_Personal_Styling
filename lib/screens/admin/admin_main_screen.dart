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
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(
              title: Text('Admin Mode'),
              subtitle: Text('Preview another role without changing your real account role.'),
            ),
            RadioListTile<AdminMode>(
              value: AdminMode.administrator,
              groupValue: _mode,
              title: const Text('Administrator'),
              secondary: const Icon(Icons.admin_panel_settings_outlined),
              onChanged: (value) {
                Navigator.pop(context);
                if (value != null) _setMode(value);
              },
            ),
            RadioListTile<AdminMode>(
              value: AdminMode.consultantPreview,
              groupValue: _mode,
              title: const Text('Consultant Preview'),
              secondary: const Icon(Icons.support_agent_outlined),
              onChanged: (value) {
                Navigator.pop(context);
                if (value != null) _setMode(value);
              },
            ),
            RadioListTile<AdminMode>(
              value: AdminMode.customerPreview,
              groupValue: _mode,
              title: const Text('Customer Preview'),
              secondary: const Icon(Icons.person_outline),
              onChanged: (value) {
                Navigator.pop(context);
                if (value != null) _setMode(value);
              },
            ),
          ],
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
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'Dashboard'),
          NavigationDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people), label: 'Users'),
          NavigationDestination(icon: Icon(Icons.analytics_outlined), selectedIcon: Icon(Icons.analytics), label: 'Analysis'),
          NavigationDestination(icon: Icon(Icons.library_books_outlined), selectedIcon: Icon(Icons.library_books), label: 'Content'),
          NavigationDestination(icon: Icon(Icons.workspace_premium_outlined), selectedIcon: Icon(Icons.workspace_premium), label: 'Premium'),
          NavigationDestination(icon: Icon(Icons.admin_panel_settings_outlined), selectedIcon: Icon(Icons.admin_panel_settings), label: 'Admin'),
          NavigationDestination(icon: Icon(Icons.support_agent_outlined), selectedIcon: Icon(Icons.support_agent), label: 'Consult'),
        ];
      case AdminMode.consultantPreview:
      case AdminMode.customerPreview:
        return const [
          NavigationDestination(icon: Icon(Icons.support_agent_outlined), selectedIcon: Icon(Icons.support_agent), label: 'Live Consultancy'),
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
            icon: const Icon(Icons.swap_horiz),
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

// Keeps the role model available to the admin shell without changing the
// authenticated Firebase role. Admin mode is only a local UI preview mode.
UserRole getAdminAccountRole() => UserRole.admin;
