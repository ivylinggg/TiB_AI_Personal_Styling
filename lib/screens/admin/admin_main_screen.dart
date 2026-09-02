import 'package:flutter/material.dart';

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
        return 'Preview the customer Talk to TiB experience';
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
                  'Only administrators can preview another role. Your real Firebase role is unchanged.',
                ),
              ),
              _ModeTile(
                title: 'Administrator',
                subtitle: 'Manage users, content, premium and analytics',
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
        ];
      case AdminMode.consultantPreview:
        return [
          const ConsultationManagementScreen(),
          const AdminProfileScreen(),
        ];
      case AdminMode.customerPreview:
        return [
          const _CustomerPreviewPlaceholder(),
          const AdminProfileScreen(),
        ];
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
        return const [
          NavigationDestination(
            icon: Icon(Icons.support_agent_outlined),
            selectedIcon: Icon(Icons.support_agent),
            label: 'Live Consultancy',
          ),
          NavigationDestination(
            icon: Icon(Icons.admin_panel_settings_outlined),
            selectedIcon: Icon(Icons.admin_panel_settings),
            label: 'Admin',
          ),
        ];
      case AdminMode.customerPreview:
        return const [
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Preview',
          ),
          NavigationDestination(
            icon: Icon(Icons.admin_panel_settings_outlined),
            selectedIcon: Icon(Icons.admin_panel_settings),
            label: 'Admin',
          ),
        ];
    }
  }

  void _navigateTo(int index) {
    if (index < 0) return;

    if (_mode == AdminMode.consultantPreview && index == 1) {
      _setMode(AdminMode.administrator);
      return;
    }

    if (_mode == AdminMode.customerPreview && index == 1) {
      _setMode(AdminMode.administrator);
      return;
    }

    if (index >= _pages.length) return;
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
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
                  Text(
                    _modeLabel,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
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

class _CustomerPreviewPlaceholder extends StatelessWidget {
  const _CustomerPreviewPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'Customer Preview\n\nUse the switch menu to open the complete customer dashboard.',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
