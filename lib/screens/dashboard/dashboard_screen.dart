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

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  String _name = '';
  String? _photoUrl;
  List<WardrobeItem> _wardrobe = const [];
  bool _loading = true;
  late final AnimationController _animation;

  @override
  void initState() {
    super.initState();
    _animation = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    )..forward();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    try {
      final results = await Future.wait([
        FirebaseFirestore.instance.collection('users').doc(uid).get(),
        FirestoreService.getWardrobeItems(uid),
      ]);

      if (!mounted) return;

      final doc = results[0] as DocumentSnapshot<Map<String, dynamic>>;
      final wardrobe = results[1] as List<WardrobeItem>;
      final data = doc.data();
      final name = data?['name'] as String?;

      setState(() {
        _name = name?.trim() ?? '';
        _photoUrl = data?['photoUrl'] as String?;
        _wardrobe = wardrobe;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 18) return 'Good afternoon';
    return 'Good evening';
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
          backgroundColor: AppColors.surface,
          onRefresh: _loadUser,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 30),
                sliver: SliverToBoxAdapter(
                  child: FadeTransition(
                    opacity: _animation,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _header(),
                        const SizedBox(height: 22),
                        _seasonCard(result),
                        const SizedBox(height: 16),
                        _insightRow(result),
                        const SizedBox(height: 28),
                        _sectionTitle('A little something for today'),
                        const SizedBox(height: 12),
                        _dailyStyleCard(result),
                        const SizedBox(height: 28),
                        _sectionTitle('Quick explore'),
                        const SizedBox(height: 12),
                        _quickActions(),
                        const SizedBox(height: 28),
                        _aiCard(result),
                        const SizedBox(height: 28),
                        _sectionTitle('Your wardrobe'),
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

  Widget _header() {
    final displayName = _name.isEmpty ? 'there' : _name;

    return Row(
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: const BoxDecoration(
            color: AppColors.primarySoft,
            shape: BoxShape.circle,
          ),
          clipBehavior: Clip.antiAlias,
          child: _photoUrl?.isNotEmpty == true
              ? CachedNetworkImage(imageUrl: _photoUrl!, fit: BoxFit.cover)
              : const Icon(
                  Icons.person_outline_rounded,
                  color: AppColors.primaryDark,
                ),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${_greeting()}, $displayName',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Let’s make getting dressed feel easy today.',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Notifications',
          onPressed: () {},
          icon: const Icon(Icons.notifications_none_rounded),
        ),
      ],
    );
  }

  Widget _seasonCard(ColourAnalysisResult? result) {
    if (result == null) {
      return InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AnalysisScreen()),
        ),
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: AppGradients.blush,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            children: [
              Container(
                width: 62,
                height: 62,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.palette_outlined,
                  color: AppColors.primaryDark,
                  size: 28,
                ),
              ),
              const SizedBox(width: 15),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your colours are waiting',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 5),
                    Text(
                      'Take the colour analysis and let TiB learn what suits you.',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_rounded),
            ],
          ),
        ),
      );
    }

    final accent = AppColors.seasonAccent(result.season);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 18, 18),
      decoration: BoxDecoration(
        gradient: AppGradients.season(result.season),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'YOUR COLOUR PROFILE',
                  style: TextStyle(
                    fontSize: 9,
                    letterSpacing: 1.3,
                    fontWeight: FontWeight.w800,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  result.season,
                  style: const TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${result.undertone} • ${result.brightness} • ${result.contrast}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.white70,
                  ),
                ),
                if (result.colours.isNotEmpty) ...[
                  const SizedBox(height: 13),
                  Row(
                    children: List.generate(
                      result.colours.take(6).length,
                      (index) => Container(
                        width: 20,
                        height: 20,
                        margin: const EdgeInsets.only(right: 5),
                        decoration: BoxDecoration(
                          color: Color.lerp(
                            accent,
                            Colors.white,
                            (index + 1) / 10,
                          ),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: .45),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Container(
            width: 76,
            height: 102,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .48),
              borderRadius: BorderRadius.circular(38),
            ),
            child: const Icon(
              Icons.face_retouching_natural_rounded,
              size: 42,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _insightRow(ColourAnalysisResult? result) {
    final colour = result?.colours.isNotEmpty == true
        ? result!.colours.first
        : '—';

    return Row(
      children: [
        Expanded(
          child: _miniMetric(
            'A colour to try',
            colour,
            Icons.palette_outlined,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _miniMetric(
            'Wardrobe',
            '${_wardrobe.length} ${_wardrobe.length == 1 ? 'piece' : 'pieces'}',
            Icons.checkroom_outlined,
          ),
        ),
      ],
    );
  }

  Widget _miniMetric(String label, String value, IconData icon) {
    return Container(
      constraints: const BoxConstraints(minHeight: 92),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 19, color: AppColors.primaryDark),
          const Spacer(),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w800,
        letterSpacing: -.15,
      ),
    );
  }

  Widget _dailyStyleCard(ColourAnalysisResult? result) {
    final colour = result?.colours.isNotEmpty == true
        ? result!.colours.first
        : null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border.withValues(alpha: .7)),
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: const BoxDecoration(
              color: AppColors.primarySoft,
              shape: BoxShape.circle,
            ),
            child: Icon(
              colour == null
                  ? Icons.auto_awesome_outlined
                  : Icons.wb_sunny_outlined,
              color: AppColors.primaryDark,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  colour == null
                      ? 'Start with your colour profile'
                      : 'Try $colour today',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  colour == null
                      ? 'A little personalisation goes a long way.'
                      : 'Let one of your best colours become the starting point for your outfit.',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _quickActions() {
    final actions = <({String label, IconData icon, VoidCallback onTap})>[
      (
        label: 'Colours',
        icon: Icons.palette_outlined,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AnalysisScreen()),
        ),
      ),
      (
        label: 'Wardrobe',
        icon: Icons.checkroom_outlined,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const WardrobeScreen()),
        ),
      ),
      (
        label: 'AI Stylist',
        icon: Icons.auto_awesome_rounded,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AIStylistScreen()),
        ),
      ),
      (
        label: 'Learn',
        icon: Icons.menu_book_outlined,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const LearningScreen()),
        ),
      ),
    ];

    return Row(
      children: actions.map((item) {
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Material(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(18),
              child: InkWell(
                onTap: item.onTap,
                borderRadius: BorderRadius.circular(18),
                child: Container(
                  height: 88,
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        item.icon,
                        color: AppColors.primaryDark,
                        size: 22,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        item.label,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _aiCard(ColourAnalysisResult? result) {
    final season = result?.season;
    final subtitle = season == null
        ? 'Tell TiB where you are going and we’ll help you build a look that feels like you.'
        : 'Build a look around your $season colours and the pieces already in your wardrobe.';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppGradients.ai,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, size: 18, color: AppColors.primaryDark),
              const SizedBox(width: 7),
              const Text(
                'TiB AI STYLIST',
                style: TextStyle(
                  fontSize: 10,
                  letterSpacing: 1.1,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primaryDark,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .65),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'PERSONAL',
                  style: TextStyle(fontSize: 8, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text(
            'Not sure what to wear?',
            style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 7),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 11,
              height: 1.5,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AIStylistScreen()),
              ),
              icon: const Icon(Icons.auto_awesome_rounded, size: 18),
              label: const Text('Style Me'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _wardrobeCard() {
    WardrobeItem? firstImage;
    for (final item in _wardrobe) {
      if (item.imageUrl.isNotEmpty) {
        firstImage = item;
        break;
      }
    }

    final categoryCounts = <String, int>{};
    for (final item in _wardrobe) {
      categoryCounts[item.category] = (categoryCounts[item.category] ?? 0) + 1;
    }

    String? largestCategory;
    var largestCount = 0;
    for (final entry in categoryCounts.entries) {
      if (entry.value > largestCount) {
        largestCategory = entry.key;
        largestCount = entry.value;
      }
    }

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const WardrobeScreen()),
        ),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_wardrobe.length} ${_wardrobe.length == 1 ? 'piece' : 'pieces'}',
                      style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      _wardrobe.isEmpty
                          ? 'Add a few pieces and let TiB style from your real wardrobe.'
                          : 'Your real clothes, ready for smarter outfit ideas.',
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                    if (largestCategory != null) ...[
                      const SizedBox(height: 11),
                      Text(
                        'Most pieces: $largestCategory ($largestCount)',
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.brown,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 92,
                height: 92,
                child: firstImage != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: CachedNetworkImage(
                          imageUrl: firstImage.imageUrl,
                          fit: BoxFit.cover,
                        ),
                      )
                    : Container(
                        decoration: BoxDecoration(
                          color: AppColors.surfaceMuted,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: const Icon(
                          Icons.checkroom_outlined,
                          color: AppColors.primary,
                          size: 30,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _learningCard() {
    return Material(
      color: AppColors.primarySoft.withValues(alpha: .55),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const LearningScreen()),
        ),
        borderRadius: BorderRadius.circular(20),
        child: const Padding(
          padding: EdgeInsets.all(18),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Learn your colours',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                    ),
                    SizedBox(height: 5),
                    Text(
                      'Small lessons. Better choices. More confidence.',
                      style: TextStyle(fontSize: 10, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_rounded, color: AppColors.primaryDark),
            ],
          ),
        ),
      ),
    );
  }
}
