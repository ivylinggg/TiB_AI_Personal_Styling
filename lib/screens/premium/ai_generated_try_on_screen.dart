import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_gradients.dart';
import '../../models/wardrobe_item.dart';
import '../../services/firestore_service.dart';
import '../../services/tib_model_service.dart';
import '../../services/virtual_try_on_result_service.dart';
import '../../widgets/premium_badge.dart';

/// TiB's AI fitting room.
///
/// The important product rule is that this screen never presents the AI as
/// generating a generic fashion model. The user first establishes a Personal
/// TiB Model, then chooses real pieces from My Wardrobe, and the AI dresses
/// that personal reference.
class AiGeneratedTryOnScreen extends StatefulWidget {
  const AiGeneratedTryOnScreen({super.key});

  @override
  State<AiGeneratedTryOnScreen> createState() => _AiGeneratedTryOnScreenState();
}

class _AiGeneratedTryOnScreenState extends State<AiGeneratedTryOnScreen> {
  static const _occasions = ['Everyday', 'Work', 'Dinner', 'Date', 'Travel', 'Event'];

  bool _loading = true;
  bool _generating = false;
  TibModelProfile? _model;
  List<WardrobeItem> _wardrobe = const [];
  final Set<String> _selectedIds = {};
  String _occasion = 'Everyday';
  String _status = '';
  String? _generatedImageUrl;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final model = await TibModelService.load();
      final wardrobe = await _loadWardrobe();
      if (!mounted) return;
      setState(() {
        _model = model;
        _wardrobe = wardrobe;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _status = 'Could not load your Personal TiB Model or wardrobe.';
      });
    }
  }

  Future<List<WardrobeItem>> _loadWardrobe() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const [];
    return FirestoreService.getWardrobeItems(uid);
  }

  List<WardrobeItem> get _selectedItems => _wardrobe
      .where((item) => _selectedIds.contains(item.id))
      .take(6)
      .toList();

  bool get _modelReady => _model?.isComplete == true;

  void _toggle(WardrobeItem item) {
    if (_generating) return;
    setState(() {
      if (_selectedIds.contains(item.id)) {
        _selectedIds.remove(item.id);
      } else if (_selectedIds.length < 6) {
        _selectedIds.add(item.id);
      }
      _generatedImageUrl = null;
      _status = _selectedIds.isEmpty
          ? ''
          : '${_selectedIds.length} ${_selectedIds.length == 1 ? 'piece' : 'pieces'} selected.';
    });
  }

  void _clearSelection() {
    if (_generating) return;
    setState(() {
      _selectedIds.clear();
      _generatedImageUrl = null;
      _status = '';
    });
  }

  Future<void> _generate() async {
    if (_generating) return;
    final model = _model;
    final items = _selectedItems;

    if (model == null || !model.isComplete || model.facePath == null || model.bodyPath == null) {
      setState(() => _status = 'Complete your Personal TiB Model first: face, full-body reference and real measurements are required.');
      return;
    }
    if (items.isEmpty) {
      setState(() => _status = 'Choose at least one piece from My Wardrobe.');
      return;
    }

    setState(() {
      _generating = true;
      _generatedImageUrl = null;
      _status = 'TiB is dressing your Personal Model…';
    });

    final result = await VirtualTryOnResultService.generate(
      VirtualTryOnRequest(
        model: model,
        items: items,
        occasion: _occasion,
        stylingBrief: [
          'This is a personal AI fitting-room request, not a generic fashion model request.',
          'Use the supplied full-body reference as the primary silhouette and proportion reference.',
          'Keep the same face, body proportions, height impression, shoulder width, waist, hips and leg proportions.',
          'Dress the person using only the selected My Wardrobe references.',
          'Show a natural head-to-toe standing fashion image whenever possible.',
          'Do not beautify, slim, lengthen, reshape or replace the person with another model.',
        ].join(' '),
      ),
    );

    if (!mounted) return;
    setState(() {
      _generating = false;
      _generatedImageUrl = result.imageUrl;
      _status = result.status;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('AI Fitting Room', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: const [Padding(padding: EdgeInsets.only(right: 14), child: PremiumBadge(compact: true))],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 36),
        children: [
          _hero(),
          const SizedBox(height: 14),
          _modelCard(),
          const SizedBox(height: 14),
          _occasionCard(),
          const SizedBox(height: 14),
          _wardrobeCard(),
          const SizedBox(height: 16),
          _generateButton(),
          if (_status.isNotEmpty) ...[
            const SizedBox(height: 11),
            _statusCard(),
          ],
          if (_generatedImageUrl != null) ...[
            const SizedBox(height: 18),
            _resultCard(),
          ],
        ],
      ),
    );
  }

  Widget _hero() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 21, 20, 20),
      decoration: BoxDecoration(
        gradient: AppGradients.premium,
        borderRadius: BorderRadius.circular(30),
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
                  'YOUR AI FITTING ROOM',
                  style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 1),
                ),
              ),
              const Spacer(),
              const Icon(Icons.auto_awesome_rounded, size: 20),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'See yourself\nin your clothes.',
            style: TextStyle(fontSize: 29, height: .98, fontWeight: FontWeight.w900, letterSpacing: -.8),
          ),
          const SizedBox(height: 10),
          Text(
            _modelReady
                ? 'Your real face + full-body reference + measurements become the model. Your wardrobe becomes the outfit.'
                : 'Build your Personal TiB Model first. TiB needs your real body reference before it can create a personal try-on.',
            style: const TextStyle(fontSize: 11, height: 1.45, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _modelCard() {
    final model = _model;
    final face = model?.faceFile;
    final body = model?.bodyFile;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(child: Text('MY PERSONAL TIΒ MODEL', style: TextStyle(fontSize: 10, letterSpacing: 1.15, fontWeight: FontWeight.w900))),
              _readyPill(_modelReady),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _referenceImage(face, 'FACE', Icons.face_retouching_natural_rounded),
              const SizedBox(width: 10),
              _referenceImage(body, 'FULL BODY', Icons.accessibility_new_rounded),
              const SizedBox(width: 10),
              Expanded(child: _modelFacts(model)),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: AppColors.primarySoft.withValues(alpha: .45),
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.lock_person_rounded, size: 16, color: AppColors.primaryDark),
                SizedBox(width: 7),
                Expanded(child: Text('This is the person TiB is dressing. The full-body reference is the primary silhouette reference; measurements provide real fit context.', style: TextStyle(fontSize: 9.5, height: 1.4, color: AppColors.primaryDark, fontWeight: FontWeight.w600))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _referenceImage(File? file, String label, IconData icon) {
    return SizedBox(
      width: 86,
      height: 128,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (file != null && file.existsSync()) Image.file(file, fit: BoxFit.cover) else Center(child: Icon(icon, size: 30, color: AppColors.primary)),
            Positioned(
              left: 7,
              right: 7,
              bottom: 7,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 4),
                decoration: BoxDecoration(color: Colors.black.withValues(alpha: .56), borderRadius: BorderRadius.circular(9)),
                child: Text(label, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 7, fontWeight: FontWeight.w900, letterSpacing: .7)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _modelFacts(TibModelProfile? model) {
    if (model == null) return const Text('Create your Personal TiB Model.', style: TextStyle(fontSize: 11, color: AppColors.textSecondary));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fact('Body', model.bodyShape),
        _fact('Face', model.faceShape),
        _fact('Height', model.height > 0 ? '${_num(model.height)} cm' : '—'),
        _fact('Fit', '${_num(model.bust)} / ${_num(model.waist)} / ${_num(model.hips)}'),
      ],
    );
  }

  Widget _fact(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: const TextStyle(fontSize: 7, letterSpacing: .8, color: AppColors.textMuted, fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }

  Widget _readyPill(bool ready) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(color: ready ? AppColors.primarySoft : AppColors.surfaceMuted, borderRadius: BorderRadius.circular(20)),
      child: Text(ready ? 'READY' : 'INCOMPLETE', style: TextStyle(fontSize: 7.5, letterSpacing: .7, fontWeight: FontWeight.w900, color: ready ? AppColors.primaryDark : AppColors.textMuted)),
    );
  }

  Widget _occasionCard() {
    return _section(
      title: 'WHAT ARE YOU DRESSING FOR?',
      child: Wrap(
        spacing: 7,
        runSpacing: 7,
        children: _occasions.map((occasion) {
          return ChoiceChip(
            label: Text(occasion),
            selected: _occasion == occasion,
            onSelected: _generating ? null : (_) => setState(() { _occasion = occasion; _generatedImageUrl = null; }),
          );
        }).toList(),
      ),
    );
  }

  Widget _wardrobeCard() {
    if (_wardrobe.isEmpty) {
      return _section(
        title: 'MY WARDROBE',
        child: const Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Text('Your wardrobe is empty. Add your real clothing pieces first so TiB can dress your Personal Model.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary, fontSize: 11, height: 1.45)),
        ),
      );
    }

    return _section(
      title: 'CHOOSE WHAT YOUR MODEL WILL WEAR',
      trailing: Text('${_selectedIds.length}/6', style: const TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w900)),
      child: Column(
        children: [
          const Align(alignment: Alignment.centerLeft, child: Text('Select the actual pieces from My Wardrobe. TiB will use these images as garment references.', style: TextStyle(color: AppColors.textSecondary, fontSize: 10, height: 1.35))),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _wardrobe.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 9, mainAxisSpacing: 9, childAspectRatio: .74),
            itemBuilder: (context, index) => _wardrobeItem(_wardrobe[index]),
          ),
        ],
      ),
    );
  }

  Widget _wardrobeItem(WardrobeItem item) {
    final selected = _selectedIds.contains(item.id);
    return GestureDetector(
      onTap: () => _toggle(item),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: selected ? AppColors.lavenderMist : AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: selected ? AppColors.primary : AppColors.border, width: selected ? 2 : 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Positioned.fill(
              child: item.imageUrl.isEmpty
                  ? const Center(child: Icon(Icons.checkroom_outlined, size: 38, color: AppColors.primary))
                  : Image.network(item.imageUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image_outlined, color: AppColors.textMuted))),
            Positioned(left: 8, right: 8, bottom: 8, child: Container(padding: const EdgeInsets.fromLTRB(9, 7, 7, 7), decoration: BoxDecoration(color: Colors.white.withValues(alpha: .9), borderRadius: BorderRadius.circular(12)), child: Row(children: [Expanded(child: Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w900))), if (selected) const Icon(Icons.check_circle_rounded, size: 18, color: AppColors.primary)]))),
            if (selected) Positioned(top: 8, right: 8, child: Container(padding: const EdgeInsets.all(5), decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle), child: const Icon(Icons.check, color: Colors.white, size: 13))),
          ],
        ),
      ),
    );
  }

  Widget _generateButton() {
    final enabled = !_generating && _modelReady && _selectedItems.isNotEmpty;
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: FilledButton.icon(
        onPressed: enabled ? _generate : null,
        icon: _generating ? const SizedBox(width: 19, height: 19, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.auto_awesome_rounded),
        label: Text(_generating ? 'Dressing Your TiB Model…' : 'Generate My Personal Try-On'),
      ),
    );
  }

  Widget _statusCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [const Icon(Icons.info_outline_rounded, size: 17, color: AppColors.primary), const SizedBox(width: 8), Expanded(child: Text(_status, textAlign: TextAlign.left, style: const TextStyle(color: AppColors.textSecondary, fontSize: 10.5, height: 1.4)))]),
    );
  }

  Widget _resultCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(27), border: Border.all(color: AppColors.primarySoft, width: 1.4)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [const Icon(Icons.auto_awesome_rounded, size: 18, color: AppColors.primary), const SizedBox(width: 7), const Expanded(child: Text('THIS IS YOUR LOOK', style: TextStyle(fontSize: 11, letterSpacing: 1.1, fontWeight: FontWeight.w900))), TextButton(onPressed: _generating ? null : _generate, child: const Text('Regenerate'))]),
          const SizedBox(height: 9),
          ClipRRect(borderRadius: BorderRadius.circular(21), child: Image.network(_generatedImageUrl!, width: double.infinity, fit: BoxFit.contain, errorBuilder: (_, __, ___) => Container(height: 360, alignment: Alignment.center, color: AppColors.surfaceMuted, child: const Text('The generated image could not be displayed.')))),
          const SizedBox(height: 11),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppColors.primarySoft.withValues(alpha: .4), borderRadius: BorderRadius.circular(16)),
            child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(Icons.person_pin_rounded, size: 17, color: AppColors.primaryDark), SizedBox(width: 7), Expanded(child: Text('TiB generated this look from your Personal TiB Model and the selected pieces in My Wardrobe. The goal is to show you — not a replacement model.', style: TextStyle(fontSize: 9.5, height: 1.4, color: AppColors.primaryDark, fontWeight: FontWeight.w600)))]),
          ),
          const SizedBox(height: 10),
          SizedBox(width: double.infinity, child: OutlinedButton.icon(onPressed: _generating ? null : _clearSelection, icon: const Icon(Icons.checkroom_rounded), label: const Text('Create Another Look'))),
        ],
      ),
    );
  }

  Widget _section({required String title, Widget? trailing, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(24), border: Border.all(color: AppColors.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Expanded(child: Text(title, style: const TextStyle(fontSize: 9.5, letterSpacing: 1.1, fontWeight: FontWeight.w900, color: AppColors.textMuted))), if (trailing != null) trailing]), const SizedBox(height: 10), child]),
    );
  }

  String _num(double value) => value <= 0 ? '—' : value == value.roundToDouble() ? value.toInt().toString() : value.toStringAsFixed(1);
}
