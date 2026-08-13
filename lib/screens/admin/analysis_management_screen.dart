import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'analysis_result_detail_screen.dart';

class AnalysisManagementScreen extends StatefulWidget {
  const AnalysisManagementScreen({super.key});

  @override
  State<AnalysisManagementScreen> createState() =>
      _AnalysisManagementScreenState();
}

class _AnalysisManagementScreenState extends State<AnalysisManagementScreen> {
  final TextEditingController _searchController = TextEditingController();

  String _selectedSeason = 'All';

  final List<String> _seasons = const [
    'All',
    'Spring',
    'Summer',
    'Autumn',
    'Winter',
  ];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {});
  }

  // ============================================================
  // FIRESTORE STREAM
  // ============================================================

  Stream<QuerySnapshot<Map<String, dynamic>>> _analysisStream() {
    return FirebaseFirestore.instance
        .collectionGroup('analysis')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // ============================================================
  // FILTER
  // ============================================================

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _filterResults(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> documents,
  ) {
    final query = _searchController.text.trim().toLowerCase();

    return documents.where((document) {
      final data = document.data();

      final season = (data['season'] as String? ?? '').toLowerCase();

      final undertone = (data['undertone'] as String? ?? '').toLowerCase();

      final brightness = (data['brightness'] as String? ?? '').toLowerCase();

      final contrast = (data['contrast'] as String? ?? '').toLowerCase();

      final matchesSearch =
          query.isEmpty ||
          season.contains(query) ||
          undertone.contains(query) ||
          brightness.contains(query) ||
          contrast.contains(query);

      final matchesSeason =
          _selectedSeason == 'All' ||
          season.contains(_selectedSeason.toLowerCase());

      return matchesSearch && matchesSeason;
    }).toList();
  }

  // ============================================================
  // SEASON COUNT
  // ============================================================

  int _countSeason(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> documents,
    String season,
  ) {
    return documents.where((document) {
      final data = document.data();

      final value = (data['season'] as String? ?? '').toLowerCase();

      return value.contains(season.toLowerCase());
    }).length;
  }

  // ============================================================
  // OPEN RESULT
  // ============================================================

  void _openResult(BuildContext context, Map<String, dynamic> data) {
    final createdAt = data['createdAt'] as Timestamp?;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AnalysisResultDetailScreen(
          season: data['season'] as String? ?? 'Unknown',
          undertone: data['undertone'] as String? ?? 'Unknown',
          brightness: data['brightness'] as String? ?? 'Unknown',
          contrast: data['contrast'] as String? ?? 'Unknown',
          imageUrl: data['imageUrl'] as String? ?? '',
          createdAt: createdAt?.toDate(),
        ),
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Analysis Management')),

      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _analysisStream(),

        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return _buildError(snapshot.error.toString());
          }

          final documents = snapshot.data?.docs ?? [];

          final filtered = _filterResults(documents);

          final total = documents.length;

          final spring = _countSeason(documents, 'Spring');

          final summer = _countSeason(documents, 'Summer');

          final autumn = _countSeason(documents, 'Autumn');

          final winter = _countSeason(documents, 'Winter');

          return RefreshIndicator(
            onRefresh: () async {
              setState(() {});
            },

            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),

              padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),

              children: [
                // ==================================================
                // DASHBOARD TITLE
                // ==================================================
                const Text(
                  'Analysis Overview',

                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 5),

                Text(
                  'Monitor customer colour analysis activity.',
                  style: TextStyle(color: Colors.grey.shade600),
                ),

                const SizedBox(height: 18),

                // ==================================================
                // TOTAL
                // ==================================================
                _buildTotalCard(total),

                const SizedBox(height: 12),

                // ==================================================
                // SEASON STATISTICS
                // ==================================================
                Row(
                  children: [
                    Expanded(
                      child: _buildSeasonCard(
                        title: 'Spring',
                        count: spring,
                        icon: Icons.local_florist_outlined,
                      ),
                    ),

                    const SizedBox(width: 10),

                    Expanded(
                      child: _buildSeasonCard(
                        title: 'Summer',
                        count: summer,
                        icon: Icons.wb_sunny_outlined,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                Row(
                  children: [
                    Expanded(
                      child: _buildSeasonCard(
                        title: 'Autumn',
                        count: autumn,
                        icon: Icons.eco_outlined,
                      ),
                    ),

                    const SizedBox(width: 10),

                    Expanded(
                      child: _buildSeasonCard(
                        title: 'Winter',
                        count: winter,
                        icon: Icons.ac_unit_outlined,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // ==================================================
                // SEARCH
                // ==================================================
                const Text(
                  'Search & Filter',

                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 10),

                TextField(
                  controller: _searchController,

                  decoration: InputDecoration(
                    hintText: 'Search analysis results',

                    prefixIcon: const Icon(Icons.search),

                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            onPressed: () {
                              _searchController.clear();
                            },
                            icon: const Icon(Icons.clear),
                          )
                        : null,

                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                // ==================================================
                // SEASON FILTER
                // ==================================================
                _buildSeasonFilter(),

                const SizedBox(height: 24),

                // ==================================================
                // RECORD TITLE
                // ==================================================
                Row(
                  children: [
                    const Text(
                      'Analysis Records',

                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const Spacer(),

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
                        '${filtered.length}',

                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFC58F73),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // ==================================================
                // RECORDS
                // ==================================================
                if (filtered.isEmpty)
                  _buildEmptyState()
                else
                  ...filtered.map((document) {
                    return _buildAnalysisCard(context, document);
                  }),
              ],
            ),
          );
        },
      ),
    );
  }

  // ============================================================
  // TOTAL CARD
  // ============================================================

  Widget _buildTotalCard(int total) {
    return Container(
      padding: const EdgeInsets.all(20),

      decoration: BoxDecoration(
        color: Colors.white,

        borderRadius: BorderRadius.circular(20),

        border: Border.all(color: const Color(0xFFF0DDD2)),
      ),

      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,

            decoration: BoxDecoration(
              color: const Color(0xFFF5D8C7),

              borderRadius: BorderRadius.circular(17),
            ),

            child: const Icon(
              Icons.analytics_outlined,
              color: Color(0xFFC58F73),
              size: 30,
            ),
          ),

          const SizedBox(width: 16),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                Text(
                  'Total Analysis Records',

                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),

                const SizedBox(height: 4),

                Text(
                  '$total',

                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          const Icon(Icons.trending_up, color: Color(0xFFC58F73)),
        ],
      ),
    );
  }

  // ============================================================
  // SEASON CARD
  // ============================================================

  Widget _buildSeasonCard({
    required String title,
    required int count,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),

      decoration: BoxDecoration(
        color: Colors.white,

        borderRadius: BorderRadius.circular(18),

        border: Border.all(color: const Color(0xFFF0DDD2)),
      ),

      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,

            decoration: BoxDecoration(
              color: const Color(0xFFFDF1EA),

              borderRadius: BorderRadius.circular(12),
            ),

            child: Icon(icon, color: const Color(0xFFC58F73), size: 22),
          ),

          const SizedBox(width: 10),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                Text(
                  title,

                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),

                const SizedBox(height: 3),

                Text(
                  '$count',

                  style: const TextStyle(
                    fontSize: 20,
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
  // SEASON FILTER
  // ============================================================

  Widget _buildSeasonFilter() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,

      child: Row(
        children: _seasons.map((season) {
          final selected = _selectedSeason == season;

          return Padding(
            padding: const EdgeInsets.only(right: 8),

            child: ChoiceChip(
              label: Text(season),

              selected: selected,

              onSelected: (_) {
                setState(() {
                  _selectedSeason = season;
                });
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  // ============================================================
  // ANALYSIS CARD
  // ============================================================

  Widget _buildAnalysisCard(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();

    final season = data['season'] as String? ?? 'Unknown';

    final undertone = data['undertone'] as String? ?? 'Unknown';

    final brightness = data['brightness'] as String? ?? 'Unknown';

    final contrast = data['contrast'] as String? ?? 'Unknown';

    final imageUrl = data['imageUrl'] as String? ?? '';

    final createdAt = data['createdAt'] as Timestamp?;

    return Card(
      elevation: 0,

      margin: const EdgeInsets.only(bottom: 10),

      clipBehavior: Clip.antiAlias,

      child: InkWell(
        onTap: () {
          _openResult(context, data);
        },

        child: Padding(
          padding: const EdgeInsets.all(14),

          child: Row(
            children: [
              _buildImage(imageUrl),

              const SizedBox(width: 14),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [
                    Text(
                      season,

                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 5),

                    Text(
                      '$undertone • '
                      '$brightness • '
                      '$contrast',

                      maxLines: 2,

                      overflow: TextOverflow.ellipsis,

                      style: TextStyle(color: Colors.grey.shade700),
                    ),

                    const SizedBox(height: 6),

                    Text(
                      createdAt == null
                          ? 'Date unavailable'
                          : _formatDate(createdAt.toDate()),

                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),

              const Icon(Icons.arrow_forward_ios, size: 16),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // IMAGE
  // ============================================================

  Widget _buildImage(String imageUrl) {
    if (imageUrl.isEmpty) {
      return Container(
        width: 70,
        height: 70,

        decoration: BoxDecoration(
          color: const Color(0xFFF5D8C7),

          borderRadius: BorderRadius.circular(14),
        ),

        child: const Icon(Icons.auto_awesome, color: Color(0xFFC58F73)),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),

      child: Image.network(
        imageUrl,

        width: 70,
        height: 70,

        fit: BoxFit.cover,

        errorBuilder: (context, error, stackTrace) {
          return Container(
            width: 70,
            height: 70,

            color: const Color(0xFFF5D8C7),

            child: const Icon(
              Icons.image_not_supported_outlined,
              color: Color(0xFFC58F73),
            ),
          );
        },
      ),
    );
  }

  // ============================================================
  // EMPTY
  // ============================================================

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(30),

      decoration: BoxDecoration(
        color: Colors.grey.shade100,

        borderRadius: BorderRadius.circular(18),
      ),

      child: Column(
        children: [
          Icon(Icons.analytics_outlined, size: 60, color: Colors.grey.shade500),

          const SizedBox(height: 12),

          const Text(
            'No analysis records found.',

            style: TextStyle(fontWeight: FontWeight.w600),
          ),

          const SizedBox(height: 5),

          Text(
            'Try changing your search or filter.',

            style: TextStyle(color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ERROR
  // ============================================================

  Widget _buildError(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),

        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,

          children: [
            const Icon(Icons.error_outline, size: 60),

            const SizedBox(height: 15),

            const Text('Unable to load analysis records.'),

            const SizedBox(height: 8),

            Text(
              error,

              textAlign: TextAlign.center,

              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
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
