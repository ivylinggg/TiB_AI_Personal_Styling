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
import '../ai/style_me_screen.dart';
import '../ai/style_preferences_screen.dart';
import '../analysis/analysis_result_screen.dart';
import '../analysis/analysis_screen.dart';
import '../auth/login_screen.dart';
import '../profile/profile_screen.dart';
import '../profile/saved_looks_screen.dart';
import '../wardrobe/wardrobe_screen.dart';

/// Home dashboard rebuilt from the TiB storyboard: compact greeting, season
/// hero, daily colour, style score, challenge and recent report.
class DashboardDesignedScreen extends StatefulWidget {
  const DashboardDesignedScreen({super.key});

  @override
  State<DashboardDesignedScreen> createState() => _DashboardDesignedScreenState();
}

class _DashboardDesignedScreenState extends State<DashboardDesignedScreen> {
  String _name = '';
  String? _photoUrl;
  bool _premium = false;
  List<WardrobeItem> _wardrobe = const [];
  Map<String, dynamic>? _stylePrefs;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      final values = await Future.wait<dynamic>([
        FirebaseFirestore.instance.collection('users').doc(uid).get(),
        FirestoreService.getWardrobeItems(uid),
        StylePreferenceService.getStylePreferences(uid),
      ]);
      if (!mounted) return;
      final user = (values[0] as DocumentSnapshot<Map<String, dynamic>>).data();
      setState(() {
        _name = (user?['name'] as String? ?? '').trim();
        _photoUrl = user?['photoUrl'] as String?;
        _premium = user?['isPremium'] == true;
        _wardrobe = values[1] as List<WardrobeItem>;
        _stylePrefs = values[2] as Map<String, dynamic>?;
      });
    } catch (_) {
      // Keep the dashboard usable with whatever data has already loaded.
    }
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
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            children: [
              _header(result),
              const SizedBox(height: 18),
              _seasonHero(result),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _todayColour(result)),
                  const SizedBox(width: 10),
                  Expanded(child: _styleScore(result)),
                ],
              ),
              const SizedBox(height: 12),
              _challenge(result),
              const SizedBox(height: 12),
              _recentReport(result),
              const SizedBox(height: 20),
              _wardrobePreview(),
              const SizedBox(height: 20),
              _quickActions(result),
              const SizedBox(height: 8),
              if (!_premium) _upgradeHint(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(ColourAnalysisResult? result) {
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning'
        : hour < 18
            ? 'Good afternoon'
            : 'Good evening';
    final name = _name.isEmpty ? 'there' : _name;
    return Row(
      children: [
        CircleAvatar(
          radius: 25,
          backgroundColor: AppColors.primarySoft,
          backgroundImage: _photoUrl?.isNotEmpty == true
              ? CachedNetworkImageProvider(_photoUrl!)
              : null,
          child: _photoUrl?.isNotEmpty == true
              ? null
              : const Icon(Icons.person_rounded, color: AppColors.primaryDark),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(greeting, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              const SizedBox(height: 1),
              Text('$greeting, $name! ✨', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -.5)),
              const SizedBox(height: 1),
              Text(
                result == null ? 'Let’s make today feel more like you.' : '${result.season} • ${result.undertone}',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
              ),
            ],
          ),
        ),
        _iconButton(Icons.notifications_none_rounded, () {}),
        const SizedBox(width: 7),
        _iconButton(Icons.logout_rounded, _confirmLogout),
      ],
    );
  }

  Widget _iconButton(IconData icon, VoidCallback onTap) {
    return Material(
      color: AppColors.surface,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(width: 44, height: 44, child: Icon(icon, color: AppColors.primaryDark)),
      ),
    );
  }

  Widget _seasonHero(ColourAnalysisResult? result) {
    if (result == null) {
      return _card(
        onTap: () => _open(const AnalysisScreen()),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(gradient: AppGradients.primary, borderRadius: BorderRadius.circular(22)),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('YOUR COLOUR SEASON', style: TextStyle(color: Colors.white70, fontSize: 9.5, fontWeight: FontWeight.w800, letterSpacing: 1)),
              SizedBox(height: 8),
              Text('Discover your season', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
              SizedBox(height: 5),
              Text('Take the guided face scan to unlock your personal colour profile.', style: TextStyle(color: Colors.white70, fontSize: 11.5, height: 1.35)),
              SizedBox(height: 14),
              _HeroPill(label: 'Start Colour Analysis'),
            ],
          ),
        ),
      );
    }

    final accent = AppColors.seasonAccent(result.season);
    return _card(
      onTap: () => _open(AnalysisResultScreen(result: result)),
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 16, 16, 15),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Color.lerp(AppColors.primary, accent, .18)!, Color.lerp(AppColors.primaryDark, accent, .34)!],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Text('YOUR COLOUR SEASON', style: TextStyle(color: Colors.white70, fontSize: 9.5, fontWeight: FontWeight.w800, letterSpacing: .8)),
                      SizedBox(width: 7),
                      _MiniTag(label: 'PERSONALISED'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(result.season, style: const TextStyle(color: Colors.white, fontSize: 25, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text('${result.undertone} • ${result.brightness} • ${result.contrast}', style: const TextStyle(color: Colors.white70, fontSize: 11.5)),
                  const SizedBox(height: 12),
                  Row(
                    children: result.colours.take(7).map((name) => Padding(
                      padding: const EdgeInsets.only(right: 5),
                      child: ColourSwatch(name: name, size: 25),
                    )).toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right_rounded, color: Colors.white70, size: 22),
          ],
        ),
      ),
    );
  }

  Widget _todayColour(ColourAnalysisResult? result) {
    final name = result?.colours.isNotEmpty == true ? result!.colours[DateTime.now().day % result.colours.length] : '—';
    return _smallCard(
      title: "TODAY'S COLOUR",
      child: Row(
        children: [
          result == null ? Container(width: 42, height: 42, decoration: const BoxDecoration(color: AppColors.primarySoft, shape: BoxShape.circle)) : ColourSwatch(name: name, size: 42),
          const SizedBox(width: 9),
          Expanded(child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800))),
        ],
      ),
    );
  }

  Widget _styleScore(ColourAnalysisResult? result) {
    final score = result == null ? 0 : (55 + (_wardrobe.length.clamp(0, 6) * 5) + (_stylePrefs == null ? 0 : 15)).clamp(0, 100);
    return _smallCard(
      title: 'STYLE SCORE',
      child: Row(
        children: [
          Text('$score', style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w900)),
          const Text(' /100', style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w700)),
          const Spacer(),
          SizedBox(width: 48, height: 32, child: CustomPaint(painter: _ScorePainter(score / 100))),
        ],
      ),
    );
  }

  Widget _challenge(ColourAnalysisResult? result) {
    final completed = _wardrobe.where((item) => item.isFavourite).length;
    return Container(
      padding: const EdgeInsets.fromLTRB(15, 14, 15, 13),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.border)),
      child: Row(
        children: [
          Container(width: 44, height: 44, decoration: const BoxDecoration(color: Color(0xFFF7EDE5), shape: BoxShape.circle), child: const Icon(Icons.emoji_events_outlined, color: AppColors.brown)),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Today's Challenge", style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800)),
                SizedBox(height: 4),
                Text('Wear one of your signature colours today.', style: TextStyle(color: AppColors.textSecondary, fontSize: 10.8, height: 1.3)),
              ],
            ),
          ),
          Text('$completed/7', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.primaryDark)),
        ],
      ),
    );
  }

  Widget _recentReport(ColourAnalysisResult? result) {
    return _card(
      onTap: result == null ? () => _open(const AnalysisScreen()) : () => _open(AnalysisResultScreen(result: result)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(15, 12, 12, 12),
        child: Row(
          children: [
            const Icon(Icons.picture_as_pdf_outlined, color: AppColors.primaryDark, size: 22),
            const SizedBox(width: 10),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Recent Report', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                  SizedBox(height: 3),
                  Text('Your latest colour analysis report', style: TextStyle(color: AppColors.textSecondary, fontSize: 10.5)),
                ],
              ),
            ),
            Text('View', style: TextStyle(color: AppColors.primaryDark, fontWeight: FontWeight.w800, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _wardrobePreview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(child: Text('My Wardrobe', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
            TextButton(onPressed: () => _open(const WardrobeScreen()), child: const Text('View all')),
          ],
        ),
        const SizedBox(height: 3),
        Text('${_wardrobe.length} pieces • ${_wardrobe.where((item) => item.isFavourite).length} favourites', style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
        const SizedBox(height: 10),
        SizedBox(
          height: 116,
          child: _wardrobe.isEmpty
              ? _emptyWardrobe()
              : ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _wardrobe.take(5).length,
                  separatorBuilder: (_, index) => const SizedBox(width: 9),
                  itemBuilder: (_, index) => _wardrobeCard(_wardrobe[index]),
                ),
        ),
      ],
    );
  }

  Widget _wardrobeCard(WardrobeItem item) {
    return InkWell(
      onTap: () => _open(const WardrobeScreen()),
      borderRadius: BorderRadius.circular(18),
      child: Ink(
        width: 94,
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.border)),
        child: Column(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                child: item.imageUrl.isEmpty
                    ? Container(color: AppColors.surfaceMuted, child: const Center(child: Icon(Icons.checkroom_outlined, color: AppColors.primary)))
                    : CachedNetworkImage(imageUrl: item.imageUrl, width: double.infinity, fit: BoxFit.cover),
              ),
            ),
            Padding(padding: const EdgeInsets.fromLTRB(7, 5, 7, 6), child: Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800))),
          ],
        ),
      ),
    );
  }

  Widget _emptyWardrobe() {
    return _card(
      onTap: () => _open(const WardrobeScreen()),
      child: const Center(
        child: Padding(
          padding: EdgeInsets.all(18),
          child: Text('Add a few pieces and TiB will style from what you already own.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary, fontSize: 11.5, height: 1.35)),
        ),
      ),
    );
  }

  Widget _quickActions(ColourAnalysisResult? result) {
    return Row(
      children: [
        Expanded(child: _quickTile(Icons.auto_awesome_rounded, 'Style Me', () => _open(const StyleMeScreen()))),
        const SizedBox(width: 9),
        Expanded(child: _quickTile(Icons.palette_outlined, 'Colours', () => _open(const AnalysisScreen()))),
        const SizedBox(width: 9),
        Expanded(child: _quickTile(Icons.tune_rounded, 'Preferences', () => _open(const StylePreferencesScreen()))),
      ],
    );
  }

  Widget _quickTile(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 13),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.border)),
        child: Column(
          children: [
            Icon(icon, color: AppColors.primary, size: 20),
            const SizedBox(height: 6),
            Text(label, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }

  Widget _upgradeHint() {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(color: AppColors.lavenderMist, borderRadius: BorderRadius.circular(16)),
      child: const Row(
        children: [
          Icon(Icons.auto_awesome_rounded, color: AppColors.primaryDark, size: 18),
          SizedBox(width: 8),
          Expanded(child: Text('Unlock more personalised AI styling with TiB Premium.', style: TextStyle(fontSize: 10.8, height: 1.3, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }

  Widget _smallCard({required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(color: AppColors.textMuted, fontSize: 9.5, fontWeight: FontWeight.w900, letterSpacing: .65)), const SizedBox(height: 8), child]),
    );
  }

  Widget _card({required Widget child, VoidCallback? onTap}) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(18), child: child),
    );
  }

  Future<void> _confirmLogout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('You can sign in again anytime with your account.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (shouldLogout == true) {
      await _logout();
    }
  }

  Future<void> _logout() async {
    try {
      await FirebaseAuth.instance.signOut();
      if (!mounted) return;
      context.read<AnalysisProvider>().clear();
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Logout failed. Please try again.')),
      );
    }
  }

  Future<void> _open(Widget page) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => page));
    if (mounted) _load();
  }
}

class _HeroPill extends StatelessWidget {
  final String label;
  const _HeroPill({required this.label});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: .16), borderRadius: BorderRadius.circular(AppRadius.full)),
      child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w800)),
    );
  }
}

class _MiniTag extends StatelessWidget {
  final String label;
  const _MiniTag({required this.label});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(color: AppColors.eggYolk, borderRadius: BorderRadius.circular(AppRadius.full)),
      child: const Text('PERSONALISED', style: TextStyle(color: AppColors.primaryDark, fontSize: 8, fontWeight: FontWeight.w800)),
    );
  }
}

class _ScorePainter extends CustomPainter {
  final double progress;
  _ScorePainter(this.progress);
  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.height * .28;
    final rect = Rect.fromLTWH(stroke, stroke, size.width - stroke * 2, size.height - stroke * 2);
    final bg = Paint()..color = AppColors.border..style = PaintingStyle.stroke..strokeWidth = stroke..strokeCap = StrokeCap.round;
    final fg = Paint()..color = AppColors.primary..style = PaintingStyle.stroke..strokeWidth = stroke..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, 3.4, 5.75, false, bg);
    canvas.drawArc(rect, 3.4, 5.75 * progress.clamp(0, 1), false, fg);
  }
  @override
  bool shouldRepaint(covariant _ScorePainter oldDelegate) => oldDelegate.progress != progress;
}
