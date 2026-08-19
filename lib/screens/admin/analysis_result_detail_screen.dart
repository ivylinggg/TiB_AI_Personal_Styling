import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/constants/app_colors.dart';

class AnalysisResultDetailScreen extends StatelessWidget {
  final String season;
  final String undertone;
  final String brightness;
  final String contrast;
  final String imageUrl;
  final DateTime? createdAt;

  const AnalysisResultDetailScreen({
    super.key,
    required this.season,
    required this.undertone,
    required this.brightness,
    required this.contrast,
    required this.imageUrl,
    required this.createdAt,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,

      appBar: AppBar(
        title: const Text('Analysis Result'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Copy result',
            onPressed: () async {
              final summary = [
                'Colour Season: $season',
                'Undertone: $undertone',
                'Brightness: $brightness',
                'Contrast: $contrast',
              ].join('\n');

              await Clipboard.setData(
                ClipboardData(text: summary),
              );

              if (!context.mounted) {
                return;
              }

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Analysis result copied.'),
                ),
              );
            },
            icon: const Icon(Icons.copy_outlined),
          ),
        ],
      ),

      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
        children: [
          // ======================================================
          // RESULT HEADER
          // ======================================================
          _buildResultHeader(),

          const SizedBox(height: 20),

          // ======================================================
          // ANALYSIS IMAGE
          // ======================================================
          _buildAnalysisImage(),

          const SizedBox(height: 24),

          // ======================================================
          // RESULT SUMMARY
          // ======================================================
          _sectionTitle('Colour Analysis'),

          const SizedBox(height: 10),

          _resultCard(
            icon: Icons.palette_outlined,
            title: 'Colour Season',
            value: season,
          ),

          _resultCard(
            icon: Icons.thermostat_outlined,
            title: 'Undertone',
            value: undertone,
          ),

          _resultCard(
            icon: Icons.wb_sunny_outlined,
            title: 'Brightness',
            value: brightness,
          ),

          _resultCard(
            icon: Icons.contrast_outlined,
            title: 'Contrast',
            value: contrast,
          ),

          const SizedBox(height: 4),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.info_outline,
                  size: 20,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'These values are the colour analysis results recorded for this customer.',
                    style: TextStyle(
                      color: AppColors.primaryDark,
                      height: 1.45,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ======================================================
          // ANALYSIS INFORMATION
          // ======================================================
          _sectionTitle('Analysis Information'),

          const SizedBox(height: 10),

          _informationCard(),

          const SizedBox(height: 24),

          // ======================================================
          // ADMIN NOTE
          // ======================================================
          _sectionTitle('Admin View'),

          const SizedBox(height: 10),

          Container(
            padding: const EdgeInsets.all(18),

            decoration: BoxDecoration(
              color: AppColors.surface,

              borderRadius: BorderRadius.circular(18),

              border: Border.all(color: AppColors.border),
            ),

            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                const Icon(Icons.info_outline, color: AppColors.primary),

                const SizedBox(width: 12),

                Expanded(
                  child: Text(
                    'Administrators can review the customer’s recorded colour analysis result and analysis information from this page.',
                    style: TextStyle(color: AppColors.textSecondary, height: 1.5),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // RESULT HEADER
  // ============================================================

  Widget _buildResultHeader() {
    return Container(
      padding: const EdgeInsets.all(20),

      decoration: BoxDecoration(
        color: AppColors.surface,

        borderRadius: BorderRadius.circular(20),

        border: Border.all(color: AppColors.border),
      ),

      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,

            decoration: BoxDecoration(
              color: AppColors.secondary,

              borderRadius: BorderRadius.circular(16),
            ),

            child: const Icon(
              Icons.auto_awesome,
              color: AppColors.primary,
              size: 30,
            ),
          ),

          const SizedBox(width: 16),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                const Text(
                  'Colour Analysis Result',

                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 6),

                Text(
                  season,

                  maxLines: 2,

                  overflow: TextOverflow.ellipsis,

                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),

                if (createdAt != null) ...[
                  const SizedBox(height: 4),

                  Text(
                    _formatDate(createdAt!),

                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // IMAGE
  // ============================================================

  Widget _buildAnalysisImage() {
    if (imageUrl.isEmpty) {
      return Container(
        width: double.infinity,
        height: 280,

        decoration: BoxDecoration(
          color: AppColors.secondary,

          borderRadius: BorderRadius.circular(20),
        ),

        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,

          children: [
            Icon(
              Icons.image_not_supported_outlined,
              size: 48,
              color: AppColors.primary,
            ),

            SizedBox(height: 10),

            Text('No analysis image available'),
          ],
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),

      child: Image.network(
        imageUrl,

        width: double.infinity,
        height: 320,

        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) {
            return child;
          }

          return Container(
            width: double.infinity,
            height: 320,
            decoration: BoxDecoration(
              color: AppColors.secondary,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.primary,
              ),
            ),
          );
        },

        errorBuilder: (context, error, stackTrace) {
          return Container(
            width: double.infinity,
            height: 320,

            decoration: BoxDecoration(
              color: AppColors.secondary,

              borderRadius: BorderRadius.circular(20),
            ),

            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,

              children: [
                Icon(
                  Icons.image_not_supported_outlined,
                  size: 48,
                  color: AppColors.primary,
                ),

                SizedBox(height: 10),

                Text('Unable to load image'),
              ],
            ),
          );
        },
      ),
    );
  }

  // ============================================================
  // RESULT CARD
  // ============================================================

  Widget _resultCard({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),

      padding: const EdgeInsets.all(16),

      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.border,
        ),
      ),

      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,

            decoration: BoxDecoration(
              color: AppColors.surfaceMuted,

              borderRadius: BorderRadius.circular(12),
            ),

            child: Icon(icon, color: AppColors.primary),
          ),

          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                Text(
                  title,

                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),

                const SizedBox(height: 4),

                Text(
                  value,

                  maxLines: 2,

                  overflow: TextOverflow.ellipsis,

                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // INFORMATION CARD
  // ============================================================

  Widget _informationCard() {
    return Container(
      padding: const EdgeInsets.all(18),

      decoration: BoxDecoration(
        color: AppColors.surface,

        borderRadius: BorderRadius.circular(18),

        border: Border.all(color: AppColors.border),
      ),

      child: Column(
        children: [
          _informationRow(
            'Analysis Date',
            createdAt == null ? 'Unavailable' : _formatDate(createdAt!),
          ),

          const Divider(height: 24),

          _informationRow('Colour Season', season),

          const Divider(height: 24),

          _informationRow('Undertone', undertone),

          const Divider(height: 24),

          _informationRow('Brightness', brightness),

          const Divider(height: 24),

          _informationRow('Contrast', contrast),
        ],
      ),
    );
  }

  Widget _informationRow(String title, String value) {
    return Row(
      children: [
        Expanded(
          child: Text(title, style: TextStyle(color: AppColors.textSecondary)),
        ),

        const SizedBox(width: 16),

        Flexible(
          child: Text(
            value,

            textAlign: TextAlign.end,

            maxLines: 2,

            overflow: TextOverflow.ellipsis,

            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // SECTION TITLE
  // ============================================================

  Widget _sectionTitle(String title) {
    return Text(
      title,

      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
    );
  }

  // ============================================================
  // DATE
  // ============================================================

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');

    final month = date.month.toString().padLeft(2, '0');

    return '$day/$month/${date.year}';
  }
}
