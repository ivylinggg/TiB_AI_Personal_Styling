import 'package:flutter/material.dart';

class AIStylistScreen extends StatelessWidget {
  const AIStylistScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI Stylist')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFFF5D8C7),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.auto_awesome,
                    size: 42,
                    color: Color(0xFFC58F73),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Your AI Styling Assistant',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Get personalised styling recommendations based on your colour profile.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            Text(
              'What would you like help with?',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 16),

            _buildOption(
              context,
              icon: Icons.checkroom_outlined,
              title: 'Outfit Recommendation',
              description: 'Get outfit ideas that match your colour profile.',
            ),

            const SizedBox(height: 12),

            _buildOption(
              context,
              icon: Icons.palette_outlined,
              title: 'Colour Matching',
              description: 'Find colours that work well together.',
            ),

            const SizedBox(height: 12),

            _buildOption(
              context,
              icon: Icons.shopping_bag_outlined,
              title: 'Shopping Assistant',
              description: 'Choose clothing colours that suit your profile.',
            ),

            const SizedBox(height: 12),

            _buildOption(
              context,
              icon: Icons.event_outlined,
              title: 'Occasion Styling',
              description: 'Get styling ideas for different occasions.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOption(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Card(
      elevation: 0,
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          backgroundColor: const Color(0xFFF5D8C7),
          child: Icon(icon, color: const Color(0xFFC58F73)),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Text(description),
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$title will be connected to the AI engine.'),
            ),
          );
        },
      ),
    );
  }
}
