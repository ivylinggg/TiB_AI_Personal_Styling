import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_radius.dart';
import '../../../models/colour_analysis_result.dart';
import '../../../services/firestore_service.dart';
import '../../../widgets/empty_state.dart';
import '../../auth/auth_service.dart';
import '../analysis_result_screen.dart';

class AnalysisHistoryScreen extends StatefulWidget {
  const AnalysisHistoryScreen({super.key});

  @override
  State<AnalysisHistoryScreen> createState() => _AnalysisHistoryScreenState();
}

class _AnalysisHistoryScreenState extends State<AnalysisHistoryScreen> {
  late Future<List<ColourAnalysisResult>> historyFuture;

  @override
  void initState() {
    super.initState();
    historyFuture = _loadHistory();
  }

  Future<List<ColourAnalysisResult>> _loadHistory() async {
    final user = AuthService.currentUser;
    if (user == null) return const <ColourAnalysisResult>[];
    return FirestoreService.getColourAnalysisHistory(user.uid);
  }

  Future<void> refreshHistory() async {
    setState(() => historyFuture = _loadHistory());
    await historyFuture;
  }

  String _confidenceLabel(double confidence) {
    if (confidence >= .85) return 'High confidence';
    if (confidence >= .65) return 'Good confidence';
    if (confidence > 0) return 'Needs a clearer photo';
    return 'Confidence unavailable';
  }

  Color _confidenceColor(double confidence) {
    if (confidence >= .85) return AppColors.success;
    if (confidence >= .65) return AppColors.primary;
    return AppColors.textMuted;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Your Analysis History'),
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: [
          IconButton(
            tooltip: 'Refresh history',
            onPressed: refreshHistory,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: FutureBuilder<List<ColourAnalysisResult>>(
        future: historyFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) return _buildErrorState();

          final history = snapshot.data ?? const <ColourAnalysisResult>[];
          if (history.isEmpty) return _buildEmptyState();

          return RefreshIndicator(
            onRefresh: refreshHistory,
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
              itemCount: history.length + 1,
              separatorBuilder: (_, __) => const SizedBox(height: 14),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return const Padding(
                    padding: EdgeInsets.only(bottom: 2),
                    child: Text(
                      'Look back at your colour journey and tap any result to explore it again.',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  );
                }
                final item = history[index - 1];
                return _buildHistoryCard(context, item, index - 1);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildHistoryCard(
    BuildContext context,
    ColourAnalysisResult item,
    int index,
  ) {
    final confidence = item.confidence.clamp(0.0, 1.0).toDouble();
    final confidenceText = _confidenceLabel(confidence);
    final confidenceColor = _confidenceColor(confidence);

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AnalysisResultScreen(result: item),
          ),
        ),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.border),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 500;
              final content = Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.season,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${item.undertone} • ${item.brightness} • ${item.contrast}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 9),
                    Wrap(
                      spacing: 7,
                      runSpacing: 7,
                      children: [
                        _pill('Analysis ${index + 1}', AppColors.secondary, AppColors.primaryDark),
                        if (confidence > 0)
                          _pill(
                            '${(confidence * 100).round()}% · $confidenceText',
                            confidenceColor.withValues(alpha: .12),
                            confidenceColor,
                          ),
                      ],
                    ),
                  ],
                ),
              );

              final cardContent = compact
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildHistoryImage(item),
                            const SizedBox(width: 14),
                            content,
                            const SizedBox(width: 8),
                            const Icon(Icons.chevron_right_rounded, size: 24, color: AppColors.primary),
                          ],
                        ),
                        if (confidence > 0) ...[
                          const SizedBox(height: 13),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(99),
                            child: LinearProgressIndicator(
                              minHeight: 5,
                              value: confidence,
                              backgroundColor: AppColors.secondary,
                              valueColor: AlwaysStoppedAnimation<Color>(confidenceColor),
                            ),
                          ),
                        ],
                      ],
                    )
                  : Row(
                      children: [
                        _buildHistoryImage(item),
                        const SizedBox(width: 14),
                        content,
                        const SizedBox(width: 10),
                        const Icon(Icons.chevron_right_rounded, size: 24, color: AppColors.primary),
                      ],
                    );

              return cardContent;
            },
          ),
        ),
      ),
    );
  }

  Widget _pill(String label, Color background, Color foreground) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: foreground,
        ),
      ),
    );
  }

  Widget _buildHistoryImage(ColourAnalysisResult item) {
    if (item.imageUrl.isEmpty) {
      return Container(
        width: 68,
        height: 68,
        decoration: const BoxDecoration(
          color: AppColors.secondary,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.auto_awesome, color: AppColors.primary, size: 30),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: CachedNetworkImage(
        imageUrl: item.imageUrl,
        width: 68,
        height: 68,
        fit: BoxFit.cover,
        placeholder: (_, __) => Container(
          width: 68,
          height: 68,
          color: AppColors.secondary,
          child: const Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
        errorWidget: (_, __, ___) => Container(
          width: 68,
          height: 68,
          color: AppColors.secondary,
          child: const Icon(Icons.image_not_supported_outlined, color: AppColors.primary),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return RefreshIndicator(
      onRefresh: refreshHistory,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 90),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: EmptyState(
              icon: Icons.history_rounded,
              title: 'Your colour journey starts here',
              description: 'Complete your first colour analysis and your personalised results will be saved here for easy reference.',
              ctaLabel: 'Start Analysis',
              onCta: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: EmptyState(
          icon: Icons.cloud_off_rounded,
          title: 'We couldn’t load your colour history',
          description: 'Please check your internet connection, then try again.',
          ctaLabel: 'Try Again',
          onCta: refreshHistory,
        ),
      ),
    );
  }
}
