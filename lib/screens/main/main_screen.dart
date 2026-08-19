import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_gradients.dart';
import '../../providers/analysis_provider.dart';
import '../ai/ai_hub_screen.dart';
import '../analysis/analysis_screen.dart';
import '../dashboard/dashboard_screen.dart';
import '../profile/profile_screen.dart';
import '../wardrobe/wardrobe_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  final List<Widget> _pages = const [
    DashboardScreen(),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: IndexedStack(index: _selectedIndex, children: _pages),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: const Border(top: BorderSide(color: AppColors.border)),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .055), blurRadius: 24, offset: const Offset(0, -7))],
          ),
          child: NavigationBar(
            selectedIndex: _selectedIndex,
            backgroundColor: Colors.transparent,
            elevation: 0,
            height: 76,
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
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
        boxShadow: selected ? [BoxShadow(color: AppColors.primary.withValues(alpha: .24), blurRadius: 13, offset: const Offset(0, 4))] : null,
      ),
      child: Icon(Icons.auto_awesome_rounded, size: selected ? 21 : 18, color: selected ? Colors.white : AppColors.primary),
    );
  }
}
