import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_gradients.dart';
import '../../models/colour_analysis_result.dart';
import '../../models/wardrobe_item.dart';
import '../../providers/analysis_provider.dart';
import '../../services/firestore_service.dart';
import '../ai/ai_stylist_screen.dart';
import '../analysis/analysis_screen.dart';
import '../learning/learning_screen.dart';
import '../wardrobe/wardrobe_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with SingleTickerProviderStateMixin {
  String _name = 'Ivy';
  String? _photoUrl;
  List<WardrobeItem> _wardrobe = const [];
  late final AnimationController _animation;

  @override
  void initState() {
    super.initState();
    _animation = AnimationController(vsync: this, duration: const Duration(milliseconds: 750))..forward();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final wardrobe = await FirestoreService.getWardrobeItems(uid);
      if (!mounted) return;
      final data = doc.data();
      setState(() {
        final name = data?['name'] as String?;
        _name = name?.trim().isNotEmpty == true ? name!.trim() : 'Ivy';
        _photoUrl = data?['photoUrl'] as String?;
        _wardrobe = wardrobe;
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final result = context.watch<AnalysisProvider>().result;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          backgroundColor: Colors.white,
          onRefresh: _loadUser,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
                sliver: SliverToBoxAdapter(
                  child: FadeTransition(
                    opacity: _animation,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _header(),
                        const SizedBox(height: 22),
                        _seasonCard(result),
                        const SizedBox(height: 18),
                        _insightRow(result),
                        const SizedBox(height: 26),
                        _sectionTitle('Today for you', 'View all'),
                        const SizedBox(height: 12),
                        _challengeCard(),
                        const SizedBox(height: 26),
                        _sectionTitle('Quick explore', null),
                        const SizedBox(height: 12),
                        _quickActions(),
                        const SizedBox(height: 26),
                        _aiCard(),
                        const SizedBox(height: 26),
                        _sectionTitle('Your wardrobe', 'Explore'),
                        const SizedBox(height: 12),
                        _wardrobeCard(),
                        const SizedBox(height: 26),
                        _learningCard(),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header() => Row(children: [
        Container(width: 48, height: 48, decoration: const BoxDecoration(color: AppColors.primarySoft, shape: BoxShape.circle), clipBehavior: Clip.antiAlias, child: _photoUrl?.isNotEmpty == true ? CachedNetworkImage(imageUrl: _photoUrl!, fit: BoxFit.cover) : const Icon(Icons.person_outline, color: AppColors.primaryDark)),
        const SizedBox(width: 13),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Good morning, $_name! 👋', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)), const SizedBox(height: 3), const Text('Let’s make today feel most like you.', style: TextStyle(color: AppColors.textSecondary, fontSize: 12))])),
        IconButton(onPressed: () {}, icon: const Icon(Icons.notifications_none_rounded)),
      ]);

  Widget _seasonCard(ColourAnalysisResult? result) {
    final season = result?.season ?? 'Soft Autumn';
    final accent = AppColors.seasonAccent(season);
    return Container(
      height: 150,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(gradient: AppGradients.season(season), borderRadius: BorderRadius.circular(22)),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
          const Text('YOUR COLOUR SEASON', style: TextStyle(fontSize: 9, letterSpacing: 1.2, fontWeight: FontWeight.w700, color: Colors.white70)),
          const SizedBox(height: 8),
          Text(season, style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w700, color: Colors.white)),
          const SizedBox(height: 5),
          Text(result == null ? 'Warm • Soft • Earthy' : 'Your personal colour palette', style: const TextStyle(fontSize: 11, color: Colors.white70)),
          const SizedBox(height: 12),
          Row(children: List.generate(6, (i) => Container(width: 18, height: 18, margin: const EdgeInsets.only(right: 5), decoration: BoxDecoration(color: Color.lerp(accent, Colors.white, i / 9), shape: BoxShape.circle)))),
        ])),
        Container(width: 82, height: 112, decoration: BoxDecoration(color: Colors.white.withValues(alpha: .5), borderRadius: BorderRadius.circular(42)), child: const Icon(Icons.face_retouching_natural, size: 48, color: Colors.white)),
      ]),
    );
  }

  Widget _insightRow(ColourAnalysisResult? result) => Row(children: [
        Expanded(child: _miniMetric('Today’s Colour', result?.colours.isNotEmpty == true ? result!.colours.first : 'Terracotta', Icons.palette_outlined)),
        const SizedBox(width: 12),
        Expanded(child: _miniMetric('Style Score', '85 /100', Icons.auto_graph_rounded)),
      ]);

  Widget _miniMetric(String label, String value, IconData icon) => Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.border)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(icon, size: 19, color: AppColors.primaryDark), const SizedBox(height: 12), Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)), const SizedBox(height: 3), Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700))]));

  Widget _sectionTitle(String title, String? action) => Row(children: [Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)), const Spacer(), if (action != null) Text(action, style: const TextStyle(color: AppColors.primaryDark, fontSize: 11, fontWeight: FontWeight.w700))]);

  Widget _challengeCard() => Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: AppColors.surfaceMuted, borderRadius: BorderRadius.circular(20)), child: Row(children: [Container(width: 54, height: 54, decoration: const BoxDecoration(color: AppColors.primarySoft, shape: BoxShape.circle), child: const Icon(Icons.wb_sunny_outlined, color: AppColors.primaryDark)), const SizedBox(width: 14), const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Today’s Challenge', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)), SizedBox(height: 5), Text('Wear one of your signature colours today.', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)), Text('+20 XP', style: TextStyle(fontSize: 10, color: AppColors.brown, fontWeight: FontWeight.w700))])), Container(width: 48, height: 48, decoration: BoxDecoration(border: Border.all(color: AppColors.primary, width: 3), shape: BoxShape.circle), child: const Center(child: Text('3/7', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700))))]));

  Widget _quickActions() {
    final actions = <({String label, IconData icon, VoidCallback onTap})>[
      (label: 'Colour', icon: Icons.palette_outlined, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AnalysisScreen()))),
      (label: 'Wardrobe', icon: Icons.checkroom_outlined, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WardrobeScreen()))),
      (label: 'AI Stylist', icon: Icons.auto_awesome, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AIStylistScreen()))),
      (label: 'Learn', icon: Icons.menu_book_outlined, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LearningScreen()))),
    ];
    return Row(children: actions.map((item) => Expanded(child: Padding(padding: const EdgeInsets.only(right: 8), child: InkWell(onTap: item.onTap, borderRadius: BorderRadius.circular(18), child: Container(height: 86, padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.border)), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(item.icon, color: AppColors.primaryDark, size: 22), const SizedBox(height: 8), Text(item.label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)]))))).toList());
  }

  Widget _aiCard() => Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(gradient: AppGradients.ai, borderRadius: BorderRadius.circular(24)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [const Icon(Icons.auto_awesome, size: 18, color: AppColors.primaryDark), const SizedBox(width: 7), const Text('TiB AI STYLIST', style: TextStyle(fontSize: 10, letterSpacing: 1.1, fontWeight: FontWeight.w800, color: AppColors.primaryDark)), const Spacer(), Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5), decoration: BoxDecoration(color: Colors.white.withValues(alpha: .65), borderRadius: BorderRadius.circular(20)), child: const Text('SMART', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w800)))]), const SizedBox(height: 14), const Text('Not sure what to wear?', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w700)), const SizedBox(height: 7), const Text('Tell TiB where you’re going and we’ll build a look around your colours and wardrobe.', style: TextStyle(fontSize: 11, height: 1.45, color: AppColors.textSecondary)), const SizedBox(height: 16), SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AIStylistScreen())), child: const Text('Style Me ✨')))]));

  Widget _wardrobeCard() => Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.border)), child: Row(children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${_wardrobe.length} pieces', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)), const SizedBox(height: 4), const Text('Your personal wardrobe is getting smarter.', style: TextStyle(fontSize: 10, color: AppColors.textSecondary)), const SizedBox(height: 12), const Text('Most matched today  •  Tops', style: TextStyle(fontSize: 10, color: AppColors.brown, fontWeight: FontWeight.w600))])), SizedBox(width: 92, height: 92, child: _wardrobe.isNotEmpty && _wardrobe.first.imageUrl.isNotEmpty ? ClipRRect(borderRadius: BorderRadius.circular(18), child: CachedNetworkImage(imageUrl: _wardrobe.first.imageUrl, fit: BoxFit.cover)) : Container(decoration: BoxDecoration(color: AppColors.surfaceMuted, borderRadius: BorderRadius.circular(18)), child: const Icon(Icons.checkroom_outlined, color: AppColors.primary)))]));

  Widget _learningCard() => InkWell(onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LearningScreen())), borderRadius: BorderRadius.circular(20), child: Container(padding: const EdgeInsets.all(18), decoration: BoxDecoration(color: AppColors.primarySoft.withValues(alpha: .55), borderRadius: BorderRadius.circular(20)), child: const Row(children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Learn your colours', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)), SizedBox(height: 5), Text('Small lessons. Better choices. More confidence.', style: TextStyle(fontSize: 10, color: AppColors.textSecondary))])), Icon(Icons.arrow_forward_rounded, color: AppColors.primaryDark)])));
}
