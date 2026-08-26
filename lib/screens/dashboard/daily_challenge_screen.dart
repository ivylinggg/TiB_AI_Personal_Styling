import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../services/daily_challenge_service.dart';

class DailyChallengeScreen extends StatefulWidget {
  const DailyChallengeScreen({super.key});

  @override
  State<DailyChallengeScreen> createState() => _DailyChallengeScreenState();
}

class _DailyChallengeScreenState extends State<DailyChallengeScreen> {
  bool _loading = true;
  bool _completed = false;
  int _points = 0;
  int _streak = 0;

  DailyChallenge get challenge => DailyChallengeService.today();

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
      final values = await Future.wait([
        DailyChallengeService.isCompleted(uid),
        DailyChallengeService.totalPoints(uid),
        DailyChallengeService.streak(uid),
      ]);
      if (!mounted) return;
      setState(() {
        _completed = values[0] as bool;
        _points = values[1] as int;
        _streak = values[2] as int;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _completeChallenge() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || _completed) return;

    setState(() => _loading = true);
    try {
      final added = await DailyChallengeService.complete(uid);
      if (!mounted) return;
      setState(() {
        _completed = true;
        _points += added ? challenge.points : 0;
        _loading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(added ? '+${challenge.points} points added!' : 'Today’s challenge is already completed.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save your challenge. Please try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Daily Challenge'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _loading && !_completed
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
              children: [
                Row(
                  children: [
                    Expanded(child: _statCard(Icons.stars_rounded, 'POINTS', '$_points')),
                    const SizedBox(width: 10),
                    Expanded(child: _statCard(Icons.local_fire_department_rounded, 'STREAK', '$_streak days')),
                  ],
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(26),
                    border: Border.all(color: AppColors.border),
                    boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: .06), blurRadius: 18, offset: const Offset(0, 8))],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 58,
                            height: 58,
                            decoration: const BoxDecoration(color: AppColors.primarySoft, shape: BoxShape.circle),
                            child: const Icon(Icons.auto_awesome_rounded, color: AppColors.primaryDark, size: 27),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              const Text('TODAY’S TASK', style: TextStyle(color: AppColors.textMuted, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: .8)),
                              const SizedBox(height: 5),
                              Text(challenge.category, style: const TextStyle(color: AppColors.primaryDark, fontSize: 11, fontWeight: FontWeight.w800)),
                            ]),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(12)),
                            child: Text('+${challenge.points} XP', style: const TextStyle(color: AppColors.primaryDark, fontSize: 10, fontWeight: FontWeight.w900)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 22),
                      Text(challenge.title, style: const TextStyle(fontSize: 25, height: 1.12, fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
                      const SizedBox(height: 10),
                      Text(challenge.description, style: const TextStyle(fontSize: 13, height: 1.55, color: AppColors.textSecondary)),
                      const SizedBox(height: 22),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(16)),
                        child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Icon(Icons.lightbulb_outline_rounded, color: AppColors.primary, size: 20),
                          SizedBox(width: 10),
                          Expanded(child: Text('Small daily actions build better styling habits. You do not need to be perfect — just keep showing up.', style: TextStyle(fontSize: 11.5, height: 1.45, color: AppColors.textSecondary))),
                        ]),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton.icon(
                          onPressed: _loading || _completed ? null : _completeChallenge,
                          icon: Icon(_completed ? Icons.check_circle_rounded : Icons.done_rounded),
                          label: Text(_completed ? 'Completed Today' : 'Mark as Completed'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: AppColors.primarySoft,
                            disabledForegroundColor: AppColors.primaryDark,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                const Text('Your progress', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
                const SizedBox(height: 7),
                const Text('Complete one meaningful styling task every day to build XP and a consistent personal style routine.', style: TextStyle(fontSize: 11.5, height: 1.5, color: AppColors.textSecondary)),
              ],
            ),
    );
  }

  Widget _statCard(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.border)),
      child: Row(children: [
        Icon(icon, color: AppColors.primary, size: 22),
        const SizedBox(width: 9),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontSize: 7.8, fontWeight: FontWeight.w900, letterSpacing: .6, color: AppColors.textMuted)),
          const SizedBox(height: 3),
          Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
        ])),
      ]),
    );
  }
}
