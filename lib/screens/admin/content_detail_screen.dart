import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ContentDetailScreen extends StatelessWidget {
  final String title;
  final String description;
  final String body;
  final String type;
  final bool isPublished;
  final bool isFeatured;
  final bool isPremium;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const ContentDetailScreen({
    super.key,
    required this.title,
    required this.description,
    required this.body,
    required this.type,
    required this.isPublished,
    required this.isFeatured,
    required this.isPremium,
    required this.createdAt,
    required this.updatedAt,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDF9F6),

      appBar: AppBar(
        title: const Text('Content Preview'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Copy content',
            onPressed: () async {
              final textToCopy = [
                title,
                description,
                body,
              ].where((value) => value.trim().isNotEmpty).join('\n\n');

              await Clipboard.setData(ClipboardData(text: textToCopy));

              if (!context.mounted) {
                return;
              }

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Content copied to clipboard.')),
              );
            },
            icon: const Icon(Icons.copy_outlined),
          ),
        ],
      ),

      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
        children: [
          _buildHeader(),

          const SizedBox(height: 20),

          _buildStatusSection(),

          const SizedBox(height: 24),

          _buildSection(
            title: 'Description',
            child: description.isEmpty
                ? _emptyContentMessage('No description available.')
                : Text(
                    description,
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.6,
                      color: Colors.grey.shade700,
                    ),
                  ),
          ),

          const SizedBox(height: 20),

          _buildSection(
            title: 'Content',
            child: body.isEmpty
                ? _emptyContentMessage('No content available.')
                : Text(body, style: const TextStyle(fontSize: 15, height: 1.7)),
          ),

          const SizedBox(height: 24),

          _buildInformation(),

          const SizedBox(height: 24),

          SizedBox(
            height: 50,
            child: FilledButton.icon(
              onPressed: () {
                Navigator.pop(context);
              },
              icon: const Icon(Icons.arrow_back),
              label: const Text('Back to Content Management'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),

      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF0DDD2)),
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5D8C7),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  type,
                  style: const TextStyle(
                    color: Color(0xFFC58F73),
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              if (isFeatured) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3D6),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.star, size: 14, color: Color(0xFFC58F73)),
                      SizedBox(width: 4),
                      Text(
                        'FEATURED',
                        style: TextStyle(
                          color: Color(0xFFC58F73),
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (isPremium) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5D8C7),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.workspace_premium,
                        size: 14,
                        color: Color(0xFFC58F73),
                      ),
                      SizedBox(width: 4),
                      Text(
                        'PREMIUM',
                        style: TextStyle(
                          color: Color(0xFFC58F73),
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),

          const SizedBox(height: 14),

          Text(
            title,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusSection() {
    return Row(
      children: [
        Expanded(
          child: _statusCard(
            icon: isPublished ? Icons.public : Icons.visibility_off_outlined,
            title: 'Status',
            value: isPublished ? 'Published' : 'Draft',
            active: isPublished,
          ),
        ),

        const SizedBox(width: 10),

        Expanded(
          child: _statusCard(
            icon: isFeatured ? Icons.star : Icons.star_border,
            title: 'Featured',
            value: isFeatured ? 'Yes' : 'No',
            active: isFeatured,
          ),
        ),

        const SizedBox(width: 10),

        Expanded(
          child: _statusCard(
            icon: isPremium
                ? Icons.workspace_premium
                : Icons.workspace_premium_outlined,
            title: 'Premium',
            value: isPremium ? 'Yes' : 'No',
            active: isPremium,
          ),
        ),
      ],
    );
  }

  Widget _statusCard({
    required IconData icon,
    required String title,
    required String value,
    required bool active,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),

      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFF0DDD2)),
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          Icon(icon, color: active ? const Color(0xFFC58F73) : Colors.grey),

          const SizedBox(height: 10),

          Text(
            title,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),

          const SizedBox(height: 4),

          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildSection({required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(20),

      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF0DDD2)),
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 12),

          child,
        ],
      ),
    );
  }

  Widget _emptyContentMessage(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFDF9F6),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, size: 20, color: Color(0xFFC58F73)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: Colors.grey.shade700, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInformation() {
    return Container(
      padding: const EdgeInsets.all(20),

      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF0DDD2)),
      ),

      child: Column(
        children: [
          _informationRow('Content Type', type),

          const Divider(height: 24),

          _informationRow(
            'Created',
            createdAt == null ? 'Unavailable' : _formatDate(createdAt!),
          ),

          const Divider(height: 24),

          _informationRow(
            'Last Updated',
            updatedAt == null ? 'Unavailable' : _formatDate(updatedAt!),
          ),
        ],
      ),
    );
  }

  Widget _informationRow(String label, String value) {
    return Row(
      children: [
        Expanded(
          child: Text(label, style: TextStyle(color: Colors.grey.shade600)),
        ),

        const SizedBox(width: 16),

        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');

    final month = date.month.toString().padLeft(2, '0');

    return '$day/$month/${date.year}';
  }
}
