import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_gradients.dart';
import '../../services/tib_model_service.dart';
import '../../widgets/tib_virtual_model_preview.dart';
import 'ai_generated_try_on_screen.dart';
import 'create_tib_model_screen.dart';

/// The user's persistent Personal TiB Model.
///
/// This is intentionally separate from a single try-on result: the model is
/// the user's reusable identity context (face + full-body reference + real
/// measurements) that every future styling experience can build on.
class PersonalTibModelScreen extends StatefulWidget {
  const PersonalTibModelScreen({super.key});

  @override
  State<PersonalTibModelScreen> createState() => _PersonalTibModelScreenState();
}

class _PersonalTibModelScreenState extends State<PersonalTibModelScreen> {
  TibModelProfile? _model;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final model = await TibModelService.load();
    if (!mounted) return;
    setState(() {
      _model = model;
      _loading = false;
    });
  }

  Future<void> _editModel() async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const CreateTibModelScreen()),
    );
    if (changed == true) await _load();
  }

  void _openTryOn() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AiGeneratedTryOnScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final model = _model;
    final ready = model?.isComplete == true;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: const Text(
          'My TiB Model',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 34),
              children: [
                _hero(model, ready),
                const SizedBox(height: 16),
                if (ready) ...[
                  _identityCard(model!),
                  const SizedBox(height: 16),
                  _referenceCard(model),
                  const SizedBox(height: 16),
                  TibVirtualModelPreview(model: model, height: 430),
                  const SizedBox(height: 16),
                  _tryOnCard(),
                ] else ...[
                  _setupCard(model),
                ],
              ],
            ),
    );
  }

  Widget _hero(TibModelProfile? model, bool ready) {
    final face = model?.faceFile;
    return Container(
      padding: const EdgeInsets.all(21),
      decoration: BoxDecoration(
        gradient: AppGradients.premium,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        children: [
          Container(
            width: 92,
            height: 116,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .58),
              borderRadius: BorderRadius.circular(24),
            ),
            clipBehavior: Clip.antiAlias,
            child: face != null && face.existsSync()
                ? Image.file(face, fit: BoxFit.cover)
                : const Icon(
                    Icons.person_rounded,
                    size: 48,
                    color: AppColors.primary,
                  ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _statusPill(ready ? 'PERSONAL MODEL READY' : 'SETUP REQUIRED'),
                const SizedBox(height: 11),
                Text(
                  ready ? 'This is\nyou.' : 'Build your\nTiB self.',
                  style: const TextStyle(
                    fontSize: 27,
                    height: 1,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -.7,
                  ),
                ),
                const SizedBox(height: 9),
                Text(
                  ready
                      ? 'Your face, full-body reference and real proportions are now the foundation for TiB styling.'
                      : 'Create one reusable model from your real face, body and measurements.',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 10.5,
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

  Widget _identityCard(TibModelProfile model) {
    return _section(
      title: 'YOUR REAL IDENTITY',
      child: Column(
        children: [
          _row(Icons.face_retouching_natural_rounded, 'Face identity', model.faceShape),
          const Divider(height: 22),
          _row(Icons.accessibility_new_rounded, 'Body shape', model.bodyShape),
          const Divider(height: 22),
          _row(Icons.straighten_rounded, 'Body reference', 'Full-body photo'),
          const SizedBox(height: 13),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primarySoft.withValues(alpha: .48),
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.auto_awesome_rounded, size: 16, color: AppColors.primaryDark),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'TiB uses these identity references when styling you. The goal is not to create a generic fashion model — it is to dress your Personal TiB Model.',
                    style: TextStyle(
                      color: AppColors.primaryDark,
                      fontSize: 10,
                      height: 1.4,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _referenceCard(TibModelProfile model) {
    return _section(
      title: 'REAL BODY PROPORTIONS',
      child: Column(
        children: [
          Row(
            children: [
              _metric('Height', model.height, 'cm'),
              _metric('Weight', model.weight, 'kg'),
            ],
          ),
          const SizedBox(height: 9),
          Row(
            children: [
              _metric('Bust', model.bust, 'cm'),
              _metric('Waist', model.waist, 'cm'),
              _metric('Hips', model.hips, 'cm'),
            ],
          ),
          const SizedBox(height: 11),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'These measurements are fit context. The full-body photo remains the primary silhouette reference.',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 10,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _setupCard(TibModelProfile? model) {
    final hasFace = model?.facePath != null;
    final hasBody = model?.bodyPath != null;
    final hasMeasurements = model != null && model.weight > 0 && model.height > 0 && model.bust > 0 && model.waist > 0 && model.hips > 0;

    return _section(
      title: 'BUILD YOUR PERSONAL MODEL',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'TiB needs three things before your Personal Model can be used for realistic full-body try-on:',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 11, height: 1.45),
          ),
          const SizedBox(height: 14),
          _check('Your face reference', hasFace),
          _check('Your full-body reference', hasBody),
          _check('Your real body measurements', hasMeasurements),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _editModel,
              icon: const Icon(Icons.face_retouching_natural_rounded),
              label: Text(hasFace || hasBody || hasMeasurements ? 'Complete My TiB Model' : 'Create My TiB Model'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tryOnCard() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _openTryOn,
        borderRadius: BorderRadius.circular(24),
        child: Ink(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: AppGradients.soft,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.primarySoft),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.checkroom_rounded,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 13),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Dress My TiB Model',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Choose clothes from My Wardrobe and see them on your Personal TiB Model.',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 10.5, height: 1.35),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_rounded, color: AppColors.primary),
            ],
          ),
        ),
      ),
    );
  }

  Widget _section({required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 9,
              letterSpacing: 1.25,
              fontWeight: FontWeight.w900,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 11),
          child,
        ],
      ),
    );
  }

  Widget _row(IconData icon, String label, String value) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: const BoxDecoration(
            color: AppColors.primarySoft,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 18, color: AppColors.primaryDark),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(label, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800)),
        ),
        Text(value, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w900, color: AppColors.primaryDark)),
      ],
    );
  }

  Widget _metric(String label, double value, String unit) {
    final formatted = value == value.roundToDouble() ? value.toInt().toString() : value.toStringAsFixed(1);
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 3),
        padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 7),
        decoration: BoxDecoration(
          color: AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Text(label, style: const TextStyle(fontSize: 8.5, color: AppColors.textMuted, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(value > 0 ? '$formatted $unit' : '—', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w900)),
          ],
        ),
      ),
    );
  }

  Widget _check(String label, bool complete) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(
            complete ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
            size: 19,
            color: complete ? AppColors.primary : AppColors.textMuted,
          ),
          const SizedBox(width: 9),
          Text(label, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _statusPill(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .72),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.primaryDark,
          fontSize: 7.5,
          fontWeight: FontWeight.w900,
          letterSpacing: .8,
        ),
      ),
    );
  }
}
