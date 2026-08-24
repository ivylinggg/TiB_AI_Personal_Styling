import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_gradients.dart';
import '../../services/tib_model_service.dart';
import 'ai_generated_try_on_screen.dart';
import 'ai_style_me_screen.dart';
import 'create_tib_model_screen.dart';
import 'outfit_builder_screen.dart';

class AIVirtualStylingStudioScreen extends StatefulWidget {
  const AIVirtualStylingStudioScreen({super.key});

  @override
  State<AIVirtualStylingStudioScreen> createState() => _AIVirtualStylingStudioScreenState();
}

class _AIVirtualStylingStudioScreenState extends State<AIVirtualStylingStudioScreen> {
  TibModelProfile? _model;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadModel();
  }

  Future<void> _loadModel() async {
    final model = await TibModelService.load();
    if (!mounted) return;
    setState(() {
      _model = model;
      _loading = false;
    });
  }

  Future<void> _openModelSetup(BuildContext context) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (context) => const CreateTibModelScreen()),
    );
    if (changed == true) await _loadModel();
  }

  void _openBuilder(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const OutfitBuilderScreen()),
    );
  }

  void _openTryOn(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AiGeneratedTryOnScreen()),
    );
  }

  void _openAiStylist(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AiStyleMeScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final model = _model;
    final ready = model?.isComplete == true;

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
            _buildModelHero(model, ready),
            const SizedBox(height: 18),
            const Text(
              'YOUR TIΒ MODEL',
              style: TextStyle(
                fontSize: 9,
                letterSpacing: 1.3,
                fontWeight: FontWeight.w900,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 9),
            _buildModelProfile(model, ready),
            const SizedBox(height: 18),
            const Text(
              'CHOOSE YOUR EXPERIENCE',
              style: TextStyle(
                fontSize: 9,
                letterSpacing: 1.3,
                fontWeight: FontWeight.w900,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 10),
            _actionCard(
              icon: Icons.face_retouching_natural_rounded,
              title: ready ? 'Edit My TiB Model' : 'Create My TiB Model',
              subtitle: ready
                  ? 'Update your face, body photo or model details.'
                  : 'Build your reusable face and body profile.',
              onTap: () => _openModelSetup(context),
              highlight: !ready,
            ),
            const SizedBox(height: 10),
            _actionCard(
              icon: Icons.checkroom_rounded,
              title: 'Build My Look',
              subtitle: 'Pick each piece from your own wardrobe.',
              onTap: () => _openBuilder(context),
              enabled: ready,
            ),
            const SizedBox(height: 10),
            _actionCard(
              icon: Icons.auto_awesome_rounded,
              title: 'Let TiB Style Me',
              subtitle: 'AI chooses a complete look for your occasion.',
              onTap: () => _openAiStylist(context),
              enabled: ready,
              highlight: true,
            ),
            const SizedBox(height: 10),
            _actionCard(
              icon: Icons.view_in_ar_rounded,
              title: 'AI Virtual Try-On',
              subtitle:
                  'Select your wardrobe and generate a try-on image with your TiB Model.',
              onTap: () => _openTryOn(context),
              enabled: ready,
              highlight: true,
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.lock_outline_rounded,
                    size: 18,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      ready
                          ? 'Your model photos stay on this device. The same TiB Model is reused across your Premium styling experiences.'
                          : 'Create your TiB Model first. Your photos stay on this device and become the foundation for your Premium styling experiences.',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 10.5,
                        height: 1.45,
                      ),
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

  Widget _buildModelHero(TibModelProfile? model, bool ready) {
    final photo = model?.faceFile;
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
      decoration: BoxDecoration(
        gradient: AppGradients.premium,
        borderRadius: BorderRadius.circular(32),
      ),
      child: Row(
        children: [
          Container(
            width: 92,
            height: 112,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .55),
              borderRadius: BorderRadius.circular(28),
            ),
            clipBehavior: Clip.antiAlias,
            child: photo != null && photo.existsSync()
                ? Image.file(photo, fit: BoxFit.cover)
                : const Icon(
                    Icons.person_rounded,
                    size: 48,
                    color: AppColors.primary,
                  ),
          ),
          const SizedBox(width: 17),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .72),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    ready ? 'MODEL READY' : 'MODEL NOT SET',
                    style: const TextStyle(
                      color: AppColors.primaryDark,
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                      letterSpacing: .9,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  ready ? 'This is your\nTiB Model.' : 'Create your\nTiB Model.',
                  style: const TextStyle(
                    fontSize: 24,
                    height: 1.0,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  ready
                      ? 'Ready to style with your own wardrobe.'
                      : 'Add your face once, then build looks around you.',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModelProfile(TibModelProfile? model, bool ready) {
    if (_loading) {
      return const SizedBox(
        height: 100,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (model == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(
                Icons.face_retouching_natural_rounded,
                size: 18,
                color: AppColors.primary,
              ),
              const SizedBox(width: 9),
              const Expanded(
                child: Text(
                  'Face Shape',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                ),
              ),
              _valueBadge(model.faceShape, model.faceShape != 'Not scanned'),
            ],
          ),
          const Divider(height: 22),
          Row(
            children: [
              const Icon(
                Icons.accessibility_new_rounded,
                size: 18,
                color: AppColors.primary,
              ),
              const SizedBox(width: 9),
              const Expanded(
                child: Text(
                  'Body Shape',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                ),
              ),
              _valueBadge(model.bodyShape, model.bodyShape != 'Not measured'),
            ],
          ),
          const SizedBox(height: 16),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'BODY MEASUREMENTS',
              style: TextStyle(
                fontSize: 9,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w900,
                color: AppColors.textMuted,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _measurement('Height', model.height, 'cm'),
              _measurement('Weight', model.weight, 'kg'),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _measurement('Bust', model.bust, 'cm'),
              _measurement('Waist', model.waist, 'cm'),
              _measurement('Hips', model.hips, 'cm'),
            ],
          ),
          if (ready) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: AppColors.primarySoft.withValues(alpha: .45),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.auto_awesome_rounded,
                    size: 15,
                    color: AppColors.primaryDark,
                  ),
                  SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      'Your face shape and body shape are automatically used for personalised AI styling.',
                      style: TextStyle(
                        color: AppColors.primaryDark,
                        fontSize: 9.5,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _valueBadge(String value, bool active) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: active ? AppColors.primarySoft : AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        value,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w900,
          color: active ? AppColors.primaryDark : AppColors.textMuted,
        ),
      ),
    );
  }

  Widget _measurement(String label, double value, String unit) {
    final text = value > 0
        ? '${value == value.roundToDouble() ? value.toInt() : value.toStringAsFixed(1)} $unit'
        : '—';
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 3),
        padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 8),
        decoration: BoxDecoration(
          color: AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 9,
                color: AppColors.textMuted,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              text,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool highlight = false,
    bool enabled = true,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: highlight ? AppGradients.soft : null,
            color: highlight ? null : AppColors.surface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: highlight ? AppColors.primarySoft : AppColors.border,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: enabled
                      ? AppColors.primarySoft
                      : AppColors.surfaceMuted,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: enabled
                      ? AppColors.primaryDark
                      : AppColors.textMuted,
                  size: 21,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        if (highlight)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: .10),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Text(
                              'AI',
                              style: TextStyle(
                                color: AppColors.primaryDark,
                                fontSize: 7.5,
                                fontWeight: FontWeight.w900,
                                letterSpacing: .7,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      enabled ? subtitle : 'Create your TiB Model first.',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 10.5,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 7),
              Icon(
                enabled
                    ? Icons.arrow_forward_ios_rounded
                    : Icons.lock_outline_rounded,
                size: 15,
                color: enabled ? AppColors.primary : AppColors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
