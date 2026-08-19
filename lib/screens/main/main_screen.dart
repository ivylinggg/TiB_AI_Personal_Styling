import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../providers/analysis_provider.dart';
import '../ai/style_me_screen.dart';
import '../analysis/analysis_screen.dart';
import '../dashboard/dashboard_screen.dart';
import '../profile/profile_screen.dart';
import '../wardrobe/wardrobe_screen.dart';

/// Primary application shell.
///
/// Home, Colour, AI, Wardrobe and Profile stay one tap away. AI is now the
/// free-form Style Me experience, while the chat stylist remains available
/// from inside that screen for users who prefer conversation.
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
    StyleMeScreen(),
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
      body: IndexedStack(index: _selectedIndex, children: _pages),
      bottomNavigationBar: _buildNavigationBar(),
    );
  }

  Widget _buildNavigationBar() {
    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          border: Border(
            top: BorderSide(
              color: Theme.of(context).dividerColor.withValues(alpha: 0.65),
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 22,
              offset: const Offset(0, -6),
            ),
          ],
        ),
        child: NavigationBar(
          selectedIndex: _selectedIndex,
          backgroundColor: Colors.transparent,
          elevation: 0,
          height: 72,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          onDestinationSelected: _selectTab,
          destinations: [
            const NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded),
              label: 'Home',
            ),
            const NavigationDestination(
              icon: Icon(Icons.palette_outlined),
              selectedIcon: Icon(Icons.palette_rounded),
              label: 'Colour',
            ),
            NavigationDestination(
              icon: _aiIcon(false),
              selectedIcon: _aiIcon(true),
              label: 'AI',
            ),
            const NavigationDestination(
              icon: Icon(Icons.checkroom_outlined),
              selectedIcon: Icon(Icons.checkroom_rounded),
              label: 'Wardrobe',
            ),
            const NavigationDestination(
              icon: Icon(Icons.person_outline_rounded),
              selectedIcon: Icon(Icons.person_rounded),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }

  Widget _aiIcon(bool selected) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: selected ? 42 : 34,
      height: selected ? 42 : 34,
      decoration: BoxDecoration(
        color: selected ? AppColors.eggYolk : AppColors.surfaceMuted,
        shape: BoxShape.circle,
        boxShadow: selected
            ? [
                BoxShadow(
                  color: AppColors.eggYolk.withValues(alpha: 0.28),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Icon(
        Icons.auto_awesome_rounded,
        size: selected ? 21 : 18,
        color: AppColors.primaryDark,
      ),
    );
  }
}
