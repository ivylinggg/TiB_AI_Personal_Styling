import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'admin_user_360_screen.dart';

class CustomerDetailScreen extends StatelessWidget {
  final DocumentSnapshot<Map<String, dynamic>> userDocument;

  const CustomerDetailScreen({
    super.key,
    required this.userDocument,
  });

  @override
  Widget build(BuildContext context) {
    final data = userDocument.data() ?? const <String, dynamic>{};
    final storedUid = data['uid'];
    final userId = storedUid is String && storedUid.trim().isNotEmpty
        ? storedUid.trim()
        : userDocument.id;

    return AdminUser360Screen(
      userId: userId,
      userData: data,
    );
  }
}
