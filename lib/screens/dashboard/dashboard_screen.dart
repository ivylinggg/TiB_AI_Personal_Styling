import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_gradients.dart';
import '../../core/constants/app_radius.dart';
import '../../models/colour_analysis_result.dart';
import '../../models/wardrobe_item.dart';
import '../../providers/analysis_provider.dart';
import '../../services/firestore_service.dart';
import '../../services/style_preference_service.dart';
import '../../widgets/colour_swatch.dart';
import '../../widgets/premium_badge.dart';
import '../ai/style_me_screen.dart';
import '../ai/style_preferences_screen.dart';
import '../analysis/analysis_result_screen.dart';
import '../analysis/analysis_screen.dart';
import '../premium/premium_screen.dart';
import '../wardrobe/wardrobe_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with SingleTickerProviderStateMixin {
  String _name = '';
  String? _photoUrl;
  bool _premium = false;
  bool _loading = true;
  List<WardrobeItem> _wardrobe = const [];
  List<String> _styles = const [];
  List<String> _preferences = const [];
  late final AnimationController _animation;

  @override
  void initState() {
    super.initState();
    _animation = AnimationController(vsync: this, duration: const Duration(milliseconds: 850))..forward();
    _load();
  }

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      final values = await Future.wait<dynamic>([
        FirebaseFirestore.instance.collection('users').doc(uid).get(),
        FirestoreService.getWardrobeItems(uid),
        StylePreferenceService.getStylePreferences(uid),
      ]);
      if (!mounted) return;
      final user = (values[0] as DocumentSnapshot<Map<String, dynamic>>).data();
      final prefs = values[2] as Map<String, dynamic>?;
      setState(() {
        _name = (user?['name'] as String? ?? '').trim();
        _photoUrl = user?['photoUrl'] as String?;
        _premium = user?['isPremium'] == true;
        _wardrobe = values[1] as List<WardrobeItem>;
        _styles = List<String>.from(prefs?['styles'] ?? const []);
        _preferences = List<String>.from(prefs?['preferences'] ?? const []);
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _reveal(int index, Widget child) {
    final start = (index * .08).clamp(0.0, .65);
    final animation = CurvedAnimation(parent: _animation, curve: Interval(start, (start + .35).clamp(.35, 1.0), curve: Curves.easeOutCubic));
    return AnimatedBuilder(animation: animation, child: child, builder: (_, value) => Opacity(opacity: animation.value, child: Transform.translate(offset: Offset(0, 12 * (1 - animation.value)), child: value)));
  }

  @override
  Widget build(BuildContext context) {
    final result = context.watch<AnalysisProvider>().result;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: _load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 34),
            children: [
              _reveal(0, _header(result)),
              const SizedBox(height: 19),
              _reveal(1, _todayHero(result)),
              const SizedBox(height: 16),
              _reveal(2, _styleSnapshot(result)),
              const SizedBox(height: 23),
              _reveal(3, _styleMeCard(result)),
              const SizedBox(height: 24),
              _reveal(4, _wardrobeSection()),
              const SizedBox(height: 24),
              _reveal(5, _preferencesSection(result)),
              if (!_premium) ...[const SizedBox(height: 18), _reveal(6, _premiumCard())],
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(ColourAnalysisResult? result) {
    final hour = DateTime.now().hour;
    final greeting = hour < 12 ? 'Good morning' : hour < 18 ? 'Good afternoon' : 'Good evening';
    final displayName = _name.isEmpty ? 'there' : _name;
    return Row(children: [
      Hero(tag: 'profile-avatar', child: CircleAvatar(radius: 25, backgroundColor: AppColors.surfaceMuted, backgroundImage: _photoUrl?.isNotEmpty == true ? CachedNetworkImageProvider(_photoUrl!) : null, child: _photoUrl?.isNotEmpty == true ? null : const Icon(Icons.person_rounded, color: AppColors.primary))),
      const SizedBox(width: 11),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(greeting, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)), const SizedBox(height: 2), Text('Hi, $displayName', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -.5)), const SizedBox(height: 2), Text(resultLabel(result), style: const TextStyle(color: AppColors.textMuted, fontSize: 10.5))])),
      _circleButton(Icons.notifications_none_rounded),
    ]);
  }

  String resultLabel(ColourAnalysisResult? result) => result == null ? 'Let’s build your style identity.' : '${result.season} • ${result.undertone}';

  Widget _todayHero(ColourAnalysisResult? result) {
    if (result == null) {
      return InkWell(onTap: () => _open(const AnalysisScreen()), borderRadius: BorderRadius.circular(29), child: Ink(padding: const EdgeInsets.all(22), decoration: BoxDecoration(gradient: AppGradients.primary, borderRadius: BorderRadius.circular(29), boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: .17), blurRadius: 24, offset: const Offset(0, 12))]), child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('YOUR STYLE JOURNEY', style: TextStyle(color: Colors.white70, fontSize: 9.5, fontWeight: FontWeight.w800, letterSpacing: 1.2)), SizedBox(height: 10), Text('Find the colours\nthat feel like you.', style: TextStyle(color: Colors.white, fontSize: 29, height: 1.04, fontWeight: FontWeight.w800, letterSpacing: -1)), SizedBox(height: 10), Text('Start with a guided colour analysis and give TiB a better understanding of you.', style: TextStyle(color: Colors.white70, height: 1.45, fontSize: 12.5)), SizedBox(height: 18), _WhitePill(label: 'Discover My Colours')])));
    }
    final accent = AppColors.seasonAccent(result.season);
    final today = result.colours.isEmpty ? null : result.colours[DateTime.now().day % result.colours.length];
    return InkWell(onTap: () => _open(AnalysisResultScreen(result: result)), borderRadius: BorderRadius.circular(29), child: Ink(padding: const EdgeInsets.all(21), decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [AppColors.primary, Color.lerp(AppColors.primaryDark, accent, .30)!]), borderRadius: BorderRadius.circular(29), boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: .15), blurRadius: 24, offset: const Offset(0, 12))]), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [const Expanded(child: Text('YOUR COLOUR IDENTITY', style: TextStyle(color: Colors.white70, fontSize: 9.5, fontWeight: FontWeight.w800, letterSpacing: 1.2))), Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6), decoration: BoxDecoration(color: AppColors.eggYolk, borderRadius: BorderRadius.circular(AppRadius.full)), child: const Text('READY', style: TextStyle(color: AppColors.primaryDark, fontSize: 8.5, fontWeight: FontWeight.w900)))]), const SizedBox(height: 8), Text(result.season, style: const TextStyle(color: Colors.white, fontSize: 29, fontWeight: FontWeight.w800, letterSpacing: -.7)), const SizedBox(height: 3), Text('${result.undertone} • ${result.brightness} • ${result.contrast}', style: const TextStyle(color: Colors.white70, fontSize: 12)), if (today != null) ...[const SizedBox(height: 15), Row(children: [ColourSwatch(name: today, size: 42), const SizedBox(width: 11), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('TODAY’S SHADE', style: TextStyle(color: Colors.white70, fontSize: 8.5, fontWeight: FontWeight.w800, letterSpacing: 1)), const SizedBox(height: 2), Text(today, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800))]))])], const SizedBox(height: 15), const Row(children: [Text('View colour profile', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12.5)), SizedBox(width: 5), Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 16)])])));
  }

  Widget _styleSnapshot(ColourAnalysisResult? result) {
    final hasIdentity = _styles.isNotEmpty || _preferences.isNotEmpty;
    final styleText = _styles.take(2).join(' · ');
    return Container(padding: const EdgeInsets.fromLTRB(16, 15, 12, 15), decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(21), border: Border.all(color: AppColors.border)), child: Row(children: [Container(width: 43, height: 43, decoration: const BoxDecoration(gradient: AppGradients.soft, shape: BoxShape.circle), child: const Icon(Icons.auto_awesome_outlined, color: AppColors.primary, size: 20)), const SizedBox(width: 11), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('STYLE IDENTITY', style: TextStyle(color: AppColors.textMuted, fontSize: 8.5, fontWeight: FontWeight.w800, letterSpacing: 1.1)), const SizedBox(height: 3), Text(hasIdentity ? styleText : 'Tell TiB what feels like you.', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)), const SizedBox(height: 2), Text(hasIdentity ? 'Your preferences guide every recommendation.' : 'Set your preferences for more personal styling.', style: const TextStyle(color: AppColors.textSecondary, fontSize: 10.5))])), TextButton(onPressed: () => _open(const StylePreferencesScreen()).then((_) => _load()), child: Text(hasIdentity ? 'Edit' : 'Set up'))]));
  }

  Widget _styleMeCard(ColourAnalysisResult? result) {
    return Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(gradient: AppGradients.ai, borderRadius: BorderRadius.circular(26)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Container(width: 39, height: 39, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle), child: const Icon(Icons.auto_awesome_rounded, color: AppColors.primary)), const SizedBox(width: 10), const Expanded(child: Text('TIB AI STYLIST', style: TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.w900, letterSpacing: 1.1))), if (_premium) const PremiumBadge(compact: true)]), const SizedBox(height: 15), Text(_wardrobe.isEmpty ? 'Let’s create your first look.' : 'What are we wearing today?', style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800, height: 1.1)), const SizedBox(height: 7), Text(_wardrobe.isEmpty ? 'Add a few pieces to your wardrobe and TiB can style what you already own.' : 'Built around your ${result?.season ?? 'personal'} palette, preferences and real wardrobe.', style: const TextStyle(color: Colors.white70, height: 1.4, fontSize: 12)), const SizedBox(height: 16), SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: () => _open(const StyleMeScreen()), icon: const Icon(Icons.auto_awesome_rounded), label: const Text('Style Me'), style: FilledButton.styleFrom(backgroundColor: AppColors.eggYolk, foregroundColor: AppColors.primaryDark, minimumSize: const Size.fromHeight(49))))]));
  }

  Widget _wardrobeSection() {
    final favourites = _wardrobe.where((item) => item.isFavourite).length;
    final pieces = _wardrobe.take(4).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [const Expanded(child: Text('My Wardrobe', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800))), TextButton(onPressed: () => _open(const WardrobeScreen()), child: const Text('See all'))]), Text('${_wardrobe.length} pieces • $favourites favourites', style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)), const SizedBox(height: 10), if (_loading) const SizedBox(height: 130, child: Center(child: CircularProgressIndicator())) else if (_wardrobe.isEmpty) InkWell(onTap: () => _open(const WardrobeScreen()), borderRadius: BorderRadius.circular(21), child: Container(padding: const EdgeInsets.all(18), decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(21), border: Border.all(color: AppColors.border)), child: const Row(children: [Icon(Icons.add_a_photo_outlined, color: AppColors.primary, size: 29), SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Start your wardrobe', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)), SizedBox(height: 3), Text('Add pieces you already own so TiB can style real outfits for you.', style: TextStyle(color: AppColors.textSecondary, fontSize: 11.5, height: 1.4))])), Icon(Icons.arrow_forward_rounded, color: AppColors.primary, size: 19)]))) else SizedBox(height: 184, child: ListView.separated(scrollDirection: Axis.horizontal, itemCount: pieces.length, separatorBuilder: (_, index) => const SizedBox(width: 10), itemBuilder: (_, i) => _wardrobeCard(pieces[i])))]);
  }

  Widget _wardrobeCard(WardrobeItem item) {
    return SizedBox(width: 140, child: Container(padding: const EdgeInsets.all(7), decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(19), border: Border.all(color: AppColors.border)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(14), child: item.imageUrl.isEmpty ? Container(color: AppColors.surfaceMuted, child: const Center(child: Icon(Icons.checkroom_outlined))) : CachedNetworkImage(imageUrl: item.imageUrl, fit: BoxFit.cover, width: double.infinity))), const SizedBox(height: 7), Row(children: [Expanded(child: Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800))), if (item.isFavourite) const Icon(Icons.favorite_rounded, color: AppColors.eggYolk, size: 14)]), const SizedBox(height: 2), Text('${item.category} · ${item.colour}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.textMuted, fontSize: 10))])));
  }

  Widget _preferencesSection(ColourAnalysisResult? result) {
    final values = [..._styles, ..._preferences].take(8).toList();
    return Container(padding: const EdgeInsets.all(18), decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(23), border: Border.all(color: AppColors.border)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [const Icon(Icons.tune_rounded, color: AppColors.primary), const SizedBox(width: 8), const Expanded(child: Text('Your Style Preferences', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800))), TextButton(onPressed: () => _open(const StylePreferencesScreen()).then((_) => _load()), child: const Text('Edit'))]), const SizedBox(height: 4), Text(result == null ? 'Set preferences so recommendations feel more like you.' : 'These choices guide the way TiB styles you.', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.4)), const SizedBox(height: 12), if (values.isEmpty) const Text('No preferences yet — start building your style identity.', style: TextStyle(color: AppColors.textMuted, fontSize: 11.5)) else Wrap(spacing: 7, runSpacing: 7, children: values.map((value) => Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7), decoration: BoxDecoration(color: AppColors.surfaceMuted, borderRadius: BorderRadius.circular(AppRadius.full)), child: Text(value, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)))).toList())]));
  }

  Widget _premiumCard() => InkWell(onTap: () => _open(const PremiumScreen()), borderRadius: BorderRadius.circular(22), child: Container(padding: const EdgeInsets.all(17), decoration: BoxDecoration(color: AppColors.premiumAccentLight, borderRadius: BorderRadius.circular(22), border: Border.all(color: AppColors.eggYolk.withValues(alpha: .7))), child: Row(children: [Container(width: 45, height: 45, decoration: const BoxDecoration(color: AppColors.eggYolk, shape: BoxShape.circle), child: const Icon(Icons.workspace_premium_rounded, color: AppColors.primaryDark)), const SizedBox(width: 12), const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Go deeper with TiB Premium', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)), SizedBox(height: 3), Text('Unlock richer AI styling built around your personal profile.', style: TextStyle(color: AppColors.textSecondary, fontSize: 11, height: 1.35))])), const Icon(Icons.arrow_forward_rounded, color: AppColors.primary)]));

  Widget _circleButton(IconData icon) => Material(color: AppColors.surfaceMuted, shape: const CircleBorder(), child: InkWell(onTap: () {}, customBorder: const CircleBorder(), child: SizedBox(width: 42, height: 42, child: Icon(icon, color: AppColors.primary, size: 20))));
  Future<void> _open(Widget page) => Navigator.push(context, MaterialPageRoute(builder: (_) => page));
}

class _WhitePill extends StatelessWidget {
  final String label;
  const _WhitePill({required this.label});
  @override
  Widget build(BuildContext context) => Container(height: 46, alignment: Alignment.center, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15)), child: Text(label, style: const TextStyle(color: AppColors.primaryDark, fontWeight: FontWeight.w800, fontSize: 13)));
}
