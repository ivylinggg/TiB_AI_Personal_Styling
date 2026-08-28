import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';

class AdminDashboardScreen extends StatefulWidget {
  final ValueChanged<int>? onNavigate;

  const AdminDashboardScreen({super.key, this.onNavigate});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  bool isLoading = true;
  String? loadError;
  DateTime? lastLoadedAt;

  int totalUsers = 0;
  int activeUsers = 0;
  int inactiveUsers = 0;
  int premiumUsers = 0;
  int totalAnalyses = 0;
  int publishedContent = 0;
  int waitingConsultations = 0;
  int activeConsultations = 0;
  int resolvedConsultations = 0;
  int onlineConsultants = 0;

  int springAnalyses = 0;
  int summerAnalyses = 0;
  int autumnAnalyses = 0;
  int winterAnalyses = 0;

  List<QueryDocumentSnapshot<Map<String, dynamic>>> recentAnalyses = [];
  List<QueryDocumentSnapshot<Map<String, dynamic>>> recentConsultations = [];

  @override
  void initState() {
    super.initState();
    loadDashboardData();
  }

  Future<void> loadDashboardData() async {
    if (mounted) {
      setState(() {
        isLoading = true;
        loadError = null;
      });
    }

    final firestore = FirebaseFirestore.instance;
    final failedSections = <String>[];

    var userDocs = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
    var analysisDocs = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
    var contentDocs = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
    var consultationDocs = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
    var presenceDocs = <QueryDocumentSnapshot<Map<String, dynamic>>>[];

    try {
      userDocs = (await firestore.collection('users').get()).docs;
    } catch (_) {
      failedSections.add('Users');
    }

    try {
      analysisDocs = (await firestore.collectionGroup('analysis').get()).docs;
      analysisDocs.sort(_compareDocumentsByDateDescending);
    } catch (_) {
      failedSections.add('Analysis');
    }

    try {
      contentDocs = (await firestore.collection('content').get()).docs;
    } catch (_) {
      failedSections.add('Content');
    }

    try {
      consultationDocs = (await firestore.collection('consultations').get()).docs;
      consultationDocs.sort(_compareDocumentsByDateDescending);
    } catch (_) {
      failedSections.add('Consultations');
    }

    try {
      presenceDocs = (await firestore.collection('consultant_presence').get()).docs;
    } catch (_) {
      failedSections.add('Consultants');
    }

    var activeUserCount = 0;
    var inactiveUserCount = 0;
    var premiumUserCount = 0;

    for (final document in userDocs) {
      final data = document.data();
      final isActive = data['isActive'] as bool? ?? true;
      final isPremium = data['isPremium'] as bool? ?? false;

      if (isActive) {
        activeUserCount++;
      } else {
        inactiveUserCount++;
      }
      if (isPremium) {
        premiumUserCount++;
      }
    }

    var springCount = 0;
    var summerCount = 0;
    var autumnCount = 0;
    var winterCount = 0;

    for (final document in analysisDocs) {
      final season = (document.data()['season'] as String? ?? '').toLowerCase();
      if (season.contains('spring')) {
        springCount++;
      } else if (season.contains('summer')) {
        summerCount++;
      } else if (season.contains('autumn') || season.contains('fall')) {
        autumnCount++;
      } else if (season.contains('winter')) {
        winterCount++;
      }
    }

    final publishedCount = contentDocs.where((document) {
      return document.data()['isPublished'] as bool? ?? false;
    }).length;

    var waitingCount = 0;
    var activeConsultationCount = 0;
    var resolvedCount = 0;

    for (final document in consultationDocs) {
      final status = (document.data()['status'] as String? ?? 'open').toLowerCase();
      if (status == 'waiting_for_consultant' ||
          status == 'open' ||
          status == 'waiting') {
        waitingCount++;
      } else if (status == 'assigned' ||
          status == 'consultant_replied' ||
          status == 'active' ||
          status == 'in_progress') {
        activeConsultationCount++;
      } else if (status == 'resolved' || status == 'closed') {
        resolvedCount++;
      }
    }

    final onlineCount = presenceDocs.where((document) {
      return document.data()['online'] as bool? ?? false;
    }).length;

    if (!mounted) return;

    setState(() {
      totalUsers = userDocs.length;
      activeUsers = activeUserCount;
      inactiveUsers = inactiveUserCount;
      premiumUsers = premiumUserCount;
      totalAnalyses = analysisDocs.length;
      publishedContent = publishedCount;
      waitingConsultations = waitingCount;
      activeConsultations = activeConsultationCount;
      resolvedConsultations = resolvedCount;
      onlineConsultants = onlineCount;
      springAnalyses = springCount;
      summerAnalyses = summerCount;
      autumnAnalyses = autumnCount;
      winterAnalyses = winterCount;
      recentAnalyses = analysisDocs.take(5).toList();
      recentConsultations = consultationDocs.take(5).toList();
      lastLoadedAt = DateTime.now();
      isLoading = false;
      loadError = failedSections.isEmpty
          ? null
          : 'Some sections could not be loaded: ${failedSections.join(', ')}.';
    });

    if (failedSections.isNotEmpty && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Dashboard loaded with limited data: ${failedSections.join(', ')}.'),
          action: SnackBarAction(label: 'Retry', onPressed: loadDashboardData),
        ),
      );
    }
  }

  int _compareDocumentsByDateDescending(
    QueryDocumentSnapshot<Map<String, dynamic>> a,
    QueryDocumentSnapshot<Map<String, dynamic>> b,
  ) {
    final aDate = _readDate(a.data()['updatedAt'] ?? a.data()['createdAt']);
    final bDate = _readDate(b.data()['updatedAt'] ?? b.data()['createdAt']);
    if (aDate == null && bDate == null) return 0;
    if (aDate == null) return 1;
    if (bDate == null) return -1;
    return bDate.compareTo(aDate);
  }

  DateTime? _readDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    return null;
  }

  void _goTo(int index) => widget.onNavigate?.call(index);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Refresh dashboard',
            onPressed: isLoading ? null : loadDashboardData,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: loadDashboardData,
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 22),
                    if (loadError != null) ...[
                      _buildWarningBanner(),
                      const SizedBox(height: 16),
                    ],
                    _buildSectionTitle(
                      'System Overview',
                      'Key numbers across your TiB AI platform.',
                    ),
                    const SizedBox(height: 14),
                    _buildStatsGrid(),
                    const SizedBox(height: 30),
                    _buildConsultancySection(),
                    const SizedBox(height: 30),
                    _buildQuickActions(),
                    const SizedBox(height: 30),
                    _buildSectionTitle(
                      'Colour Analysis Overview',
                      'Distribution of customer colour seasons.',
                    ),
                    const SizedBox(height: 14),
                    _buildSeasonOverview(),
                    const SizedBox(height: 30),
                    _buildSectionTitle(
                      'Recent Analyses',
                      'The latest colour analysis records.',
                    ),
                    const SizedBox(height: 14),
                    _buildRecentAnalyses(),
                    const SizedBox(height: 30),
                    _buildSectionTitle(
                      'Recent Consultations',
                      'Latest live consultancy activity.',
                    ),
                    const SizedBox(height: 14),
                    _buildRecentConsultations(),
                    const SizedBox(height: 30),
                    _buildSectionTitle('Management', 'Open an administration area.'),
                    const SizedBox(height: 14),
                    _buildManagementList(),
                    const SizedBox(height: 30),
                    _buildSectionTitle('System Status', 'Current service connection status.'),
                    const SizedBox(height: 14),
                    _buildSystemStatus(),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildHeader() {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: AppColors.secondary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.admin_panel_settings_rounded),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Welcome back, Admin 👋',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 5),
                  Text('Monitor users, styling activity and live consultancy.'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWarningBanner() {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: Icon(Icons.warning_amber_rounded, color: AppColors.warning),
        title: const Text('Some dashboard data is unavailable'),
        subtitle: Text(loadError ?? 'Pull down to refresh and try again.'),
        trailing: IconButton(
          tooltip: 'Retry',
          onPressed: isLoading ? null : loadDashboardData,
          icon: const Icon(Icons.refresh_rounded),
        ),
      ),
    );
  }

  Widget _buildStatsGrid() {
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.25,
      children: [
        _buildStatCard('Total Users', totalUsers, Icons.people_outline, () => _goTo(1)),
        _buildStatCard('Active Users', activeUsers, Icons.person_outline, () => _goTo(1)),
        _buildStatCard('Premium Users', premiumUsers, Icons.workspace_premium_outlined, () => _goTo(4)),
        _buildStatCard('Total Analyses', totalAnalyses, Icons.analytics_outlined, () => _goTo(2)),
        _buildStatCard('Published Content', publishedContent, Icons.library_books_outlined, () => _goTo(3)),
        _buildStatCard('Waiting Consults', waitingConsultations, Icons.mark_chat_unread_outlined, () => _goTo(6)),
        _buildStatCard('Resolved Consults', resolvedConsultations, Icons.check_circle_outline, () => _goTo(6)),
        _buildStatCard('Online Consultants', onlineConsultants, Icons.support_agent_outlined, () => _goTo(6)),
      ],
    );
  }

  Widget _buildStatCard(String title, int value, IconData icon, VoidCallback onTap) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: AppColors.border),
      ),
      child: InkWell(
        onTap: onTap,
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
                  color: AppColors.secondary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: AppColors.primary),
              ),
              Text(
                value.toString(),
                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
              ),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios_rounded, size: 11),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConsultancySection() {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.support_agent_rounded),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Live Consultancy',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                TextButton(
                  onPressed: () => _goTo(6),
                  child: const Text('Open'),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                _buildConsultStat('Waiting', waitingConsultations),
                _buildConsultStat('Active', activeConsultations),
                _buildConsultStat('Resolved', resolvedConsultations),
                _buildConsultStat('Online', onlineConsultants),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConsultStat(String label, int value) {
    return Expanded(
      child: Column(
        children: [
          Text(value.toString(), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Quick Actions', 'Jump directly to common admin tasks.'),
        const SizedBox(height: 14),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _buildActionChip(Icons.people_outline, 'Manage Users', () => _goTo(1)),
            _buildActionChip(Icons.analytics_outlined, 'View Analysis', () => _goTo(2)),
            _buildActionChip(Icons.library_books_outlined, 'Manage Content', () => _goTo(3)),
            _buildActionChip(Icons.workspace_premium_outlined, 'Premium', () => _goTo(4)),
            _buildActionChip(Icons.support_agent_outlined, 'Consultations', () => _goTo(6)),
            _buildActionChip(Icons.admin_panel_settings_outlined, 'Admin Profile', () => _goTo(5)),
          ],
        ),
      ],
    );
  }

  Widget _buildActionChip(IconData icon, String label, VoidCallback onTap) {
    return ActionChip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
      onPressed: onTap,
    );
  }

  Widget _buildSectionTitle(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 5),
        Text(subtitle, style: TextStyle(color: AppColors.textSecondary)),
      ],
    );
  }

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
    final percentage = totalAnalyses == 0 ? 0.0 : (count / totalAnalyses).clamp(0.0, 1.0);

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
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
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(season, style: const TextStyle(fontWeight: FontWeight.w600)),
                      const Spacer(),
                      Text('$count', style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(value: percentage, minHeight: 7),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentAnalyses() {
    if (recentAnalyses.isEmpty) return _buildEmptyCard('No analysis records available.');

    return Column(
      children: recentAnalyses.map((document) {
        final data = document.data();
        final season = data['season'] as String? ?? 'Unknown';
        final undertone = data['undertone'] as String? ?? 'Unknown';
        final createdAt = _readDate(data['createdAt']);

        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppColors.border),
          ),
          child: ListTile(
            onTap: () => _goTo(2),
            leading: const CircleAvatar(
              backgroundColor: AppColors.secondary,
              child: Icon(Icons.analytics_outlined, color: AppColors.primary),
            ),
            title: Text(season, style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(undertone),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(createdAt == null ? '--' : _formatDate(createdAt), style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right, size: 18),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildRecentConsultations() {
    if (recentConsultations.isEmpty) return _buildEmptyCard('No consultation records available.');

    return Column(
      children: recentConsultations.map((document) {
        final data = document.data();
        final name = data['userName'] as String? ?? data['customerName'] as String? ?? 'TiB User';
        final status = data['status'] as String? ?? 'open';
        final lastMessage = data['lastMessage'] as String? ?? data['lastMessageText'] as String? ?? 'No message yet';
        final assigned = data['assignedConsultantName'] as String?;
        final subtitle = assigned == null || assigned.isEmpty ? lastMessage : '$lastMessage\nAssigned: $assigned';

        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppColors.border),
          ),
          child: ListTile(
            onTap: () => _goTo(6),
            leading: CircleAvatar(
              backgroundColor: AppColors.secondary,
              child: Icon(
                status == 'resolved' || status == 'closed' ? Icons.check_circle_outline : Icons.support_agent_outlined,
                color: AppColors.primary,
              ),
            ),
            title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
            isThreeLine: assigned != null && assigned.isNotEmpty,
            trailing: _buildStatusPill(status),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildStatusPill(String status) {
    final label = status.replaceAll('_', ' ');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700)),
    );
  }

  Widget _buildEmptyCard(String message) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(child: Text(message, style: TextStyle(color: AppColors.textSecondary))),
      ),
    );
  }

  Widget _buildManagementList() {
    final items = <_ManagementItem>[
      _ManagementItem(Icons.people_outline, 'User Management', 'View, search and manage registered users.', 1),
      _ManagementItem(Icons.analytics_outlined, 'Analysis Management', 'Monitor colour analysis activity and results.', 2),
      _ManagementItem(Icons.library_books_outlined, 'Content Management', 'Manage learning content and styling resources.', 3),
      _ManagementItem(Icons.workspace_premium_outlined, 'Premium Management', 'Manage premium access for customers.', 4),
      _ManagementItem(Icons.support_agent_outlined, 'Live Consultancy', 'Monitor and manage customer consultations.', 6),
      _ManagementItem(Icons.admin_panel_settings_outlined, 'Admin Profile', 'Manage the administrator account and settings.', 5),
    ];

    return Column(
      children: [
        for (final item in items) ...[
          _buildOverviewCard(item.icon, item.title, item.description, () => _goTo(item.index)),
          if (item != items.last) const SizedBox(height: 10),
        ],
      ],
    );
  }

  Widget _buildOverviewCard(IconData icon, String title, String description, VoidCallback onTap) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: AppColors.secondary,
          child: Icon(icon, color: AppColors.primary),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Padding(padding: const EdgeInsets.only(top: 4), child: Text(description)),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      ),
    );
  }

  Widget _buildSystemStatus() {
    final operational = loadError == null;
    final color = operational ? AppColors.success : AppColors.warning;
    final icon = operational ? Icons.check_circle : Icons.warning_amber_rounded;

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
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    operational ? 'System Operational' : 'Partial Data Available',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    lastLoadedAt == null
                        ? 'Firebase dashboard connection is being checked.'
                        : 'Last updated ${_formatDateTime(lastLoadedAt!)}.',
                  ),
                ],
              ),
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

  String _formatDateTime(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$day/$month/${date.year} $hour:$minute';
  }
}

class _ManagementItem {
  final IconData icon;
  final String title;
  final String description;
  final int index;

  const _ManagementItem(this.icon, this.title, this.description, this.index);
}
