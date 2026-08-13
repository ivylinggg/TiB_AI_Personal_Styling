import 'package:flutter/material.dart';

import 'admin_dashboard_screen.dart';
import 'admin_profile_screen.dart';
import 'analysis_management_screen.dart';
import 'content_management_screen.dart';
import 'premium_management_screen.dart';
import 'user_management_screen.dart';

class AdminMainScreen extends StatefulWidget {
  const AdminMainScreen({super.key});

  @override
  State<AdminMainScreen> createState() => _AdminMainScreenState();
}

class _AdminMainScreenState extends State<AdminMainScreen> {
  int _selectedIndex = 0;

  late final List<Widget> _pages = [
    AdminDashboardScreen(onNavigate: _navigateTo),
    const UserManagementScreen(),
    const AnalysisManagementScreen(),
    const ContentManagementScreen(),
    const PremiumManagementScreen(),
    const AdminProfileScreen(),
  ];

  void _navigateTo(int index) {
    if (index < 0 || index >= _pages.length) return;
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _navigateTo,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'Dashboard'),
          NavigationDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people), label: 'Users'),
          NavigationDestination(icon: Icon(Icons.analytics_outlined), selectedIcon: Icon(Icons.analytics), label: 'Analysis'),
          NavigationDestination(icon: Icon(Icons.library_books_outlined), selectedIcon: Icon(Icons.library_books), label: 'Content'),
          NavigationDestination(icon: Icon(Icons.workspace_premium_outlined), selectedIcon: Icon(Icons.workspace_premium), label: 'Premium'),
          NavigationDestination(icon: Icon(Icons.admin_panel_settings_outlined), selectedIcon: Icon(Icons.admin_panel_settings), label: 'Admin'),
        ],
      ),
    );
  }
}
