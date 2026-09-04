import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_gradients.dart';
import '../../core/constants/app_radius.dart';
import '../../models/wardrobe_item.dart';
import '../../providers/analysis_provider.dart';
import '../../services/firestore_service.dart';
import '../../services/image_picker_service.dart';
import '../../services/storage_service.dart';
import '../../widgets/colour_swatch.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/premium_badge.dart';
import '../../widgets/style_chip.dart';
import '../ai/ai_stylist_screen.dart';

class WardrobeScreen extends StatefulWidget {
  const WardrobeScreen({super.key});
  @override
  State<WardrobeScreen> createState() => _WardrobeScreenState();
}

class _WardrobeScreenState extends State<WardrobeScreen> with SingleTickerProviderStateMixin {
  static const _brown = AppColors.primary;
  static const _cream = AppColors.background;
  static const _soft = AppColors.secondary;
  static const _text = AppColors.textPrimary;
  static const _muted = AppColors.textSecondary;

  static const _categoryOptions = ['Tops','Bottoms','Dresses','Suits','Jackets','Skirts','Shoes','Accessories'];
  static const _colourOptions = ['Black','White','Beige','Brown','Pink','Red','Orange','Yellow','Green','Blue','Purple','Neutral'];
  static const _styleOptions = ['Everyday','Minimal','Elegant','Casual','Smart Casual','Feminine','Trendy'];
  static const _seasonOptions = ['All seasons','Spring','Summer','Autumn','Winter'];

  String _category = 'All';
  String _colour = 'All';
  String _sort = 'Recently added';
  String _searchQuery = '';
  bool _showFavouritesOnly = false;
  bool _isPremium = false;
  bool _premiumLoaded = false;
  bool _filtersExpanded = false;

  final TextEditingController _searchController = TextEditingController();
  late final AnimationController _revealController;
  late final Animation<double> _headerReveal;
  late final Animation<double> _summaryReveal;
  late final Animation<double> _browseReveal;

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    _revealController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _headerReveal = _stage(0, .4);
    _summaryReveal = _stage(.18, .68);
    _browseReveal = _stage(.38, 1);
    _revealController.forward();
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    if (!mounted) return;
    setState(() => _searchQuery = _searchController.text);
  }

  Animation<double> _stage(double begin, double end) => CurvedAnimation(parent: _revealController, curve: Interval(begin, end, curve: Curves.easeOut));

  Widget _reveal(Animation<double> animation, Widget child) => AnimatedBuilder(
        animation: animation,
        builder: (context, animatedChild) {
          final value = animation.value.clamp(0.0, 1.0);
          return Opacity(opacity: value, child: Transform.translate(offset: Offset(0, (1 - value) * 14), child: animatedChild));
        },
        child: child,
      );

  @override
  void dispose() {
    _searchController..removeListener(_onSearchChanged)..dispose();
    _revealController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final uid = _uid;
    if (uid != null && !_premiumLoaded) _loadPremiumStatus(uid);
    final analysisResult = context.watch<AnalysisProvider>().result;
    final wantedColours = (analysisResult?.colours ?? const <String>[]).map((colour) => colour.toLowerCase()).toList();

    return Scaffold(
      backgroundColor: _cream,
      appBar: AppBar(
        backgroundColor: _cream,
        elevation: 0,
        title: const Text('Wardrobe', style: TextStyle(color: _text, fontWeight: FontWeight.w800, fontSize: 18)),
        actions: [
          IconButton(tooltip: 'Favourites', onPressed: uid == null ? null : () => setState(() => _showFavouritesOnly = !_showFavouritesOnly), icon: Icon(_showFavouritesOnly ? Icons.favorite_rounded : Icons.favorite_border_rounded, color: _showFavouritesOnly ? AppColors.premiumAccent : _text)),
          IconButton(tooltip: 'Smart Wardrobe', onPressed: uid == null ? null : () => _showSmartWardrobe(uid), icon: Icon(_isPremium ? Icons.auto_awesome_rounded : Icons.lock_outline_rounded)),
          IconButton(tooltip: 'Add clothing', onPressed: uid == null ? null : () => _showAddItem(uid), icon: const Icon(Icons.add_rounded)),
        ],
      ),
      body: uid == null
          ? const Center(child: Text('Please login to use your wardrobe.'))
          : StreamBuilder<List<WardrobeItem>>(
              stream: FirestoreService.watchWardrobeItems(uid),
              builder: (context, snapshot) {
                if (snapshot.hasError) return const Center(child: Text('Could not load your wardrobe.'));
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                final items = snapshot.data ?? const <WardrobeItem>[];
                final query = _searchQuery.trim().toLowerCase();
                final filtered = items.where((item) {
                  final categoryMatches = _category == 'All' || item.category == _category;
                  final colourMatches = _colour == 'All' || item.colour == _colour;
                  final favouriteMatches = !_showFavouritesOnly || item.isFavourite;
                  final searchMatches = query.isEmpty || item.name.toLowerCase().contains(query) || item.category.toLowerCase().contains(query) || item.colour.toLowerCase().contains(query) || item.style.toLowerCase().contains(query);
                  return categoryMatches && colourMatches && favouriteMatches && searchMatches;
                }).toList();
                if (_sort == 'Name A–Z') filtered.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
                else if (_sort == 'Category') filtered.sort((a, b) => a.category.toLowerCase().compareTo(b.category.toLowerCase()));
                else if (_sort == 'Favourites first') filtered.sort((a, b) => (b.isFavourite ? 1 : 0).compareTo(a.isFavourite ? 1 : 0));
                final hasActiveFilters = _category != 'All' || _colour != 'All' || _showFavouritesOnly || query.isNotEmpty;
                return RefreshIndicator(
                  onRefresh: () async => setState(() {}),
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverToBoxAdapter(child: _reveal(_headerReveal, _buildHeader(uid, items.length))),
                      if (items.isNotEmpty) SliverToBoxAdapter(child: _reveal(_summaryReveal, _buildSummaryRow(items))),
                      if (_isPremium && items.isNotEmpty) SliverToBoxAdapter(child: _reveal(_summaryReveal, _buildPremiumInsightCard(items))),
                      SliverToBoxAdapter(child: _reveal(_browseReveal, Padding(padding: const EdgeInsets.fromLTRB(20, 14, 20, 0), child: _buildSearchAndFilterBar(hasActiveFilters)))),
                      if (hasActiveFilters) SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(20, 8, 20, 0), child: _buildActiveFilters(query, filtered.length, items.length))),
                      if (_filtersExpanded) SliverToBoxAdapter(child: _reveal(_browseReveal, _buildFilterPanel())),
                      if (filtered.isEmpty)
                        SliverFillRemaining(hasScrollBody: false, child: Padding(padding: const EdgeInsets.fromLTRB(24, 20, 24, 20), child: _buildEmptyState(hasAnyItems: items.isNotEmpty, uid: uid)))
                      else
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(18, 12, 18, 30),
                          sliver: SliverGrid(
                            delegate: SliverChildBuilderDelegate((context, index) => _buildItemCard(filtered[index], uid, index, wantedColours), childCount: filtered.length),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 14, childAspectRatio: .70),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
      floatingActionButton: uid == null ? null : FloatingActionButton.extended(onPressed: () => _showAddItem(uid), backgroundColor: _brown, foregroundColor: _cream, icon: const Icon(Icons.add_rounded), label: const Text('Add Item')),
    );
  }

  Widget _buildSearchAndFilterBar(bool hasActiveFilters) {
    return Row(
      children: [
        Expanded(child: _buildSearchBar()),
        const SizedBox(width: 10),
        Material(
          color: _filtersExpanded || hasActiveFilters ? AppColors.primarySoft : AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.full),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.full),
            onTap: () => setState(() => _filtersExpanded = !_filtersExpanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
              child: Row(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.tune_rounded, size: 18, color: _brown), const SizedBox(width: 6), const Text('Filter', style: TextStyle(color: _brown, fontSize: 12, fontWeight: FontWeight.w800)), const SizedBox(width: 3), Icon(_filtersExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded, size: 18, color: _brown)]),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterPanel() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 4),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.border)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('FILTER YOUR WARDROBE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1, color: _brown)),
          const SizedBox(height: 12),
          const Text('SORT BY', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: _muted, letterSpacing: .8)),
          const SizedBox(height: 8),
          Wrap(spacing: 7, runSpacing: 7, children: ['Recently added', 'Name A–Z', 'Category', 'Favourites first'].map((value) => StyleChip(label: value, icon: Icons.sort_rounded, selected: _sort == value, onTap: () => setState(() => _sort = value))).toList()),
          const SizedBox(height: 14),
          const Text('CATEGORY', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: _muted, letterSpacing: .8)),
          const SizedBox(height: 8),
          Wrap(spacing: 7, runSpacing: 7, children: ['All', ..._categoryOptions].map((value) => StyleChip(label: value, icon: value == 'All' ? Icons.grid_view_rounded : _categoryIcon(value), selected: _category == value, onTap: () => setState(() => _category = value))).toList()),
          const SizedBox(height: 14),
          const Text('COLOUR', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: _muted, letterSpacing: .8)),
          const SizedBox(height: 8),
          Wrap(spacing: 7, runSpacing: 7, children: ['All', ..._colourOptions].map((value) => StyleChip(label: value, icon: Icons.palette_outlined, selected: _colour == value, onTap: () => setState(() => _colour = value))).toList()),
          const SizedBox(height: 14),
          Row(children: [Expanded(child: OutlinedButton.icon(onPressed: _clearFilters, icon: const Icon(Icons.clear_rounded, size: 17), label: const Text('Clear'))), const SizedBox(width: 9), Expanded(child: FilledButton.icon(onPressed: () => setState(() => _filtersExpanded = false), icon: const Icon(Icons.check_rounded, size: 17), label: const Text('Done'), style: FilledButton.styleFrom(backgroundColor: _brown)))])
        ]),
      ),
    );
  }

  Widget _buildActiveFilters(String query, int filteredCount, int totalCount) {
    final chips = <Widget>[];
    if (_category != 'All') chips.add(_buildActiveFilterChip(label: _category, onRemove: () => setState(() => _category = 'All')));
    if (_colour != 'All') chips.add(_buildActiveFilterChip(label: _colour, onRemove: () => setState(() => _colour = 'All')));
    if (_showFavouritesOnly) chips.add(_buildActiveFilterChip(label: 'Favourites', icon: Icons.favorite_rounded, onRemove: () => setState(() => _showFavouritesOnly = false)));
    if (query.isNotEmpty) chips.add(_buildActiveFilterChip(label: 'Search: ${_searchQuery.trim()}', onRemove: _searchController.clear));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [const Text('Active filters', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: _muted)), const Spacer(), TextButton(onPressed: _clearFilters, style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 28), tapTargetSize: MaterialTapTargetSize.shrinkWrap), child: const Text('Clear all', style: TextStyle(fontSize: 11)))]),
      Wrap(spacing: 6, runSpacing: 6, children: chips),
      const SizedBox(height: 6),
      Text('Showing $filteredCount of $totalCount', style: const TextStyle(color: _muted, fontSize: 12)),
    ]);
  }

  Widget _buildActiveFilterChip({required String label, required VoidCallback onRemove, IconData? icon}) {
    return Container(
      decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: .08), borderRadius: BorderRadius.circular(99), border: Border.all(color: AppColors.primary.withValues(alpha: .16))),
      child: InkWell(
        borderRadius: BorderRadius.circular(99), onTap: onRemove,
        child: Padding(padding: const EdgeInsets.fromLTRB(10, 6, 7, 6), child: Row(mainAxisSize: MainAxisSize.min, children: [if (icon != null) ...[Icon(icon, size: 12, color: AppColors.primary), const SizedBox(width: 4)], ConstrainedBox(constraints: const BoxConstraints(maxWidth: 150), child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.primary))), const SizedBox(width: 4), const Icon(Icons.close_rounded, size: 13, color: AppColors.primary)])),
      ),
    );
  }

  void _clearFilters() {
    setState(() { _category = 'All'; _colour = 'All'; _sort = 'Recently added'; _showFavouritesOnly = false; _searchController.clear(); _filtersExpanded = false; });
  }

  Future<void> _loadPremiumStatus(String uid) async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (!mounted || _uid != uid) return;
      setState(() { _isPremium = snapshot.data()?['isPremium'] == true; _premiumLoaded = true; });
    } catch (_) {
      if (!mounted || _uid != uid) return;
      setState(() { _isPremium = false; _premiumLoaded = true; });
    }
  }

  Future<void> _openPremiumAccess(BuildContext context) async {
    await showDialog<void>(context: context, builder: (dialogContext) => AlertDialog(title: const Row(children: [Icon(Icons.workspace_premium_outlined, color: _brown), SizedBox(width: 8), Text('Premium Feature')]), content: const Text('Smart Wardrobe is a Premium feature. Premium access is managed by your administrator.'), actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Close'))]));
  }

  void _showSmartWardrobe(String uid) {
    if (!_isPremium) { _openPremiumAccess(context); return; }
    showModalBottomSheet<void>(context: context, showDragHandle: true, backgroundColor: _cream, builder: (sheetContext) => SafeArea(child: Padding(padding: const EdgeInsets.fromLTRB(20, 8, 20, 25), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Row(children: [PremiumBadge(compact: true), SizedBox(width: 10), Text('Smart Wardrobe', style: TextStyle(color: _text, fontSize: 21, fontWeight: FontWeight.w700))]),
      const SizedBox(height: 8),
      const Text('Premium tools help you understand what is already in your wardrobe and turn it into more useful outfit ideas.', style: TextStyle(color: _muted, height: 1.45)),
      const SizedBox(height: 18),
      _premiumInsightListTile(Icons.category_outlined, 'Wardrobe overview', 'See your collection by category, favourites and colour.'),
      _premiumInsightListTile(Icons.palette_outlined, 'Colour insights', 'Find the colours you have saved most often.'),
      _premiumInsightListTile(Icons.auto_awesome_outlined, 'AI outfit matching', 'Use your wardrobe with the Premium AI Stylist.'),
      const SizedBox(height: 12),
      SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: () { Navigator.pop(sheetContext); Navigator.push(context, MaterialPageRoute(builder: (_) => const AIStylistScreen())); }, icon: const Icon(Icons.auto_awesome), label: const Text('Open AI Stylist'), style: FilledButton.styleFrom(backgroundColor: _brown, minimumSize: const Size.fromHeight(52))))
    ]))));
  }

  Widget _premiumInsightListTile(IconData icon, String title, String subtitle) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(15), border: Border.all(color: AppColors.border)),
          child: Row(children: [Container(width: 38, height: 38, decoration: const BoxDecoration(color: _soft, shape: BoxShape.circle), child: Icon(icon, size: 19, color: _brown)), const SizedBox(width: 11), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(color: _text, fontWeight: FontWeight.w700)), const SizedBox(height: 2), Text(subtitle, style: const TextStyle(color: _muted, fontSize: 12, height: 1.35))]))]),
        ),
      );

  Widget _buildPremiumInsightCard(List<WardrobeItem> items) {
    final categoryCounts = <String, int>{};
    final colourCounts = <String, int>{};
    for (final item in items) {
      categoryCounts[item.category] = (categoryCounts[item.category] ?? 0) + 1;
      colourCounts[item.colour] = (colourCounts[item.colour] ?? 0) + 1;
    }
    String mostCommon(Map<String, int> values) {
      if (values.isEmpty) return '—';
      var bestKey = values.keys.first;
      var bestValue = values[bestKey] ?? 0;
      for (final entry in values.entries) {
        if (entry.value > bestValue) { bestKey = entry.key; bestValue = entry.value; }
      }
      return bestKey;
    }
    final favouriteCount = items.where((item) => item.isFavourite).length;
    return Padding(padding: const EdgeInsets.fromLTRB(18, 2, 18, 12), child: Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(gradient: AppGradients.premium, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.border)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Row(children: [PremiumBadge(compact: true), SizedBox(width: 8), Text('Wardrobe Insights', style: TextStyle(color: _text, fontWeight: FontWeight.w700))]), const SizedBox(height: 12), Row(children: [Expanded(child: _insightStat('Pieces', '${items.length}')), const SizedBox(width: 8), Expanded(child: _insightStat('Favourites', '$favouriteCount')), const SizedBox(width: 8), Expanded(child: _insightStat('Top colour', mostCommon(colourCounts)))]), const SizedBox(height: 9), Text('Most saved category: ${mostCommon(categoryCounts)}', style: const TextStyle(color: AppColors.premiumAccentDark, fontSize: 12, fontWeight: FontWeight.w600))])));
  }

  Widget _insightStat(String label, String value) => Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10), decoration: BoxDecoration(color: AppColors.background.withValues(alpha: .75), borderRadius: BorderRadius.circular(13)), child: Column(children: [Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _brown, fontSize: 14, fontWeight: FontWeight.w800)), const SizedBox(height: 2), Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _muted, fontSize: 10))]));

  String _headlineFor(int count) => count == 0 ? 'Your closet is empty' : count == 1 ? '1 piece' : '$count pieces';

  Widget _buildHeader(String uid, int totalCount) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 2),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('MY WARDROBE', style: TextStyle(color: _brown, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1.2)), const SizedBox(height: 6), Text(_headlineFor(totalCount), style: const TextStyle(color: _text, fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -.4)), const SizedBox(height: 4), const Text('Pieces you love, ready to style.', style: TextStyle(color: _muted, fontSize: 13, height: 1.4))])), const SizedBox(width: 10), TextButton.icon(onPressed: () => _showAddItem(uid), icon: const Icon(Icons.add_rounded, size: 18), label: const Text('Add'), style: TextButton.styleFrom(foregroundColor: _brown, backgroundColor: _soft, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.full)), padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10)))]),
      );

  Widget _buildSummaryRow(List<WardrobeItem> items) {
    final counts = <String, int>{};
    for (final category in _categoryOptions) {
      final count = items.where((item) => item.category == category).length;
      if (count > 0) counts[category] = count;
    }
    if (counts.isEmpty) return const SizedBox.shrink();
    return Padding(padding: const EdgeInsets.fromLTRB(20, 14, 20, 0), child: Wrap(spacing: 8, runSpacing: 8, children: counts.entries.map((entry) => Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.full), border: Border.all(color: AppColors.border)), child: Row(mainAxisSize: MainAxisSize.min, children: [Text('${entry.value}', style: const TextStyle(color: _brown, fontWeight: FontWeight.w800, fontSize: 13)), const SizedBox(width: 5), Text(entry.key, style: const TextStyle(color: _muted, fontSize: 12, fontWeight: FontWeight.w600))]))).toList()));
  }

  Widget _buildSearchBar() => Container(
        decoration: BoxDecoration(color: AppColors.surfaceMuted, borderRadius: BorderRadius.circular(AppRadius.full), border: Border.all(color: AppColors.border)),
        child: TextField(controller: _searchController, style: const TextStyle(color: _text, fontSize: 14), decoration: InputDecoration(hintText: 'Search your wardrobe...', hintStyle: const TextStyle(color: _muted, fontSize: 14), prefixIcon: const Icon(Icons.search_rounded, color: _muted), suffixIcon: _searchQuery.isEmpty ? null : IconButton(tooltip: 'Clear search', icon: const Icon(Icons.close_rounded, color: _muted), onPressed: _searchController.clear), border: InputBorder.none, isDense: true, contentPadding: const EdgeInsets.symmetric(vertical: 14))),
      );

  IconData _categoryIcon(String category) {
    switch (category) {
      case 'Bottoms':
      case 'Skirts': return Icons.layers_outlined;
      case 'Shoes': return Icons.directions_walk_outlined;
      case 'Accessories': return Icons.diamond_outlined;
      case 'Suits': return Icons.business_center_outlined;
      case 'Jackets': return Icons.checkroom_outlined;
      default: return Icons.checkroom_outlined;
    }
  }

  Widget _buildEmptyState({required bool hasAnyItems, required String uid}) {
    if (!hasAnyItems) return EmptyState(icon: Icons.checkroom_outlined, title: 'Your Closet Starts Here', description: 'Add a few pieces you already love and your AI stylist can start creating looks from them.', ctaLabel: 'Add your first piece', onCta: () => _showAddItem(uid));
    return EmptyState(icon: Icons.search_off_rounded, title: 'No pieces match', description: 'Try a different category, search term or turn off the favourites filter.', ctaLabel: 'Clear filters', onCta: _clearFilters);
  }

  bool _matchesPalette(WardrobeItem item, List<String> wantedColours) {
    if (wantedColours.isEmpty) return false;
    final itemColour = item.colour.toLowerCase();
    return wantedColours.any((colour) => colour.contains(itemColour) || itemColour.contains(colour));
  }

  Widget _buildItemCard(WardrobeItem item, String uid, int index, List<String> wantedColours) {
    final matchesPalette = _matchesPalette(item, wantedColours);
    return TweenAnimationBuilder<double>(
      key: ValueKey(item.id), tween: Tween(begin: 0, end: 1), duration: Duration(milliseconds: 320 + (index % 6) * 45), curve: Curves.easeOut,
      builder: (context, value, child) => Opacity(opacity: value, child: Transform.translate(offset: Offset(0, (1 - value) * 10), child: child)),
      child: Material(
        color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.lg), clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _showItemDetails(item, uid),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: Stack(children: [
              Positioned.fill(child: item.imageUrl.isEmpty ? Container(color: _soft, child: Icon(_categoryIcon(item.category), size: 38, color: _brown)) : CachedNetworkImage(imageUrl: item.imageUrl, fit: BoxFit.cover, placeholder: (context, url) => Container(color: _soft, child: const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))), errorWidget: (context, url, error) => Container(color: _soft, child: Icon(_categoryIcon(item.category), color: _brown)))),
              Positioned(top: 8, right: 8, child: Material(color: AppColors.background.withValues(alpha: .92), shape: const CircleBorder(), child: IconButton(padding: EdgeInsets.zero, constraints: const BoxConstraints.tightFor(width: 36, height: 36), onPressed: () => _toggleFavourite(item, uid), icon: AnimatedScale(scale: item.isFavourite ? 1.12 : 1, duration: const Duration(milliseconds: 160), child: Icon(item.isFavourite ? Icons.favorite : Icons.favorite_border, color: item.isFavourite ? AppColors.premiumAccent : _brown, size: 19))))),
              if (matchesPalette) Positioned(left: 8, bottom: 8, child: Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4), decoration: BoxDecoration(color: AppColors.background.withValues(alpha: .94), borderRadius: BorderRadius.circular(AppRadius.full)), child: const Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.check_circle_rounded, size: 11, color: AppColors.success), SizedBox(width: 3), Text('Match', style: TextStyle(color: AppColors.success, fontSize: 9.5, fontWeight: FontWeight.w800))]))),
            ])),
            Padding(padding: const EdgeInsets.fromLTRB(12, 9, 12, 11), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _text, fontWeight: FontWeight.w700, fontSize: 13.5)), const SizedBox(height: 4), Row(children: [Container(width: 9, height: 9, decoration: BoxDecoration(color: ColourNameMapper.colourFor(item.colour), shape: BoxShape.circle)), const SizedBox(width: 5), Expanded(child: Text('${item.category} · ${item.colour}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _muted, fontSize: 11.5)))])])),
          ]),
        ),
      ),
    );
  }

  Widget _photoSourceTile({required IconData icon, required String label, required VoidCallback onTap}) => Material(color: AppColors.surfaceMuted, borderRadius: BorderRadius.circular(AppRadius.lg), child: InkWell(borderRadius: BorderRadius.circular(AppRadius.lg), onTap: onTap, child: Container(height: 110, decoration: BoxDecoration(borderRadius: BorderRadius.circular(AppRadius.lg), border: Border.all(color: AppColors.border)), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon, size: 30, color: _brown), const SizedBox(height: 8), Text(label, style: const TextStyle(color: _text, fontWeight: FontWeight.w700))]))));

  Future<void> _showAddItem(String uid) async {
    final image = await showModalBottomSheet<File?>(context: context, showDragHandle: true, backgroundColor: _cream, builder: (context) => SafeArea(child: Padding(padding: const EdgeInsets.fromLTRB(20, 8, 20, 25), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Add to Your Wardrobe', style: TextStyle(color: _text, fontSize: 21, fontWeight: FontWeight.w700)), const SizedBox(height: 8), const Text('A clear photo works best. You can add the details after choosing it.', style: TextStyle(color: _muted, height: 1.4)), const SizedBox(height: 20), Row(children: [Expanded(child: _photoSourceTile(icon: Icons.camera_alt_outlined, label: 'Camera', onTap: () async { final image = await ImagePickerService.pickCamera(); if (!context.mounted) return; Navigator.pop(context, image); })), const SizedBox(width: 12), Expanded(child: _photoSourceTile(icon: Icons.photo_outlined, label: 'Gallery', onTap: () async { final image = await ImagePickerService.pickGallery(); if (!context.mounted) return; Navigator.pop(context, image); }))])])));
    if (image == null || !mounted) return;
    await _showItemForm(uid, image);
  }

  Future<void> _showItemForm(String uid, File image) async {
    final nameController = TextEditingController();
    final notesController = TextEditingController();
    var category = _categoryOptions.first;
    var colour = 'Neutral';
    var style = _styleOptions.first;
    var season = _seasonOptions.first;
    var saving = false;

    await showModalBottomSheet<void>(
      context: context, isScrollControlled: true, showDragHandle: true, backgroundColor: _cream,
      builder: (sheetContext) => StatefulBuilder(builder: (context, setSheetState) {
        Future<void> save() async {
          if (nameController.text.trim().isEmpty || saving) return;
          setSheetState(() => saving = true);
          try {
            final imageUrl = await StorageService.uploadWardrobeImage(uid: uid, image: image);
            await FirestoreService.addWardrobeItem(WardrobeItem(id: '', userId: uid, imageUrl: imageUrl, name: nameController.text.trim(), category: category, colour: colour, style: style, season: season, isFavourite: false, notes: notesController.text.trim(), createdAt: null));
            if (sheetContext.mounted) Navigator.pop(sheetContext);
          } catch (_) {
            if (sheetContext.mounted) ScaffoldMessenger.of(sheetContext).showSnackBar(const SnackBar(content: Text('Could not save this piece. Please try again.')));
          } finally {
            if (sheetContext.mounted) setSheetState(() => saving = false);
          }
        }
        return SafeArea(child: Padding(padding: EdgeInsets.only(left: 20, right: 20, bottom: MediaQuery.viewInsetsOf(context).bottom + 20), child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Tell me a little about it', style: TextStyle(color: _text, fontSize: 21, fontWeight: FontWeight.w700)), const SizedBox(height: 15), ClipRRect(borderRadius: BorderRadius.circular(AppRadius.lg), child: Image.file(image, height: 190, width: double.infinity, fit: BoxFit.cover)), const SizedBox(height: 15), TextField(controller: nameController, decoration: _fieldDecoration('Name', hint: 'e.g. Cream knit cardigan')), const SizedBox(height: 12), _dropdown('Category', category, _categoryOptions, (value) => setSheetState(() => category = value)), _dropdown('Colour', colour, _colourOptions, (value) => setSheetState(() => colour = value)), _dropdown('Style', style, _styleOptions, (value) => setSheetState(() => style = value)), _dropdown('Season', season, _seasonOptions, (value) => setSheetState(() => season = value)), const SizedBox(height: 4), TextField(controller: notesController, maxLines: 2, decoration: _fieldDecoration('Notes (optional)')), const SizedBox(height: 16), SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: saving ? null : save, icon: saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.background)) : const Icon(Icons.check_rounded), label: Text(saving ? 'Saving...' : 'Save to My Wardrobe'), style: FilledButton.styleFrom(backgroundColor: _brown, minimumSize: const Size.fromHeight(52))))]))));
      }),
    );
    nameController.dispose();
    notesController.dispose();
  }

  InputDecoration _fieldDecoration(String label, {String? hint}) => InputDecoration(labelText: label, hintText: hint, filled: true, fillColor: AppColors.surface, border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: AppColors.border)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: AppColors.border)));

  Widget _dropdown(String label, String value, List<String> values, ValueChanged<String> onChanged) => Padding(padding: const EdgeInsets.only(bottom: 12), child: DropdownButtonFormField<String>(initialValue: value, decoration: _fieldDecoration(label), items: values.map((value) => DropdownMenuItem<String>(value: value, child: Text(value))).toList(), onChanged: (value) { if (value != null) onChanged(value); }));

  Future<void> _toggleFavourite(WardrobeItem item, String uid) async {
    try { await FirestoreService.updateWardrobeItem(uid, item.id, {'isFavourite': !item.isFavourite}); }
    catch (_) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not update favourite. Please try again.'))); }
  }

  Widget _detailRow(String label, String value) => Padding(padding: const EdgeInsets.only(bottom: 10), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [SizedBox(width: 90, child: Text(label, style: const TextStyle(color: _muted, fontSize: 12, fontWeight: FontWeight.w600))), Expanded(child: Text(value, style: const TextStyle(color: _text, fontWeight: FontWeight.w600)))]));

  Future<void> _confirmDelete(WardrobeItem item, String uid) async {
    final confirmed = await showDialog<bool>(context: context, builder: (dialogContext) => AlertDialog(title: const Text('Remove this piece?'), content: Text('“${item.name}” will be removed from your wardrobe.'), actions: [TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Keep it')), FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Remove'))]));
    if (confirmed != true) return;
    try { await FirestoreService.deleteWardrobeItem(uid, item.id); if (mounted) Navigator.pop(context); }
    catch (_) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not remove this piece. Please try again.'))); }
  }

  void _showItemDetails(WardrobeItem item, String uid) {
    final analysisResult = context.read<AnalysisProvider>().result;
    final wantedColours = (analysisResult?.colours ?? const <String>[]).map((colour) => colour.toLowerCase()).toList();
    final matchesPalette = _matchesPalette(item, wantedColours);
    showModalBottomSheet<void>(context: context, showDragHandle: true, isScrollControlled: true, backgroundColor: _cream, builder: (context) => SafeArea(child: Padding(padding: const EdgeInsets.fromLTRB(20, 5, 20, 25), child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      ClipRRect(borderRadius: BorderRadius.circular(AppRadius.lg), child: AspectRatio(aspectRatio: 4 / 3, child: item.imageUrl.isEmpty ? Container(color: _soft, child: Icon(_categoryIcon(item.category), size: 46, color: _brown)) : CachedNetworkImage(imageUrl: item.imageUrl, fit: BoxFit.cover))), const SizedBox(height: 16),
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: Text(item.name, style: const TextStyle(color: _text, fontSize: 21, fontWeight: FontWeight.w700))), Material(color: _soft, shape: const CircleBorder(), child: IconButton(tooltip: item.isFavourite ? 'Remove from favourites' : 'Save as favourite', onPressed: () => _toggleFavourite(item, uid), icon: Icon(item.isFavourite ? Icons.favorite : Icons.favorite_border, color: item.isFavourite ? AppColors.premiumAccent : _brown)))]),
      if (matchesPalette) ...[const SizedBox(height: 4), const Row(children: [Icon(Icons.check_circle_rounded, size: 14, color: AppColors.success), SizedBox(width: 5), Text('Matches your colour palette', style: TextStyle(color: AppColors.success, fontSize: 12, fontWeight: FontWeight.w700))])],
      const SizedBox(height: 16), const Text('DETAILS', style: TextStyle(color: _muted, fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: .6)), const SizedBox(height: 10),
      _detailRow('Colour', item.colour), _detailRow('Category', item.category), _detailRow('Style', item.style), if (item.season.isNotEmpty && item.season != 'All seasons') _detailRow('Season', item.season),
      if (item.notes.isNotEmpty) ...[const SizedBox(height: 4), const Text('NOTES', style: TextStyle(color: _muted, fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: .6)), const SizedBox(height: 6), Text(item.notes, style: const TextStyle(color: _text, height: 1.4))], const SizedBox(height: 20),
      Row(children: [Expanded(child: OutlinedButton.icon(onPressed: () { Navigator.pop(context); _showEditItem(item, uid); }, icon: const Icon(Icons.edit_outlined), label: const Text('Edit'))), const SizedBox(width: 10), Expanded(child: FilledButton.icon(onPressed: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => AIStylistScreen(selectedItem: item))); }, icon: const Icon(Icons.auto_awesome_rounded), label: const Text('Style this'), style: FilledButton.styleFrom(backgroundColor: _brown)))]), const SizedBox(height: 10), SizedBox(width: double.infinity, child: TextButton.icon(onPressed: () => _confirmDelete(item, uid), icon: const Icon(Icons.delete_outline), label: const Text('Delete'), style: TextButton.styleFrom(foregroundColor: AppColors.error))),
    ]))));
  }

  Future<void> _showEditItem(WardrobeItem item, String uid) async {
    final nameController = TextEditingController(text: item.name);
    final notesController = TextEditingController(text: item.notes);
    var category = _categoryOptions.contains(item.category) ? item.category : _categoryOptions.first;
    var colour = _colourOptions.contains(item.colour) ? item.colour : _colourOptions.last;
    var style = _styleOptions.contains(item.style) ? item.style : _styleOptions.first;
    var season = _seasonOptions.contains(item.season) ? item.season : _seasonOptions.first;
    var saving = false;
    File? newImage;

    await showModalBottomSheet<void>(
      context: context, isScrollControlled: true, showDragHandle: true, backgroundColor: _cream,
      builder: (sheetContext) => StatefulBuilder(builder: (context, setSheetState) {
        Future<void> pickNewPhoto() async {
          final picked = await showModalBottomSheet<File?>(context: context, showDragHandle: true, backgroundColor: _cream, builder: (pickContext) => SafeArea(child: Padding(padding: const EdgeInsets.fromLTRB(20, 8, 20, 25), child: Row(children: [
            Expanded(child: _photoSourceTile(icon: Icons.camera_alt_outlined, label: 'Camera', onTap: () async { final image = await ImagePickerService.pickCamera(); if (!pickContext.mounted) return; Navigator.pop(pickContext, image); })), const SizedBox(width: 12), Expanded(child: _photoSourceTile(icon: Icons.photo_outlined, label: 'Gallery', onTap: () async { final image = await ImagePickerService.pickGallery(); if (!pickContext.mounted) return; Navigator.pop(pickContext, image); }))])));
          if (picked != null) setSheetState(() => newImage = picked);
        }
        Future<void> save() async {
          if (nameController.text.trim().isEmpty || saving) return;
          setSheetState(() => saving = true);
          try {
            var imageUrl = item.imageUrl;
            if (newImage != null) imageUrl = await StorageService.uploadWardrobeImage(uid: uid, image: newImage!);
            await FirestoreService.updateWardrobeItem(uid, item.id, {'imageUrl': imageUrl, 'name': nameController.text.trim(), 'category': category, 'colour': colour, 'style': style, 'season': season, 'notes': notesController.text.trim()});
            if (sheetContext.mounted) Navigator.pop(sheetContext);
          } catch (_) {
            if (sheetContext.mounted) ScaffoldMessenger.of(sheetContext).showSnackBar(const SnackBar(content: Text('Could not save your changes. Please try again.')));
          } finally {
            if (sheetContext.mounted) setSheetState(() => saving = false);
          }
        }
        return SafeArea(child: Padding(padding: EdgeInsets.only(left: 20, right: 20, bottom: MediaQuery.viewInsetsOf(context).bottom + 20), child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Edit this piece', style: TextStyle(color: _text, fontSize: 21, fontWeight: FontWeight.w700)), const SizedBox(height: 15), GestureDetector(onTap: pickNewPhoto, child: Stack(children: [ClipRRect(borderRadius: BorderRadius.circular(AppRadius.lg), child: SizedBox(height: 190, width: double.infinity, child: newImage != null ? Image.file(newImage!, fit: BoxFit.cover) : item.imageUrl.isEmpty ? Container(color: _soft, child: Icon(_categoryIcon(item.category), size: 40, color: _brown)) : CachedNetworkImage(imageUrl: item.imageUrl, fit: BoxFit.cover))), Positioned(right: 10, bottom: 10, child: Material(color: AppColors.background.withValues(alpha: .92), shape: const CircleBorder(), child: const Padding(padding: EdgeInsets.all(8), child: Icon(Icons.edit_outlined, size: 18, color: _brown))))])), const SizedBox(height: 15),
          TextField(controller: nameController, decoration: _fieldDecoration('Name')), const SizedBox(height: 12), _dropdown('Category', category, _categoryOptions, (value) => setSheetState(() => category = value)), _dropdown('Colour', colour, _colourOptions, (value) => setSheetState(() => colour = value)), _dropdown('Style', style, _styleOptions, (value) => setSheetState(() => style = value)), _dropdown('Season', season, _seasonOptions, (value) => setSheetState(() => season = value)), const SizedBox(height: 4), TextField(controller: notesController, maxLines: 2, decoration: _fieldDecoration('Notes (optional)')), const SizedBox(height: 16), SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: saving ? null : save, icon: saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.background)) : const Icon(Icons.check_rounded), label: Text(saving ? 'Saving...' : 'Save changes'), style: FilledButton.styleFrom(backgroundColor: _brown, minimumSize: const Size.fromHeight(52))))
        ]))));
      }),
    );
    nameController.dispose();
    notesController.dispose();
  }
}
