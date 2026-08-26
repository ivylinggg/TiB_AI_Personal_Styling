import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../services/tib_style_journey_service.dart';

class TibStyleJourneyScreen extends StatefulWidget {
  const TibStyleJourneyScreen({super.key});

  @override
  State<TibStyleJourneyScreen> createState() => _TibStyleJourneyScreenState();
}

class _TibStyleJourneyScreenState extends State<TibStyleJourneyScreen> {
  TibStyleJourney? _journey;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    final journey = await TibStyleJourneyService.load(uid);
    if (!mounted) return;
    setState(() {
      _journey = journey;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final journey = _journey ??
        const TibStyleJourney(
          points: 0,
          streak: 0,
          completedChallenges: 0,
          level: 1,
          levelTitle: 'Getting Started',
          currentLevelPoints: 0,
          nextLevelPoints: 50,
          badges: [],
        );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Style Journey'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            _hero(journey),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _stat(Icons.stars_rounded, '${journey.points}', 'XP')),
                const SizedBox(width: 10),
                Expanded(child: _stat(Icons.local_fire_department_rounded, '${journey.streak}', 'Day Streak')),
                const SizedBox(width: 10),
                Expanded(child: _stat(Icons.check_circle_rounded, '${journey.completedChallenges}', 'Completed')),
              ],
            ),
            const SizedBox(height: 24),
            const Text(
              'Your badges',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
            const Text(
              'Small, real actions build your personal styling journey.',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.45),
            ),
            const SizedBox(height: 14),
            ...journey.badges.map(_badgeCard),
          ],
        ),
      ),
    );
  }

  Widget _hero(TibStyleJourney journey) {
    final isMax = journey.level >= 5;
    final progressText = isMax
        ? '${journey.points} XP'
        : '${journey.points} / ${journey.nextLevelPoints} XP';

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: .06),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 62,
                height: 62,
                decoration: const BoxDecoration(
                  color: AppColors.primarySoft,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '${journey.level}',
                    style: const TextStyle(
                      color: AppColors.primaryDark,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'YOUR STYLE JOURNEY',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: .9,
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Level ${journey.level} · ${journey.levelTitle}',
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Progress',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.textSecondary),
              ),
              Text(
                progressText,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: AppColors.primaryDark),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LinearProgressIndicator(
              minHeight: 9,
              value: journey.progress,
              backgroundColor: AppColors.primarySoft,
              valueColor: const AlwaysStoppedAnimation(AppColors.primary),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            isMax
                ? 'You have reached the current TiB Stylist level. Keep building your styling habits.'
                : '${journey.nextLevelPoints - journey.points} XP to your next level.',
            style: const TextStyle(fontSize: 11.5, height: 1.45, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _stat(IconData icon, String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 13),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Icon(icon, size: 21, color: AppColors.primary),
          const SizedBox(height: 5),
          Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
          const SizedBox(height: 2),
          Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.w700, color: AppColors.textMuted)),
        ],
      ),
    );
  }

  Widget _badgeCard(TibBadge badge) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: badge.unlocked ? AppColors.primarySoft : AppColors.border,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: badge.unlocked ? AppColors.primarySoft : AppColors.background,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                badge.icon,
                style: TextStyle(fontSize: 23, color: badge.unlocked ? null : AppColors.textMuted),
              ),
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  badge.title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: badge.unlocked ? AppColors.textPrimary : AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  badge.description,
                  style: const TextStyle(fontSize: 10.5, height: 1.35, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          Icon(
            badge.unlocked ? Icons.check_circle_rounded : Icons.lock_outline_rounded,
            color: badge.unlocked ? AppColors.primary : AppColors.textMuted,
            size: 20,
          ),
        ],
      ),
    );
  }
}
