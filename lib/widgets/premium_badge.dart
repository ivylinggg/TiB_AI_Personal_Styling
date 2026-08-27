import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_radius.dart';

/// Premium visual identity used when Premium is actually enabled.
///
/// During the current pre-launch/testing period, the app does not present
/// Premium as an access requirement. The badge is therefore intentionally
/// hidden so Free users are not told that a feature is locked.
class PremiumBadge extends StatelessWidget {
  final String label;
  final bool compact;

  const PremiumBadge({
    super.key,
    this.label = 'PREMIUM',
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    // Pre-launch: Premium is not an access gate.
    return const SizedBox.shrink();
  }
}
