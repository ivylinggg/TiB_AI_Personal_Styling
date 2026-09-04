import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_radius.dart';

/// Presentation-only selectable style chip. Selection remains controlled by
/// the parent screen; this widget contains no business logic.
class StyleChip extends StatelessWidget {
  final String label;
  final bool selected;
  final IconData? icon;
  final VoidCallback? onTap;

  const StyleChip({
    super.key,
    required this.label,
    required this.selected,
    this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.full),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.full),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 15, color: selected ? Colors.white : AppColors.textSecondary),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.white : AppColors.textPrimary,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  fontSize: 13,
                ),
              ),
              if (selected) ...[
                const SizedBox(width: 6),
                const Icon(Icons.check_rounded, size: 14, color: Colors.white),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
