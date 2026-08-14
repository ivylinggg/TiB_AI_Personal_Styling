import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class PremiumScreen extends StatefulWidget {
  const PremiumScreen({super.key});

  @override
  State<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends State<PremiumScreen> {
  static const Color _brown = Color(0xFF8E5E46);
  static const Color _cream = Color(0xFFFFFAF7);
  static const Color _soft = Color(0xFFF8E3DC);
  static const Color _text = Color(0xFF302A27);
  static const Color _muted = Color(0xFF756B67);

  bool _loading = true;
  bool _isPremium = false;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      if (!mounted) {
        return;
      }
      setState(() => _loading = false);
      return;
    }

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!mounted) {
        return;
      }

      setState(() {
        _isPremium = snapshot.data()?['isPremium'] as bool? ?? false;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not load your Premium status.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _cream,
      appBar: AppBar(
        backgroundColor: _cream,
        elevation: 0,
        iconTheme: const IconThemeData(color: _text),
        title: const Text(
          'Premium',
          style: TextStyle(
            color: _text,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading ? null : _loadStatus,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadStatus,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 32),
                children: [
                  _buildHero(),
                  const SizedBox(height: 20),
                  _buildBenefits(),
                  const SizedBox(height: 20),
                  _buildStatusCard(),
                ],
              ),
            ),
    );
  }

  Widget _buildHero() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFFF4D5C8),
            Color(0xFFF9EAE5),
          ],
        ),
        borderRadius: BorderRadius.circular(26),
      ),
      child: Column(
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.workspace_premium_rounded,
              color: Color(0xFFB27B27),
              size: 38,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _isPremium
                ? 'You’re a Premium Member'
                : 'Make your styling experience more personal',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _text,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _isPremium
                ? 'Your Premium access is active. Keep exploring your personalised styling tools.'
                : 'Premium access unlocks the enhanced styling experience as your account grows.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _muted,
              height: 1.45,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBenefits() {
    const benefits = [
      (
        Icons.auto_awesome_rounded,
        'More personalised styling',
        'Get styling suggestions built around your wardrobe and preferences.',
      ),
      (
        Icons.checkroom_rounded,
        'Wardrobe-based ideas',
        'Use the pieces you already own as the starting point for your looks.',
      ),
      (
        Icons.palette_outlined,
        'Colour-aware suggestions',
        'Keep your personal colour direction in mind when building outfits.',
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'What Premium is for',
          style: TextStyle(
            color: _text,
            fontSize: 19,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        ...benefits.map(
          (benefit) => Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: const Color(0xFFF0DDD2),
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: _soft,
                  child: Icon(
                    benefit.$1,
                    color: _brown,
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        benefit.$2,
                        style: const TextStyle(
                          color: _text,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        benefit.$3,
                        style: const TextStyle(
                          color: _muted,
                          height: 1.35,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFF0DDD2),
        ),
      ),
      child: Row(
        children: [
          Icon(
            _isPremium
                ? Icons.check_circle_rounded
                : Icons.info_outline_rounded,
            color: _isPremium ? Colors.green : _brown,
            size: 28,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _isPremium
                  ? 'Premium is currently active on your account.'
                  : 'Premium access is currently managed by your administrator.',
              style: const TextStyle(
                color: _text,
                height: 1.4,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
