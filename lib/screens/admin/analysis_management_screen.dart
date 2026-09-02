import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
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
    if (!mounted) return;
    setState(() {});
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _analysisStream() {
    return FirebaseFirestore.instance
        .collectionGroup('analysis')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

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
      final uid = document.reference.parent.parent?.id ?? '';

      final matchesSearch = query.isEmpty ||
          season.contains(query) ||
          undertone.contains(query) ||
          brightness.contains(query) ||
          contrast.contains(query) ||
          uid.toLowerCase().contains(query);

      final matchesSeason = _selectedSeason == 'All' ||
          season.contains(_selectedSeason.toLowerCase());

      return matchesSearch && matchesSeason;
    }).toList();
  }

  int _countSeason(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> documents,
    String season,
  ) {
    return documents.where((document) {
      final value = (document.data()['season'] as String? ?? '').toLowerCase();
      return value.contains(season.toLowerCase());
    }).length;
  }

  Future<Map<String, dynamic>?> _loadCustomer(String userId) async {
    if (userId.isEmpty) return null;
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      return snapshot.data();
    } catch (_) {
      return null;
    }
  }

  void _openResult(
    BuildContext context,
    Map<String, dynamic> data,
    String userId,
  ) {
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
          userId: userId,
        ),
      ),
    );
  }

  String _customerName(Map<String, dynamic>? data) {
    final name = data?['name'] as String?;
    return name?.trim() ?? '';
  }

  String _customerEmail(Map<String, dynamic>? data) {
    final email = data?['email'] as String?;
    return email?.trim() ?? '';
  }

  bool _matchesCustomer(
    Map<String, dynamic>? customer,
    String query,
  ) {
    if (query.isEmpty) return true;
    final name = _customerName(customer).toLowerCase();
    final email = _customerEmail(customer).toLowerCase();
    return name.contains(query) || email.contains(query);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Analysis Management'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () => setState(() {}),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _analysisStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) return _buildError();

          final documents = snapshot.data?.docs ?? [];
          final filtered = _filterResults(documents);
          final total = documents.length;
          final spring = _countSeason(documents, 'Spring');
          final summer = _countSeason(documents, 'Summer');
          final autumn = _countSeason(documents, 'Autumn');
          final winter = _countSeason(documents, 'Winter');

          return RefreshIndicator(
            onRefresh: () async => setState(() {}),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
              children: [
                const Text(
                  'Analysis Overview',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 5),
                Text(
                  'Monitor customer colour analysis activity.',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 18),
                _buildTotalCard(total),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildSeasonCard(
                        title: 'Spring', count: spring, icon: Icons.local_florist_outlined,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildSeasonCard(
                        title: 'Summer', count: summer, icon: Icons.wb_sunny_outlined,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _buildSeasonCard(
                        title: 'Autumn', count: autumn, icon: Icons.eco_outlined,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildSeasonCard(
                        title: 'Winter', count: winter, icon: Icons.ac_unit_outlined,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const Text(
                  'Search & Filter',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search customer name, email, UID or colour profile',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            onPressed: _searchController.clear,
                            icon: const Icon(Icons.clear),
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                _buildSeasonFilter(),
                const SizedBox(height: 24),
                Row(
                  children: [
                    const Text(
                      'Analysis Records',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppColors.secondary,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${filtered.length}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (filtered.isEmpty)
                  _buildEmptyState()
                else
                  ...filtered.map((document) => _buildAnalysisCard(context, document)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTotalCard(int total) {
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
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: AppColors.secondary,
              borderRadius: BorderRadius.circular(17),
            ),
            child: const Icon(Icons.analytics_outlined, color: AppColors.primary, size: 30),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Total Analysis Records', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                const SizedBox(height: 4),
                Text('$total', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const Icon(Icons.trending_up, color: AppColors.primary),
        ],
      ),
    );
  }

  Widget _buildSeasonCard({
    required String title,
    required int count,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.primary, size: 22),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                const SizedBox(height: 3),
                Text('$count', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }

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
              showCheckmark: false,
              onSelected: (_) => setState(() => _selectedSeason = season),
            ),
          );
        }).toList(),
      ),
    );
  }

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
    final userId = document.reference.parent.parent?.id ?? '';

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openResult(context, data, userId),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              _buildImage(imageUrl),
              const SizedBox(width: 14),
              Expanded(
                child: FutureBuilder<Map<String, dynamic>?>(
                  future: userId.isEmpty ? Future.value(null) : _loadCustomer(userId),
                  builder: (context, customerSnapshot) {
                    final customer = customerSnapshot.data;
                    final customerName = _customerName(customer);
                    final customerEmail = _customerEmail(customer);
                    final query = _searchController.text.trim().toLowerCase();

                    if (query.isNotEmpty && !_matchesCustomer(customer, query)) {
                      return const SizedBox.shrink();
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                season,
                                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                              ),
                            ),
                            if (customerName.isNotEmpty)
                              Container(
                                constraints: const BoxConstraints(maxWidth: 135),
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.secondary,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  customerName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        Text(
                          '$undertone • $brightness • $contrast',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                        if (customerEmail.isNotEmpty) ...[
                          const SizedBox(height: 5),
                          Text(
                            customerEmail,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 10.5, color: AppColors.textSecondary),
                          ),
                        ],
                        const SizedBox(height: 4),
                        Text(
                          userId.isEmpty ? 'Customer: unavailable' : 'Customer ID: $userId',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 10.5, color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          createdAt == null ? 'Date unavailable' : _formatDate(createdAt.toDate()),
                          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.arrow_forward_ios, size: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImage(String imageUrl) {
    if (imageUrl.isEmpty) {
      return Container(
        width: 70,
        height: 70,
        decoration: BoxDecoration(
          color: AppColors.secondary,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(Icons.auto_awesome, color: AppColors.primary, size: 30),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Image.network(
        imageUrl,
        width: 70,
        height: 70,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(
          width: 70,
          height: 70,
          color: AppColors.secondary,
          child: const Icon(Icons.image_not_supported_outlined, color: AppColors.primary),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          const Icon(Icons.analytics_outlined, size: 42, color: AppColors.primary),
          const SizedBox(height: 10),
          const Text('No matching analysis records', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 5),
          Text(
            'Try another customer name, email, UID, profile value or season filter.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 44),
            const SizedBox(height: 12),
            const Text(
              'Unable to load analysis records.',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            const SizedBox(height: 6),
            Text(
              'Please check your connection and try again.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }
}
