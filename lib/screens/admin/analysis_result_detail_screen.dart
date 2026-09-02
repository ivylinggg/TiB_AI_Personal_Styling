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
  final String? userId;

  const AnalysisResultDetailScreen({
    super.key,
    required this.season,
    required this.undertone,
    required this.brightness,
    required this.contrast,
    required this.imageUrl,
    required this.createdAt,
    this.userId,
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
                if (userId != null && userId!.isNotEmpty) 'User ID: $userId',
                'Colour Season: $season',
                'Undertone: $undertone',
                'Brightness: $brightness',
                'Contrast: $contrast',
                if (createdAt != null) 'Analysis Date: ${_formatDate(createdAt!)}',
              ].join('\n');
              await Clipboard.setData(ClipboardData(text: summary));
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Analysis result copied.')),
              );
            },
            icon: const Icon(Icons.copy_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
        children: [
          _buildResultHeader(),
          const SizedBox(height: 20),
          _buildAnalysisImage(),
          const SizedBox(height: 24),
          _sectionTitle('Colour Analysis'),
          const SizedBox(height: 10),
          _resultCard(Icons.palette_outlined, 'Colour Season', season),
          _resultCard(Icons.thermostat_outlined, 'Undertone', undertone),
          _resultCard(Icons.wb_sunny_outlined, 'Brightness', brightness),
          _resultCard(Icons.contrast_outlined, 'Contrast', contrast),
          const SizedBox(height: 20),
          _sectionTitle('Customer Reference'),
          const SizedBox(height: 10),
          _customerReferenceCard(),
          const SizedBox(height: 20),
          _sectionTitle('Analysis Information'),
          const SizedBox(height: 10),
          _informationCard(),
        ],
      ),
    );
  }

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
            child: const Icon(Icons.auto_awesome, color: AppColors.primary, size: 30),
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
            Icon(Icons.image_not_supported_outlined, size: 48, color: AppColors.primary),
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
        errorBuilder: (context, error, stackTrace) => Container(
          width: double.infinity,
          height: 320,
          color: AppColors.secondary,
          child: const Icon(Icons.image_not_supported_outlined, size: 48, color: AppColors.primary),
        ),
      ),
    );
  }

  Widget _customerReferenceCard() {
    final hasUser = userId != null && userId!.isNotEmpty;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
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
            child: Icon(
              hasUser ? Icons.person_outline_rounded : Icons.person_off_outlined,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Customer User ID',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 4),
                Text(
                  hasUser ? userId! : 'Not linked in this record',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _resultCard(IconData icon, String title, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
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
                Text(title, style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                const SizedBox(height: 4),
                Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }

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
          _informationRow('Analysis Date', createdAt == null ? 'Unavailable' : _formatDate(createdAt!)),
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
        Expanded(child: Text(title, style: TextStyle(color: AppColors.textSecondary))),
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

  Widget _sectionTitle(String title) => Text(
        title,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      );

  String _formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
}
