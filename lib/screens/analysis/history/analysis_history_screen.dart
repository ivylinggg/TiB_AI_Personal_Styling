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
    final user = AuthService.currentUser;
    historyFuture = user == null
        ? Future.value(<ColourAnalysisResult>[])
        : FirestoreService.getColourAnalysisHistory(user.uid);
  }

  Future<void> refreshHistory() async {
    final user = AuthService.currentUser;
    if (user == null) {
      if (!mounted) return;
      setState(() => historyFuture = Future.value(<ColourAnalysisResult>[]));
      return;
    }
    setState(() {
      historyFuture = FirestoreService.getColourAnalysisHistory(user.uid);
    });
    await historyFuture;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Your Analysis History'),
        backgroundColor: AppColors.background,
        elevation: 0,
        actions: [
          Semantics(
            button: true,
            label: 'Refresh analysis history',
            child: IconButton(
              tooltip: 'Refresh history',
              onPressed: refreshHistory,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ),
        ],
      ),
      body: FutureBuilder<List<ColourAnalysisResult>>(
        future: historyFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: Semantics(
                liveRegion: true,
                label: 'Loading analysis history',
                child: CircularProgressIndicator(),
              ),
            );
          }
          if (snapshot.hasError) return _buildErrorState();

          final history = snapshot.data ?? <ColourAnalysisResult>[];
          if (history.isEmpty) return _buildEmptyState();

          return RefreshIndicator(
            onRefresh: refreshHistory,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 900;
                final contentWidth = wide ? 900.0 : constraints.maxWidth;
                return ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(
                    wide ? (constraints.maxWidth - contentWidth) / 2 : 20,
                    8,
                    wide ? (constraints.maxWidth - contentWidth) / 2 : 20,
                    30,
                  ),
                  itemCount: history.length + 1,
                  separatorBuilder: (_, __) => const SizedBox(height: 14),
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return Semantics(
                        header: true,
                        child: const Padding(
                          padding: EdgeInsets.only(bottom: 2),
                          child: Text(
                            'Look back at your colour journey and tap any result to explore it again.',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              height: 1.4,
                            ),
                          ),
                        ),
                      );
                    }
                    return _buildHistoryCard(context, history[index - 1], index - 1);
                  },
                );
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
    return Semantics(
      button: true,
      label: 'Analysis ${index + 1}: ${item.season}, ${item.undertone}, ${item.brightness}, ${item.contrast}',
      hint: 'Double tap to open this analysis result',
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AnalysisResultScreen(result: item),
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: AppColors.border),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 430;
                final image = _buildHistoryImage(item);
                final content = Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.season, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.textPrimary, fontSize: 17, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      Text('${item.undertone} • ${item.brightness} • ${item.contrast}', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.textSecondary)),
                      const SizedBox(height: 10),
                      Align(alignment: Alignment.centerLeft, child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(color: AppColors.secondary, borderRadius: BorderRadius.circular(AppRadius.full)),
                        child: Text('Analysis ${index + 1}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primaryDark)),
                      )),
                    ],
                  ),
                );

                if (!compact) {
                  return Row(children: [image, const SizedBox(width: 14), content, const SizedBox(width: 8), const Icon(Icons.chevron_right_rounded, size: 24, color: AppColors.primary)]);
                }

                return Row(children: [image, const SizedBox(width: 11), content]);
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryImage(ColourAnalysisResult item) {
    if (item.imageUrl.isEmpty) {
      return Semantics(
        image: true,
        label: 'No analysis photo available',
        child: Container(
          width: 68,
          height: 68,
          decoration: const BoxDecoration(color: AppColors.secondary, shape: BoxShape.circle),
          child: const Icon(Icons.auto_awesome, color: AppColors.primary, size: 30),
        ),
      );
    }

    return Semantics(
      image: true,
      label: '${item.season} analysis photo',
      child: ClipRRect(
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
            child: const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
          ),
          errorWidget: (_, __, ___) => Container(
            width: 68,
            height: 68,
            color: AppColors.secondary,
            child: const Icon(Icons.image_not_supported_outlined, color: AppColors.primary),
          ),
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
            child: Semantics(
              header: true,
              child: EmptyState(
                icon: Icons.history_rounded,
                title: 'Your colour journey starts here',
                description: 'Complete your first colour analysis and your personalised results will be saved here for easy reference.',
                ctaLabel: 'Start Analysis',
                onCta: () => Navigator.pop(context),
              ),
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
        child: Semantics(
          liveRegion: true,
          child: EmptyState(
            icon: Icons.cloud_off_rounded,
            title: 'We couldn’t load your colour history',
            description: 'Please check your internet connection, then try again.',
            ctaLabel: 'Try Again',
            onCta: refreshHistory,
          ),
        ),
      ),
    );
  }
}
