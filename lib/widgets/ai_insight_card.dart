import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_gradients.dart';
import '../core/constants/app_radius.dart';

/// A reusable visual container that marks content as a genuine, real
/// Claude AI-generated styling insight -- never a decorative wrapper for
/// heuristic/local content. This is a presentation component only: it
/// does not call the AI itself and does not fabricate output. Pass real
/// AI-produced content as [child], or set [loading] true while a real
/// request is in flight (mirrors ai_stylist_screen.dart's existing
/// "Asking your AI stylist..." state).
class AIInsightCard extends StatelessWidget {
  final Widget child;
  final bool loading;
  final String loadingLabel;

  const AIInsightCard({
    super.key,
    required this.child,
    this.loading = false,
    this.loadingLabel = 'Your AI stylist is thinking...',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.aiAccentLight,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.aiAccent.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: const BoxDecoration(
                  gradient: AppGradients.ai,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: AppColors.background,
                  size: 16,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'AI Stylist',
                style: TextStyle(
                  color: AppColors.aiAccentDark,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (loading)
            Row(
              children: [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.aiAccent,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    loadingLabel,
                    style: TextStyle(
                      color: AppColors.aiAccentDark,
                      fontStyle: FontStyle.italic,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            )
          else
            child,
        ],
      ),
    );
  }
}
