import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  bool isLoading = true;

  int totalUsers = 0;
  int activeUsers = 0;
  int inactiveUsers = 0;
  int totalAnalyses = 0;
  int publishedContent = 0;

  int springAnalyses = 0;
  int summerAnalyses = 0;
  int autumnAnalyses = 0;
  int winterAnalyses = 0;

  List<QueryDocumentSnapshot<Map<String, dynamic>>> recentAnalyses = [];

  @override
  void initState() {
    super.initState();
    loadDashboardData();
  }

  // ============================================================
  // LOAD DASHBOARD DATA
  // ============================================================

  Future<void> loadDashboardData() async {
    setState(() {
      isLoading = true;
    });

    try {
      final firestore = FirebaseFirestore.instance;

      // ----------------------------------------------------------
      // USERS
      // ----------------------------------------------------------

      final usersSnapshot = await firestore.collection('users').get();

      int active = 0;
      int inactive = 0;

      for (final document in usersSnapshot.docs) {
        final data = document.data();

        final isActive = data['isActive'] as bool? ?? true;

        if (isActive) {
          active++;
        } else {
          inactive++;
        }
      }

      // ----------------------------------------------------------
      // ANALYSES
      // ----------------------------------------------------------

      final analysisSnapshot = await firestore
          .collectionGroup('analysis')
          .orderBy('createdAt', descending: true)
          .get();

      int spring = 0;
      int summer = 0;
      int autumn = 0;
      int winter = 0;

      for (final document in analysisSnapshot.docs) {
        final data = document.data();

        final season = (data['season'] as String? ?? '').toLowerCase();

        if (season.contains('spring')) {
          spring++;
        } else if (season.contains('summer')) {
          summer++;
        } else if (season.contains('autumn')) {
          autumn++;
        } else if (season.contains('winter')) {
          winter++;
        }
      }

      // ----------------------------------------------------------
      // CONTENT
      // ----------------------------------------------------------

      final contentSnapshot = await firestore.collection('content').get();

      int published = 0;

      for (final document in contentSnapshot.docs) {
        final data = document.data();

        final isPublished = data['isPublished'] as bool? ?? false;

        if (isPublished) {
          published++;
        }
      }

      if (!mounted) return;

      setState(() {
        totalUsers = usersSnapshot.docs.length;

        activeUsers = active;

        inactiveUsers = inactive;

        totalAnalyses = analysisSnapshot.docs.length;

        publishedContent = published;

        springAnalyses = spring;

        summerAnalyses = summer;

        autumnAnalyses = autumn;

        winterAnalyses = winter;

        recentAnalyses = analysisSnapshot.docs.take(5).toList();

        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to load dashboard data: $e')),
      );
    }
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F6F4),

      appBar: AppBar(title: const Text('Admin Dashboard'), elevation: 0),

      body: RefreshIndicator(
        onRefresh: loadDashboardData,

        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),

                padding: const EdgeInsets.all(20),

                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [
                    // ==================================================
                    // WELCOME
                    // ==================================================
                    Text(
                      'Welcome, Admin 👋',

                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),

                    const SizedBox(height: 6),

                    Text(
                      'Here is your TiB AI system overview.',

                      style: TextStyle(color: Colors.grey.shade600),
                    ),

                    const SizedBox(height: 24),

                    // ==================================================
                    // STATISTICS
                    // ==================================================
                    const Text(
                      'System Overview',

                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 14),

                    GridView.count(
                      crossAxisCount: 2,

                      crossAxisSpacing: 12,

                      mainAxisSpacing: 12,

                      shrinkWrap: true,

                      physics: const NeverScrollableScrollPhysics(),

                      childAspectRatio: 1.35,

                      children: [
                        _buildStatCard(
                          title: 'Total Users',
                          value: totalUsers.toString(),
                          icon: Icons.people_outline,
                        ),

                        _buildStatCard(
                          title: 'Active Users',
                          value: activeUsers.toString(),
                          icon: Icons.person_outline,
                        ),

                        _buildStatCard(
                          title: 'Inactive Users',
                          value: inactiveUsers.toString(),
                          icon: Icons.person_off_outlined,
                        ),

                        _buildStatCard(
                          title: 'Total Analyses',
                          value: totalAnalyses.toString(),
                          icon: Icons.analytics_outlined,
                        ),

                        _buildStatCard(
                          title: 'Published Content',
                          value: publishedContent.toString(),
                          icon: Icons.library_books_outlined,
                        ),
                      ],
                    ),

                    const SizedBox(height: 30),

                    // ==================================================
                    // COLOUR ANALYSIS OVERVIEW
                    // ==================================================
                    const Text(
                      'Colour Analysis Overview',

                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 6),

                    Text(
                      'Distribution of customer colour seasons.',

                      style: TextStyle(color: Colors.grey.shade600),
                    ),

                    const SizedBox(height: 14),

                    _buildSeasonOverview(),

                    const SizedBox(height: 30),

                    // ==================================================
                    // RECENT ANALYSIS
                    // ==================================================
                    const Text(
                      'Recent Analyses',

                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 14),

                    _buildRecentAnalyses(),

                    const SizedBox(height: 30),

                    // ==================================================
                    // MANAGEMENT MODULES
                    // ==================================================
                    const Text(
                      'Management',

                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 14),

                    _buildOverviewCard(
                      icon: Icons.people_outline,
                      title: 'User Management',
                      description: 'View, search and manage registered users.',
                    ),

                    const SizedBox(height: 10),

                    _buildOverviewCard(
                      icon: Icons.analytics_outlined,
                      title: 'Analysis Management',
                      description:
                          'Monitor colour analysis activity and results.',
                    ),

                    const SizedBox(height: 10),

                    _buildOverviewCard(
                      icon: Icons.library_books_outlined,
                      title: 'Content Management',
                      description:
                          'Manage learning content and styling resources.',
                    ),

                    const SizedBox(height: 10),

                    _buildOverviewCard(
                      icon: Icons.workspace_premium_outlined,
                      title: 'Premium Management',
                      description: 'Monitor premium users and subscriptions.',
                    ),

                    const SizedBox(height: 30),

                    // ==================================================
                    // SYSTEM STATUS
                    // ==================================================
                    const Text(
                      'System Status',

                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 14),

                    _buildSystemStatus(),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
      ),
    );
  }

  // ============================================================
  // STAT CARD
  // ============================================================

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
  }) {
    return Card(
      elevation: 0,

      child: Padding(
        padding: const EdgeInsets.all(16),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,

          mainAxisAlignment: MainAxisAlignment.spaceBetween,

          children: [
            Container(
              width: 42,
              height: 42,

              decoration: BoxDecoration(
                color: const Color(0xFFF5D8C7),

                borderRadius: BorderRadius.circular(12),
              ),

              child: Icon(icon, color: const Color(0xFFC58F73)),
            ),

            Text(
              value,

              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
            ),

            Text(
              title,

              style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // SEASON OVERVIEW
  // ============================================================

  Widget _buildSeasonOverview() {
    return Column(
      children: [
        _buildSeasonRow('Spring', springAnalyses, Icons.local_florist_outlined),

        const SizedBox(height: 10),

        _buildSeasonRow('Summer', summerAnalyses, Icons.wb_sunny_outlined),

        const SizedBox(height: 10),

        _buildSeasonRow('Autumn', autumnAnalyses, Icons.eco_outlined),

        const SizedBox(height: 10),

        _buildSeasonRow('Winter', winterAnalyses, Icons.ac_unit_outlined),
      ],
    );
  }

  Widget _buildSeasonRow(String season, int count, IconData icon) {
    final percentage = totalAnalyses == 0 ? 0.0 : count / totalAnalyses;

    return Card(
      elevation: 0,

      child: Padding(
        padding: const EdgeInsets.all(16),

        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,

              decoration: BoxDecoration(
                color: const Color(0xFFFDF1EA),

                borderRadius: BorderRadius.circular(12),
              ),

              child: Icon(icon, color: const Color(0xFFC58F73)),
            ),

            const SizedBox(width: 12),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,

                children: [
                  Row(
                    children: [
                      Text(
                        season,

                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),

                      const Spacer(),

                      Text(
                        '$count',

                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),

                    child: LinearProgressIndicator(
                      value: percentage,

                      minHeight: 7,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // RECENT ANALYSES
  // ============================================================

  Widget _buildRecentAnalyses() {
    if (recentAnalyses.isEmpty) {
      return Card(
        elevation: 0,

        child: Padding(
          padding: const EdgeInsets.all(24),

          child: Center(
            child: Text(
              'No analysis records available.',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ),
        ),
      );
    }

    return Column(
      children: recentAnalyses.map((document) {
        final data = document.data();

        final season = data['season'] as String? ?? 'Unknown';

        final undertone = data['undertone'] as String? ?? 'Unknown';

        final createdAt = data['createdAt'] as Timestamp?;

        return Card(
          elevation: 0,

          margin: const EdgeInsets.only(bottom: 10),

          child: ListTile(
            leading: const CircleAvatar(
              backgroundColor: Color(0xFFF5D8C7),

              child: Icon(Icons.analytics_outlined, color: Color(0xFFC58F73)),
            ),

            title: Text(
              season,

              style: const TextStyle(fontWeight: FontWeight.w600),
            ),

            subtitle: Text(undertone),

            trailing: Text(
              createdAt == null ? '--' : _formatDate(createdAt.toDate()),

              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ============================================================
  // MANAGEMENT CARD
  // ============================================================

  Widget _buildOverviewCard({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Card(
      elevation: 0,

      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),

        leading: CircleAvatar(
          backgroundColor: const Color(0xFFF5D8C7),

          child: Icon(icon, color: const Color(0xFFC58F73)),
        ),

        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),

        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),

          child: Text(description),
        ),

        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      ),
    );
  }

  // ============================================================
  // SYSTEM STATUS
  // ============================================================

  Widget _buildSystemStatus() {
    return Card(
      elevation: 0,

      child: Padding(
        padding: const EdgeInsets.all(20),

        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,

              decoration: BoxDecoration(
                color: Colors.green.shade50,

                shape: BoxShape.circle,
              ),

              child: Icon(Icons.check_circle, color: Colors.green.shade700),
            ),

            const SizedBox(width: 16),

            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,

                children: [
                  Text(
                    'System Operational',

                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),

                  SizedBox(height: 4),

                  Text('Firebase services are connected.'),
                ],
              ),
            ),
          ],
        ),
      ),
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
