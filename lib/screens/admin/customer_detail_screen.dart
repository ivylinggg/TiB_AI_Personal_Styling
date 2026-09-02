import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'admin_user_360_screen.dart';

/// Compatibility entry point used by User Management.
///
/// The admin View action continues to target CustomerDetailScreen, while
/// the actual customer inspection is now provided by the richer 360 view.
class CustomerDetailScreen extends StatelessWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> userDocument;

  const CustomerDetailScreen({
    super.key,
    required this.userDocument,
  });

  @override
  Widget build(BuildContext context) {
    return AdminUser360Screen(
      userId: userDocument.id,
      userData: userDocument.data(),
    );
  }
}
