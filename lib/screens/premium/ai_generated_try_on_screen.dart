import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../models/wardrobe_item.dart';
import '../../services/firestore_service.dart';
import '../../services/tib_model_service.dart';
import '../../services/virtual_try_on_result_service.dart';
import '../../widgets/premium_badge.dart';

class AiGeneratedTryOnScreen extends StatefulWidget {
  const AiGeneratedTryOnScreen({super.key});

  @override
  State<AiGeneratedTryOnScreen> createState() => _AiGeneratedTryOnScreenState();
}

class _AiGeneratedTryOnScreenState extends State<AiGeneratedTryOnScreen> {
  static const _occasions = ['Dinner', 'Work', 'Casual', 'Date', 'Travel', 'Event'];

  bool _loading = true;
  bool _generating = false;
  TibModelProfile? _model;
  List<WardrobeItem> _wardrobe = const [];
  final Set<String> _selectedIds = {};
  String _occasion = 'Dinner';
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
      final items = await _loadWardrobe();
      if (!mounted) return;
      setState(() {
        _model = model;
        _wardrobe = items;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _status = 'Could not load your styling data. Please try again.';
      });
    }
  }

  Future<List<WardrobeItem>> _loadWardrobe() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const [];
    return FirestoreService.getWardrobeItems(uid);
  }

  List<WardrobeItem> get _selectedItems => _wardrobe.where((item) => _selectedIds.contains(item.id)).take(6).toList();

  void _toggle(WardrobeItem item) {
    if (_generating) return;
    setState(() {
      if (_selectedIds.contains(item.id)) {
        _selectedIds.remove(item.id);
      } else if (_selectedIds.length < 6) {
        _selectedIds.add(item.id);
      }
      _generatedImageUrl = null;
      _status = _selectedIds.isEmpty ? '' : '${_selectedIds.length} piece${_selectedIds.length == 1 ? '' : 's'} selected.';
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

    if (model == null || !model.isComplete || model.facePath == null) {
      setState(() => _status = 'Create your complete TiB Model first so I can style you accurately.');
      return;
    }
    if (items.isEmpty) {
      setState(() => _status = 'Choose at least one wardrobe piece first.');
      return;
    }

    setState(() {
      _generating = true;
      _generatedImageUrl = null;
      _status = 'TiB is analysing your model, wardrobe and occasion…';
    });

    final result = await VirtualTryOnResultService.generate(
      VirtualTryOnRequest(
        model: model,
        items: items,
        occasion: _occasion,
        stylingBrief: 'Preserve the person identity and natural body proportions. Use the selected wardrobe pieces as the clothing source. Create a realistic, tasteful full-body fashion try-on for the selected occasion. Do not invent unrelated garments or change the person\'s face.',
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
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final modelFile = _model?.faceFile;
    final model = _model;
    final ready = model?.isComplete == true;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('AI Virtual Try-On'),
        actions: const [Padding(padding: EdgeInsets.only(right: 14), child: PremiumBadge(compact: true))],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 34),
        children: [
          _buildHero(modelFile, ready),
          const SizedBox(height: 14),
          _buildModelSummary(model),
          const SizedBox(height: 14),
          _buildOccasion(),
          const SizedBox(height: 14),
          _buildSelectedStrip(),
          const SizedBox(height: 14),
          _buildWardrobe(),
          const SizedBox(height: 16),
          SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: _generating ? null : _generate, icon: _generating ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.auto_awesome_rounded), label: Text(_generating ? 'Creating Your Look…' : 'Generate My Try-On')),
          if (_status.isNotEmpty) ...[const SizedBox(height: 12), Text(_status, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11.5, height: 1.45))],
          if (_generatedImageUrl != null) ...[const SizedBox(height: 20), _buildResult()],
        ],
      ),
    );
  }

  Widget _buildHero(File? modelFile, bool ready) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(28), border: Border.all(color: AppColors.border)),
      child: Row(children: [
        Container(width: 92, height: 112, decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(22)), clipBehavior: Clip.antiAlias, child: modelFile != null && modelFile.existsSync() ? Image.file(modelFile, fit: BoxFit.cover) : const Icon(Icons.person_rounded, size: 46, color: AppColors.primary)),
        const SizedBox(width: 16),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5), decoration: BoxDecoration(color: ready ? AppColors.primarySoft : AppColors.surfaceMuted, borderRadius: BorderRadius.circular(20)), child: Text(ready ? 'TIΒ MODEL READY' : 'MODEL REQUIRED', style: TextStyle(color: ready ? AppColors.primaryDark : AppColors.textMuted, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: .9))),
          const SizedBox(height: 10),
          const Text('Try your clothes\nbefore you wear them.', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, height: 1.05)),
          const SizedBox(height: 7),
          const Text('TiB uses your model profile, selected wardrobe and occasion to create the look.', style: TextStyle(color: AppColors.textSecondary, fontSize: 10.5, height: 1.4)),
        ])),
      ]),
    );
  }

  Widget _buildModelSummary(TibModelProfile? model) {
    if (model == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(22), border: Border.all(color: AppColors.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('PERSONAL FIT CONTEXT', style: TextStyle(fontSize: 9, letterSpacing: 1.2, fontWeight: FontWeight.w900, color: AppColors.textMuted)),
        const SizedBox(height: 10),
        Wrap(spacing: 7, runSpacing: 7, children: [
          _profileChip('Face', model.faceShape),
          _profileChip('Body', model.bodyShape),
          _profileChip('Height', model.height > 0 ? '${_num(model.height)} cm' : '—'),
          _profileChip('Bust', model.bust > 0 ? '${_num(model.bust)} cm' : '—'),
          _profileChip('Waist', model.waist > 0 ? '${_num(model.waist)} cm' : '—'),
          _profileChip('Hips', model.hips > 0 ? '${_num(model.hips)} cm' : '—'),
        ]),
      ]),
    );
  }

  String _num(double value) => value == value.roundToDouble() ? value.toInt().toString() : value.toStringAsFixed(1);

  Widget _profileChip(String label, String value) => Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7), decoration: BoxDecoration(color: AppColors.surfaceMuted, borderRadius: BorderRadius.circular(13)), child: Text('$label · $value', style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800)));

  Widget _buildOccasion() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(22), border: Border.all(color: AppColors.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('WHAT ARE YOU DRESSING FOR?', style: TextStyle(fontSize: 9, letterSpacing: 1.2, fontWeight: FontWeight.w900, color: AppColors.textMuted)),
        const SizedBox(height: 9),
        Wrap(spacing: 7, runSpacing: 7, children: _occasions.map((value) => ChoiceChip(label: Text(value), selected: _occasion == value, onSelected: _generating ? null : (_) => setState(() { _occasion = value; _generatedImageUrl = null; }))).toList()),
      ]),
    );
  }

  Widget _buildSelectedStrip() {
    final items = _selectedItems;
    if (items.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(gradient: AppGradients.soft, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.primarySoft)),
      child: Row(children: [
        const Icon(Icons.checkroom_rounded, size: 18, color: AppColors.primaryDark),
        const SizedBox(width: 8),
        Expanded(child: Text('${items.length} selected for this look', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800))),
        TextButton(onPressed: _clearSelection, child: const Text('Clear')),
      ]),
    );
  }

  Widget _buildWardrobe() {
    if (_wardrobe.isEmpty) {
      return Container(padding: const EdgeInsets.all(22), decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(22), border: Border.all(color: AppColors.border)), child: const Text('Your wardrobe is empty. Add some pieces first, then come back and create your virtual look.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary, height: 1.45)));
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(22), border: Border.all(color: AppColors.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [const Expanded(child: Text('SELECT FROM MY WARDROBE', style: TextStyle(fontSize: 11, letterSpacing: 1.1, fontWeight: FontWeight.w900))), Text('${_selectedIds.length}/6', style: const TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w800))]),
        const SizedBox(height: 5),
        const Text('Choose the pieces you want TiB to use. For the most realistic result, include the main outfit pieces.', style: TextStyle(color: AppColors.textSecondary, fontSize: 10, height: 1.35)),
        const SizedBox(height: 11),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _wardrobe.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: .78),
          itemBuilder: (_, index) {
            final item = _wardrobe[index];
            final selected = _selectedIds.contains(item.id);
            return GestureDetector(
              onTap: () => _toggle(item),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                decoration: BoxDecoration(color: selected ? AppColors.lavenderMist : AppColors.surfaceMuted, borderRadius: BorderRadius.circular(18), border: Border.all(color: selected ? AppColors.primary : AppColors.border, width: selected ? 2 : 1)),
                clipBehavior: Clip.antiAlias,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(child: item.imageUrl.isEmpty ? const Center(child: Icon(Icons.checkroom_outlined, size: 36, color: AppColors.primary)) : Image.network(item.imageUrl, width: double.infinity, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image_outlined, color: AppColors.textMuted)))),
                  Padding(padding: const EdgeInsets.fromLTRB(10, 8, 10, 10), child: Row(children: [Expanded(child: Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800))), if (selected) const Icon(Icons.check_circle_rounded, size: 18, color: AppColors.primary)])),
                ]),
              ),
            );
          },
        ),
      ]),
    );
  }

  Widget _buildResult() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(26), border: Border.all(color: AppColors.primarySoft)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [Icon(Icons.auto_awesome_rounded, size: 18, color: AppColors.primary), SizedBox(width: 8), Text('YOUR AI TRY-ON', style: TextStyle(fontSize: 11, letterSpacing: 1.1, fontWeight: FontWeight.w900))]),
        const SizedBox(height: 12),
        ClipRRect(borderRadius: BorderRadius.circular(20), child: Image.network(_generatedImageUrl!, width: double.infinity, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(height: 300, alignment: Alignment.center, color: AppColors.surfaceMuted, child: const Text('The generated image could not be displayed.'))),
        const SizedBox(height: 12),
        Row(children: [Expanded(child: OutlinedButton.icon(onPressed: _generating ? null : _generate, icon: const Icon(Icons.refresh_rounded), label: const Text('Try Again'))), const SizedBox(width: 9), Expanded(child: FilledButton.icon(onPressed: _generating ? null : () { setState(() { _generatedImageUrl = null; _status = ''; }); }, icon: const Icon(Icons.checkroom_rounded), label: const Text('Change Look')))]),
      ]),
    );
  }
}
