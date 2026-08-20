import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../models/wardrobe_item.dart';
import '../../providers/analysis_provider.dart';
import '../../services/firestore_service.dart';

class WardrobeAuditScreen extends StatefulWidget {
  const WardrobeAuditScreen({super.key});

  @override
  State<WardrobeAuditScreen> createState() => _WardrobeAuditScreenState();
}

class _WardrobeAuditScreenState extends State<WardrobeAuditScreen> {
  bool _loading = true;
  List<WardrobeItem> _items = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      final items = await FirestoreService.getWardrobeItems(uid);
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final result = context.watch<AnalysisProvider>().result;
    final targetColours = result?.colours.map((e) => e.toLowerCase()).toList() ?? const <String>[];
    final categories = <String, int>{};
    for (final item in _items) {
      categories[item.category] = (categories[item.category] ?? 0) + 1;
    }

    final missing = <String>[];
    if (!_items.any((i) => i.category.toLowerCase() == 'tops')) missing.add('Tops');
    if (!_items.any((i) => i.category.toLowerCase() == 'bottoms')) missing.add('Bottoms');
    if (!_items.any((i) => i.category.toLowerCase() == 'shoes')) missing.add('Shoes');
    if (!_items.any((i) => ['jackets', 'jacket', 'suits', 'blazer'].contains(i.category.toLowerCase()))) missing.add('Jacket / Blazer');
    if (!_items.any((i) => i.category.toLowerCase() == 'dresses')) missing.add('Dress / One-piece');

    final paletteMatches = _items.where((item) {
      final colour = item.colour.toLowerCase();
      return targetColours.any((target) => colour.contains(target) || target.contains(colour));
    }).length;

    final capsule = _capsuleSuggestions(missing);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: const Text('Wardrobe Audit'),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : RefreshIndicator(
              color: AppColors.primary,
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                children: [
                  _summaryCard(categories, paletteMatches, result?.colours.length ?? 0),
                  const SizedBox(height: 16),
                  _sectionTitle('Wardrobe balance'),
                  const SizedBox(height: 8),
                  _balanceCard(categories),
                  const SizedBox(height: 18),
                  _sectionTitle('Missing essentials'),
                  const SizedBox(height: 8),
                  _missingCard(missing),
                  const SizedBox(height: 18),
                  _sectionTitle('Capsule wardrobe starter'),
                  const SizedBox(height: 8),
                  _capsuleCard(capsule),
                  const SizedBox(height: 18),
                  _sectionTitle('Use your palette more'),
                  const SizedBox(height: 8),
                  _paletteCard(paletteMatches, result?.colours.length ?? 0),
                ],
              ),
            ),
    );
  }

  Widget _summaryCard(Map<String, int> categories, int matches, int paletteSize) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(25),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('YOUR WARDROBE HEALTH', style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.1)),
                const SizedBox(height: 8),
                Text('${_items.length} pieces', style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text('${categories.length} categories • $matches palette matches', style: const TextStyle(color: Colors.white70, fontSize: 11.5)),
              ],
            ),
          ),
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: .15), shape: BoxShape.circle),
            child: Center(
              child: Text(
                paletteSize == 0 ? '—' : '${((matches / paletteSize).clamp(0, 1) * 100).round()}%',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _balanceCard(Map<String, int> categories) {
    if (categories.isEmpty) {
      return _empty('Add a few pieces first. TiB will audit the balance for you.');
    }
    final sorted = categories.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _box(),
      child: Column(children: sorted.map((entry) {
        final ratio = _items.isEmpty ? 0.0 : entry.value / _items.length;
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              SizedBox(width: 82, child: Text(entry.key, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700))),
              Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(10), child: LinearProgressIndicator(value: ratio, minHeight: 8, backgroundColor: AppColors.surfaceMuted, valueColor: const AlwaysStoppedAnimation(AppColors.primary)))),
              const SizedBox(width: 9),
              Text('${entry.value}', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800)),
            ],
          ),
        );
      }).toList()),
    );
  }

  Widget _missingCard(List<String> missing) {
    if (missing.isEmpty) {
      return Container(padding: const EdgeInsets.all(16), decoration: _box(), child: const Row(children: [Icon(Icons.check_circle_rounded, color: AppColors.success), SizedBox(width: 9), Expanded(child: Text('Your basic categories are represented. Next, build stronger outfit combinations from what you own.', style: TextStyle(color: AppColors.textSecondary, fontSize: 11.5, height: 1.4)))]));
    }
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: _box(),
      child: Wrap(spacing: 8, runSpacing: 8, children: missing.map((name) => Chip(label: Text(name), backgroundColor: AppColors.surfaceMuted, side: const BorderSide(color: AppColors.border))).toList()),
    );
  }

  Widget _capsuleCard(List<String> suggestions) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _box(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: suggestions.map((item) => Padding(padding: const EdgeInsets.only(bottom: 9), child: Row(children: [Container(width: 32, height: 32, decoration: const BoxDecoration(color: AppColors.lavenderMist, shape: BoxShape.circle), child: const Icon(Icons.checkroom_outlined, size: 17, color: AppColors.primary)), const SizedBox(width: 9), Expanded(child: Text(item, style: const TextStyle(fontSize: 11.5, height: 1.35)))]))).toList(),
      ),
    );
  }

  Widget _paletteCard(int matches, int paletteSize) {
    final ratio = paletteSize == 0 ? 0.0 : (matches / paletteSize).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _box(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [Expanded(child: Text(paletteSize == 0 ? 'Run Colour Analysis first' : '$matches of your palette shades are represented', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13))), Text('${(ratio * 100).round()}%', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800))]),
          const SizedBox(height: 9),
          ClipRRect(borderRadius: BorderRadius.circular(8), child: LinearProgressIndicator(value: ratio, minHeight: 9, backgroundColor: AppColors.surfaceMuted, valueColor: const AlwaysStoppedAnimation(AppColors.primary))),
          const SizedBox(height: 8),
          const Text('A healthy wardrobe does not need every colour. Prioritise versatile pieces inside your personal palette.', style: TextStyle(color: AppColors.textSecondary, fontSize: 11.5, height: 1.4)),
        ],
      ),
    );
  }

  List<String> _capsuleSuggestions(List<String> missing) {
    final result = <String>[];
    if (missing.contains('Tops')) result.add('1 versatile top in a signature palette neutral.');
    if (missing.contains('Bottoms')) result.add('1 tailored bottom that works with at least three existing tops.');
    if (missing.contains('Jacket / Blazer')) result.add('1 structured jacket or blazer for work, meetings and elevated casual outfits.');
    if (missing.contains('Shoes')) result.add('1 polished neutral shoe that bridges everyday and work looks.');
    if (missing.contains('Dress / One-piece')) result.add('1 versatile one-piece for quick, complete outfits.');
    if (result.isEmpty) {
      result.add('Build a 5–8 piece mini capsule around your most-worn neutrals and one signature accent.');
      result.add('Choose pieces that can create at least three different outfit combinations.');
      result.add('Keep one structured layer and one comfortable everyday option in rotation.');
    }
    return result;
  }

  Widget _sectionTitle(String title) => Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800));

  BoxDecoration _box() => BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.border));

  Widget _empty(String text) => Container(padding: const EdgeInsets.all(16), decoration: _box(), child: Text(text, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11.5, height: 1.4)));
}
