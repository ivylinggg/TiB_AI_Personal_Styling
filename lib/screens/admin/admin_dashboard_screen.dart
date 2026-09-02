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
  int totalStaff = 0;
  int activeStaff = 0;
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
    var staffCount = 0;
    var activeStaffCount = 0;

    for (final document in userDocs) {
      final data = document.data();
      final isActive = data['isActive'] as bool? ?? true;
      final isPremium = data['isPremium'] as bool? ?? false;
      final role = (data['role'] as String? ?? 'customer').toLowerCase();
      final isStaff = role == 'consultant' || role == 'staff';

      if (isActive) {
        activeUserCount++;
      } else {
        inactiveUserCount++;
      }
      if (isPremium) premiumUserCount++;
      if (isStaff) {
        staffCount++;
        if (isActive) activeStaffCount++;
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
      if (status == 'waiting_for_consultant' || status == 'open' || status == 'waiting') {
        waitingCount++;
      } else if (status == 'assigned' || status == 'consultant_replied' || status == 'active' || status == 'in_progress') {
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
      totalStaff = staffCount;
      activeStaff = activeStaffCount;
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
      loadError = failedSections.isEmpty ? null : 'Some sections could not be loaded: ${failedSections.join(', ')}.';
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

  String _formatShortDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
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
                    _buildSectionTitle('System Overview', 'Key numbers across your TiB AI platform.'),
                    const SizedBox(height: 14),
                    _buildStatsGrid(),
                    const SizedBox(height: 30),
                    _buildConsultancySection(),
                    const SizedBox(height: 30),
                    _buildQuickActions(),
                    const SizedBox(height: 30),
                    _buildSectionTitle('Colour Analysis Overview', 'Distribution of customer colour seasons.'),
                    const SizedBox(height: 14),
                    _buildSeasonOverview(),
                    const SizedBox(height: 30),
                    _buildSectionTitle('Recent Analyses', 'The latest colour analysis records.'),
                    const SizedBox(height: 14),
                    _buildRecentAnalyses(),
                    const SizedBox(height: 30),
                    _buildSectionTitle('Recent Consultations', 'Latest live consultancy activity.'),
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
              decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(16)),
              child: const Icon(Icons.admin_panel_settings_rounded),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Welcome back, Admin 👋', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
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
        trailing: IconButton(tooltip: 'Retry', onPressed: isLoading ? null : loadDashboardData, icon: const Icon(Icons.refresh_rounded)),
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
        _buildStatCard('Staff', totalStaff, Icons.badge_outlined, () => _goTo(7)),
        _buildStatCard('Active Staff', activeStaff, Icons.support_agent_outlined, () => _goTo(7)),
        _buildStatCard('Published Content', publishedContent, Icons.library_books_outlined, () => _goTo(3)),
        _buildStatCard('Waiting Consults', waitingConsultations, Icons.mark_chat_unread_outlined, () => _goTo(6)),
        _buildStatCard('Resolved Consults', resolvedConsultations, Icons.check_circle_outline, () => _goTo(6)),
        _buildStatCard('Online Consultants', onlineConsultants, Icons.wifi_tethering_rounded, () => _goTo(6)),
      ],
    );
  }

  Widget _buildStatCard(String title, int value, IconData icon, VoidCallback onTap) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: const BorderSide(color: AppColors.border)),
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
                decoration: BoxDecoration(color: AppColors.secondary, borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: AppColors.primary),
              ),
              Text(value.toString(), style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
              Row(
                children: [
                  Expanded(child: Text(title, style: TextStyle(fontSize: 13, color: AppColors.textSecondary))),
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: const BorderSide(color: AppColors.border)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.support_agent_rounded),
                const SizedBox(width: 10),
                const Expanded(child: Text('Live Consultancy', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
                TextButton(onPressed: () => _goTo(6), child: const Text('Open')),
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
            _buildActionChip(Icons.admin_panel_settings_outlined, 'Admin Profile', () => _goTo(5)),
            _buildActionChip(Icons.support_agent_outlined, 'Consultations', () => _goTo(6)),
            _buildActionChip(Icons.badge_outlined, 'Staff Management', () => _goTo(7)),
          ],
        ),
      ],
    );
  }

  Widget _buildActionChip(IconData icon, String label, VoidCallback onPressed) {
    return ActionChip(avatar: Icon(icon, size: 18), label: Text(label), onPressed: onPressed);
  }

  Widget _buildSeasonOverview() {
    final total = springAnalyses + summerAnalyses + autumnAnalyses + winterAnalyses;
    final items = [
      ('Spring', springAnalyses, Icons.local_florist_outlined),
      ('Summer', summerAnalyses, Icons.wb_sunny_outlined),
      ('Autumn', autumnAnalyses, Icons.eco_outlined),
      ('Winter', winterAnalyses, Icons.ac_unit_outlined),
    ];

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: const BorderSide(color: AppColors.border)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            Row(
              children: [
                const Expanded(child: Text('Season distribution', style: TextStyle(fontWeight: FontWeight.bold))),
                Text('$total analysed', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 14),
            ...items.map((item) {
              final ratio = total == 0 ? 0.0 : item.$2 / total;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Icon(item.$3, size: 18, color: AppColors.primary),
                    const SizedBox(width: 10),
                    SizedBox(width: 58, child: Text(item.$1, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700))),
                    Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(10), child: LinearProgressIndicator(value: ratio, minHeight: 9))),
                    const SizedBox(width: 10),
                    SizedBox(width: 28, child: Text('${item.$2}', textAlign: TextAlign.right, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentAnalyses() {
    if (recentAnalyses.isEmpty) return _buildEmptyCard('No analysis records yet.');
    return Column(
      children: recentAnalyses.map((document) {
        final data = document.data();
        final season = data['season'] as String? ?? 'Unknown';
        final createdAt = _readDate(data['createdAt']);
        final uid = document.reference.parent.parent?.id ?? 'Unknown user';
        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), side: const BorderSide(color: AppColors.border)),
          child: ListTile(
            leading: const CircleAvatar(child: Icon(Icons.analytics_outlined, size: 18)),
            title: Text(season, style: const TextStyle(fontWeight: FontWeight.w800)),
            subtitle: Text('Customer: ${uid.length > 16 ? '${uid.substring(0, 16)}…' : uid}'),
            trailing: Text(createdAt == null ? '—' : _formatShortDate(createdAt), style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildRecentConsultations() {
    if (recentConsultations.isEmpty) return _buildEmptyCard('No consultation records yet.');
    return Column(
      children: recentConsultations.map((document) {
        final data = document.data();
        final status = (data['status'] as String? ?? 'open').replaceAll('_', ' ');
        final userName = (data['userName'] ?? data['name'] ?? 'TiB User') as String;
        final updatedAt = _readDate(data['updatedAt'] ?? data['createdAt']);
        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), side: const BorderSide(color: AppColors.border)),
          child: ListTile(
            leading: const CircleAvatar(child: Icon(Icons.support_agent_outlined, size: 18)),
            title: Text(userName, style: const TextStyle(fontWeight: FontWeight.w800)),
            subtitle: Text(status, style: const TextStyle(fontSize: 11)),
            trailing: Text(updatedAt == null ? '—' : _formatShortDate(updatedAt), style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildManagementList() {
    final items = [
      ('Users', 'Customers, account status and profiles', Icons.people_outline, 1),
      ('Analysis', 'Colour analysis history and results', Icons.analytics_outlined, 2),
      ('Content', 'Published, draft and premium content', Icons.library_books_outlined, 3),
      ('Premium', 'Premium account access and status', Icons.workspace_premium_outlined, 4),
      ('Admin Profile', 'Administrator account information', Icons.admin_panel_settings_outlined, 5),
      ('Consultations', 'Live customer conversations', Icons.support_agent_outlined, 6),
      ('Staff', 'Staff and consultant accounts', Icons.badge_outlined, 7),
    ];
    return Column(
      children: items.map((item) {
        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), side: const BorderSide(color: AppColors.border)),
          child: ListTile(
            leading: CircleAvatar(child: Icon(item.$3, size: 18)),
            title: Text(item.$1, style: const TextStyle(fontWeight: FontWeight.w800)),
            subtitle: Text(item.$2),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => _goTo(item.$4),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSystemStatus() {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: const BorderSide(color: AppColors.border)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            _statusRow('Firebase / Firestore', loadError == null ? 'Connected' : 'Partial', loadError == null),
            const Divider(height: 22),
            _statusRow('Live consultancy', onlineConsultants > 0 ? '$onlineConsultants online' : 'No consultants online', true),
            const Divider(height: 22),
            _statusRow('Dashboard refresh', lastLoadedAt == null ? 'Not available' : _formatShortDate(lastLoadedAt!), true),
          ],
        ),
      ),
    );
  }

  Widget _statusRow(String title, String value, bool healthy) {
    return Row(
      children: [
        Icon(healthy ? Icons.check_circle_outline_rounded : Icons.warning_amber_rounded, color: healthy ? AppColors.success : AppColors.warning),
        const SizedBox(width: 10),
        Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w700))),
        Text(value, style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
      ],
    );
  }

  Widget _buildSectionTitle(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(subtitle, style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
      ],
    );
  }

  Widget _buildEmptyCard(String message) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), side: const BorderSide(color: AppColors.border)),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Center(child: Text(message, style: TextStyle(color: AppColors.textSecondary))),
      ),
    );
  }
}
