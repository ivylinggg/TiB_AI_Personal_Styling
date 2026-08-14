import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/wardrobe_item.dart';
import '../../providers/analysis_provider.dart';
import '../../services/firestore_service.dart';
import '../../services/style_preference_service.dart';
import '../wardrobe/wardrobe_screen.dart';
import 'style_preferences_screen.dart';
import '../premium/premium_screen.dart';

class AIStylistScreen extends StatefulWidget {
  const AIStylistScreen({super.key});

  @override
  State<AIStylistScreen> createState() => _AIStylistScreenState();
}

class _AIStylistScreenState extends State<AIStylistScreen> {
  static const _brown = Color(0xFF8E5E46);
  static const _soft = Color(0xFFF8E3DC);
  static const _cream = Color(0xFFFFFAF7);
  static const _text = Color(0xFF302A27);
  static const _muted = Color(0xFF756B67);

  String _occasion = 'Everyday';
  List<WardrobeItem> _wardrobe = const [];
  List<String> _styles = const [];
  List<String> _preferences = const [];
  bool _loading = true;
  bool _isPremium = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _loadPersonalData();
  }

  Future<void> _loadPersonalData() async {
    if (_loading && _wardrobe.isNotEmpty) {
      return;
    }

    if (mounted) {
      setState(() {
        _loading = true;
      });
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
        setState(() => _loading = false);
      }
      return;
    }

    try {
      final wardrobe = await FirestoreService.getWardrobeItems(user.uid);
      final style = await StylePreferenceService.getStylePreferences(user.uid);
      final userSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final userData = userSnapshot.data();
      final isPremium = userData?['isPremium'] == true;

      if (!mounted) {
        return;
      }

      setState(() {
        _wardrobe = wardrobe;
        _styles = List<String>.from(style?['styles'] ?? const []);
        _preferences = List<String>.from(style?['preferences'] ?? const []);
        _isPremium = isPremium;
        _loadError = null;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadError = 'I couldn’t refresh your wardrobe and style profile.';
          _loading = false;
        });
      }
    }
  }

  Future<void> _openWardrobe() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const WardrobeScreen()),
    );
    await _loadPersonalData();
  }

  Future<void> _openPreferences() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const StylePreferencesScreen()),
    );
    await _loadPersonalData();
  }

  @override
  Widget build(BuildContext context) {
    final result = context.watch<AnalysisProvider>().result;
    final colours = result?.colours ?? const <String>[];
    final matches = _matchingItems(colours);
    final mainColour = colours.isEmpty ? 'a soft neutral' : colours.first;

    return Scaffold(
      backgroundColor: _cream,
      appBar: AppBar(
        backgroundColor: _cream,
        elevation: 0,
        iconTheme: const IconThemeData(color: _text),
        title: const Text(
          'Styling Assistant',
          style: TextStyle(color: _text, fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            onPressed: _loadPersonalData,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh my style data',
          ),
          IconButton(
            onPressed: _openPreferences,
            icon: const Icon(Icons.tune_rounded),
            tooltip: 'My Style',
          ),
          IconButton(
            onPressed: _openWardrobe,
            icon: const Icon(Icons.checkroom_outlined),
            tooltip: 'My Wardrobe',
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadPersonalData,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              _welcome(result?.season, result?.undertone),
              if (_loadError != null) ...[
                const SizedBox(height: 10),
                _errorCard(),
              ],
              const SizedBox(height: 18),
              _profileCard(result?.season, result?.undertone, colours),
              const SizedBox(height: 10),
              _premiumStatusCard(),
              const SizedBox(height: 10),
              _personalCard(),
              const SizedBox(height: 26),
              _title(
                'What are you dressing for?',
                'Tell me the moment. I will help with the rest.',
              ),
              const SizedBox(height: 12),
              _occasions(),
              const SizedBox(height: 18),
              _recommendation(result != null, mainColour, matches),
              const SizedBox(height: 26),
              _title(
                'A little help, when you need it',
                'Small decisions can make getting dressed easier.',
              ),
              const SizedBox(height: 12),
              _helpGrid(),
              const SizedBox(height: 22),
              _humanNote(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _welcome(String? season, String? undertone) {
    return Container(
      padding: const EdgeInsets.all(21),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF4D5C8), Color(0xFFF9EAE5)],
        ),
        borderRadius: BorderRadius.circular(25),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              color: _brown,
              size: 27,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Let’s make getting dressed easier.',
                  style: TextStyle(
                    color: _text,
                    fontSize: 21,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  season == null
                      ? 'Start with your colour analysis, then tell me what feels like you.'
                      : 'I know your $season profile and ${undertone ?? 'colour'} undertone. Now let’s make it personal.',
                  style: const TextStyle(
                    color: _muted,
                    fontSize: 14,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _errorCard() {
    return Material(
      color: const Color(0xFFFFF4F0),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: _loadPersonalData,
        borderRadius: BorderRadius.circular(16),
        child: const Padding(
          padding: EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(Icons.cloud_off_rounded, color: _brown),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Some personal styling data could not be refreshed. Tap to try again.',
                  style: TextStyle(color: _text, fontSize: 13, height: 1.35),
                ),
              ),
              Icon(Icons.refresh_rounded, color: _brown, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _profileCard(String? season, String? undertone, List<String> colours) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: const Color(0xFFEADFD9)),
      ),
      child: Row(
        children: [
          const Icon(Icons.palette_outlined, color: _brown),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Your colour guide',
                  style: TextStyle(color: _muted, fontSize: 12),
                ),
                const SizedBox(height: 3),
                Text(
                  season == null
                      ? 'Complete your colour analysis'
                      : '$season · ${undertone ?? 'Unknown'} undertone',
                  style: const TextStyle(
                    color: _text,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          if (colours.isNotEmpty)
            Row(
              children: colours
                  .take(3)
                  .map(
                    (c) => Container(
                      width: 21,
                      height: 21,
                      margin: const EdgeInsets.only(left: 5),
                      decoration: BoxDecoration(
                        color: _colour(c),
                        shape: BoxShape.circle,
                      ),
                    ),
                  )
                  .toList(),
            ),
        ],
      ),
    );
  }

  Widget _premiumStatusCard() {
    return Material(
      color: _isPremium ? const Color(0xFFFFF3D6) : Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const PremiumScreen(),
            ),
          );
        },
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: _isPremium
                  ? const Color(0xFFE7C77A)
                  : const Color(0xFFEADFD9),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _isPremium ? Colors.white : _soft,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _isPremium
                      ? Icons.workspace_premium_rounded
                      : Icons.lock_outline_rounded,
                  color: _brown,
                  size: 21,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isPremium
                          ? 'Premium styling is active'
                          : 'Unlock Premium styling',
                      style: const TextStyle(
                        color: _text,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _isPremium
                          ? 'Your account can use advanced wardrobe styling.'
                          : 'Get advanced wardrobe-based styling features.',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: _muted,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _personalCard() {
    final wardrobeText = _loading
        ? 'Looking through your wardrobe...'
        : _wardrobe.isEmpty
        ? 'Add a few pieces I can style for you'
        : '${_wardrobe.length} pieces ready to style';
    final styleText = _loading
        ? 'Loading your style...'
        : _styles.isEmpty
        ? 'Tell me what feels like you'
        : _styles.take(2).join(' · ');
    return Column(
      children: [
        _action(
          Icons.checkroom_outlined,
          'My wardrobe',
          wardrobeText,
          _openWardrobe,
        ),
        const SizedBox(height: 8),
        _action(
          Icons.favorite_border_rounded,
          'My style',
          styleText,
          _openPreferences,
        ),
      ],
    );
  }

  Widget _action(
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap,
  ) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(17),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(17),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: _soft,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: _brown, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: _text,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: _muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: _muted),
            ],
          ),
        ),
      ),
    );
  }

  Widget _title(String title, String subtitle) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: const TextStyle(
          color: _text,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),
      const SizedBox(height: 4),
      Text(
        subtitle,
        style: const TextStyle(color: _muted, fontSize: 13, height: 1.4),
      ),
    ],
  );

  Widget _occasions() {
    const values = ['Everyday', 'Work', 'Date', 'Event', 'Weekend'];
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: values.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, index) {
          final selected = values[index] == _occasion;
          return ChoiceChip(
            label: Text(values[index]),
            selected: selected,
            onSelected: (_) => setState(() => _occasion = values[index]),
            selectedColor: _brown,
            backgroundColor: Colors.white,
            labelStyle: TextStyle(
              color: selected ? Colors.white : _text,
              fontWeight: FontWeight.w600,
            ),
          );
        },
      ),
    );
  }

  List<WardrobeItem> _matchingItems(List<String> colours) {
    if (_wardrobe.isEmpty) {
      return const [];
    }

    final wanted = colours.map((e) => e.toLowerCase()).toList();

    final ranked = List<WardrobeItem>.from(_wardrobe)
      ..sort((a, b) => _itemScore(b, wanted).compareTo(_itemScore(a, wanted)));

    return ranked.take(_isPremium ? 6 : 2).toList();
  }

  int _itemScore(WardrobeItem item, List<String> wantedColours) {
    var score = 0;

    if (item.isFavourite) {
      score += 4;
    }

    final itemColour = item.colour.toLowerCase();
    if (wantedColours.any(
      (colour) => colour.contains(itemColour) || itemColour.contains(colour),
    )) {
      score += 6;
    }

    final styleProfile = [
      ..._styles,
      ..._preferences,
    ].map((value) => value.toLowerCase()).join(' ');

    final itemText = '${item.name} ${item.category} $itemColour'.toLowerCase();

    for (final keyword in [
      'casual',
      'minimal',
      'classic',
      'elegant',
      'feminine',
      'street',
      'smart',
      'comfortable',
      'neutral',
    ]) {
      if (styleProfile.contains(keyword) && itemText.contains(keyword)) {
        score += 2;
      }
    }

    if (_isPremium) {
      final premiumStyleRules = <String, List<String>>{
        'minimal': ['minimal', 'basic', 'plain', 'simple', 'neutral'],
        'elegant': ['elegant', 'dress', 'blouse', 'skirt', 'heels'],
        'classic': ['classic', 'blazer', 'shirt', 'trousers', 'neutral'],
        'casual': ['casual', 'jeans', 't-shirt', 'tee', 'sneaker'],
        'feminine': ['feminine', 'dress', 'skirt', 'blouse', 'pink'],
        'street': ['street', 'oversized', 'hoodie', 'sneaker', 'denim'],
        'smart': ['smart', 'blazer', 'shirt', 'trousers', 'loafer'],
        'comfortable': ['comfortable', 'knit', 'cardigan', 'sweater', 'flat'],
      };

      for (final entry in premiumStyleRules.entries) {
        if (styleProfile.contains(entry.key) &&
            entry.value.any(itemText.contains)) {
          score += 5;
        }
      }

      if (styleProfile.contains('keep it simple') &&
          !itemText.contains('statement') &&
          !itemText.contains('bold')) {
        score += 3;
      }

      if (styleProfile.contains('i love accessories')) {
        score += item.category == 'Accessories' ? 6 : 1;
      }

      if (styleProfile.contains('comfort first') &&
          (itemText.contains('comfortable') ||
              itemText.contains('soft') ||
              itemText.contains('relaxed'))) {
        score += 5;
      }
    }

    if (_occasion == 'Work' &&
        (item.category == 'Tops' || item.category == 'Bottoms')) {
      score += 2;
    }

    if (_occasion == 'Weekend' && item.category == 'Tops') {
      score += 1;
    }

    return score;
  }

  Widget _recommendation(
    bool hasProfile,
    String mainColour,
    List<WardrobeItem> items,
  ) {
    WardrobeItem? top;
    WardrobeItem? bottom;
    WardrobeItem? shoes;
    for (final item in items) {
      if (top == null &&
          (item.category == 'Tops' || item.category == 'Dresses')) {
        top = item;
      }
      if (bottom == null && item.category == 'Bottoms') {
        bottom = item;
      }
      if (shoes == null && item.category == 'Shoes') {
        shoes = item;
      }
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: _soft,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _occasion,
                  style: const TextStyle(
                    color: _brown,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Spacer(),
              if (_isPremium)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3D6),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.workspace_premium_rounded,
                        size: 15,
                        color: _brown,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'PREMIUM',
                        style: TextStyle(
                          color: _brown,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(width: 8),
              const Icon(Icons.favorite_border_rounded, color: _brown),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            items.isEmpty
                ? 'Your first styling idea'
                : 'A look from your wardrobe',
            style: const TextStyle(
              color: _text,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            items.isEmpty
                ? (hasProfile
                      ? 'Try $mainColour as your main colour, then add a calm neutral.'
                      : 'Complete your colour analysis and add a few wardrobe pieces so I can style what you actually own.')
                : _isPremium
                    ? 'I prioritised pieces you already own, your colour profile and your saved Style Profile. Premium preferences have a stronger influence on the ranking.'
                    : 'I prioritised pieces you already own, your colour profile and the style preferences you saved.',
            style: const TextStyle(color: _muted, fontSize: 14, height: 1.5),
          ),
          if (_styles.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'Style direction · ${_styles.take(2).join(' · ')}',
              style: const TextStyle(
                color: _brown,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: 17),
          if (top != null)
            _lookRow(
              Icons.checkroom_outlined,
              'Main piece',
              top.name,
              top.colour,
            ),
          if (bottom != null) ...[
            const SizedBox(height: 11),
            _lookRow(
              Icons.layers_outlined,
              'Bottom',
              bottom.name,
              bottom.colour,
            ),
          ],
          if (shoes != null) ...[
            const SizedBox(height: 11),
            _lookRow(
              Icons.directions_walk_outlined,
              'Shoes',
              shoes.name,
              shoes.colour,
            ),
          ],
          if (items.isEmpty)
            _lookRow(
              Icons.auto_awesome_outlined,
              'Finishing touch',
              _preferences.contains('I love accessories')
                  ? 'One accessory you enjoy'
                  : 'One small personal detail',
              '',
            ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _showRecommendation(items, mainColour),
                  icon: const Icon(Icons.auto_awesome_rounded),
                  label: const Text('Build this look'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _brown,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              IconButton.filledTonal(
                onPressed: _openWardrobe,
                icon: const Icon(Icons.checkroom_outlined),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _lookRow(
    IconData icon,
    String title,
    String name,
    String colour,
  ) => Row(
    children: [
      Container(
        width: 38,
        height: 38,
        decoration: const BoxDecoration(color: _soft, shape: BoxShape.circle),
        child: Icon(icon, size: 20, color: _brown),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(color: _muted, fontSize: 11)),
            const SizedBox(height: 2),
            Text(
              name,
              style: const TextStyle(color: _text, fontWeight: FontWeight.w600),
            ),
            if (colour.isNotEmpty)
              Text(colour, style: const TextStyle(color: _muted, fontSize: 11)),
          ],
        ),
      ),
    ],
  );

  Widget _helpGrid() => GridView.count(
    crossAxisCount: 2,
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    crossAxisSpacing: 12,
    mainAxisSpacing: 12,
    childAspectRatio: 1.12,
    children: [
      _help(
        Icons.checkroom_outlined,
        'My wardrobe',
        'Style pieces you already own.',
        _openWardrobe,
      ),
      _help(
        Icons.palette_outlined,
        'Mix & match',
        'Find colours that work together.',
        _showColourIdeas,
      ),
      _help(
        Icons.shopping_bag_outlined,
        'Shopping help',
        _isPremium
            ? 'See what your wardrobe is missing.'
            : 'Premium feature · See what your wardrobe is missing.',
        () => _runPremiumAction(_showShoppingIdeas),
      ),
      _help(
        Icons.event_outlined,
        'Dress for it',
        'Make an occasion feel effortless.',
        _showOccasionIdeas,
      ),
    ],
  );

  Widget _help(
    IconData icon,
    String title,
    String description,
    VoidCallback onTap,
  ) => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(20),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: const BoxDecoration(
                color: _soft,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: _brown),
            ),
            const Spacer(),
            Text(
              title,
              style: const TextStyle(color: _text, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: _muted, fontSize: 12, height: 1.35),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _humanNote() => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: const Color(0xFFF2EEE9),
      borderRadius: BorderRadius.circular(20),
    ),
    child: const Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.tips_and_updates_outlined, color: _brown),
        SizedBox(width: 12),
        Expanded(
          child: Text(
            'Good style does not mean following every trend. It is about finding choices that feel comfortable, confident and right for you.',
            style: TextStyle(color: _muted, fontSize: 13, height: 1.5),
          ),
        ),
      ],
    ),
  );

  void _runPremiumAction(VoidCallback action) {
    if (_isPremium) {
      action();
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: _cream,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: const BoxDecoration(
                      color: _soft,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.workspace_premium_rounded,
                      color: _brown,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Premium feature',
                      style: TextStyle(
                        color: _text,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Text(
                'This advanced styling feature is available to Premium members.',
                style: TextStyle(
                  color: _muted,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const PremiumScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.workspace_premium_rounded),
                  label: const Text('View Premium'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _brown,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showRecommendation(List<WardrobeItem> items, String colour) {
    _sheet('Your personal look', Icons.auto_awesome_rounded, [
      _sheetText(
        items.isEmpty
            ? 'Add a few pieces first. Then I can build outfits from what you actually own.'
            : 'I picked from your own wardrobe first, then considered your colour profile, saved preferences and $_occasion.',
      ),
      ...items
          .map(
            (item) =>
                _sheetItem(item.category, '${item.name} · ${item.colour}'),
          )
          .take(4),
      _sheetItem('Styling thought', _occasionTip()),
    ]);
  }

  String _occasionTip() {
    switch (_occasion) {
      case 'Work':
        return 'Keep the outfit polished and comfortable. Let one colour or accessory add personality.';
      case 'Date':
        return 'Choose one flattering colour near your face and keep the rest relaxed so the look still feels like you.';
      case 'Event':
        return 'Let one piece be the focus. Keep the other pieces simple enough to support it.';
      case 'Weekend':
        return 'Start with comfort, then add one detail that makes the outfit feel intentional.';
      default:
        return 'Keep one main colour, one supporting neutral and one small detail that feels like you.';
    }
  }

  void _showColourIdeas() {
    final colours =
        context.read<AnalysisProvider>().result?.colours ?? const <String>[];
    _sheet('Mix & match', Icons.palette_outlined, [
      _sheetText(
        colours.isEmpty
            ? 'Complete your colour analysis to see your personal palette.'
            : 'Use one of your best colours as the focus and pair it with a calm neutral.',
      ),
      ...colours
          .take(5)
          .map(
            (c) =>
                _sheetItem(c, 'Use it as a main piece, accent or accessory.'),
          ),
    ]);
  }

  void _showShoppingIdeas() {
    final missing = <String>[];
    if (!_wardrobe.any((i) => i.category == 'Tops')) {
      missing.add('a versatile top');
    }
    if (!_wardrobe.any((i) => i.category == 'Bottoms')) {
      missing.add('an easy-to-match bottom');
    }
    if (!_wardrobe.any((i) => i.category == 'Shoes')) {
      missing.add('a reliable pair of shoes');
    }
    _sheet('Shopping assistant', Icons.shopping_bag_outlined, [
      _sheetText(
        missing.isEmpty
            ? 'Your basics are covered. Look for variety rather than duplicates.'
            : 'These are the wardrobe gaps I would fill first.',
      ),
      ...missing.map((m) => _sheetItem('Consider', m)),
      _sheetItem(
        'Before buying',
        'Ask yourself if the new piece works with at least three things you already own.',
      ),
    ]);
  }

  void
  _showOccasionIdeas() => _sheet('Dress for $_occasion', Icons.event_outlined, [
    _sheetItem('Work', 'Polished, comfortable and easy to repeat.'),
    _sheetItem(
      'Date',
      'Keep a flattering colour close to your face and add one personal detail.',
    ),
    _sheetItem(
      'Event',
      'Choose one statement piece and let the rest support it.',
    ),
    _sheetItem(
      'Weekend',
      'Prioritise comfort without losing your personal style.',
    ),
  ]);

  void _sheet(String title, IconData icon, List<Widget> children) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: _cream,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 5, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(
                      color: _soft,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: _brown),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        color: _text,
                        fontSize: 21,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              ...children,
            ],
          ),
        ),
      ),
    );
  }

  Widget _sheetText(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Text(
      text,
      style: const TextStyle(color: _muted, height: 1.5, fontSize: 14),
    ),
  );
  Widget _sheetItem(String title, String description) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(color: _text, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          description,
          style: const TextStyle(color: _muted, fontSize: 13, height: 1.4),
        ),
      ],
    ),
  );

  Color _colour(String name) {
    final v = name.toLowerCase();
    if (v.contains('pink') || v.contains('rose')) {
      return const Color(0xFFE8A7B7);
    }
    if (v.contains('red') || v.contains('coral')) {
      return const Color(0xFFD97968);
    }
    if (v.contains('orange') || v.contains('peach')) {
      return const Color(0xFFE7A16F);
    }
    if (v.contains('yellow') || v.contains('gold')) {
      return const Color(0xFFD8B85A);
    }
    if (v.contains('green') || v.contains('olive')) {
      return const Color(0xFF8A9A68);
    }
    if (v.contains('blue') || v.contains('navy')) {
      return const Color(0xFF7189A8);
    }
    if (v.contains('purple') || v.contains('violet')) {
      return const Color(0xFF9A7AA8);
    }
    if (v.contains('brown') || v.contains('beige') || v.contains('neutral')) {
      return const Color(0xFFB59A83);
    }
    return const Color(0xFFC9B7AD);
  }
}
