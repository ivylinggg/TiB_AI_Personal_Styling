import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';

/// Subtle VYEA premium marker. Presentation-only; entitlement logic remains
/// with the calling feature.
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
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 7 : 9,
        vertical: compact ? 4 : 5,
      ),
      decoration: BoxDecoration(
        color: AppColors.premiumAccentLight,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: AppColors.premiumAccent.withValues(alpha: .28),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.auto_awesome_rounded,
            size: compact ? 10 : 11,
            color: AppColors.premiumAccentDark,
          ),
          const SizedBox(width: 4),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: AppColors.premiumAccentDark,
              fontSize: compact ? 8 : 9,
              fontWeight: FontWeight.w800,
              letterSpacing: .65,
            ),
          ),
        ],
      ),
    );
  }
}
