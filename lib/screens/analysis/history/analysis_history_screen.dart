import 'package:flutter/material.dart';

import '../../../models/analysis_model.dart';
import '../../../services/firestore_service.dart';
import '../../auth/auth_service.dart';

class AnalysisHistoryScreen extends StatefulWidget {
  const AnalysisHistoryScreen({super.key});

  @override
  State<AnalysisHistoryScreen> createState() => _AnalysisHistoryScreenState();
}

class _AnalysisHistoryScreenState extends State<AnalysisHistoryScreen> {
  late Future<List<AnalysisModel>> historyFuture;

  @override
  void initState() {
    super.initState();

    final user = AuthService.currentUser;

    if (user != null) {
      historyFuture = FirestoreService.getAnalysisHistory(user.uid);
    } else {
      historyFuture = Future.value([]);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Analysis History")),

      body: FutureBuilder<List<AnalysisModel>>(
        future: historyFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text(snapshot.error.toString()));
          }

          final history = snapshot.data ?? [];

          if (history.isEmpty) {
            return const Center(child: Text("No analysis history yet."));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: history.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final item = history[index];

              return Card(
                child: ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.auto_awesome)),

                  title: Text(item.colourSeason),

                  subtitle: Text(item.skinTone),

                  trailing: Text(
                    "${item.createdAt.day}/${item.createdAt.month}/${item.createdAt.year}",
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
