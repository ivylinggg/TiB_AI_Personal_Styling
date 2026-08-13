import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/analysis_provider.dart';
import '../../screens/auth/auth_service.dart';
import '../../services/style_preference_service.dart';
import 'style_preferences_screen.dart';

class AIStylistScreen extends StatefulWidget {
  const AIStylistScreen({super.key});

  @override
  State<AIStylistScreen> createState() => _AIStylistScreenState();
}

class _AIStylistScreenState extends State<AIStylistScreen> {
  static const Color _brown = Color(0xFF8E5E46);
  static const Color _softPink = Color(0xFFF8E3DC);
  static const Color _cream = Color(0xFFFFFAF7);
  static const Color _text = Color(0xFF302A27);
  static const Color _muted = Color(0xFF756B67);

  String _occasion = 'Everyday';
  List<String> _styles = [];
  List<String> _preferences = [];
  bool _loadingPreferences = true;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final user = AuthService.currentUser;
    if (user == null) {
      if (mounted) setState(() => _loadingPreferences = false);
      return;
    }

    try {
      final data = await StylePreferenceService.getStylePreferences(user.uid);
      if (!mounted) return;
      setState(() {
        _styles = List<String>.from(data?['styles'] ?? const []);
        _preferences = List<String>.from(data?['preferences'] ?? const []);
        _loadingPreferences = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingPreferences = false);
    }
  }

  Future<void> _openPreferences() async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const StylePreferencesScreen()),
    );
    if (changed == true) await _loadPreferences();
  }

  @override
  Widget build(BuildContext context) {
    final result = context.watch<AnalysisProvider>().result;
    final season = result?.season ?? 'Your colour profile';
    final undertone = result?.undertone ?? 'Not analysed yet';
    final colours = result?.colours ?? const <String>[];
    final primaryColour = colours.isNotEmpty ? colours.first : 'a soft neutral';
    final styleLabel = _styles.isEmpty ? 'Tell me what feels like you' : _styles.take(2).join(' · ');

    return Scaffold(
      backgroundColor: _cream,
      appBar: AppBar(
        backgroundColor: _cream,
        elevation: 0,
        iconTheme: const IconThemeData(color: _text),
        title: const Text('Styling Assistant', style: TextStyle(color: _text, fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            tooltip: 'My Style',
            onPressed: _openPreferences,
            icon: const Icon(Icons.tune_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _welcome(season, undertone),
              const SizedBox(height: 18),
              _profileCard(season, undertone, colours),
              const SizedBox(height: 18),
              _styleCard(styleLabel),
              const SizedBox(height: 28),
              _sectionTitle('What are you dressing for?', 'Tell me the moment. I will help with the rest.'),
              const SizedBox(height: 12),
              _occasionSelector(),
              const SizedBox(height: 18),
              _lookCard(result != null, primaryColour),
              const SizedBox(height: 28),
              _sectionTitle('A little help, when you need it', 'Small decisions can make getting dressed much easier.'),
              const SizedBox(height: 12),
              _helpGrid(),
              const SizedBox(height: 22),
              _personalNote(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _welcome(String season, String undertone) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(21),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFFF4D5C8), Color(0xFFF9EAE5)]),
        borderRadius: BorderRadius.circular(25),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
            child: const Icon(Icons.auto_awesome_rounded, color: _brown, size: 27),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Let’s make getting dressed easier.', style: TextStyle(color: _text, fontSize: 21, height: 1.2, fontWeight: FontWeight.w700)),
                const SizedBox(height: 7),
                Text(
                  season == 'Your colour profile'
                      ? 'Start with your colour analysis, then tell me what feels like you.'
                      : 'I know your $season profile and $undertone undertone. Now let’s make it personal.',
                  style: const TextStyle(color: _muted, fontSize: 14, height: 1.45),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _profileCard(String season, String undertone, List<String> colours) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(19), border: Border.all(color: const Color(0xFFEADFD9))),
      child: Row(
        children: [
          const Icon(Icons.palette_outlined, color: _brown),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Your colour guide', style: TextStyle(color: _muted, fontSize: 12)),
                const SizedBox(height: 3),
                Text(
                  season == 'Your colour profile' ? 'Complete your colour analysis' : '$season · $undertone undertone',
                  style: const TextStyle(color: _text, fontWeight: FontWeight.w700, fontSize: 14),
                ),
              ],
            ),
          ),
          if (colours.isNotEmpty)
            Row(children: colours.take(3).map((colour) => Container(width: 21, height: 21, margin: const EdgeInsets.only(left: 5), decoration: BoxDecoration(color: _colourFromName(colour), shape: BoxShape.circle))).toList()),
        ],
      ),
    );
  }

  Widget _styleCard(String label) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: _openPreferences,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(17),
          child: Row(
            children: [
              Container(width: 43, height: 43, decoration: const BoxDecoration(color: _softPink, shape: BoxShape.circle), child: const Icon(Icons.favorite_border_rounded, color: _brown)),
              const SizedBox(width: 13),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('My style', style: TextStyle(color: _muted, fontSize: 12)),
                  const SizedBox(height: 3),
                  Text(label, style: const TextStyle(color: _text, fontWeight: FontWeight.w700, fontSize: 15)),
                ]),
              ),
              _loadingPreferences ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.chevron_right_rounded, color: _muted),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String title, String subtitle) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(color: _text, fontSize: 20, fontWeight: FontWeight.w700)),
      const SizedBox(height: 4),
      Text(subtitle, style: const TextStyle(color: _muted, fontSize: 13, height: 1.4)),
    ]);
  }

  Widget _occasionSelector() {
    const occasions = ['Everyday', 'Work', 'Date', 'Event', 'Weekend'];
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: occasions.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final selected = occasions[index] == _occasion;
          return ChoiceChip(
            label: Text(occasions[index]),
            selected: selected,
            onSelected: (_) => setState(() => _occasion = occasions[index]),
            selectedColor: _brown,
            backgroundColor: Colors.white,
            side: BorderSide(color: selected ? _brown : const Color(0xFFE5DAD4)),
            labelStyle: TextStyle(color: selected ? Colors.white : _text, fontWeight: FontWeight.w600),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          );
        },
      ),
    );
  }

  Widget _lookCard(bool hasProfile, String primaryColour) {
    final style = _styles.isNotEmpty ? _styles.first : 'your own style';
    final tone = _preferences.contains('Comfort first') ? 'comfortable and easy to move in' : 'balanced and easy to wear';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 16, offset: const Offset(0, 6))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: _softPink, borderRadius: BorderRadius.circular(20)), child: Text(_occasion, style: const TextStyle(color: _brown, fontSize: 12, fontWeight: FontWeight.w700))),
          const Spacer(),
          const Icon(Icons.favorite_border_rounded, color: _brown),
        ]),
        const SizedBox(height: 16),
        Text(hasProfile ? 'A look that feels like you' : 'Your first styling idea', style: const TextStyle(color: _text, fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 7),
        Text(
          hasProfile
              ? 'For $_occasion, start with $primaryColour and keep the rest $tone. This works especially well with a $style approach.'
              : 'Complete your colour analysis and My Style preferences so your suggestions can become personal instead of generic.',
          style: const TextStyle(color: _muted, fontSize: 14, height: 1.5),
        ),
        const SizedBox(height: 18),
        _lookRow(Icons.checkroom_outlined, 'Main piece', hasProfile ? primaryColour : 'Your best colour'),
        const SizedBox(height: 11),
        _lookRow(Icons.layers_outlined, 'Keep it balanced', _preferences.contains('I like layering') ? 'Add one light layer' : 'One simple neutral layer'),
        const SizedBox(height: 11),
        _lookRow(Icons.auto_awesome_outlined, 'Finishing touch', _preferences.contains('I love accessories') ? 'Add one accessory you enjoy' : 'One small personal detail'),
        const SizedBox(height: 18),
        SizedBox(width: double.infinity, child: ElevatedButton.icon(onPressed: () => _showLook(hasProfile, primaryColour), icon: const Icon(Icons.arrow_forward_rounded), label: const Text('Build this look'), style: ElevatedButton.styleFrom(backgroundColor: _brown, foregroundColor: Colors.white, elevation: 0, minimumSize: const Size.fromHeight(50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))))),
      ]),
    );
  }

  Widget _lookRow(IconData icon, String title, String value) {
    return Row(children: [
      Container(width: 38, height: 38, decoration: const BoxDecoration(color: _softPink, shape: BoxShape.circle), child: Icon(icon, size: 20, color: _brown)),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(color: _muted, fontSize: 11)), const SizedBox(height: 2), Text(value, style: const TextStyle(color: _text, fontWeight: FontWeight.w600))])),
    ]);
  }

  Widget _helpGrid() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.12,
      children: [
        _helpCard(Icons.checkroom_outlined, 'Outfit ideas', 'Put together a complete look.', () => _showLook(true, 'your best colour')),
        _helpCard(Icons.palette_outlined, 'Mix & match', 'Find colours that work together.', _showColourIdeas),
        _helpCard(Icons.shopping_bag_outlined, 'Shopping help', 'Know what colours and pieces to look for.', _showShoppingIdeas),
        _helpCard(Icons.event_outlined, 'Dress for it', 'Make an occasion feel effortless.', _showOccasionIdeas),
      ],
    );
  }

  Widget _helpCard(IconData icon, String title, String description, VoidCallback onTap) {
    return Material(color: Colors.white, borderRadius: BorderRadius.circular(20), child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(20), child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(width: 42, height: 42, decoration: const BoxDecoration(color: _softPink, shape: BoxShape.circle), child: Icon(icon, color: _brown)),
      const Spacer(),
      Text(title, style: const TextStyle(color: _text, fontWeight: FontWeight.w700)),
      const SizedBox(height: 4),
      Text(description, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _muted, fontSize: 12, height: 1.35)),
    ]))));
  }

  Widget _personalNote() {
    return Container(width: double.infinity, padding: const EdgeInsets.all(18), decoration: BoxDecoration(color: const Color(0xFFF2EEE9), borderRadius: BorderRadius.circular(20)), child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(Icons.tips_and_updates_outlined, color: _brown), SizedBox(width: 12), Expanded(child: Text('Good style does not mean following every trend. It is about finding choices that feel comfortable, confident and right for you.', style: TextStyle(color: _muted, fontSize: 13, height: 1.5)))]));
  }

  void _showLook(bool hasProfile, String colour) {
    _sheet('Let’s build your look', Icons.checkroom_outlined, [
      _sheetText(hasProfile ? 'For $_occasion, start with $colour. Then let your own preferences guide the details.' : 'Complete your colour profile first so we can make this more personal.'),
      _sheetItem('Top', 'Choose a piece in your strongest colour.'),
      _sheetItem('Bottom', _preferences.contains('Keep it simple') ? 'Keep the base clean and uncomplicated.' : 'Choose something that balances the top.'),
      _sheetItem('Shoes & accessories', _preferences.contains('I love accessories') ? 'Add one accessory that feels like you.' : 'Keep the finishing detail subtle.'),
    ]);
  }

  void _showColourIdeas() {
    final colours = context.read<AnalysisProvider>().result?.colours ?? const <String>[];
    _sheet('Mix & match', Icons.palette_outlined, [
      _sheetText(colours.isEmpty ? 'Complete your colour analysis to see your personal palette.' : 'Use one of your best colours as the focus and pair it with a calm neutral.'),
      ...colours.take(5).map((colour) => _sheetItem(colour, 'Use it as a main piece, accent or accessory.')),
    ]);
  }

  void _showShoppingIdeas() {
    _sheet('Shopping assistant', Icons.shopping_bag_outlined, [
      _sheetText('Before buying something new, ask whether it works with at least three things you already own.'),
      _sheetItem('Look for', 'Colours from your personal palette.'),
      _sheetItem('Prioritise', 'Pieces you can style in more than one way.'),
      _sheetItem('Pause before buying', 'If you only like it because it is trending, give yourself a little time.'),
    ]);
  }

  void _showOccasionIdeas() {
    _sheet('Dress for the occasion', Icons.event_outlined, [
      _sheetItem('Work', 'Polished, comfortable and easy to repeat.'),
      _sheetItem('Date', 'Keep a colour you love close to your face.'),
      _sheetItem('Event', 'Choose one statement piece and keep the rest balanced.'),
      _sheetItem('Weekend', 'Prioritise comfort without losing your personality.'),
    ]);
  }

  void _sheet(String title, IconData icon, List<Widget> children) {
    showModalBottomSheet<void>(context: context, showDragHandle: true, backgroundColor: _cream, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))), builder: (_) => SafeArea(child: SingleChildScrollView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 28), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Container(width: 44, height: 44, decoration: const BoxDecoration(color: _softPink, shape: BoxShape.circle), child: Icon(icon, color: _brown)), const SizedBox(width: 12), Expanded(child: Text(title, style: const TextStyle(color: _text, fontSize: 21, fontWeight: FontWeight.w700)))]), const SizedBox(height: 20), ...children]))));
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