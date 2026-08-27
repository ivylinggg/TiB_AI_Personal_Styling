import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_gradients.dart';
import '../../services/tib_model_service.dart';
import '../../widgets/tib_virtual_model_preview.dart';
import 'ai_generated_try_on_screen.dart';
import 'create_tib_model_screen.dart';

/// Persistent representation of the user's real self inside TiB.
///
/// This screen is the identity layer for the AI fitting room. Existing
/// onboarding, measurements, face scan, wardrobe and try-on flows remain
/// separate; this screen simply brings their data together as one model.
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
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final model = _model!;
    final ready = model.isComplete;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: const Text('My TiB Model', style: TextStyle(fontWeight: FontWeight.w900)),
        actions: [
          TextButton.icon(
            onPressed: _editModel,
            icon: const Icon(Icons.edit_rounded, size: 17),
            label: const Text('Edit'),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 6, 18, 36),
        children: [
          _identityHero(model, ready),
          const SizedBox(height: 14),
          if (!ready) ...[
            _setupCard(model),
            const SizedBox(height: 14),
          ],
          if (ready) ...[
            _bodyReferenceCard(model),
            const SizedBox(height: 14),
            _measurementCard(model),
            const SizedBox(height: 14),
            TibVirtualModelPreview(model: model, height: 440),
            const SizedBox(height: 14),
            _dressMeCard(),
          ],
        ],
      ),
    );
  }

  Widget _identityHero(TibModelProfile model, bool ready) {
    final face = model.faceFile;
    final body = model.bodyFile;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: AppGradients.premium,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _pill(ready ? 'PERSONAL MODEL READY' : 'BUILD YOUR MODEL'),
              const Spacer(),
              const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 20),
            ],
          ),
          const SizedBox(height: 15),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _referenceTile(body, 'YOUR BODY', Icons.accessibility_new_rounded, large: true),
              const SizedBox(width: 9),
              _referenceTile(face, 'YOUR FACE', Icons.face_retouching_natural_rounded),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ready ? 'This is you.' : 'This becomes you.',
                      style: const TextStyle(fontSize: 26, height: .98, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -.7),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      ready
                          ? 'Your real face, body reference and measurements are now the foundation for every personal try-on.'
                          : 'TiB combines your real references into one reusable styling identity.',
                      style: const TextStyle(fontSize: 10.5, height: 1.42, color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .14),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: Colors.white.withValues(alpha: .18)),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.lock_person_rounded, color: Colors.white, size: 16),
                SizedBox(width: 7),
                Expanded(
                  child: Text(
                    'TiB is not building a generic model. It is dressing your real-person reference.',
                    style: TextStyle(color: Colors.white, fontSize: 9.5, height: 1.4, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _bodyReferenceCard(TibModelProfile model) {
    return _section(
      eyebrow: 'PRIMARY SILHOUETTE REFERENCE',
      title: 'Your real body',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _bodyPhoto(model.bodyFile),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _factLine('Body shape', model.bodyShape),
                _factLine('Height', _number(model.height, 'cm')),
                _factLine('Fit profile', '${_number(model.bust)} / ${_number(model.waist)} / ${_number(model.hips)} cm'),
                const SizedBox(height: 10),
                const Text(
                  'The full-body reference anchors silhouette, scale and natural proportions. Measurements reinforce the fit rather than replacing the person.',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 9.5, height: 1.42),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _measurementCard(TibModelProfile model) {
    return _section(
      eyebrow: 'REAL FIT DATA',
      title: 'Your proportions',
      child: Column(
        children: [
          Row(children: [
            _metric('Height', model.height, 'cm'),
            _metric('Weight', model.weight, 'kg'),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            _metric('Bust', model.bust, 'cm'),
            _metric('Waist', model.waist, 'cm'),
            _metric('Hips', model.hips, 'cm'),
          ]),
          const SizedBox(height: 11),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: AppColors.primarySoft.withValues(alpha: .45), borderRadius: BorderRadius.circular(13)),
            child: const Text(
              'These numbers are used as hard fit context: TiB should adapt clothing to your body, not change your body to fit the clothing.',
              style: TextStyle(color: AppColors.primaryDark, fontSize: 9.5, height: 1.4, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _setupCard(TibModelProfile model) {
    final hasFace = model.facePath != null;
    final hasBody = model.bodyPath != null;
    final hasMeasurements = model.weight > 0 && model.height > 0 && model.bust > 0 && model.waist > 0 && model.hips > 0;

    return _section(
      eyebrow: 'SETUP',
      title: 'Build your real-person model',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('TiB needs these three identity layers before realistic full-body try-on is enabled.', style: TextStyle(color: AppColors.textSecondary, fontSize: 10.5, height: 1.4)),
          const SizedBox(height: 13),
          _check('Face reference', hasFace),
          _check('Full-body reference', hasBody),
          _check('Real body measurements', hasMeasurements),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _editModel,
              icon: const Icon(Icons.person_add_alt_1_rounded),
              label: Text(hasFace || hasBody || hasMeasurements ? 'Complete My TiB Model' : 'Create My TiB Model'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dressMeCard() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _openTryOn,
        borderRadius: BorderRadius.circular(25),
        child: Ink(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(gradient: AppGradients.soft, borderRadius: BorderRadius.circular(25), border: Border.all(color: AppColors.primarySoft)),
          child: Row(
            children: [
              Container(width: 50, height: 50, decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle), child: const Icon(Icons.checkroom_rounded, color: Colors.white)),
              const SizedBox(width: 13),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Dress My TiB Model', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
                    SizedBox(height: 3),
                    Text('Pick real pieces from My Wardrobe and see them on this same person.', style: TextStyle(color: AppColors.textSecondary, fontSize: 10.5, height: 1.35)),
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

  Widget _referenceTile(File? file, String label, IconData icon, {bool large = false}) {
    return SizedBox(
      width: large ? 86 : 70,
      height: large ? 122 : 92,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(17),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (file != null && file.existsSync()) Image.file(file, fit: BoxFit.cover) else Container(color: Colors.white.withValues(alpha: .35), child: Icon(icon, color: AppColors.primary, size: 28)),
            Positioned(left: 6, right: 6, bottom: 6, child: Container(padding: const EdgeInsets.symmetric(vertical: 4), decoration: BoxDecoration(color: Colors.black.withValues(alpha: .52), borderRadius: BorderRadius.circular(8)), child: Text(label, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 6.5, fontWeight: FontWeight.w900, letterSpacing: .6))),
          ],
        ),
      ),
    );
  }

  Widget _bodyPhoto(File? file) {
    return Container(
      width: 96,
      height: 142,
      decoration: BoxDecoration(color: AppColors.surfaceMuted, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.border)),
      clipBehavior: Clip.antiAlias,
      child: file != null && file.existsSync() ? Image.file(file, fit: BoxFit.cover) : const Icon(Icons.accessibility_new_rounded, color: AppColors.primary, size: 38),
    );
  }

  Widget _section({required String eyebrow, required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(25), border: Border.all(color: AppColors.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(eyebrow, style: const TextStyle(fontSize: 8, letterSpacing: 1.15, fontWeight: FontWeight.w900, color: AppColors.textMuted)),
        const SizedBox(height: 4),
        Text(title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900, letterSpacing: -.3)),
        const SizedBox(height: 12),
        child,
      ]),
    );
  }

  Widget _factLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [Expanded(child: Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary))), Text(value, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w900, color: AppColors.primaryDark))]),
    );
  }

  Widget _metric(String label, double value, String unit) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 3),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 5),
        decoration: BoxDecoration(color: AppColors.surfaceMuted, borderRadius: BorderRadius.circular(14)),
        child: Column(children: [Text(label, style: const TextStyle(fontSize: 8, color: AppColors.textMuted, fontWeight: FontWeight.w700)), const SizedBox(height: 3), Text(value > 0 ? _number(value, unit) : '—', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w900))]),
      ),
    );
  }

  Widget _check(String label, bool complete) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(children: [Icon(complete ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded, size: 18, color: complete ? AppColors.primary : AppColors.textMuted), const SizedBox(width: 8), Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700))]),
    );
  }

  Widget _pill(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: .78), borderRadius: BorderRadius.circular(20)),
      child: Text(text, style: const TextStyle(color: AppColors.primaryDark, fontSize: 7, letterSpacing: .75, fontWeight: FontWeight.w900)),
    );
  }

  String _number(double value, [String? unit]) {
    if (value <= 0) return '—';
    final text = value == value.roundToDouble() ? value.toInt().toString() : value.toStringAsFixed(1);
    return unit == null ? text : '$text $unit';
  }
}
