import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_radius.dart';

/// The app's single Premium visual identity: a restrained gold/champagne
/// pill, not a bright yellow badge. Replaces the badge currently
/// hand-rolled inline in ai_stylist_screen.dart and
/// content_management_screen.dart -- those screens will be switched over
/// to this when they are redesigned (out of scope for this
/// design-system-only phase).
class PremiumBadge extends StatelessWidget {
  final String label;
  final bool compact;

  const PremiumBadge({super.key, this.label = 'PREMIUM', this.compact = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 9 : 12,
        vertical: compact ? 5 : 7,
      ),
      decoration: BoxDecoration(
        color: AppColors.premiumAccentLight,
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(
          color: AppColors.premiumAccent.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.workspace_premium_rounded,
            size: compact ? 13 : 15,
            color: AppColors.premiumAccentDark,
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: AppColors.premiumAccentDark,
              fontSize: compact ? 10 : 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}
