import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_radius.dart';

/// Reusable VYEA empty/error state. The caller owns the copy and action.
class EmptyState extends StatefulWidget {
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
  State<EmptyState> createState() => _EmptyStateState();
}

class _EmptyStateState extends State<EmptyState>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<double> _scale;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _scale = Tween<double>(begin: .96, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _slide = Tween<Offset>(begin: const Offset(0, .025), end: Offset.zero).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gradient = widget.accent ??
        LinearGradient(
          colors: [
            AppColors.secondary,
            AppColors.secondary.withValues(alpha: .48),
          ],
        );

    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: ScaleTransition(
          scale: _scale,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(22, 25, 22, 21),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.xl),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    gradient: gradient,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(widget.icon, color: AppColors.background, size: 29),
                ),
                const SizedBox(height: 17),
                Text(
                  widget.title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 7),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 330),
                  child: Text(
                    widget.description,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.45),
                  ),
                ),
                if (widget.ctaLabel != null && widget.onCta != null) ...[
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: widget.onCta,
                      icon: const Icon(Icons.arrow_forward_rounded, size: 17),
                      label: Text(widget.ctaLabel!),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
