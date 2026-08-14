import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../models/colour_analysis_result.dart';

class AnalysisResultScreen extends StatefulWidget {
  final ColourAnalysisResult result;

  const AnalysisResultScreen({super.key, required this.result});

  @override
  State<AnalysisResultScreen> createState() => _AnalysisResultScreenState();
}

class _AnalysisResultScreenState extends State<AnalysisResultScreen> {
  bool _isPremium = false;
  bool _premiumLoaded = false;

  ColourAnalysisResult get result => widget.result;

  @override
  void initState() {
    super.initState();
    _loadPremiumStatus();
  }

  Future<void> _loadPremiumStatus() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      if (mounted) {
        setState(() {
          _premiumLoaded = true;
        });
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDF9F6),
      appBar: AppBar(
        title: const Text('Your Colour Result'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Back to analysis',
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
        children: [
          // ========================================================
          // HEADER
          // ========================================================
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: const Color(0xFFF5D8C7),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFE7B9A3), width: 1.5),
            ),
            child: const Icon(
              Icons.auto_awesome,
              size: 34,
              color: Color(0xFFC58F73),
            ),
          ),

          const SizedBox(height: 12),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  'Here’s what suits you',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (_premiumLoaded && _isPremium) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5D8C7),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    Icons.workspace_premium,
                    size: 16,
                    color: Color(0xFFC58F73),
                  ),
                ),
              ],
            ],
          ),

          const SizedBox(height: 6),

          Text(
            'Your result gives you a simple starting point for choosing clothes, accessories and everyday colours.',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade700),
          ),

          const SizedBox(height: 24),

          // ========================================================
          // MAIN SEASON CARD
          // ========================================================
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFFF5D8C7),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              children: [
                const Text(
                  'YOUR COLOUR SEASON',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                    color: Color(0xFF8B5E4B),
                  ),
                ),

                const SizedBox(height: 10),

                Text(
                  result.season,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 8),

                Text(
                  'Your personalised colour direction',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF8B5E4B),
                  ),
                ),

                const SizedBox(height: 14),

                const Divider(color: Color(0xFFC58F73)),

                const SizedBox(height: 14),

                Row(
                  children: [
                    Expanded(
                      child: _buildSummaryItem(
                        icon: Icons.thermostat_outlined,
                        title: 'Undertone',
                        value: result.undertone,
                      ),
                    ),
                    Expanded(
                      child: _buildSummaryItem(
                        icon: Icons.wb_sunny_outlined,
                        title: 'Brightness',
                        value: result.brightness,
                      ),
                    ),
                    Expanded(
                      child: _buildSummaryItem(
                        icon: Icons.contrast,
                        title: 'Contrast',
                        value: result.contrast,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 28),

          // ========================================================
          // ANALYSIS DETAILS
          // ========================================================
          Text(
            'What we found',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 14),

          _buildDetailCard(
            icon: Icons.thermostat_outlined,
            title: 'Skin Undertone',
            value: result.undertone,
          ),

          _buildDetailCard(
            icon: Icons.wb_sunny_outlined,
            title: 'Brightness',
            value: result.brightness,
          ),

          _buildDetailCard(
            icon: Icons.contrast,
            title: 'Contrast Level',
            value: result.contrast,
          ),

          const SizedBox(height: 18),

          if (_premiumLoaded && _isPremium) _buildPremiumInsights(),

          const SizedBox(height: 18),

          // ========================================================
          // BEST COLOURS
          // ========================================================
          Text(
            'Colours to Try',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 8),

          Text(
            'Start with these shades when choosing your next outfit.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade700),
          ),

          const SizedBox(height: 16),

          if (result.colours.isEmpty)
            _buildEmptyColours()
          else
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: result.colours
                  .map((colour) => _buildColourChip(colour))
                  .toList(),
            ),

          const SizedBox(height: 24),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFF0DDD2)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const CircleAvatar(
                  radius: 21,
                  backgroundColor: Color(0xFFF5D8C7),
                  child: Icon(
                    Icons.lightbulb_outline,
                    color: Color(0xFFC58F73),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'A little tip for you',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'Use your recommended colours as a guide, not a rule. The best outfit is one that also feels comfortable and like you.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey.shade700,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 30),

          // ========================================================
          // IMAGE REFERENCE
          // ========================================================
          if (result.imageUrl.isNotEmpty) ...[
            Text(
              'Your Analysis Photo',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 14),

            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.network(
                result.imageUrl,
                height: 240,
                width: double.infinity,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) {
                    return child;
                  }

                  return Container(
                    height: 240,
                    color: const Color(0xFFF5D8C7),
                    child: const Center(child: CircularProgressIndicator()),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    height: 240,
                    color: const Color(0xFFF5D8C7),
                    child: const Center(
                      child: Icon(Icons.image_not_supported_outlined, size: 50),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 30),
          ],

          // ========================================================
          // ACTION
          // ========================================================
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () {
                Navigator.pop(context);
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Analyse Another Photo'),
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 52),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SUMMARY ITEM
  // ============================================================

  Widget _buildPremiumInsights() {
    final season = result.season.trim();
    final undertone = result.undertone.trim();
    final brightness = result.brightness.trim();
    final contrast = result.contrast.trim();

    String stylingDirection() {
      if (season.isEmpty) {
        return 'Build outfits around your recommended colours and keep your palette consistent across clothing and accessories.';
      }

      return 'Use your $season palette as the main colour direction, then balance it with your recorded undertone and contrast level.';
    }

    String contrastTip() {
      final value = contrast.toLowerCase();

      if (value.contains('high')) {
        return 'Your contrast level can support clearer separation between outfit colours. Try pairing a stronger colour with a lighter or darker supporting shade.';
      }

      if (value.contains('low')) {
        return 'A softer tonal outfit can work well with your contrast level. Try keeping neighbouring shades close in depth for a more blended look.';
      }

      return 'Your contrast level gives you flexibility. Start with one main colour and add a supporting shade without making the outfit feel too busy.';
    }

    String undertoneTip() {
      final value = undertone.toLowerCase();

      if (value.contains('warm')) {
        return 'For everyday styling, explore warmer versions of your recommended colours and repeat warm accents in accessories.';
      }

      if (value.contains('cool')) {
        return 'For everyday styling, explore cooler versions of your recommended colours and repeat cool accents in accessories.';
      }

      return 'Your undertone can work with a broad range of shades. Compare warmer and cooler versions of a colour to find the most flattering balance.';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFDF1EA),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE7B9A3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.workspace_premium_outlined,
                color: Color(0xFFC58F73),
                size: 22,
              ),
              SizedBox(width: 8),
              Text(
                'Premium Colour Insights',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF5D4037),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Personalised styling guidance based on your recorded analysis.',
            style: TextStyle(
              color: Color(0xFF7A6258),
              fontSize: 12.5,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          _buildPremiumInsightRow(
            Icons.palette_outlined,
            'Colour direction',
            stylingDirection(),
          ),
          _buildPremiumInsightRow(
            Icons.thermostat_outlined,
            'Undertone styling',
            undertoneTip(),
          ),
          _buildPremiumInsightRow(
            Icons.contrast_outlined,
            'Contrast styling',
            contrastTip(),
          ),
          const SizedBox(height: 4),
          Text(
            'Profile: $undertone • $brightness • $contrast',
            style: TextStyle(
              color: Colors.brown.shade700,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumInsightRow(
    IconData icon,
    String title,
    String description,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: const BoxDecoration(
              color: Color(0xFFF5D8C7),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 18, color: Color(0xFFC58F73)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF5D4037),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  description,
                  style: TextStyle(
                    color: Colors.brown.shade700,
                    fontSize: 12,
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

  Widget _buildSummaryItem({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Column(
      children: [
        Icon(icon, size: 22, color: const Color(0xFF8B5E4B)),

        const SizedBox(height: 6),

        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        ),

        const SizedBox(height: 3),

        Text(
          value,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  // ============================================================
  // DETAIL CARD
  // ============================================================

  Widget _buildDetailCard({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: CircleAvatar(
          backgroundColor: const Color(0xFFF5D8C7),
          child: Icon(icon, color: const Color(0xFFC58F73)),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        trailing: Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  // ============================================================
  // COLOUR CHIP
  // ============================================================

  Widget _buildColourChip(String colour) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      decoration: BoxDecoration(
        color: const Color(0xFFF5D8C7),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.palette_outlined,
            size: 17,
            color: Color(0xFFC58F73),
          ),
          const SizedBox(width: 7),
          Text(colour, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  // ============================================================
  // EMPTY COLOURS
  // ============================================================

  Widget _buildEmptyColours() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(Icons.palette_outlined, size: 32, color: Colors.grey),
          const SizedBox(height: 8),
          const Text(
            'No recommended colours are available for this result yet.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
