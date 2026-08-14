import 'package:flutter/material.dart';

import '../../models/colour_analysis_result.dart';

class AnalysisResultScreen extends StatelessWidget {
  final ColourAnalysisResult result;

  const AnalysisResultScreen({super.key, required this.result});

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

          Text(
            'Here’s what suits you',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
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
