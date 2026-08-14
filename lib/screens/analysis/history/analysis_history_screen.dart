import 'package:flutter/material.dart';

import '../../../models/colour_analysis_result.dart';
import '../../../services/firestore_service.dart';
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

    if (user != null) {
      historyFuture = FirestoreService.getColourAnalysisHistory(user.uid);
    } else {
      historyFuture = Future.value(<ColourAnalysisResult>[]);
    }
  }

  Future<void> refreshHistory() async {
    final user = AuthService.currentUser;

    if (user == null) {
      setState(() {
        historyFuture = Future.value(<ColourAnalysisResult>[]);
      });
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
      backgroundColor: const Color(0xFFFDF9F6),

      appBar: AppBar(
        title: const Text('Your Analysis History'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Refresh history',
            onPressed: refreshHistory,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),

      body: FutureBuilder<List<ColourAnalysisResult>>(
        future: historyFuture,
        builder: (context, snapshot) {
          // ======================================================
          // LOADING
          // ======================================================

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // ======================================================
          // ERROR
          // ======================================================

          if (snapshot.hasError) {
            return _buildErrorState(snapshot.error.toString());
          }

          final history = snapshot.data ?? <ColourAnalysisResult>[];

          // ======================================================
          // EMPTY
          // ======================================================

          if (history.isEmpty) {
            return _buildEmptyState();
          }

          // ======================================================
          // HISTORY LIST
          // ======================================================

          return RefreshIndicator(
            onRefresh: refreshHistory,
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
              itemCount: history.length + 1,
              separatorBuilder: (context, index) => const SizedBox(height: 14),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(
                      'Look back at your colour journey and tap any result to explore it again.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey.shade700,
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

  // ============================================================
  // HISTORY CARD
  // ============================================================

  Widget _buildHistoryCard(
    BuildContext context,
    ColourAnalysisResult item,
    int index,
  ) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Color(0xFFF0DDD2)),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AnalysisResultScreen(result: item),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // ==================================================
              // IMAGE
              // ==================================================
              _buildHistoryImage(item),

              const SizedBox(width: 14),

              // ==================================================
              // CONTENT
              // ==================================================
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.season,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 6),

                    Text(
                      '${item.undertone} • '
                      '${item.brightness} • '
                      '${item.contrast}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.grey.shade700),
                    ),

                    const SizedBox(height: 10),

                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5D8C7),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Analysis ${index + 1}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF8B5E4B),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              const Icon(
                Icons.chevron_right_rounded,
                size: 24,
                color: Color(0xFFC58F73),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // HISTORY IMAGE
  // ============================================================

  Widget _buildHistoryImage(ColourAnalysisResult item) {
    if (item.imageUrl.isEmpty) {
      return const CircleAvatar(
        radius: 34,
        backgroundColor: Color(0xFFF5D8C7),
        child: Icon(Icons.auto_awesome, color: Color(0xFFC58F73), size: 30),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Image.network(
        item.imageUrl,
        width: 68,
        height: 68,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            width: 68,
            height: 68,
            color: const Color(0xFFF5D8C7),
            child: const Icon(
              Icons.image_not_supported_outlined,
              color: Color(0xFFC58F73),
            ),
          );
        },
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) {
            return child;
          }

          return Container(
            width: 68,
            height: 68,
            color: const Color(0xFFF5D8C7),
            child: const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        },
      ),
    );
  }

  // ============================================================
  // EMPTY STATE
  // ============================================================

  Widget _buildEmptyState() {
    return RefreshIndicator(
      onRefresh: refreshHistory,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 130),

          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 35),
              child: Column(
                children: [
                  Icon(
                    Icons.history_outlined,
                    size: 80,
                    color: Colors.grey.shade400,
                  ),

                  const SizedBox(height: 18),

                  Text(
                    'Your colour journey starts here',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 8),

                  Text(
                    'Complete your first colour analysis and your personalised results will be saved here for easy reference.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade600),
                  ),

                  const SizedBox(height: 24),

                  FilledButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.auto_awesome),
                    label: const Text('Start Analysis'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ERROR STATE
  // ============================================================

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 65),

            const SizedBox(height: 16),

            const Text(
              'We couldn’t load your colour history.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 8),

            Text(
              'Please check your internet connection, then try again.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),

            const SizedBox(height: 20),

            FilledButton(
              onPressed: refreshHistory,
              child: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }
}
