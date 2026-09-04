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
    final changed = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => const CreateTibModelScreen()));
    if (changed == true) await _loadModel();
  }

  void _openBuilder(BuildContext context) => Navigator.push(context, MaterialPageRoute(builder: (_) => const OutfitBuilderScreen()));
  void _openTryOn(BuildContext context) => Navigator.push(context, MaterialPageRoute(builder: (_) => const AiGeneratedTryOnScreen()));
  void _openAiStylist(BuildContext context) => Navigator.push(context, MaterialPageRoute(builder: (_) => const AiStyleMeScreen()));

  @override
  Widget build(BuildContext context) {
    final model = _model;
    final ready = model?.isComplete == true;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 36),
          children: [
            Row(children: [IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.arrow_back_rounded)), const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [Text('VYEA', style: TextStyle(color: AppColors.brown, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 2.5)), SizedBox(height: 2), Text('Styling Studio', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800))])), const SizedBox(width: 48)]),
            const SizedBox(height: 8),
            _studioHero(model, ready),
            const SizedBox(height: 22),
            const Text('YOUR VYEA MODEL', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.3, color: AppColors.textMuted)),
            const SizedBox(height: 9),
            _modelSnapshot(model, ready),
            const SizedBox(height: 22),
            const Text('CHOOSE YOUR NEXT MOVE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.3, color: AppColors.textMuted)),
            const SizedBox(height: 10),
            _actionCard(icon: Icons.face_retouching_natural_rounded, title: ready ? 'Edit My VYEA Model' : 'Create My VYEA Model', subtitle: ready ? 'Refresh your face, body reference or measurements.' : 'Create the personal model used throughout your styling studio.', onTap: () => _openModelSetup(context), highlight: !ready),
            const SizedBox(height: 10),
            Row(children: [Expanded(child: _smallAction(icon: Icons.checkroom_rounded, title: 'Build a Look', subtitle: 'Choose pieces', enabled: ready, onTap: () => _openBuilder(context))), const SizedBox(width: 10), Expanded(child: _smallAction(icon: Icons.auto_awesome_rounded, title: 'Let VYEA Style', subtitle: 'AI chooses', enabled: ready, onTap: () => _openAiStylist(context)))]),
            const SizedBox(height: 10),
            _actionCard(icon: Icons.view_in_ar_rounded, title: 'AI Virtual Try-On', subtitle: 'Select pieces from your wardrobe and visualise them on your VYEA Model.', onTap: () => _openTryOn(context), enabled: ready, highlight: true),
            const SizedBox(height: 20),
            _privacyCard(ready),
          ],
        ),
      ),
    );
  }

  Widget _studioHero(TibModelProfile? model, bool ready) {
    final photo = model?.faceFile;
    return Container(
      padding: const EdgeInsets.fromLTRB(21, 21, 21, 20),
      decoration: BoxDecoration(gradient: AppGradients.premium, borderRadius: BorderRadius.circular(30)),
      child: Row(children: [
        Container(width: 82, height: 104, decoration: BoxDecoration(color: Colors.white.withValues(alpha: .55), borderRadius: BorderRadius.circular(23)), clipBehavior: Clip.antiAlias, child: photo != null && photo.existsSync() ? Image.file(photo, fit: BoxFit.cover) : const Icon(Icons.person_rounded, size: 44, color: AppColors.primary)),
        const SizedBox(width: 15),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5), decoration: BoxDecoration(color: Colors.white.withValues(alpha: .72), borderRadius: BorderRadius.circular(10)), child: Text(ready ? 'MODEL READY' : 'FIRST, CREATE YOUR MODEL', style: const TextStyle(color: AppColors.primaryDark, fontSize: 7.8, fontWeight: FontWeight.w900, letterSpacing: .8))),
          const SizedBox(height: 11),
          Text(ready ? 'Style yourself.\nThen see it on you.' : 'Create your model.\nMake styling personal.', style: const TextStyle(fontSize: 23, height: 1.04, fontWeight: FontWeight.w900, letterSpacing: -.6)),
          const SizedBox(height: 7),
          Text(ready ? 'One personal reference for every virtual styling experience.' : 'Your face, body and measurements become your reusable styling reference.', style: const TextStyle(color: AppColors.textSecondary, fontSize: 10.5, height: 1.4)),
        ])),
      ]),
    );
  }

  Widget _modelSnapshot(TibModelProfile? model, bool ready) {
    if (_loading) return const SizedBox(height: 90, child: Center(child: CircularProgressIndicator()));
    if (model == null) return _emptyModelCard();
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(23), border: Border.all(color: AppColors.border)),
      child: Column(children: [
        Row(children: [_snapshotIcon(Icons.face_retouching_natural_rounded), const SizedBox(width: 10), const Expanded(child: Text('Face shape', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800))), _valueBadge(model.faceShape, model.faceShape != 'Not scanned')]),
        const Divider(height: 22),
        Row(children: [_snapshotIcon(Icons.accessibility_new_rounded), const SizedBox(width: 10), const Expanded(child: Text('Body shape', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800))), _valueBadge(model.bodyShape, model.bodyShape != 'Not measured')]),
        const SizedBox(height: 15),
        const Align(alignment: Alignment.centerLeft, child: Text('MEASUREMENTS', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1.2, color: AppColors.textMuted))),
        const SizedBox(height: 9),
        Row(children: [_measurement('Height', model.height, 'cm'), _measurement('Weight', model.weight, 'kg')]),
        const SizedBox(height: 8),
        Row(children: [_measurement('Bust', model.bust, 'cm'), _measurement('Waist', model.waist, 'cm'), _measurement('Hips', model.hips, 'cm')]),
        if (ready) ...[
          const SizedBox(height: 13),
          Container(width: double.infinity, padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: AppColors.primarySoft.withValues(alpha: .45), borderRadius: BorderRadius.circular(13)), child: const Row(children: [Icon(Icons.auto_awesome_rounded, size: 15, color: AppColors.primaryDark), SizedBox(width: 7), Expanded(child: Text('Your model profile is applied automatically to personalised styling experiences.', style: TextStyle(color: AppColors.primaryDark, fontSize: 9.5, height: 1.35)))])),
        ],
      ]),
    );
  }

  Widget _emptyModelCard() => Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(21), border: Border.all(color: AppColors.border)), child: const Row(children: [Icon(Icons.person_outline_rounded, color: AppColors.primary, size: 24), SizedBox(width: 10), Expanded(child: Text('Your VYEA Model has not been created yet. Start here before using virtual styling.', style: TextStyle(color: AppColors.textSecondary, fontSize: 11.5, height: 1.4)))]));
  Widget _snapshotIcon(IconData icon) => Container(width: 34, height: 34, decoration: const BoxDecoration(color: AppColors.primarySoft, shape: BoxShape.circle), child: Icon(icon, size: 17, color: AppColors.primaryDark));
  Widget _valueBadge(String value, bool active) => Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5), decoration: BoxDecoration(color: active ? AppColors.primarySoft : AppColors.surfaceMuted, borderRadius: BorderRadius.circular(11)), child: Text(value, style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w900, color: active ? AppColors.primaryDark : AppColors.textMuted)));

  Widget _measurement(String label, double value, String unit) {
    final text = value > 0 ? '${value == value.roundToDouble() ? value.toInt() : value.toStringAsFixed(1)} $unit' : '—';
    return Expanded(child: Container(margin: const EdgeInsets.symmetric(horizontal: 3), padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 7), decoration: BoxDecoration(color: AppColors.surfaceMuted, borderRadius: BorderRadius.circular(13)), child: Column(children: [Text(label, style: const TextStyle(fontSize: 8.8, color: AppColors.textMuted, fontWeight: FontWeight.w700)), const SizedBox(height: 4), Text(text, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w900))])));
  }

  Widget _actionCard({required IconData icon, required String title, required String subtitle, required VoidCallback onTap, bool highlight = false, bool enabled = true}) {
    return Material(color: Colors.transparent, child: InkWell(onTap: enabled ? onTap : null, borderRadius: BorderRadius.circular(21), child: Ink(padding: const EdgeInsets.all(15), decoration: BoxDecoration(gradient: highlight ? AppGradients.soft : null, color: highlight ? null : AppColors.surface, borderRadius: BorderRadius.circular(21), border: Border.all(color: highlight ? AppColors.primarySoft : AppColors.border)), child: Row(children: [Container(width: 44, height: 44, decoration: BoxDecoration(color: enabled ? AppColors.primarySoft : AppColors.surfaceMuted, shape: BoxShape.circle), child: Icon(icon, color: enabled ? AppColors.primaryDark : AppColors.textMuted, size: 20)), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Expanded(child: Text(title, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800))), if (highlight) Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4), decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: .10), borderRadius: BorderRadius.circular(9)), child: const Text('AI', style: TextStyle(fontSize: 7.3, fontWeight: FontWeight.w900, color: AppColors.primaryDark, letterSpacing: .5)))]), const SizedBox(height: 3), Text(enabled ? subtitle : 'Create your VYEA Model first.', style: const TextStyle(color: AppColors.textSecondary, fontSize: 10.3, height: 1.35))])), const SizedBox(width: 7), Icon(enabled ? Icons.arrow_forward_ios_rounded : Icons.lock_outline_rounded, size: 14, color: enabled ? AppColors.primary : AppColors.textMuted)]))));
  }

  Widget _smallAction({required IconData icon, required String title, required String subtitle, required bool enabled, required VoidCallback onTap}) {
    return Material(color: Colors.transparent, child: InkWell(onTap: enabled ? onTap : null, borderRadius: BorderRadius.circular(20), child: Ink(padding: const EdgeInsets.fromLTRB(13, 14, 12, 14), decoration: BoxDecoration(color: enabled ? AppColors.surface : AppColors.surfaceMuted, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.border)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Container(width: 38, height: 38, decoration: const BoxDecoration(color: AppColors.primarySoft, shape: BoxShape.circle), child: Icon(icon, color: AppColors.primaryDark, size: 18)), const SizedBox(height: 10), Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)), const SizedBox(height: 2), Text(enabled ? subtitle : 'Locked', style: const TextStyle(color: AppColors.textSecondary, fontSize: 9.5)), const SizedBox(height: 7), Icon(enabled ? Icons.arrow_forward_rounded : Icons.lock_outline_rounded, size: 15, color: enabled ? AppColors.primary : AppColors.textMuted)]))));
  }

  Widget _privacyCard(bool ready) => Container(padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.border)), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [const Icon(Icons.lock_outline_rounded, size: 18, color: AppColors.primary), const SizedBox(width: 9), Expanded(child: Text(ready ? 'Your model photos stay on this device. The same VYEA Model is reused across your styling experiences.' : 'Your model photos stay on this device. Create your VYEA Model once and reuse it across styling experiences.', style: const TextStyle(color: AppColors.textSecondary, fontSize: 10.5, height: 1.45)))]));
}
