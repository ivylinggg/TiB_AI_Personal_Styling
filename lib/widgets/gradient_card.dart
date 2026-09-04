import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_radius.dart';

/// Reusable branded surface. Existing gradient input remains supported so
/// callers do not lose behaviour; VYEA simply makes the surface quieter.
class GradientCard extends StatelessWidget {
  final Gradient gradient;
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final IconData? icon;
  final VoidCallback? onTap;

  const GradientCard({
    super.key,
    required this.gradient,
    required this.child,
    this.padding = const EdgeInsets.all(22),
    this.borderRadius = AppRadius.xl,
    this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final content = Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: AppColors.border.withValues(alpha: .75)),
        boxShadow: [
          BoxShadow(
            color: AppColors.textPrimary.withValues(alpha: .055),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.surface.withValues(alpha: .58),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppColors.primary, size: 21),
            ),
            const SizedBox(height: 14),
          ],
          child,
        ],
      ),
    );

    if (onTap == null) return content;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(borderRadius),
      child: InkWell(
        borderRadius: BorderRadius.circular(borderRadius),
        onTap: onTap,
        child: content,
      ),
    );
  }
}
