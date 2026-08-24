import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_gradients.dart';
import 'virtual_try_on_screen.dart';

class PremiumScreen extends StatefulWidget {
  const PremiumScreen({super.key});

  @override
  State<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends State<PremiumScreen>
    with SingleTickerProviderStateMixin {
  static const Color _brown = AppColors.primary;
  static const Color _cream = AppColors.background;
  static const Color _soft = AppColors.secondary;
  static const Color _text = AppColors.textPrimary;
  static const Color _muted = AppColors.textSecondary;

  bool _loading = true;
  bool _isPremium = false;
  String? _loadError;

  late final AnimationController _revealController;
  late final Animation<double> _heroReveal;
  late final Animation<double> _contentReveal;
  late final Animation<double> _statusReveal;

  @override
  void initState() {
    super.initState();
    _revealController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    );
    _heroReveal = _stage(0.0, 0.42);
    _contentReveal = _stage(0.18, 0.72);
    _statusReveal = _stage(0.45, 1.0);
    _revealController.forward();
    _loadStatus();
  }

  Animation<double> _stage(double begin, double end) {
    return CurvedAnimation(
      parent: _revealController,
      curve: Interval(begin, end, curve: Curves.easeOut),
    );
  }

  Widget _reveal(Animation<double> animation, Widget child) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, animatedChild) {
        final value = animation.value.clamp(0.0, 1.0);
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 14),
            child: animatedChild,
          ),
        );
      },
      child: child,
    );
  }

  @override
  void dispose() {
    _revealController.dispose();
    super.dispose();
  }

  Future<void> _loadStatus() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = 'Please sign in to view your Premium status.';
      });
      return;
    }

    if (mounted) {
      setState(() {
        _loading = true;
        _loadError = null;
      });
    }

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!mounted) return;

      setState(() {
        _isPremium = snapshot.data()?['isPremium'] == true;
        _loading = false;
        _loadError = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = 'We could not load your Premium status right now.';
      });
    }
  }

  void _openVirtualTryOn() {
    if (!_isPremium) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const VirtualTryOnScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _cream,
      appBar: AppBar(
        backgroundColor: _cream,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: _text),
        title: const Text(
          'Premium',
          style: TextStyle(color: _text, fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh Premium status',
            onPressed: _loading ? null : _loadStatus,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadStatus,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
                children: [
                  _reveal(_heroReveal, _buildHero()),
                  const SizedBox(height: 24),
                  if (_loadError != null) ...[
                    _buildErrorCard(),
                    const SizedBox(height: 18),
                  ],
                  _reveal(_contentReveal, _buildIntro()),
                  const SizedBox(height: 14),
                  _reveal(_contentReveal, _buildBenefits()),
                  const SizedBox(height: 14),
                  _reveal(_contentReveal, _buildVirtualTryOnCard()),
                  const SizedBox(height: 20),
                  _reveal(_statusReveal, _buildAccessInfo()),
                  const SizedBox(height: 14),
                  _reveal(_statusReveal, _buildStatusCard()),
                ],
              ),
            ),
    );
  }

  Widget _buildHero() {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 26, 22, 22),
      decoration: BoxDecoration(
        gradient: AppGradients.premium,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 92,
                height: 92,
                decoration: BoxDecoration(
                  color: _cream.withValues(alpha: 0.55),
                  shape: BoxShape.circle,
                ),
              ),
              Container(
                width: 68,
                height: 68,
                decoration: const BoxDecoration(
                  color: _cream,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.workspace_premium_rounded,
                  color: AppColors.premiumAccentDark,
                  size: 38,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
            decoration: BoxDecoration(
              color: _cream.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _isPremium
                      ? Icons.check_circle_rounded
                      : Icons.auto_awesome_rounded,
                  size: 15,
                  color: _isPremium ? AppColors.success : _brown,
                ),
                const SizedBox(width: 6),
                Text(
                  _isPremium ? 'PREMIUM ACTIVE' : 'TIB PREMIUM',
                  style: const TextStyle(
                    color: _brown,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            _isPremium
                ? 'Your style, elevated.'
                : 'Make your style more personal.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _text,
              fontSize: 25,
              height: 1.12,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 9),
          Text(
            _isPremium
                ? 'Your Premium access is active. Explore the styling tools designed around you.'
                : 'Unlock a more connected styling experience built around your wardrobe, colours and preferences.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _muted,
              height: 1.5,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIntro() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'A smarter way to style',
          style: TextStyle(
            color: _text,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        SizedBox(height: 5),
        Text(
          'TiB connects the things you already told us about your style with the clothes you actually own.',
          style: TextStyle(color: _muted, height: 1.45, fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildBenefits() {
    const benefits = [
      (
        Icons.auto_awesome_rounded,
        'Personalised styling',
        'Get outfit ideas that consider your personal colour direction and style profile.',
      ),
      (
        Icons.checkroom_rounded,
        'Your wardrobe first',
        'Build looks from pieces already saved in your own wardrobe instead of generic items.',
      ),
      (
        Icons.palette_outlined,
        'Colour-aware choices',
        'Keep your colour palette in the conversation when you plan your next look.',
      ),
    ];

    return Column(
      children: [
        for (var i = 0; i < benefits.length; i++) ...[
          _benefitCard(
            icon: benefits[i].$1,
            title: benefits[i].$2,
            description: benefits[i].$3,
            index: i + 1,
          ),
          if (i != benefits.length - 1) const SizedBox(height: 10),
        ],
      ],
    );
  }

  Widget _benefitCard({
    required IconData icon,
    required String title,
    required String description,
    required int index,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              color: _soft,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: _brown, size: 22),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          color: _text,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    Text(
                      '0$index',
                      style: TextStyle(
                        color: _brown.withValues(alpha: 0.35),
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  description,
                  style: const TextStyle(
                    color: _muted,
                    height: 1.4,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVirtualTryOnCard() {
    return InkWell(
      onTap: _isPremium ? _openVirtualTryOn : null,
      borderRadius: BorderRadius.circular(24),
      child: Ink(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: AppGradients.ai,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.view_in_ar_rounded,
                color: AppColors.primaryDark,
                size: 25,
              ),
            ),
            const SizedBox(width: 13),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'TiB Virtual Try-On',
                          style: TextStyle(
                            color: _text,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      Text(
                        'NEW',
                        style: TextStyle(
                          color: AppColors.primaryDark,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Create your TiB Model, choose your own clothes or let AI build a look for you.',
                    style: TextStyle(
                      color: _muted,
                      fontSize: 11.5,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              Icons.arrow_forward_rounded,
              color: _isPremium
                  ? AppColors.primaryDark
                  : AppColors.textMuted,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccessInfo() {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: const BoxDecoration(
              color: _soft,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.admin_panel_settings_outlined,
              color: _brown,
              size: 21,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'How Premium access works',
                  style: TextStyle(
                    color: _text,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  'Premium access is assigned by the administrator. There is currently no in-app payment or subscription checkout.',
                  style: TextStyle(
                    color: _muted,
                    height: 1.45,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard() {
    final active = _isPremium;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: active
              ? AppColors.success.withValues(alpha: 0.35)
              : AppColors.border,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: active
                  ? AppColors.success.withValues(alpha: 0.10)
                  : _soft,
              shape: BoxShape.circle,
            ),
            child: Icon(
              active
                  ? Icons.check_circle_rounded
                  : Icons.lock_outline_rounded,
              color: active ? AppColors.success : _brown,
              size: 23,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  active ? 'Premium is active' : 'Free account',
                  style: const TextStyle(
                    color: _text,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  active
                      ? 'Premium access is currently enabled for your account.'
                      : 'Premium access is currently managed by your administrator.',
                  style: const TextStyle(
                    color: _muted,
                    height: 1.4,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            Icons.chevron_right_rounded,
            color: active ? AppColors.success : AppColors.textMuted,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_off_rounded, color: AppColors.error),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _loadError!,
              style: const TextStyle(
                color: _text,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
          TextButton(
            onPressed: _loadStatus,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
