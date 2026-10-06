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
import '../../services/wardrobe_image_validation_service.dart';
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

class _WardrobeScreenState extends State<WardrobeScreen>
    with SingleTickerProviderStateMixin {
  static const _brown = AppColors.primary;
  static const _cream = AppColors.background;
  static const _soft = AppColors.secondary;
  static const _text = AppColors.textPrimary;
  static const _muted = AppColors.textSecondary;

  static const _categoryOptions =
      WardrobeImageValidationService.allowedCategories;
  static const _colourOptions = [
    'Black',
    'White',
    'Beige',
    'Brown',
    'Pink',
    'Red',
    'Orange',
    'Yellow',
    'Green',
    'Blue',
    'Purple',
    'Neutral',
  ];
  static const _styleOptions = [
    'Everyday',
    'Minimal',
    'Elegant',
    'Casual',
    'Smart Casual',
    'Feminine',
    'Trendy',
  ];
  static const _seasonOptions = [
    'All seasons',
    'Spring',
    'Summer',
    'Autumn',
    'Winter',
  ];

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
    _revealController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _headerReveal = _stage(0, .4);
    _summaryReveal = _stage(.18, .68);
    _browseReveal = _stage(.38, 1);
    _revealController.forward();
  }

  Animation<double> _stage(double begin, double end) => CurvedAnimation(
    parent: _revealController,
    curve: Interval(begin, end, curve: Curves.easeOut),
  );

  Widget _reveal(Animation<double> animation, Widget child) => AnimatedBuilder(
    animation: animation,
    builder: (context, animatedChild) {
      final value = animation.value.clamp(0.0, 1.0);
      return Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, (1 - value) * 14),
          child: animatedChild,
        ),
      );
    },
    child: child,
  );

  @override
  void dispose() {
    _searchController.dispose();
    _revealController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final uid = _uid;
    if (uid != null && !_premiumLoaded) {
      _loadPremiumStatus(uid);
    }
    final analysisResult = context.watch<AnalysisProvider>().result;
    final wantedColours = (analysisResult?.colours ?? const <String>[])
        .map((colour) => colour.toLowerCase())
        .toList();

    return Scaffold(
      backgroundColor: _cream,
      appBar: AppBar(
        backgroundColor: _cream,
        elevation: 0,
        title: const Text(
          'Wardrobe',
          style: TextStyle(
            color: _text,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Favourites',
            onPressed: uid == null
                ? null
                : () => setState(
                    () => _showFavouritesOnly = !_showFavouritesOnly,
                  ),
            icon: Icon(
              _showFavouritesOnly
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
              color: _showFavouritesOnly ? AppColors.premiumAccent : _text,
            ),
          ),
          IconButton(
            tooltip: 'Smart Wardrobe',
            onPressed: uid == null ? null : () => _showSmartWardrobe(uid),
            icon: Icon(
              _isPremium
                  ? Icons.auto_awesome_rounded
                  : Icons.lock_outline_rounded,
            ),
          ),
          IconButton(
            tooltip: 'Add clothing',
            onPressed: uid == null ? null : () => _showAddItem(uid),
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
      body: uid == null
          ? const Center(child: Text('Please login to use your wardrobe.'))
          : StreamBuilder<List<WardrobeItem>>(
              key: ValueKey(uid),
              stream: FirestoreService.watchWardrobeItems(uid),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(
                    child: Text('Could not load your wardrobe.'),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final items = snapshot.data ?? const <WardrobeItem>[];
                final query = _searchQuery.trim().toLowerCase();
                final filtered = items.where((item) {
                  final categoryMatches =
                      _category == 'All' || item.category == _category;
                  final colourMatches =
                      _colour == 'All' || item.colour == _colour;
                  final favouriteMatches =
                      !_showFavouritesOnly || item.isFavourite;
                  final searchMatches =
                      query.isEmpty ||
                      item.name.toLowerCase().contains(query) ||
                      item.category.toLowerCase().contains(query) ||
                      item.colour.toLowerCase().contains(query) ||
                      item.style.toLowerCase().contains(query) ||
                      item.season.toLowerCase().contains(query);
                  return categoryMatches &&
                      colourMatches &&
                      favouriteMatches &&
                      searchMatches;
                }).toList();

                if (_sort == 'Name A–Z') {
                  filtered.sort(
                    (a, b) =>
                        a.name.toLowerCase().compareTo(b.name.toLowerCase()),
                  );
                } else if (_sort == 'Category') {
                  filtered.sort(
                    (a, b) => a.category.toLowerCase().compareTo(
                      b.category.toLowerCase(),
                    ),
                  );
                } else if (_sort == 'Favourites first') {
                  filtered.sort(
                    (a, b) => (b.isFavourite ? 1 : 0).compareTo(
                      a.isFavourite ? 1 : 0,
                    ),
                  );
                }

                final hasActiveFilters =
                    _category != 'All' ||
                    _colour != 'All' ||
                    _showFavouritesOnly ||
                    query.isNotEmpty;
                final paletteCount = items
                    .where((item) => _matchesPalette(item, wantedColours))
                    .length;

                return RefreshIndicator(
                  onRefresh: () async => setState(() {}),
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverToBoxAdapter(
                        child: _reveal(
                          _headerReveal,
                          _buildHeader(uid, items.length),
                        ),
                      ),
                      if (items.isNotEmpty)
                        SliverToBoxAdapter(
                          child: _reveal(
                            _summaryReveal,
                            _buildSummaryRow(items),
                          ),
                        ),
                      if (_isPremium && items.isNotEmpty)
                        SliverToBoxAdapter(
                          child: _reveal(
                            _summaryReveal,
                            _buildPremiumInsightCard(
                              items,
                              paletteCount,
                              wantedColours,
                            ),
                          ),
                        ),
                      SliverToBoxAdapter(
                        child: _reveal(
                          _browseReveal,
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                            child: _buildSearchAndFilterBar(hasActiveFilters),
                          ),
                        ),
                      ),
                      if (hasActiveFilters)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                            child: _buildActiveFilters(
                              query,
                              filtered.length,
                              items.length,
                            ),
                          ),
                        ),
                      if (_filtersExpanded)
                        SliverToBoxAdapter(
                          child: _reveal(_browseReveal, _buildFilterPanel()),
                        ),
                      if (filtered.isEmpty)
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
                            child: _buildEmptyState(
                              hasAnyItems: items.isNotEmpty,
                              uid: uid,
                            ),
                          ),
                        )
                      else
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(18, 12, 18, 30),
                          sliver: SliverGrid(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) => _buildItemCard(
                                filtered[index],
                                uid,
                                index,
                                wantedColours,
                              ),
                              childCount: filtered.length,
                            ),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 14,
                                  childAspectRatio: .70,
                                ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
      floatingActionButton: uid == null
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _showAddItem(uid),
              backgroundColor: _brown,
              foregroundColor: _cream,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add Item'),
            ),
    );
  }

  Widget _buildSearchAndFilterBar(bool hasActiveFilters) {
    return Row(
      children: [
        Expanded(child: _buildSearchBar()),
        const SizedBox(width: 10),
        Material(
          color: _filtersExpanded || hasActiveFilters
              ? AppColors.primarySoft
              : AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.full),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.full),
            onTap: () => setState(() => _filtersExpanded = !_filtersExpanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.tune_rounded, size: 18, color: _brown),
                  const SizedBox(width: 6),
                  const Text(
                    'Filter',
                    style: TextStyle(
                      color: _brown,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(width: 3),
                  Icon(
                    _filtersExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    size: 18,
                    color: _brown,
                  ),
                ],
              ),
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
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'FILTER YOUR WARDROBE',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
                color: _brown,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'SORT BY',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: _muted,
                letterSpacing: .8,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children:
                  ['Recently added', 'Name A–Z', 'Category', 'Favourites first']
                      .map(
                        (value) => StyleChip(
                          label: value,
                          icon: Icons.sort_rounded,
                          selected: _sort == value,
                          onTap: () => setState(() => _sort = value),
                        ),
                      )
                      .toList(),
            ),
            const SizedBox(height: 14),
            const Text(
              'CATEGORY',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: _muted,
                letterSpacing: .8,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: ['All', ..._categoryOptions]
                  .map(
                    (value) => StyleChip(
                      label: value,
                      icon: value == 'All'
                          ? Icons.grid_view_rounded
                          : _categoryIcon(value),
                      selected: _category == value,
                      onTap: () => setState(() => _category = value),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 14),
            const Text(
              'COLOUR',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: _muted,
                letterSpacing: .8,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: ['All', ..._colourOptions]
                  .map(
                    (value) => StyleChip(
                      label: value,
                      icon: Icons.palette_outlined,
                      selected: _colour == value,
                      onTap: () => setState(() => _colour = value),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _clearFilters,
                    icon: const Icon(Icons.clear_rounded, size: 17),
                    label: const Text('Clear'),
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => setState(() => _filtersExpanded = false),
                    icon: const Icon(Icons.check_rounded, size: 17),
                    label: const Text('Done'),
                    style: FilledButton.styleFrom(backgroundColor: _brown),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveFilters(String query, int filteredCount, int totalCount) {
    final chips = <Widget>[];
    if (_category != 'All') {
      chips.add(
        _buildActiveFilterChip(
          label: _category,
          onRemove: () => setState(() => _category = 'All'),
        ),
      );
    }

    if (_colour != 'All') {
      chips.add(
        _buildActiveFilterChip(
          label: _colour,
          onRemove: () => setState(() => _colour = 'All'),
        ),
      );
    }

    if (_showFavouritesOnly) {
      chips.add(
        _buildActiveFilterChip(
          label: 'Favourites',
          icon: Icons.favorite_rounded,
          onRemove: () => setState(() => _showFavouritesOnly = false),
        ),
      );
    }

    if (query.isNotEmpty) {
      chips.add(
        _buildActiveFilterChip(
          label: 'Search: ${_searchQuery.trim()}',
          onRemove: _searchController.clear,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Active filters',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: _muted,
              ),
            ),
            const Spacer(),
            TextButton(
              onPressed: _clearFilters,
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 28),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('Clear all', style: TextStyle(fontSize: 11)),
            ),
          ],
        ),
        Wrap(spacing: 6, runSpacing: 6, children: chips),
        const SizedBox(height: 6),
        Text(
          'Showing $filteredCount of $totalCount',
          style: const TextStyle(color: _muted, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildActiveFilterChip({
    required String label,
    required VoidCallback onRemove,
    IconData? icon,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: AppColors.primary.withValues(alpha: .16)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(99),
        onTap: onRemove,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 6, 7, 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 12, color: AppColors.primary),
                const SizedBox(width: 4),
              ],
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 150),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.close_rounded,
                size: 13,
                color: AppColors.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _clearFilters() {
    setState(() {
      _category = 'All';
      _colour = 'All';
      _sort = 'Recently added';
      _showFavouritesOnly = false;
      _searchController.clear();
      _searchQuery = '';
      _filtersExpanded = false;
    });
  }

  Future<void> _loadPremiumStatus(String uid) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      if (!mounted || _uid != uid) return;
      setState(() {
        _isPremium = snapshot.data()?['isPremium'] == true;
        _premiumLoaded = true;
      });
    } catch (_) {
      if (!mounted || _uid != uid) return;
      setState(() {
        _isPremium = false;
        _premiumLoaded = true;
      });
    }
  }

  Widget _buildSearchBar() => _WardrobeSearchField(
    controller: _searchController,
    onChanged: (value) {
      if (!mounted) return;
      setState(() => _searchQuery = value);
    },
  );

  // The remaining methods are unchanged from the original file.
  Widget _placeholder() => const SizedBox.shrink();
}
