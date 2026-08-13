import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/wardrobe_item.dart';
import '../../providers/analysis_provider.dart';
import '../../services/firestore_service.dart';
import 'style_preferences_screen.dart';
import '../wardrobe/wardrobe_screen.dart';

class AIStylistScreen extends StatefulWidget {
  const AIStylistScreen({super.key});

  @override
  State<AIStylistScreen> createState() => _AIStylistScreenState();
}

class _AIStylistScreenState extends State<AIStylistScreen> {
  static const _brown = Color(0xFF8E5E46);
  static const _softPink = Color(0xFFF8E3DC);
  static const _cream = Color(0xFFFFFAF7);
  static const _text = Color(0xFF302A27);
  static const _muted = Color(0xFF756B67);

  String _occasion = 'Everyday';
  List<WardrobeItem> _wardrobe = const [];
  List<String> _styles = const [];
  List<String> _preferences = const [];
  bool _loadingWardrobe = true;
  bool _loadingPreferences = true;

  User? get _user => FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _loadPersonalData();
  }

  Future<void> _loadPersonalData() async {
    final user = _user;
    if (user == null) {
      if (mounted) setState(() { _loadingWardrobe = false; _loadingPreferences = false; });
      return;
    }

    try {
      final results = await Future.wait<dynamic>([
        FirestoreService.getWardrobeItems(user.uid),
        FirestoreService.getUser(user.uid),
      ]);
      final userModel = results[1];
      if (!mounted) return;
      setState(() {
        _wardrobe = List<WardrobeItem>.from(results[0] as List<WardrobeItem>);
        final data = userModel?.toMap() as Map<String, dynamic>?;
        _styles = data == null ? const [] : List<String>.from(data['stylePreferences']?['styles'] ?? const []);
        _preferences = data == null ? const [] : List<String>.from(data['stylePreferences']?['preferences'] ?? const []);
        _loadingWardrobe = false;
        _loadingPreferences = false;
      });
    } catch (_) {
      if (mounted) setState(() { _loadingWardrobe = false; _loadingPreferences = false; });
    }
  }

  Future<void> _openWardrobe() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const WardrobeScreen()));
    await _loadPersonalData();
  }

  Future<void> _openPreferences() async {
    await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => const StylePreferencesScreen()));
    await _loadPersonalData();
  }

  @override
  Widget build(BuildContext context) {
    final result = context.watch<AnalysisProvider>().result;
    final colours = result?.colours ?? const <String>[];
    final primaryColour = colours.isNotEmpty ? colours.first : 'a soft neutral';
    final matchingItems = _matchingWardrobe(colours);

    return Scaffold(
      backgroundColor: _cream,
      appBar: AppBar(
        backgroundColor: _cream,
        elevation: 0,
        iconTheme: const IconThemeData(color: _text),
        title: const Text('Styling Assistant', style: TextStyle(color: _text, fontWeight: FontWeight.w700)),
        actions: [
          IconButton(onPressed: _openPreferences, tooltip: 'My Style', icon: const Icon(Icons.tune_rounded)),
          IconButton(onPressed: _openWardrobe, tooltip: 'My Wardrobe', icon: const Icon(Icons.checkroom_outlined)),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadPersonalData,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 32),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _welcome(result?.season, result?.undertone),
              const SizedBox(height: 18),
              _profileCard(result?.season, result?.undertone, colours),
              const SizedBox(height: 12),
              _personalDataCard(),
              const SizedBox(height: 26),
              _sectionTitle('What are you dressing for?', 'Tell me the moment. I will help with the rest.'),
              const SizedBox(height: 12),
              _occasionSelector(),
              const SizedBox(height: 18),
              _wardrobeLookCard(result != null, primaryColour, matchingItems),
              const SizedBox(height: 28),
              _sectionTitle('A little help, when you need it', 'Small decisions can make getting dressed much easier.'),
              const SizedBox(height: 12),
              _helpGrid(),
              const SizedBox(height: 22),
              _personalNote(),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _welcome(String? season, String? undertone) {
    final hasProfile = season != null;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(21),
      decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFFF4D5C8), Color(0xFFF9EAE5)]), borderRadius: BorderRadius.circular(25)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(width: 52, height: 52, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle), child: const Icon(Icons.auto_awesome_rounded, color: _brown, size: 27)),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Let’s make getting dressed easier.', style: TextStyle(color: _text, fontSize: 21, height: 1.2, fontWeight: FontWeight.w700)),
          const SizedBox(height: 7),
          Text(hasProfile ? 'I know your $season profile and ${undertone ?? 'colour'} undertone. Now let’s make it personal.' : 'Start with your colour analysis, then tell me what feels like you.', style: const TextStyle(color: _muted, fontSize: 14, height: 1.45)),
        ])),
      ]),
    );
  }

  Widget _profileCard(String? season, String? undertone, List<String> colours) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(19), border: Border.all(color: const Color(0xFFEADFD9))),
      child: Row(children: [
        const Icon(Icons.palette_outlined, color: _brown),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Your colour guide', style: TextStyle(color: _muted, fontSize: 12)),
          const SizedBox(height: 3),
          Text(season == null ? 'Complete your colour analysis' : '$season · ${undertone ?? 'Unknown'} undertone', style: const TextStyle(color: _text, fontWeight: FontWeight.w700, fontSize: 14)),
        ])),
        if (colours.isNotEmpty) Row(children: colours.take(3).map((c) => Container(width: 21, height: 21, margin: const EdgeInsets.only(left: 5), decoration: BoxDecoration(color: _colourFromName(c), shape: BoxShape.circle))).toList()),
      ]),
    );
  }

  Widget _personalDataCard() {
    final wardrobeText = _loadingWardrobe ? 'Looking through your wardrobe...' : _wardrobe.isEmpty ? 'Your wardrobe is still waiting for its first piece' : '${_wardrobe.length} pieces in your wardrobe';
    final styleText = _loadingPreferences ? 'Loading your style...' : _styles.isEmpty ? 'Tell me what feels like you' : _styles.take(2).join(' · ');
    return Column(children: [
      _smallAction(Icons.checkroom_outlined, 'My wardrobe', wardrobeText, _openWardrobe),
      const SizedBox(height: 8),
      _smallAction(Icons.favorite_border_rounded, 'My style', styleText, _openPreferences),
    ]);
  }

  Widget _smallAction(IconData icon, String title, String subtitle, VoidCallback onTap) {
    return Material(color: Colors.white, borderRadius: BorderRadius.circular(17), child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(17), child: Padding(padding: const EdgeInsets.all(14), child: Row(children: [
      Container(width: 40, height: 40, decoration: const BoxDecoration(color: _softPink, shape: BoxShape.circle), child: Icon(icon, color: _brown, size: 20)),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(color: _text, fontWeight: FontWeight.w700)), const SizedBox(height: 2), Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _muted, fontSize: 12))])),
      const Icon(Icons.chevron_right_rounded, color: _muted),
    ]))));
  }

  Widget _sectionTitle(String title, String subtitle) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(color: _text, fontSize: 20, fontWeight: FontWeight.w700)), const SizedBox(height: 4), Text(subtitle, style: const TextStyle(color: _muted, fontSize: 13, height: 1.4))]);

  Widget _occasionSelector() {
    const values = ['Everyday', 'Work', 'Date', 'Event', 'Weekend'];
    return SizedBox(height: 44, child: ListView.separated(scrollDirection: Axis.horizontal, itemCount: values.length, separatorBuilder: (_, _) => const SizedBox(width: 8), itemBuilder: (context, index) {
      final selected = values[index] == _occasion;
      return ChoiceChip(label: Text(values[index]), selected: selected, onSelected: (_) => setState(() => _occasion = values[index]), selectedColor: _brown, backgroundColor: Colors.white, labelStyle: TextStyle(color: selected ? Colors.white : _text, fontWeight: FontWeight.w600), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)));
    }));
  }

  List<WardrobeItem> _matchingWardrobe(List<String> colours) {
    if (_wardrobe.isEmpty) return const [];
    if (colours.isEmpty) return _wardrobe.take(4).toList();
    final wanted = colours.map((e) => e.toLowerCase()).toSet();
    final matches = _wardrobe.where((item) => wanted.any((c) => item.colour.toLowerCase().contains(c) || c.contains(item.colour.toLowerCase()))).toList();
    return [...matches, ..._wardrobe.where((item) => !matches.contains(item))].take(4).toList();
  }

  Widget _wardrobeLookCard(bool hasProfile, String primaryColour, List<WardrobeItem> items) {
    final top = items.where((i) => i.category == 'Tops' || i.category == 'Dresses').firstOrNull;
    final bottom = items.where((i) => i.category == 'Bottoms').firstOrNull;
    final shoe = items.where((i) => i.category == 'Shoes').firstOrNull;
    return Container(width: double.infinity, padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .04), blurRadius: 16, offset: const Offset(0, 6))]), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: _softPink, borderRadius: BorderRadius.circular(20)), child: Text(_occasion, style: const TextStyle(color: _brown, fontSize: 12, fontWeight: FontWeight.w700))), const Spacer(), const Icon(Icons.favorite_border_rounded, color: _brown)]),
      const SizedBox(height: 16),
      Text(items.isEmpty ? 'Your first styling idea' : 'A look from your wardrobe', style: const TextStyle(color: _text, fontSize: 18, fontWeight: FontWeight.w700)),
      const SizedBox(height: 7),
      Text(items.isEmpty ? (hasProfile ? 'Try $primaryColour as your main colour, then add a calm neutral.' : 'Complete your colour analysis and add a few wardrobe pieces so I can style what you actually own.') : 'I found pieces you already own that can work together for $_occasion. Start with the strongest match and keep the rest balanced.', style: const TextStyle(color: _muted, fontSize: 14, height: 1.5)),
      const SizedBox(height: 17),
      if (top != null) _lookRow(Icons.checkroom_outlined, 'Top / main piece', top.name, top.colour),
      if (bottom != null) ...[const SizedBox(height: 11), _lookRow(Icons.layers_outlined, 'Bottom', bottom.name, bottom.colour)],
      if (shoe != null) ...[const SizedBox(height: 11), _lookRow(Icons.directions_walk_outlined, 'Shoes', shoe.name, shoe.colour)],
      if (items.isEmpty) _lookRow(Icons.auto_awesome_outlined, 'Finishing touch', _preferences.contains('I love accessories') ? 'One accessory you enjoy' : 'One small personal detail', ''),
      const SizedBox(height: 18),
      Row(children: [
        Expanded(child: ElevatedButton.icon(onPressed: () => _showRecommendation(items, primaryColour), icon: const Icon(Icons.auto_awesome_rounded), label: const Text('Build this look'), style: ElevatedButton.styleFrom(backgroundColor: _brown, foregroundColor: Colors.white, elevation: 0, minimumSize: const Size.fromHeight(50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))))),
        const SizedBox(width: 10),
        IconButton.filledTonal(onPressed: _openWardrobe, icon: const Icon(Icons.checkroom_outlined), tooltip: 'Open wardrobe'),
      ]),
    ]));
  }

  Widget _lookRow(IconData icon, String title, String name, String colour) => Row(children: [Container(width: 38, height: 38, decoration: const BoxDecoration(color: _softPink, shape: BoxShape.circle), child: Icon(icon, size: 20, color: _brown)), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(color: _muted, fontSize: 11)), const SizedBox(height: 2), Text(name, style: const TextStyle(color: _text, fontWeight: FontWeight.w600)), if (colour.isNotEmpty) Text(colour, style: const TextStyle(color: _muted, fontSize: 11))]))]);

  Widget _helpGrid() => GridView.count(crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.12, children: [
    _helpCard(Icons.checkroom_outlined, 'My wardrobe', 'See and add the pieces I can style.', _openWardrobe),
    _helpCard(Icons.palette_outlined, 'Mix & match', 'Find colours that work together.', _showColourIdeas),
    _helpCard(Icons.shopping_bag_outlined, 'Shopping help', 'Know what is worth adding next.', _showShoppingIdeas),
    _helpCard(Icons.event_outlined, 'Dress for it', 'Make an occasion feel effortless.', _showOccasionIdeas),
  ]);

  Widget _helpCard(IconData icon, String title, String description, VoidCallback onTap) => Material(color: Colors.white, borderRadius: BorderRadius.circular(20), child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(20), child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Container(width: 42, height: 42, decoration: const BoxDecoration(color: _softPink, shape: BoxShape.circle), child: Icon(icon, color: _brown)), const Spacer(), Text(title, style: const TextStyle(color: _text, fontWeight: FontWeight.w700)), const SizedBox(height: 4), Text(description, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _muted, fontSize: 12, height: 1.35))]))));

  Widget _personalNote() => Container(width: double.infinity, padding: const EdgeInsets.all(18), decoration: BoxDecoration(color: const Color(0xFFF2EEE9), borderRadius: BorderRadius.circular(20)), child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(Icons.tips_and_updates_outlined, color: _brown), SizedBox(width: 12), Expanded(child: Text('Good style does not mean following every trend. It is about finding choices that feel comfortable, confident and right for you.', style: TextStyle(color: _muted, fontSize: 13, height: 1.5)))]));

  void _showRecommendation(List<WardrobeItem> items, String colour) {
    _sheet('Your personal look', Icons.auto_awesome_rounded, [
      _sheetText(items.isEmpty ? 'I need a few wardrobe pieces before I can build an outfit from what you own.' : 'For $_occasion, I picked pieces from your own wardrobe first. That keeps the recommendation realistic and easy to wear.'),
      ...items.take(4).map((item) => _sheetItem(item.category, '${item.name} · ${item.colour}')),
      if (items.isEmpty) _sheetItem('Start here', 'Add a top, bottom and pair of shoes to your wardrobe.'),
      _sheetItem('Styling thought', 'Keep one main colour, one supporting neutral and one small detail that feels like you.'),
    ]);
  }

  void _showColourIdeas() {
    final colours = context.read<AnalysisProvider>().result?.colours ?? const <String>[];
    _sheet('Mix & match', Icons.palette_outlined, [
      _sheetText(colours.isEmpty ? 'Complete your colour analysis to see your personal palette.' : 'Use one of your best colours as the focus and pair it with a calm neutral.'),
      ...colours.take(5).map((c) => _sheetItem(c, 'Use it as a main piece, accent or accessory.')),
    ]);
  }

  void _showShoppingIdeas() {
    final missing = <String>[];
    if (!_wardrobe.any((i) => i.category == 'Tops')) missing.add('a versatile top');
    if (!_wardrobe.any((i) => i.category == 'Bottoms')) missing.add('an easy-to-match bottom');
    if (!_wardrobe.any((i) => i.category == 'Shoes')) missing.add('a reliable pair of shoes');
    _sheet('Shopping assistant', Icons.shopping_bag_outlined, [
      _sheetText(missing.isEmpty ? 'Your wardrobe already has the basics. Look for pieces that add variety rather than duplicates.' : 'If you want to grow your wardrobe, these are the gaps I would fill first.'),
      ...missing.map((item) => _sheetItem('Consider', item)),
      _sheetItem('Always check', 'Can you wear the new piece with at least three things you already own?'),
    ]);
  }

  void _showOccasionIdeas() => _sheet('Dress for $_occasion', Icons.event_outlined, [
    _sheetItem('Work', 'Polished, comfortable and easy to repeat.'),
    _sheetItem('Date', 'Keep a flattering colour close to your face and add one personal detail.'),
    _sheetItem('Event', 'Choose one statement piece and let the rest support it.'),
    _sheetItem('Weekend', 'Prioritise comfort without losing your personal style.'),
  ]);

  void _sheet(String title, IconData icon, List<Widget> children) {
    showModalBottomSheet<void>(context: context, showDragHandle: true, backgroundColor: _cream, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))), builder: (context) => SafeArea(child: SingleChildScrollView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 28), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Container(width: 44, height: 44, decoration: const BoxDecoration(color: _softPink, shape: BoxShape.circle), child: Icon(icon, color: _brown)), const SizedBox(width: 12), Expanded(child: Text(title, style: const TextStyle(color: _text, fontSize: 21, fontWeight: FontWeight.w700)))]), const SizedBox(height: 20), ...children]))));
  }

  Widget _sheetText(String text) => Padding(padding: const EdgeInsets.only(bottom: 14), child: Text(text, style: const TextStyle(color: _muted, height: 1.5, fontSize: 14)));

  Widget _sheetItem(String title, String description) => Container(width: double.infinity, margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(color: _text, fontWeight: FontWeight.w700)), const SizedBox(height: 4), Text(description, style: const TextStyle(color: _muted, fontSize: 13, height: 1.4))]));

  Color _colourFromName(String name) {
    final value = name.toLowerCase();
    if (value.contains('pink') || value.contains('rose')) return const Color(0xFFE8A7B7);
    if (value.contains('red') || value.contains('coral')) return const Color(0xFFD97968);
    if (value.contains('orange') || value.contains('peach')) return const Color(0xFFE7A16F);
    if (value.contains('yellow') || value.contains('gold')) return const Color(0xFFD8B85A);
    if (value.contains('green') || value.contains('olive')) return const Color(0xFF8A9A68);
    if (value.contains('blue') || value.contains('navy')) return const Color(0xFF7189A8);
    if (value.contains('purple') || value.contains('violet')) return const Color(0xFF9A7AA8);
    if (value.contains('brown') || value.contains('beige') || value.contains('neutral')) return const Color(0xFFB59A83);
    return const Color(0xFFC9B7AD);
  }
}
