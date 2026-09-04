import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_gradients.dart';
import '../../screens/auth/auth_service.dart';
import '../../services/style_preference_service.dart';

class StylePreferencesScreen extends StatefulWidget {
  const StylePreferencesScreen({super.key});

  @override
  State<StylePreferencesScreen> createState() => _StylePreferencesScreenState();
}

class _StylePreferencesScreenState extends State<StylePreferencesScreen> {
  static const Color _text = AppColors.textPrimary;
  static const Color _muted = AppColors.textSecondary;

  final Set<String> _styles = <String>{};
  final Set<String> _preferences = <String>{};
  bool _loading = true;
  bool _saving = false;
  bool _isPremium = false;
  bool _premiumLoaded = false;

  static const _styleOptions = [
    ('Minimal', 'Clean and uncomplicated'),
    ('Elegant', 'Polished and timeless'),
    ('Casual', 'Relaxed and effortless'),
    ('Smart Casual', 'Put-together but comfortable'),
    ('Feminine', 'Soft and expressive'),
    ('Trendy', 'Modern and experimental'),
  ];

  static const _preferenceOptions = [
    ('Comfort first', 'I want clothes that feel easy to wear.'),
    ('Keep it simple', 'I prefer fewer pieces and cleaner looks.'),
    ('I like layering', 'I enjoy combining different pieces.'),
    ('I love accessories', 'Accessories are part of my style.'),
  ];

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final user = AuthService.currentUser;
    if (user == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      final results = await Future.wait([
        StylePreferenceService.getStylePreferences(user.uid),
        FirebaseFirestore.instance.collection('users').doc(user.uid).get(),
      ]);
      final data = results[0] as Map<String, dynamic>?;
      final snapshot = results[1] as DocumentSnapshot<Map<String, dynamic>>;
      if (!mounted) return;
      setState(() {
        _styles..clear()..addAll(List<String>.from(data?['styles'] ?? const []));
        _preferences..clear()..addAll(List<String>.from(data?['preferences'] ?? const []));
        _isPremium = snapshot.data()?['isPremium'] == true;
        _premiumLoaded = true;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() { _premiumLoaded = true; _loading = false; });
    }
  }

  Future<void> _save() async {
    final user = AuthService.currentUser;
    if (user == null) return;
    if (_styles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Choose at least one style you like.')));
      return;
    }
    setState(() => _saving = true);
    try {
      await StylePreferenceService.saveStylePreferences(uid: user.uid, styles: _styles.toList(), preferences: _preferences.toList());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Your style preferences have been saved.')));
      Navigator.pop(context, true);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not save your preferences. Please try again.')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        iconTheme: const IconThemeData(color: _text),
        title: const Text('My Style', style: TextStyle(color: _text, fontWeight: FontWeight.w700)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _intro(),
                    const SizedBox(height: 15),
                    _profileStatus(),
                    const SizedBox(height: 18),
                    _selectionSummary(),
                    const SizedBox(height: 27),
                    _sectionTitle('What feels most like you?', 'Choose the styles you naturally reach for.'),
                    const SizedBox(height: 12),
                    ..._styleOptions.map((item) => _optionCard(title: item.$1, subtitle: item.$2, selected: _styles.contains(item.$1), onTap: () => setState(() { _styles.contains(item.$1) ? _styles.remove(item.$1) : _styles.add(item.$1); }))),
                    const SizedBox(height: 18),
                    _sectionTitle('What matters when you get dressed?', 'These small details help VYEA style for your real life.'),
                    const SizedBox(height: 12),
                    ..._preferenceOptions.map((item) => _optionCard(title: item.$1, subtitle: item.$2, selected: _preferences.contains(item.$1), onTap: () => setState(() { _preferences.contains(item.$1) ? _preferences.remove(item.$1) : _preferences.add(item.$1); }))),
                    const SizedBox(height: 14),
                    _guidanceCard(),
                    const SizedBox(height: 18),
                    if (_premiumLoaded && _isPremium) _buildPremiumProfileCard(),
                    const SizedBox(height: 22),
                    SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: _saving ? null : _save, icon: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.check_rounded), label: Text(_saving ? 'Saving your style...' : 'Save My Style'), style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54), backgroundColor: AppColors.primaryDark, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17))))),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _intro() => Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
        decoration: BoxDecoration(color: AppColors.primaryDark, borderRadius: BorderRadius.circular(28)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('VYEA  /  STYLE PROFILE', style: TextStyle(color: AppColors.peach, fontSize: 9.5, fontWeight: FontWeight.w900, letterSpacing: 1.45)),
          const SizedBox(height: 15),
          const Text('Make it feel\nlike you.', style: TextStyle(color: Colors.white, fontSize: 31, height: 1.0, fontWeight: FontWeight.w800, letterSpacing: -1)),
          const SizedBox(height: 9),
          const Text('Tell VYEA what you love, what matters and how you want your clothes to feel.', style: TextStyle(color: Colors.white70, fontSize: 12.5, height: 1.45)),
        ]),
      );

  Widget _profileStatus() {
    final premium = _premiumLoaded && _isPremium;
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.border)),
      child: Row(children: [
        Container(width: 42, height: 42, decoration: const BoxDecoration(color: AppColors.secondary, shape: BoxShape.circle), child: Icon(premium ? Icons.workspace_premium_outlined : Icons.tune_rounded, color: AppColors.primary, size: 20)),
        const SizedBox(width: 11),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(premium ? 'Premium style profile' : 'Personal style profile', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
          const SizedBox(height: 3),
          Text(premium ? 'Your preferences can guide your premium styling experiences.' : 'Your choices help VYEA personalise future styling suggestions.', style: const TextStyle(color: _muted, fontSize: 10.5, height: 1.35)),
        ])),
      ]),
    );
  }

  Widget _selectionSummary() {
    final total = _styles.length + _preferences.length;
    final text = total == 0 ? 'Start with what feels most like you.' : '$total personal choices selected';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
      decoration: BoxDecoration(color: AppColors.surfaceMuted, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.border)),
      child: Row(children: [
        Container(width: 40, height: 40, decoration: const BoxDecoration(color: AppColors.secondary, shape: BoxShape.circle), child: const Icon(Icons.tune_rounded, color: AppColors.primary, size: 20)),
        const SizedBox(width: 11),
        Expanded(child: Text(text, style: const TextStyle(color: _text, fontSize: 12.5, fontWeight: FontWeight.w700))),
      ]),
    );
  }

  Widget _sectionTitle(String title, String subtitle) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(color: _text, fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -.3)),
        const SizedBox(height: 4),
        Text(subtitle, style: const TextStyle(color: _muted, fontSize: 12.5, height: 1.4)),
      ]);

  Widget _optionCard({required String title, required String subtitle, required bool selected, required VoidCallback onTap}) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(20),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.fromLTRB(15, 14, 15, 14),
              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: selected ? AppColors.primary : AppColors.border, width: selected ? 1.5 : 1)),
              child: Row(children: [
                AnimatedContainer(duration: const Duration(milliseconds: 180), width: 43, height: 43, decoration: BoxDecoration(color: selected ? AppColors.primary : AppColors.secondary, shape: BoxShape.circle), child: Icon(selected ? Icons.check_rounded : Icons.add_rounded, color: selected ? Colors.white : AppColors.primary, size: 21)),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(color: _text, fontSize: 14, fontWeight: FontWeight.w800)), const SizedBox(height: 3), Text(subtitle, style: const TextStyle(color: _muted, fontSize: 10.5, height: 1.35))])),
                const SizedBox(width: 8),
                Icon(selected ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded, color: selected ? AppColors.primary : AppColors.textMuted, size: 20),
              ]),
            ),
          ),
        ),
      );

  Widget _guidanceCard() => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: AppColors.secondary.withValues(alpha: .55), borderRadius: BorderRadius.circular(19)),
        child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.auto_awesome_rounded, color: AppColors.primary, size: 18),
          SizedBox(width: 9),
          Expanded(child: Text('There is no right style. Your choices simply help VYEA understand what feels like you.', style: TextStyle(color: _muted, height: 1.45, fontSize: 12.5))),
        ]),
      );

  Widget _buildPremiumProfileCard() {
    final selectedStyles = _styles.toList()..sort();
    final selectedPreferences = _preferences.toList()..sort();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(gradient: AppGradients.soft, borderRadius: BorderRadius.circular(22), border: Border.all(color: AppColors.primarySoft)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [Icon(Icons.auto_awesome_rounded, color: AppColors.primary, size: 20), SizedBox(width: 8), Text('YOUR VYEA STYLE PROFILE', style: TextStyle(fontSize: 10, letterSpacing: 1, fontWeight: FontWeight.w900))]),
        const SizedBox(height: 9),
        Text(selectedStyles.isEmpty ? 'Choose at least one preferred style.' : selectedStyles.join(' · '), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, height: 1.35)),
        if (selectedPreferences.isNotEmpty) ...[const SizedBox(height: 6), Text(selectedPreferences.join(' · '), style: const TextStyle(color: _muted, fontSize: 10.5, height: 1.4))],
      ]),
    );
  }
}
