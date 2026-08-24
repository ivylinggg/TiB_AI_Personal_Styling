import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_gradients.dart';
import 'virtual_try_on_screen.dart';

class AIVirtualStylingStudioScreen extends StatelessWidget {
  const AIVirtualStylingStudioScreen({super.key});

  void _openTryOn(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const VirtualTryOnScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 34),
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
                const Expanded(
                  child: Text(
                    'AI Styling Studio',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(width: 48),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
              decoration: BoxDecoration(
                gradient: AppGradients.premium,
                borderRadius: BorderRadius.circular(32),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: .72),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'TIB PREMIUM',
                          style: TextStyle(
                            color: AppColors.primaryDark,
                            fontSize: 8,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                      const Spacer(),
                      const Icon(Icons.auto_awesome_rounded, size: 23, color: AppColors.primaryDark),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'See yourself\nin the look.',
                    style: TextStyle(
                      fontSize: 31,
                      height: 1.0,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1.1,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Build outfits from your own wardrobe, then preview them on your TiB Model.',
                    style: TextStyle(color: AppColors.textSecondary, height: 1.45, fontSize: 12),
                  ),
                  const SizedBox(height: 20),
                  GestureDetector(
                    onTap: () => _openTryOn(context),
                    child: Container(
                      height: 190,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .52),
                        borderRadius: BorderRadius.circular(26),
                        border: Border.all(color: Colors.white.withValues(alpha: .65)),
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Positioned(
                            top: 18,
                            child: Container(
                              width: 72,
                              height: 72,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.primarySoft,
                              ),
                              child: const Icon(Icons.person_rounded, size: 39, color: AppColors.primary),
                            ),
                          ),
                          Positioned(
                            bottom: 19,
                            child: Container(
                              width: 145,
                              height: 82,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: .76),
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(65),
                                  bottom: Radius.circular(22),
                                ),
                              ),
                              child: const Icon(Icons.checkroom_rounded, size: 38, color: AppColors.primary),
                            ),
                          ),
                          Positioned(
                            right: 14,
                            bottom: 14,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.auto_awesome_rounded, size: 13, color: AppColors.primary),
                                  SizedBox(width: 5),
                                  Text('AI READY', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'CHOOSE YOUR EXPERIENCE',
              style: TextStyle(fontSize: 9, letterSpacing: 1.3, fontWeight: FontWeight.w900, color: AppColors.textMuted),
            ),
            const SizedBox(height: 10),
            _actionCard(
              context,
              icon: Icons.face_retouching_natural_rounded,
              title: 'Create My TiB Model',
              subtitle: 'Scan your face or upload a clear photo.',
              onTap: () => _openTryOn(context),
            ),
            const SizedBox(height: 10),
            _actionCard(
              context,
              icon: Icons.checkroom_rounded,
              title: 'Build My Look',
              subtitle: 'Pick pieces from your own wardrobe.',
              onTap: () => _openTryOn(context),
            ),
            const SizedBox(height: 10),
            _actionCard(
              context,
              icon: Icons.auto_awesome_rounded,
              title: 'Let TiB Style Me',
              subtitle: 'AI chooses a complete look for your occasion.',
              onTap: () => _openTryOn(context),
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: AppColors.border),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.lock_outline_rounded, size: 18, color: AppColors.primary),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Your model photo stays on your device until you choose a future AI try-on provider. TiB only uses your wardrobe data to build styling recommendations.',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 10.5, height: 1.45),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: const BoxDecoration(
                  color: AppColors.primarySoft,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: AppColors.primaryDark, size: 21),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 3),
                    Text(subtitle, style: const TextStyle(color: AppColors.textSecondary, fontSize: 10.5, height: 1.35)),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded, size: 15, color: AppColors.primary),
            ],
          ),
        ),
      ),
    );
  }
}
