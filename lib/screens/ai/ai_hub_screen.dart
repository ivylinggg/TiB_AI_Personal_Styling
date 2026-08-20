import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_gradients.dart';
import '../../providers/analysis_provider.dart';
import '../../services/firestore_service.dart';
import '../../widgets/premium_badge.dart';
import '../analysis/analysis_screen.dart';
import '../wardrobe/wardrobe_screen.dart';
import 'ai_outfit_screen.dart';
import 'ai_stylist_screen.dart';
import 'style_me_screen.dart';

/// TiB's central styling hub: one place for every styling action.
/// The hub now reflects the user's real styling profile instead of behaving
/// like a static landing page.
class AIHubScreen extends StatefulWidget {
  const AIHubScreen({super.key});

  @override
  State<AIHubScreen> createState() => _AIHubScreenState();
}

class _AIHubScreenState extends State<AIHubScreen> {
  bool _loading = true;
  bool _isPremium = false;
  int _wardrobeCount = 0;
  String? _firstName;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    try {
      final results = await Future.wait<dynamic>([
        FirebaseFirestore.instance.collection('users').doc(user.uid).get(),
        FirestoreService.getWardrobeItems(user.uid),
      ]);
      if (!mounted) return;

      final userData =
          (results[0] as DocumentSnapshot<Map<String, dynamic>>).data();
      final wardrobe = results[1] as List;
      final displayName = user.displayName?.trim();
      final storedName = userData?['name']?.toString().trim();

      setState(() {
        _isPremium = userData?['isPremium'] == true;
        _wardrobeCount = wardrobe.length;
        _firstName = _nameFrom(displayName?.isNotEmpty == true
            ? displayName
            : storedName);
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  String? _nameFrom(String? value) {
    if (value == null || value.isEmpty) return null;
    return value.split(RegExp(r'\s+')).first;
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<AnalysisProvider>().result;
    final greeting = _firstName == null ? 'What are we wearing?' : 'What are we wearing, $_firstName?';
    final hasColourProfile = profile != null;
    final hasWardrobe = _wardrobeCount > 0;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadProfile,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'YOUR PERSONAL STYLIST',
                          style: TextStyle(
                            fontSize: 9,
                            letterSpacing: 1.4,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textMuted,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          greeting,
                          style: const TextStyle(
                            fontSize: 27,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.9,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_isPremium)
                    const PremiumBadge(compact: true)
                  else
                    IconButton(
                      tooltip: 'Refresh style profile',
                      onPressed: _loading ? null : _loadProfile,
                      icon: const Icon(Icons.refresh_rounded),
                    ),
                ],
              ),
              const SizedBox(height: 7),
              const Text(
                'Your colours, preferences and wardrobe come together here so getting dressed feels easier.',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  height: 1.45,
                  fontSize: 12.5,
                ),
              ),
              const SizedBox(height: 16),
              _profileReadinessCard(
                hasColourProfile: hasColourProfile,
                hasWardrobe: hasWardrobe,
                profile: profile,
              ),
              const SizedBox(height: 16),
              _heroCard(hasColourProfile, hasWardrobe),
              const SizedBox(height: 18),
              _sectionLabel('START HERE'),
              const SizedBox(height: 9),
              _featureCard(
                context,
                icon: Icons.auto_awesome_rounded,
                title: 'Style Me',
                subtitle: 'Describe your plan and build a look from your wardrobe.',
                gradient: AppGradients.ai,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const StyleMeScreen()),
                ),
                primary: true,
              ),
              const SizedBox(height: 11),
              _featureCard(
                context,
                icon: Icons.checkroom_rounded,
                title: 'AI Outfit',
                subtitle: 'Choose an occasion and create a complete outfit.',
                gradient: AppGradients.blush,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AIOutfitScreen()),
                ),
                primary: false,
              ),
              const SizedBox(height: 11),
              _featureCard(
                context,
                icon: Icons.chat_bubble_outline_rounded,
                title: 'Talk to TiB',
                subtitle: 'Have a natural conversation about what to wear.',
                gradient: AppGradients.soft,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AIStylistScreen()),
                ),
                primary: false,
              ),
              const SizedBox(height: 22),
              _sectionLabel('YOUR STYLE DATA'),
              const SizedBox(height: 9),
              Row(
                children: [
                  Expanded(
                    child: _smallLink(
                      context,
                      Icons.palette_outlined,
                      hasColourProfile ? profile!.season : 'Colour profile',
                      const AnalysisScreen(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _smallLink(
                      context,
                      Icons.checkroom_outlined,
                      hasWardrobe ? 'Wardrobe · $_wardrobeCount' : 'Add wardrobe',
                      const WardrobeScreen(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _profileHint(hasColourProfile, hasWardrobe),
            ],
          ),
        ),
      ),
    );
  }

  Widget _profileReadinessCard({
    required bool hasColourProfile,
    required bool hasWardrobe,
    required dynamic profile,
  }) {
    final complete = hasColourProfile && hasWardrobe;
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: complete ? AppColors.lavenderMist : AppColors.surface,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: complete ? AppColors.primarySoft : AppColors.surfaceMuted,
              shape: BoxShape.circle,
            ),
            child: Icon(
              complete ? Icons.auto_awesome_rounded : Icons.tune_rounded,
              color: AppColors.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  complete ? 'Your styling profile is ready' : 'Complete your styling profile',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 3),
                Text(
                  complete
                      ? 'TiB can work with your ${profile.season} palette and $_wardrobeCount wardrobe pieces.'
                      : hasColourProfile
                          ? 'Add a few wardrobe pieces so TiB can style what you actually own.'
                          : 'Start with Colour Analysis, then add a few pieces you already love.',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 11.5, height: 1.4),
                ),
              ],
            ),
          ),
          if (!complete)
            const Icon(Icons.arrow_forward_ios_rounded, size: 13, color: AppColors.primary),
        ],
      ),
    );
  }

  Widget _heroCard(bool hasColourProfile, bool hasWardrobe) {
    return Container(
      padding: const EdgeInsets.fromLTRB(19, 19, 19, 18),
      decoration: BoxDecoration(
        gradient: AppGradients.primary,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 43,
                height: 43,
                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                child: const Icon(Icons.auto_awesome_rounded, color: AppColors.primaryDark, size: 21),
              ),
              const Spacer(),
              if (_isPremium)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .18),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text('PREMIUM AI', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 1)),
                ),
            ],
          ),
          const SizedBox(height: 22),
          const Text(
            'Your style,\nwithout the guesswork.',
            style: TextStyle(color: Colors.white, fontSize: 24, height: 1.05, fontWeight: FontWeight.w800, letterSpacing: -.6),
          ),
          const SizedBox(height: 9),
          Text(
            hasColourProfile && hasWardrobe
                ? 'You are ready to turn your own pieces into personalised looks.'
                : 'Set up your colour profile and wardrobe first for the most personal results.',
            style: const TextStyle(color: Colors.white70, fontSize: 11.5, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _profileHint(bool hasColourProfile, bool hasWardrobe) {
    final text = hasColourProfile && hasWardrobe
        ? 'Tip: the more accurately you keep your wardrobe and preferences updated, the more useful your styling results become.'
        : hasColourProfile
            ? 'Next step: add your everyday pieces to My Wardrobe.'
            : 'Next step: complete Colour Analysis to give TiB your colour direction.';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.lightbulb_outline_rounded, size: 17, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11.5, height: 1.4))),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(text, style: const TextStyle(fontSize: 9, letterSpacing: 1.3, fontWeight: FontWeight.w800, color: AppColors.textMuted));
  }

  Widget _featureCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required LinearGradient gradient,
    required VoidCallback onTap,
    required bool primary,
  }) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Ink(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(gradient: gradient, borderRadius: BorderRadius.circular(24)),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: primary ? .95 : .78), shape: BoxShape.circle),
                child: Icon(icon, color: AppColors.primaryDark, size: 21),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(color: primary ? Colors.white : AppColors.textPrimary, fontSize: 17, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text(subtitle, style: TextStyle(color: primary ? Colors.white70 : AppColors.textSecondary, fontSize: 11, height: 1.35)),
                  ],
                ),
              ),
              const SizedBox(width: 7),
              Icon(Icons.arrow_forward_rounded, color: primary ? Colors.white : AppColors.primary),
            ],
          ),
        ),
      ),
    );
  }

  Widget _smallLink(BuildContext context, IconData icon, String label, Widget page) {
    return InkWell(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => page)),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.border)),
        child: Row(
          children: [
            Icon(icon, color: AppColors.primary, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700))),
          ],
        ),
      ),
    );
  }
}
