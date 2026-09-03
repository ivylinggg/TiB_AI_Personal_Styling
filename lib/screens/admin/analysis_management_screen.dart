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
  bool _loading = true;
  String? _errorMessage;
  List<_AnalysisRecord> _records = [];

  static const _seasons = ['All', 'Spring', 'Summer', 'Autumn', 'Winter'];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onChanged);
    _loadAnalysis();
  }

  @override
  void dispose() {
    _searchController.removeListener(_onChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadAnalysis() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _errorMessage = null;
      });
    }

    try {
      final users = await FirebaseFirestore.instance.collection('users').get();
      final records = <_AnalysisRecord>[];

      for (final userDoc in users.docs) {
        final role = (userDoc.data()['role'] as String? ?? 'customer').toLowerCase();
        if (role != 'customer') continue;

        final analysis = await userDoc.reference
            .collection('analysis')
            .orderBy('createdAt', descending: true)
            .get();

        final userData = userDoc.data();
        for (final analysisDoc in analysis.docs) {
          final data = analysisDoc.data();
          records.add(_AnalysisRecord.fromData(
            userId: userDoc.id,
            userName: (userData['name'] as String? ?? '').trim(),
            userEmail: (userData['email'] as String? ?? '').trim(),
            data: data,
          ));
        }
      }

      records.sort((a, b) {
        final left = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final right = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return right.compareTo(left);
      });

      if (!mounted) return;
      setState(() {
        _records = records;
        _loading = false;
      });
    } on FirebaseException catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMessage = error.message ?? 'Unable to load analysis records.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMessage = 'Unable to load analysis records: $error';
      });
    }
  }

  List<_AnalysisRecord> get _filteredRecords {
    final query = _searchController.text.trim().toLowerCase();
    return _records.where((record) {
      final matchesSeason = _selectedSeason == 'All' ||
          record.season.toLowerCase().contains(_selectedSeason.toLowerCase());
      final searchable = [
        record.season,
        record.undertone,
        record.brightness,
        record.contrast,
        record.userId,
        record.userName,
        record.userEmail,
      ].join(' ').toLowerCase();
      return matchesSeason && (query.isEmpty || searchable.contains(query));
    }).toList();
  }

  int _seasonCount(String season) {
    return _records.where((record) =>
        record.season.toLowerCase().contains(season.toLowerCase())).length;
  }

  void _openRecord(_AnalysisRecord record) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AnalysisResultDetailScreen(
          season: record.season,
          undertone: record.undertone,
          brightness: record.brightness,
          contrast: record.contrast,
          imageUrl: record.imageUrl,
          createdAt: record.createdAt,
          userId: record.userId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredRecords;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Analysis Management'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading ? null : _loadAnalysis,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? _buildError()
              : RefreshIndicator(
                  onRefresh: _loadAnalysis,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
                    children: [
                      const Text(
                        'Analysis Overview',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'Monitor customer colour analysis activity.',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 18),
                      _buildTotalCard(_records.length),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(child: _buildSeasonCard('Spring', _seasonCount('Spring'), Icons.local_florist_outlined)),
                          const SizedBox(width: 10),
                          Expanded(child: _buildSeasonCard('Summer', _seasonCount('Summer'), Icons.wb_sunny_outlined)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(child: _buildSeasonCard('Autumn', _seasonCount('Autumn'), Icons.eco_outlined)),
                          const SizedBox(width: 10),
                          Expanded(child: _buildSeasonCard('Winter', _seasonCount('Winter'), Icons.ac_unit_outlined)),
                        ],
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Search & Filter',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Search customer, email, UID or colour profile',
                          prefixIcon: const Icon(Icons.search_rounded),
                          suffixIcon: _searchController.text.isEmpty
                              ? null
                              : IconButton(
                                  onPressed: _searchController.clear,
                                  icon: const Icon(Icons.clear_rounded),
                                ),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SingleChildScrollView(
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
                      ),
                      const SizedBox(height: 22),
                      Row(
                        children: [
                          const Text(
                            'Analysis Records',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
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
                              style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.primary),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      if (filtered.isEmpty)
                        _buildEmptyState()
                      else
                        ...filtered.map(_buildAnalysisCard),
                    ],
                  ),
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
                Text('$total', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
          const Icon(Icons.trending_up_rounded, color: AppColors.primary),
        ],
      ),
    );
  }

  Widget _buildSeasonCard(String title, int count, IconData icon) {
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
                Text('$count', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalysisCard(_AnalysisRecord record) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: AppColors.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _openRecord(record),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              _buildImage(record.imageUrl),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            record.season,
                            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                          ),
                        ),
                        if (record.userName.isNotEmpty)
                          Container(
                            constraints: const BoxConstraints(maxWidth: 130),
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.secondary,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              record.userName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: AppColors.primary),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${record.undertone} • ${record.brightness} • ${record.contrast}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                    if (record.userEmail.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text(
                        record.userEmail,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 10.5, color: AppColors.textSecondary),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      'Customer ID: ${record.userId}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 10.5, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      record.createdAt == null ? 'Date unavailable' : _formatDate(record.createdAt!),
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.arrow_forward_ios_rounded, size: 16),
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
        decoration: BoxDecoration(color: AppColors.secondary, borderRadius: BorderRadius.circular(14)),
        child: const Icon(Icons.auto_awesome_rounded, color: AppColors.primary, size: 30),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Image.network(
        imageUrl,
        width: 70,
        height: 70,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
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
      decoration: BoxDecoration(color: AppColors.surfaceMuted, borderRadius: BorderRadius.circular(18)),
      child: Column(
        children: [
          const Icon(Icons.analytics_outlined, size: 42, color: AppColors.primary),
          const SizedBox(height: 10),
          const Text('No matching analysis records', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 5),
          Text(
            _records.isEmpty
                ? 'Customer analysis results will appear here once a customer completes a colour analysis.'
                : 'Try another customer, email, UID or season filter.',
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
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            const SizedBox(height: 6),
            Text(
              _errorMessage ?? 'Please check your connection and try again.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _loadAnalysis,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$day/$month/${date.year} • $hour:$minute';
  }
}

class _AnalysisRecord {
  final String userId;
  final String userName;
  final String userEmail;
  final String season;
  final String undertone;
  final String brightness;
  final String contrast;
  final String imageUrl;
  final DateTime? createdAt;

  const _AnalysisRecord({
    required this.userId,
    required this.userName,
    required this.userEmail,
    required this.season,
    required this.undertone,
    required this.brightness,
    required this.contrast,
    required this.imageUrl,
    required this.createdAt,
  });

  factory _AnalysisRecord.fromData({
    required String userId,
    required String userName,
    required String userEmail,
    required Map<String, dynamic> data,
  }) {
    final timestamp = data['createdAt'];
    return _AnalysisRecord(
      userId: userId,
      userName: userName,
      userEmail: userEmail,
      season: data['season'] as String? ?? 'Unknown',
      undertone: data['undertone'] as String? ?? 'Unknown',
      brightness: data['brightness'] as String? ?? 'Unknown',
      contrast: data['contrast'] as String? ?? 'Unknown',
      imageUrl: data['imageUrl'] as String? ?? '',
      createdAt: timestamp is Timestamp ? timestamp.toDate() : null,
    );
  }
}
