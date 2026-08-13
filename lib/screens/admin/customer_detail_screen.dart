import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

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

    return Scaffold(
      backgroundColor: const Color(0xFFFDF9F6),

      appBar: AppBar(
        title: const Text('Customer Detail'),
        backgroundColor: Colors.transparent,
        elevation: 0,
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
  }) {
    return Container(
      padding: const EdgeInsets.all(20),

      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF0DDD2)),
      ),

      child: Row(
        children: [
          CircleAvatar(
            radius: 38,
            backgroundColor: const Color(0xFFF5D8C7),

            child: const Icon(Icons.person, size: 42, color: Color(0xFFC58F73)),
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

                  style: TextStyle(color: Colors.grey.shade700),
                ),

                const SizedBox(height: 10),

                Wrap(
                  spacing: 8,
                  runSpacing: 6,

                  children: [
                    _statusChip(role.toUpperCase(), Colors.blue),

                    _statusChip(
                      isActive ? 'ACTIVE' : 'INACTIVE',
                      isActive ? Colors.green : Colors.red,
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
                color: Colors.white,

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
                        color: Colors.grey.shade300,

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

                      style: TextStyle(color: Colors.grey.shade600),
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
    } catch (e) {
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Unable to update account: $e')));
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
        color: Colors.grey.shade100,

        borderRadius: BorderRadius.circular(18),
      ),

      child: Column(
        children: [
          Icon(Icons.history_outlined, size: 50, color: Colors.grey.shade500),

          const SizedBox(height: 10),

          const Text(
            'No analysis records yet.',

            style: TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ERROR CARD
  // ============================================================

  Widget _errorCard() {
    return Container(
      width: double.infinity,

      padding: const EdgeInsets.all(18),

      decoration: BoxDecoration(
        color: Colors.red.shade50,

        borderRadius: BorderRadius.circular(16),
      ),

      child: Text(
        'Unable to load analysis history.',

        style: TextStyle(
          color: Colors.red.shade700,

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
          color: const Color(0xFFF5D8C7),

          borderRadius: BorderRadius.circular(14),
        ),

        child: const Icon(
          Icons.auto_awesome,
          color: Color(0xFFC58F73),
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

      color: const Color(0xFFF5D8C7),

      child: const Icon(
        Icons.image_not_supported_outlined,
        color: Color(0xFFC58F73),
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
        color: const Color(0xFFFDF9F6),

        borderRadius: BorderRadius.circular(14),
      ),

      child: Row(
        children: [
          Expanded(
            child: Text(title, style: TextStyle(color: Colors.grey.shade700)),
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
          backgroundColor: const Color(0xFFF5D8C7),

          child: Icon(icon, color: const Color(0xFFC58F73), size: 20),
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
        color: const Color(0xFFFDF9F6),

        borderRadius: BorderRadius.circular(16),

        border: Border.all(color: const Color(0xFFF0DDD2)),
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          Icon(icon, color: const Color(0xFFC58F73)),

          const SizedBox(height: 10),

          Text(
            title,

            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
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
        color: Colors.white,

        borderRadius: BorderRadius.circular(16),

        border: Border.all(color: const Color(0xFFF0DDD2)),
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          Icon(icon, color: const Color(0xFFC58F73), size: 22),

          const Spacer(),

          Text(
            title,

            maxLines: 2,

            overflow: TextOverflow.ellipsis,

            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
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

  Widget _statusChip(String text, MaterialColor color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),

      decoration: BoxDecoration(
        color: color.shade50,

        borderRadius: BorderRadius.circular(20),
      ),

      child: Text(
        text,

        style: TextStyle(
          color: color.shade700,

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
