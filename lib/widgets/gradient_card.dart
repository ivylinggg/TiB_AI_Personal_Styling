import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_radius.dart';

/// A reusable branded gradient surface. Generalises the pattern
/// dashboard/hero_card.dart already established (gradient container,
/// white content, optional icon, optional tap) so it can be reused for
/// AI, Premium and other branded gradient moments without copy-pasting
/// the same Container/BoxDecoration block again in every screen.
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
        boxShadow: [
          BoxShadow(
            color: AppColors.textPrimary.withValues(alpha: 0.10),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(icon, color: AppColors.background, size: 32),
            const SizedBox(height: 16),
          ],
          child,
        ],
      ),
    );

    if (onTap == null) {
      return content;
    }

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
