import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../services/tib_style_journey_service.dart';

class TibStyleJourneyScreen extends StatefulWidget {
  const TibStyleJourneyScreen({super.key});

  @override
  State<TibStyleJourneyScreen> createState() => _TibStyleJourneyScreenState();
}

enum _JourneyFilter { all, unlocked, locked }

class _TibStyleJourneyScreenState extends State<TibStyleJourneyScreen> {
  TibStyleJourney? _journey;
  bool _loading = true;
  _JourneyFilter _filter = _JourneyFilter.all;

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
    try {
      final journey = await TibStyleJourneyService.load(uid);
      if (!mounted) return;
      setState(() {
        _journey = journey;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<TibBadge> get _visibleBadges {
    final badges = _journey?.badges ?? const <TibBadge>[];
    switch (_filter) {
      case _JourneyFilter.unlocked:
        return badges.where((badge) => badge.unlocked).toList();
      case _JourneyFilter.locked:
        return badges.where((badge) => !badge.unlocked).toList();
      case _JourneyFilter.all:
        return badges;
    }
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

    final unlocked = journey.badges.where((badge) => badge.unlocked).length;
    final visibleBadges = _visibleBadges;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Style Journey', style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(20, 8, 20, 0), child: _hero(journey))),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                child: Row(
                  children: [
                    Expanded(child: _stat(Icons.stars_rounded, '${journey.points}', 'XP')),
                    const SizedBox(width: 10),
                    Expanded(child: _stat(Icons.local_fire_department_rounded, '${journey.streak}', 'Day Streak')),
                    const SizedBox(width: 10),
                    Expanded(child: _stat(Icons.check_circle_rounded, '${journey.completedChallenges}', 'Completed')),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('BADGES', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1.4, color: AppColors.primary)),
                          SizedBox(height: 5),
                          Text('Proof of your progress.', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -.35)),
                          SizedBox(height: 5),
                          Text('Small actions turn into a personal style habit.', style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary, height: 1.4)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(99), border: Border.all(color: AppColors.border)),
                      child: Text('$unlocked / ${journey.badges.length}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.primaryDark)),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: SizedBox(
                  height: 38,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: 3,
                    separatorBuilder: (_, _) => const SizedBox(width: 7),
                    itemBuilder: (_, index) {
                      final filter = _JourneyFilter.values[index];
                      final selected = filter == _filter;
                      final label = switch (filter) {
                        _JourneyFilter.all => 'All',
                        _JourneyFilter.unlocked => 'Unlocked',
                        _JourneyFilter.locked => 'Locked',
                      };
                      return ChoiceChip(
                        label: Text(label),
                        selected: selected,
                        onSelected: (_) => setState(() => _filter = filter),
                        showCheckmark: false,
                        selectedColor: AppColors.primary,
                        backgroundColor: AppColors.surface,
                        side: BorderSide(color: selected ? AppColors.primary : AppColors.border),
                        labelStyle: TextStyle(color: selected ? Colors.white : AppColors.textPrimary, fontSize: 10.5, fontWeight: FontWeight.w700),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(99)),
                      );
                    },
                  ),
                ),
              ),
            ),
            if (visibleBadges.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 28, vertical: 32),
                  child: Center(child: Text('No badges in this view yet.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary))),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                sliver: SliverList.separated(
                  itemCount: visibleBadges.length,
                  itemBuilder: (_, index) => _badgeCard(visibleBadges[index]),
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _hero(TibStyleJourney journey) {
    final isMax = journey.level >= 5;
    final remaining = isMax ? 0 : (journey.nextLevelPoints - journey.points).clamp(0, journey.nextLevelPoints);
    final progressText = isMax ? '${journey.points} XP' : '${journey.points} / ${journey.nextLevelPoints} XP';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [AppColors.primaryDark, AppColors.primary]),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: .12), blurRadius: 24, offset: const Offset(0, 12))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 64, height: 64, decoration: BoxDecoration(color: Colors.white.withValues(alpha: .12), shape: BoxShape.circle, border: Border.all(color: Colors.white.withValues(alpha: .16))), child: Center(child: Text('${journey.level}', style: const TextStyle(color: Colors.white, fontSize: 25, fontWeight: FontWeight.w900)))),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('YOUR STYLE JOURNEY', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1.2, color: Colors.white70)),
                  const SizedBox(height: 4),
                  Text('Level ${journey.level}', style: const TextStyle(color: Colors.white, fontSize: 23, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 2),
                  Text(journey.levelTitle, style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
                ]),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Progress to next level', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Colors.white70)), Text(progressText, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w900, color: Colors.white))]),
          const SizedBox(height: 8),
          ClipRRect(borderRadius: BorderRadius.circular(99), child: LinearProgressIndicator(minHeight: 9, value: journey.progress, backgroundColor: Colors.white.withValues(alpha: .16), valueColor: const AlwaysStoppedAnimation(Colors.white))),
          const SizedBox(height: 12),
          Text(isMax ? 'You have reached the current highest level.' : '$remaining XP to your next level.', style: const TextStyle(color: Colors.white70, fontSize: 11, height: 1.4)),
        ],
      ),
    );
  }

  Widget _stat(IconData icon, String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 13),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.border)),
      child: Column(children: [Icon(icon, size: 20, color: AppColors.primary), const SizedBox(height: 5), Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900)), const SizedBox(height: 2), Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.w700, color: AppColors.textMuted))]),
    );
  }

  Widget _badgeCard(TibBadge badge) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), border: Border.all(color: badge.unlocked ? AppColors.primarySoft : AppColors.border)),
        child: Row(children: [
          Container(width: 50, height: 50, decoration: BoxDecoration(color: badge.unlocked ? AppColors.primarySoft : AppColors.background, shape: BoxShape.circle), child: Center(child: Text(badge.icon, style: TextStyle(fontSize: 22, color: badge.unlocked ? null : AppColors.textMuted)))),
          const SizedBox(width: 13),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(badge.title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: badge.unlocked ? AppColors.textPrimary : AppColors.textMuted)), const SizedBox(height: 4), Text(badge.description, style: const TextStyle(fontSize: 10.5, height: 1.35, color: AppColors.textSecondary))])),
          const SizedBox(width: 8),
          Icon(badge.unlocked ? Icons.check_circle_rounded : Icons.lock_outline_rounded, color: badge.unlocked ? AppColors.primary : AppColors.textMuted, size: 20),
        ]),
      ),
    );
  }
}
