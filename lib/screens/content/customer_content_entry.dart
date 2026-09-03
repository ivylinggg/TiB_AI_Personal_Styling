import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import 'customer_content_screen.dart';

class CustomerContentEntry extends StatelessWidget {
  const CustomerContentEntry({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColors.border),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: const CircleAvatar(
          backgroundColor: AppColors.secondary,
          child: Icon(Icons.menu_book_outlined, color: AppColors.primary),
        ),
        title: const Text('TiB Learning', style: TextStyle(fontWeight: FontWeight.w800)),
        subtitle: const Text('Style tips, colour guides and learning resources.'),
        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CustomerContentScreen()),
        ),
      ),
    );
  }
}
