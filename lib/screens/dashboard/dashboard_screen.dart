import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';

import '../analysis/history/analysis_history_screen.dart';

import '/screens/dashboard/feature_card.dart';
import '/screens/dashboard/style_score_card.dart';
import '/screens/dashboard/tip_card.dart';
import '/widgets/todays_colour_card.dart';
import '/screens/dashboard/hero_card.dart';
import '../analysis/analysis_screen.dart';
import '../ai/ai_stylist_screen.dart';
import '../learning/learning_screen.dart';
import '../wardrobe/wardrobe_screen.dart';


class _PremiumChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _PremiumChip({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: Colors.white,
            size: 15,
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _isPremium = false;
  bool _premiumLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadPremiumStatus();
  }

  Future<void> _loadPremiumStatus() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      if (mounted) {
        setState(() => _premiumLoaded = true);
      }
      return;
    }

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

      if (!mounted) {
        return;
      }

      setState(() {
        _isPremium = snapshot.data()?['isPremium'] == true;
        _premiumLoaded = true;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isPremium = false;
        _premiumLoaded = true;
      });
    }
  }


  Widget _buildPremiumDashboardCard() {
    final isPremium = _premiumLoaded && _isPremium;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isPremium
              ? const [
                  Color(0xFFC58F73),
                  Color(0xFFE7B9A3),
                ]
              : const [
                  Color(0xFFB78E7A),
                  Color(0xFFD9B5A2),
                ],
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.workspace_premium,
                color: Colors.white,
                size: 30,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  isPremium
                      ? 'Premium Membership'
                      : 'TiB AI Premium',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (isPremium)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'ACTIVE',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            isPremium
                ? 'Your Premium access is active. Enjoy the full TiB AI styling experience.'
                : 'Unlock advanced colour insights, smart wardrobe tools, Premium learning and personalised AI styling.',
            style: const TextStyle(
              color: Colors.white,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 18),
          if (isPremium)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: const [
                _PremiumChip(
                  icon: Icons.palette_outlined,
                  label: 'Colour Insights',
                ),
                _PremiumChip(
                  icon: Icons.checkroom_outlined,
                  label: 'Smart Wardrobe',
                ),
                _PremiumChip(
                  icon: Icons.auto_awesome,
                  label: 'AI Stylist',
                ),
                _PremiumChip(
                  icon: Icons.school_outlined,
                  label: 'Premium Learning',
                ),
              ],
            )
          else
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Premium plans will be available soon.',
                      ),
                    ),
                  );
                },
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Color(0xFF8B5E4A),
                ),
                child: const Text('Upgrade to Premium'),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,

      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const CircleAvatar(
                    radius: 28,
                    backgroundColor: Color(0xffF5D8C7),
                    child: Icon(Icons.person, color: Colors.white),
                  ),

                  const SizedBox(width: 15),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Builder(
                          builder: (context) {
                            final hour = DateTime.now().hour;
                            final greeting = hour < 12
                                ? 'Good Morning 👋'
                                : hour < 18
                                    ? 'Good Afternoon 👋'
                                    : 'Good Evening 👋';

                            return Text(
                              greeting,
                              style: Theme.of(context).textTheme.bodyMedium,
                            );
                          },
                        ),

                        const SizedBox(height: 4),

                        Text(
                          "Welcome back to TiB AI",
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),

                        const SizedBox(height: 3),

                        Text(
                          "Let’s find a look that feels like you.",
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),

                  IconButton(
                    tooltip: 'Notifications',
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'You’re all caught up. New styling updates will appear here.',
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.notifications_none),
                  ),
                ],
              ),

              const SizedBox(height: 30),

              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AnalysisScreen(),
                    ),
                  );
                },
                child: const HeroCard(),
              ),

              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AnalysisHistoryScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.history),
                  label: const Text("View Analysis History"),
                ),
              ),

              const SizedBox(height: 25),

              const StyleScoreCard(score: 98, season: "Warm Spring"),

              const SizedBox(height: 25),

              const TodaysColourCard(),

              const SizedBox(height: 30),

              _buildPremiumDashboardCard(),

              const SizedBox(height: 30),

              Text(
                "Quick Access",
                style: Theme.of(context).textTheme.titleLarge,
              ),

              const SizedBox(height: 15),

              GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 15,
                mainAxisSpacing: 15,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 1.15,

                children: [
                  FeatureCard(
                    icon: Icons.palette_outlined,
                    title: "Colour\nAnalysis",
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AnalysisScreen(),
                        ),
                      );
                    },
                  ),

                  FeatureCard(
                    icon: Icons.checkroom_outlined,
                    title: "Wardrobe",
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const WardrobeScreen(),
                        ),
                      );
                    },
                  ),

                  FeatureCard(
                    icon: Icons.auto_awesome,
                    title: "AI Stylist",
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AIStylistScreen(),
                        ),
                      );
                    },
                  ),

                  FeatureCard(
                    icon: Icons.school_outlined,
                    title: "Learning",
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const LearningScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),

              const SizedBox(height: 30),

              Text(
                "Today's Tip",
                style: Theme.of(context).textTheme.titleLarge,
              ),

              const SizedBox(height: 15),

              const TipCard(
                title: "Today's Style Tip",
                description:
                    "Warm beige, peach and olive green will enhance your complexion today.",
              ),

              const SizedBox(height: 30),

              const SizedBox(height: 0),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}
