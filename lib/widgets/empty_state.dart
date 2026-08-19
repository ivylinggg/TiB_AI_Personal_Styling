import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_radius.dart';

/// A reusable, visually attractive empty state: an icon in a gradient
/// circle, a title, a description and an optional call-to-action button.
/// Every string is supplied by the caller -- this component never
/// hardcodes copy like "No Colour Analysis Yet", so each screen stays in
/// control of its own real, accurate empty-state message and never shows
/// fabricated data.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final String? ctaLabel;
  final VoidCallback? onCta;
  final Gradient? accent;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    this.ctaLabel,
    this.onCta,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final gradient = accent ??
        LinearGradient(
          colors: [
            AppColors.secondary,
            AppColors.secondary.withValues(alpha: 0.4),
          ],
        );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(gradient: gradient, shape: BoxShape.circle),
            child: Icon(icon, color: AppColors.background, size: 32),
          ),
          const SizedBox(height: 18),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            description,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          if (ctaLabel != null && onCta != null) ...[
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onCta,
                child: Text(ctaLabel!),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
