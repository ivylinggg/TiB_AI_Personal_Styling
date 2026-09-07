import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../services/notification_service.dart';
import '../../providers/theme_provider.dart';
import '../auth/login_screen.dart';
import '../ai/style_preferences_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _showAppearance(BuildContext context) async {
    final provider = context.read<ThemeProvider>();
    final selected = await showModalBottomSheet<ThemeMode>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Appearance', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
              const SizedBox(height: 10),
              _themeTile(sheetContext, ThemeMode.system, 'System', Icons.brightness_auto_outlined, provider.themeMode),
              _themeTile(sheetContext, ThemeMode.light, 'Light', Icons.light_mode_outlined, provider.themeMode),
              _themeTile(sheetContext, ThemeMode.dark, 'Dark', Icons.dark_mode_outlined, provider.themeMode),
            ],
          ),
        ),
      ),
    );
    if (selected != null && context.mounted) {
      await provider.setThemeMode(selected);
    }
  }

  Widget _themeTile(BuildContext context, ThemeMode mode, String label, IconData icon, ThemeMode current) {
    final selected = current == mode;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: AppColors.surfaceMuted,
        child: Icon(icon, color: AppColors.primary),
      ),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
      trailing: selected
          ? const Icon(Icons.radio_button_checked_rounded, color: AppColors.primary)
          : const Icon(Icons.radio_button_unchecked_rounded, color: AppColors.textMuted),
      onTap: () => Navigator.pop(context, mode),
    );
  }

  Future<void> _changePassword(BuildContext context) async {
    final email = FirebaseAuth.instance.currentUser?.email;
    if (email == null || email.trim().isEmpty) return;
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password reset email sent.')));
      }
    } on FirebaseAuthException catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message ?? 'Unable to send password reset email.')));
      }
    }
  }

  Future<void> _markNotificationsRead(BuildContext context) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await NotificationService.markAllRead(uid);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('All notifications marked as read.')));
    }
  }

  Future<void> _logout(BuildContext context) async {
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
    if (confirmed != true || !context.mounted) return;
    await FirebaseAuth.instance.signOut();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('VYEA', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 2.7, color: AppColors.brown)),
            Text('Settings', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
        children: [
          if (user?.email != null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(22), border: Border.all(color: AppColors.border)),
              child: Row(children: [
                const CircleAvatar(backgroundColor: AppColors.secondary, child: Icon(Icons.person_outline_rounded, color: AppColors.primary)),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Account', style: TextStyle(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 3),
                  Text(user!.email!, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                ])),
              ]),
            ),
          const SizedBox(height: 24),
          const Text('PREFERENCES', style: TextStyle(color: AppColors.textMuted, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.4)),
          const SizedBox(height: 8),
          _sectionCard([
            _item(context, Icons.palette_outlined, 'Style Preferences', 'Refine your style profile and recommendations.', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StylePreferencesScreen()))),
            _item(context, Icons.dark_mode_outlined, 'Appearance', 'Choose system, light, or dark mode.', () => _showAppearance(context)),
          ]),
          const SizedBox(height: 22),
          const Text('NOTIFICATIONS', style: TextStyle(color: AppColors.textMuted, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.4)),
          const SizedBox(height: 8),
          _sectionCard([
            _item(context, Icons.done_all_rounded, 'Mark All as Read', 'Clear unread notification badges.', () => _markNotificationsRead(context), showChevron: false),
          ]),
          const SizedBox(height: 22),
          const Text('SECURITY', style: TextStyle(color: AppColors.textMuted, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.4)),
          const SizedBox(height: 8),
          _sectionCard([
            _item(context, Icons.lock_outline_rounded, 'Change Password', 'Send a secure password reset email.', () => _changePassword(context)),
          ]),
          const SizedBox(height: 22),
          const Text('SESSION', style: TextStyle(color: AppColors.textMuted, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.4)),
          const SizedBox(height: 8),
          _sectionCard([
            _item(context, Icons.logout_rounded, 'Log Out', 'Sign out of this VYEA account.', () => _logout(context), destructive: true, showChevron: false),
          ]),
        ],
      ),
    );
  }

  Widget _sectionCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.border)),
      child: Column(children: children),
    );
  }

  Widget _item(BuildContext context, IconData icon, String title, String subtitle, VoidCallback onTap, {bool destructive = false, bool showChevron = true}) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      onTap: onTap,
      leading: CircleAvatar(backgroundColor: destructive ? AppColors.error.withValues(alpha: .10) : AppColors.secondary, child: Icon(icon, color: destructive ? AppColors.error : AppColors.primary)),
      title: Text(title, style: TextStyle(fontWeight: FontWeight.w800, color: destructive ? AppColors.error : null)),
      subtitle: Padding(padding: const EdgeInsets.only(top: 3), child: Text(subtitle, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11.5))),
      trailing: showChevron ? const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted) : null,
    );
  }
}
