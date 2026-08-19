import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';

class CustomerDetailScreen extends StatelessWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> userDocument;

  const CustomerDetailScreen({super.key, required this.userDocument});

  Map<String, dynamic> get userData {
    return userDocument.data();
  }

  String get userId {
    return userDocument.id;
  }

  String _stringValue(String key, String fallback) {
    final value = userData[key];

    if (value is String && value.trim().isNotEmpty) {
      return value;
    }

    return fallback;
  }

  bool _boolValue(String key, bool fallback) {
    final value = userData[key];

    if (value is bool) {
      return value;
    }

    return fallback;
  }

  @override
  Widget build(BuildContext context) {
    final name = _stringValue('name', 'Unknown User');

    final email = _stringValue('email', 'No email');

    final role = _stringValue('role', 'customer');

    final colourSeason = _stringValue('colourSeason', 'Not analysed');

    final skinTone = _stringValue('skinTone', 'Not analysed');

    final isActive = _boolValue('isActive', true);
    final isPremium = _boolValue('isPremium', false);

    return Scaffold(
      backgroundColor: AppColors.background,

      appBar: AppBar(
        title: const Text('Customer Detail'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () => (context as Element).markNeedsBuild(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),

      body: RefreshIndicator(
        onRefresh: () async {
          await Future<void>.delayed(const Duration(milliseconds: 300));
        },

        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),

          children: [
            // ======================================================
            // PROFILE HEADER
            // ======================================================
            _buildProfileHeader(
              context,
              name: name,
              email: email,
              role: role,
              isActive: isActive,
              isPremium: isPremium,
            ),

            const SizedBox(height: 24),

            // ======================================================
            // ACCOUNT INFORMATION
            // ======================================================
            _sectionTitle('Account Information'),

            const SizedBox(height: 10),

            _detailCard(
              icon: Icons.person_outline,
              title: 'Full Name',
              value: name,
            ),

            _detailCard(
              icon: Icons.email_outlined,
              title: 'Email',
              value: email,
            ),

            _detailCard(
              icon: Icons.admin_panel_settings_outlined,
              title: 'Role',
              value: role.toUpperCase(),
            ),

            _detailCard(
              icon: Icons.verified_user_outlined,
              title: 'Account Status',
              value: isActive ? 'Active' : 'Inactive',
            ),

            _detailCard(
              icon: Icons.workspace_premium_outlined,
              title: 'Membership',
              value: isPremium ? 'Premium' : 'Free',
            ),

            const SizedBox(height: 20),

            // ======================================================
            // COLOUR PROFILE
            // ======================================================
            _sectionTitle('Colour Profile'),

            const SizedBox(height: 10),

            Row(
              children: [
                Expanded(
                  child: _colourInfoCard(
                    icon: Icons.palette_outlined,
                    title: 'Colour Season',
                    value: colourSeason,
                  ),
                ),

                const SizedBox(width: 12),

                Expanded(
                  child: _colourInfoCard(
                    icon: Icons.face_outlined,
                    title: 'Skin Tone',
                    value: skinTone,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // ======================================================
            // ANALYSIS OVERVIEW
            // ======================================================
            _sectionTitle('Analysis Overview'),

            const SizedBox(height: 10),

            _buildAnalysisOverview(),

            const SizedBox(height: 24),

            // ======================================================
            // ANALYSIS HISTORY
            // ======================================================
            _sectionTitle('Analysis History'),

            const SizedBox(height: 10),

            _buildAnalysisHistory(context),

            const SizedBox(height: 24),

            // ======================================================
            // ACCOUNT ACTION
            // ======================================================
            _sectionTitle('Account Actions'),

            const SizedBox(height: 10),

            SizedBox(
              width: double.infinity,

              child: OutlinedButton.icon(
                onPressed: () {
                  _toggleUserStatus(context, isActive);
                },

                icon: Icon(isActive ? Icons.block : Icons.check_circle),

                label: Text(isActive ? 'Deactivate User' : 'Activate User'),

                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 52),

                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // PROFILE HEADER
  // ============================================================

  Widget _buildProfileHeader(
    BuildContext context, {
    required String name,
    required String email,
    required String role,
    required bool isActive,
    required bool isPremium,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),

      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),

      child: Row(
        children: [
          CircleAvatar(
            radius: 38,
            backgroundColor: AppColors.secondary,

            child: const Icon(Icons.person, size: 42, color: AppColors.primary),
          ),

          const SizedBox(width: 16),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,

                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 5),

                Text(
                  email,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,

                  style: TextStyle(color: AppColors.textSecondary),
                ),

                const SizedBox(height: 10),

                Wrap(
                  spacing: 8,
                  runSpacing: 6,

                  children: [
                    _statusChip(
                      role.toUpperCase(),
                      AppColors.surfaceMuted,
                      AppColors.primaryDark,
                    ),

                    _statusChip(
                      isActive ? 'ACTIVE' : 'INACTIVE',
                      isActive
                          ? AppColors.success.withValues(alpha: 0.12)
                          : AppColors.error.withValues(alpha: 0.12),
                      isActive ? AppColors.success : AppColors.error,
                    ),
                    if (isPremium)
                      _statusChip(
                        'PREMIUM',
                        AppColors.premiumAccentLight,
                        AppColors.premiumAccentDark,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ANALYSIS OVERVIEW
  // ============================================================

  Widget _buildAnalysisOverview() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('analysis')
          .orderBy('createdAt', descending: true)
          .snapshots(),

      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _errorCard(
            message: 'Unable to load the analysis overview.',
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const SizedBox(
            height: 100,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final documents = snapshot.data?.docs ?? [];

        final total = documents.length;

        String latestSeason = 'No analysis';

        String latestDate = 'No analysis';

        if (documents.isNotEmpty) {
          final latest = documents.first.data();

          latestSeason = latest['season'] as String? ?? 'Unknown';

          final timestamp = latest['createdAt'] as Timestamp?;

          if (timestamp != null) {
            latestDate = _formatDate(timestamp.toDate());
          }
        }

        return Row(
          children: [
            Expanded(
              child: _overviewCard(
                icon: Icons.analytics_outlined,
                title: 'Total Analyses',
                value: total.toString(),
              ),
            ),

            const SizedBox(width: 12),

            Expanded(
              child: _overviewCard(
                icon: Icons.auto_awesome,
                title: 'Latest Result',
                value: latestSeason,
              ),
            ),

            const SizedBox(width: 12),

            Expanded(
              child: _overviewCard(
                icon: Icons.calendar_today_outlined,
                title: 'Last Analysis',
                value: latestDate,
              ),
            ),
          ],
        );
      },
    );
  }

  // ============================================================
  // ANALYSIS HISTORY
  // ============================================================

  Widget _buildAnalysisHistory(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('analysis')
          .orderBy('createdAt', descending: true)
          .snapshots(),

      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 30),

            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return _errorCard();
        }

        final documents = snapshot.data?.docs ?? [];

        if (documents.isEmpty) {
          return _emptyHistory();
        }

        return Column(
          children: documents.map((document) {
            final data = document.data();

            return _analysisCard(context, data);
          }).toList(),
        );
      },
    );
  }

  // ============================================================
  // ANALYSIS CARD
  // ============================================================

  Widget _analysisCard(BuildContext context, Map<String, dynamic> data) {
    final season = data['season'] as String? ?? 'Unknown';

    final undertone = data['undertone'] as String? ?? 'Unknown';

    final brightness = data['brightness'] as String? ?? 'Unknown';

    final contrast = data['contrast'] as String? ?? 'Unknown';

    final imageUrl = data['imageUrl'] as String? ?? '';

    final createdAt = data['createdAt'] as Timestamp?;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(
          color: AppColors.border,
        ),
      ),
      clipBehavior: Clip.antiAlias,

      child: InkWell(
        onTap: () {
          _showAnalysisDetails(
            context,

            season: season,
            undertone: undertone,
            brightness: brightness,
            contrast: contrast,
            imageUrl: imageUrl,
            createdAt: createdAt,
          );
        },

        child: Padding(
          padding: const EdgeInsets.all(14),

          child: Row(
            children: [
              _analysisImage(imageUrl),

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

                      style: TextStyle(color: AppColors.textSecondary),
                    ),

                    const SizedBox(height: 6),

                    Text(
                      createdAt == null
                          ? 'Date unavailable'
                          : _formatDate(createdAt.toDate()),

                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
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
  // FULL ANALYSIS DETAILS
  // ============================================================

  void _showAnalysisDetails(
    BuildContext context, {
    required String season,
    required String undertone,
    required String brightness,
    required String contrast,
    required String imageUrl,
    required Timestamp? createdAt,
  }) {
    showModalBottomSheet(
      context: context,

      isScrollControlled: true,

      backgroundColor: Colors.transparent,

      builder: (sheetContext) {
        return DraggableScrollableSheet(
          initialChildSize: 0.82,
          maxChildSize: 0.95,
          minChildSize: 0.60,

          expand: false,

          builder: (context, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: AppColors.surface,

                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),

              child: ListView(
                controller: scrollController,

                padding: const EdgeInsets.all(24),

                children: [
                  Center(
                    child: Container(
                      width: 45,
                      height: 5,

                      decoration: BoxDecoration(
                        color: AppColors.border,

                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),

                  const SizedBox(height: 22),

                  const Text(
                    'Analysis Result',

                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),

                  const SizedBox(height: 6),

                  if (createdAt != null)
                    Text(
                      _formatDate(createdAt.toDate()),

                      style: TextStyle(color: AppColors.textSecondary),
                    ),

                  const SizedBox(height: 20),

                  if (imageUrl.isNotEmpty)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),

                      child: Image.network(
                        imageUrl,

                        height: 240,

                        width: double.infinity,

                        fit: BoxFit.cover,

                        errorBuilder: (context, error, stackTrace) {
                          return _imageErrorBox();
                        },
                      ),
                    ),

                  const SizedBox(height: 20),

                  _resultDetail('Colour Season', season),

                  _resultDetail('Undertone', undertone),

                  _resultDetail('Brightness', brightness),

                  _resultDetail('Contrast', contrast),

                  const SizedBox(height: 20),

                  SizedBox(
                    width: double.infinity,

                    child: FilledButton(
                      onPressed: () {
                        Navigator.pop(sheetContext);
                      },

                      child: const Text('Close'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ============================================================
  // ACCOUNT STATUS
  // ============================================================

  Future<void> _toggleUserStatus(
    BuildContext context,
    bool currentStatus,
  ) async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;

    if (currentUserId == userId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'You cannot deactivate the account you are currently using.',
          ),
        ),
      );
      return;
    }

    final action = currentStatus ? 'deactivate' : 'activate';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            currentStatus ? 'Deactivate User?' : 'Activate User?',
          ),
          content: Text(
            currentStatus
                ? 'This user will no longer be able to use the app until the account is activated again.'
                : 'This user will be able to use the app again after activation.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(
                action[0].toUpperCase() + action.substring(1),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    try {
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'isActive': !currentStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            currentStatus
                ? 'User account deactivated.'
                : 'User account activated.',
          ),
        ),
      );

      Navigator.pop(context);
    } catch (_) {
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not update this account. Please try again.',
          ),
        ),
      );
    }
  }

  // ============================================================
  // EMPTY HISTORY
  // ============================================================

  Widget _emptyHistory() {
    return Container(
      width: double.infinity,

      padding: const EdgeInsets.all(24),

      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,

        borderRadius: BorderRadius.circular(18),
      ),

      child: Column(
        children: [
          Icon(Icons.history_outlined, size: 50, color: AppColors.textMuted),

          const SizedBox(height: 10),

          const Text(
            'No analysis records yet',
            

            style: TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ERROR CARD
  // ============================================================

  Widget _errorCard({
    String message = 'Unable to load analysis history.',
  }) {
    return Container(
      width: double.infinity,

      padding: const EdgeInsets.all(18),

      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.12),

        borderRadius: BorderRadius.circular(16),
      ),

      child: Text(
        message,

        style: TextStyle(
          color: AppColors.error,

          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  // ============================================================
  // IMAGE
  // ============================================================

  Widget _analysisImage(String imageUrl) {
    if (imageUrl.isEmpty) {
      return Container(
        width: 70,
        height: 70,

        decoration: BoxDecoration(
          color: AppColors.secondary,

          borderRadius: BorderRadius.circular(14),
        ),

        child: const Icon(
          Icons.auto_awesome,
          color: AppColors.primary,
          size: 30,
        ),
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
          return _imageErrorBox(size: 70);
        },
      ),
    );
  }

  Widget _imageErrorBox({double size = 240}) {
    return Container(
      width: double.infinity,
      height: size,

      color: AppColors.secondary,

      child: const Icon(
        Icons.image_not_supported_outlined,
        color: AppColors.primary,
        size: 40,
      ),
    );
  }

  // ============================================================
  // RESULT DETAIL
  // ============================================================

  Widget _resultDetail(String title, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),

      padding: const EdgeInsets.all(16),

      decoration: BoxDecoration(
        color: AppColors.background,

        borderRadius: BorderRadius.circular(14),
      ),

      child: Row(
        children: [
          Expanded(
            child: Text(title, style: TextStyle(color: AppColors.textSecondary)),
          ),

          const SizedBox(width: 15),

          Flexible(
            child: Text(
              value,

              textAlign: TextAlign.end,

              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SECTION TITLE
  // ============================================================

  Widget _sectionTitle(String title) {
    return Text(
      title,

      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
    );
  }

  // ============================================================
  // DETAIL CARD
  // ============================================================

  Widget _detailCard({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Card(
      elevation: 0,

      margin: const EdgeInsets.only(bottom: 8),

      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),

        leading: CircleAvatar(
          backgroundColor: AppColors.secondary,

          child: Icon(icon, color: AppColors.primary, size: 20),
        ),

        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),

        trailing: SizedBox(
          width: 135,

          child: Text(
            value,

            textAlign: TextAlign.end,

            maxLines: 2,

            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }

  // ============================================================
  // COLOUR INFO CARD
  // ============================================================

  Widget _colourInfoCard({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),

      decoration: BoxDecoration(
        color: AppColors.background,

        borderRadius: BorderRadius.circular(16),

        border: Border.all(color: AppColors.border),
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          Icon(icon, color: AppColors.primary),

          const SizedBox(height: 10),

          Text(
            title,

            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),

          const SizedBox(height: 5),

          Text(
            value,

            maxLines: 2,

            overflow: TextOverflow.ellipsis,

            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // OVERVIEW CARD
  // ============================================================

  Widget _overviewCard({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Container(
      constraints: const BoxConstraints(minHeight: 120),

      padding: const EdgeInsets.all(14),

      decoration: BoxDecoration(
        color: AppColors.surface,

        borderRadius: BorderRadius.circular(16),

        border: Border.all(color: AppColors.border),
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          Icon(icon, color: AppColors.primary, size: 22),

          const Spacer(),

          Text(
            title,

            maxLines: 2,

            overflow: TextOverflow.ellipsis,

            style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),

          const SizedBox(height: 5),

          Text(
            value,

            maxLines: 2,

            overflow: TextOverflow.ellipsis,

            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // STATUS CHIP
  // ============================================================

  Widget _statusChip(String text, Color background, Color foreground) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),

      decoration: BoxDecoration(
        color: background,

        borderRadius: BorderRadius.circular(20),
      ),

      child: Text(
        text,

        style: TextStyle(
          color: foreground,

          fontSize: 10,

          fontWeight: FontWeight.bold,
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
