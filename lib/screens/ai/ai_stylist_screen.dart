import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/analysis_provider.dart';

class AIStylistScreen extends StatefulWidget {
  const AIStylistScreen({super.key});

  @override
  State<AIStylistScreen> createState() => _AIStylistScreenState();
}

class _AIStylistScreenState extends State<AIStylistScreen> {
  String _selectedOccasion = 'Everyday';

  static const Color _brown = Color(0xFF8E5E46);
  static const Color _softPink = Color(0xFFF8E3DC);
  static const Color _cream = Color(0xFFFFFAF7);
  static const Color _text = Color(0xFF302A27);
  static const Color _muted = Color(0xFF756B67);

  @override
  Widget build(BuildContext context) {
    final result = context.watch<AnalysisProvider>().result;

    final season = result?.season ?? 'Your colour profile';
    final undertone = result?.undertone ?? 'Not analysed yet';
    final colours = result?.colours ?? const <String>[];

    return Scaffold(
      backgroundColor: _cream,
      appBar: AppBar(
        backgroundColor: _cream,
        elevation: 0,
        title: const Text(
          'Styling Assistant',
          style: TextStyle(
            color: _text,
            fontWeight: FontWeight.w700,
          ),
        ),
        iconTheme: const IconThemeData(color: _text),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildWelcomeCard(season, undertone),
              const SizedBox(height: 22),
              _buildProfileStrip(season, undertone, colours),
              const SizedBox(height: 28),
              _buildSectionTitle(
                'What are you dressing for?',
                'Tell me the situation and I will help you put it together.',
              ),
              const SizedBox(height: 14),
              _buildOccasionSelector(),
              const SizedBox(height: 22),
              _buildMainRecommendation(result, colours),
              const SizedBox(height: 28),
              _buildSectionTitle(
                'A little help, when you need it',
                'Choose what you want to figure out today.',
              ),
              const SizedBox(height: 14),
              _buildHelpGrid(),
              const SizedBox(height: 28),
              _buildPersonalNote(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeCard(String season, String undertone) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF4D5C8), Color(0xFFF9EAE5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(26),
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
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Let’s make getting dressed easier.',
                  style: TextStyle(
                    color: _text,
                    fontSize: 21,
                    height: 1.2,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  season == 'Your colour profile'
                      ? 'Start with your colour analysis and I’ll help you make choices that feel like you.'
                      : 'I’ll use your $season profile and $undertone undertone to guide today’s choices.',
                  style: const TextStyle(
                    color: _muted,
                    height: 1.45,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileStrip(
    String season,
    String undertone,
    List<String> colours,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
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
                  style: TextStyle(
                    color: _muted,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  season == 'Your colour profile'
                      ? 'Complete your colour analysis'
                      : '$season · $undertone undertone',
                  style: const TextStyle(
                    color: _text,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          if (colours.isNotEmpty)
            Row(
              children: colours.take(3).map((colour) {
                return Container(
                  width: 22,
                  height: 22,
                  margin: const EdgeInsets.only(left: 5),
                  decoration: BoxDecoration(
                    color: _colourFromName(colour),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, String subtitle) {
    return Column(
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
        const SizedBox(height: 5),
        Text(
          subtitle,
          style: const TextStyle(
            color: _muted,
            fontSize: 13,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  Widget _buildOccasionSelector() {
    const occasions = [
      'Everyday',
      'Work',
      'Date',
      'Event',
      'Weekend',
    ];

    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: occasions.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final occasion = occasions[index];
          final selected = occasion == _selectedOccasion;

          return ChoiceChip(
            label: Text(occasion),
            selected: selected,
            onSelected: (_) {
              setState(() => _selectedOccasion = occasion);
            },
            selectedColor: _brown,
            backgroundColor: Colors.white,
            side: BorderSide(
              color: selected ? _brown : const Color(0xFFE5DAD4),
            ),
            labelStyle: TextStyle(
              color: selected ? Colors.white : _text,
              fontWeight: FontWeight.w600,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMainRecommendation(
    dynamic result,
    List<String> colours,
  ) {
    final hasProfile = result != null;
    final primaryColour = colours.isNotEmpty ? colours.first : 'Soft neutral';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
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
                  color: _softPink,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _selectedOccasion,
                  style: const TextStyle(
                    color: _brown,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Spacer(),
              const Icon(
                Icons.favorite_border_rounded,
                color: _brown,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            hasProfile
                ? 'A simple look to start with'
                : 'Your first styling idea',
            style: const TextStyle(
              color: _text,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            hasProfile
                ? 'Try $primaryColour as your main colour, then keep the rest of the outfit calm so your natural colouring stays the focus.'
                : 'Complete your colour analysis first. Then your suggestions can feel personal instead of generic.',
            style: const TextStyle(
              color: _muted,
              fontSize: 14,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 18),
          _buildOutfitRow(
            Icons.checkroom_outlined,
            'Main piece',
            hasProfile ? primaryColour : 'Your best colour',
          ),
          const SizedBox(height: 11),
          _buildOutfitRow(
            Icons.layers_outlined,
            'Keep it balanced',
            'One neutral layer',
          ),
          const SizedBox(height: 11),
          _buildOutfitRow(
            Icons.auto_awesome_outlined,
            'Finishing touch',
            'A small personal detail',
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _showStylingIdeas(hasProfile),
              icon: const Icon(Icons.arrow_forward_rounded),
              label: const Text('Build this look'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _brown,
                foregroundColor: Colors.white,
                elevation: 0,
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOutfitRow(IconData icon, String title, String value) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: const BoxDecoration(
            color: _softPink,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 20, color: _brown),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: _muted,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  color: _text,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHelpGrid() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.12,
      children: [
        _buildHelpCard(
          Icons.checkroom_outlined,
          'Outfit ideas',
          'Put together a complete look.',
          () => _showStylingIdeas(true),
        ),
        _buildHelpCard(
          Icons.palette_outlined,
          'Mix & match',
          'Find colours that work together.',
          () => _showColourIdeas(),
        ),
        _buildHelpCard(
          Icons.shopping_bag_outlined,
          'Shopping help',
          'Know what colours to look for.',
          () => _showShoppingIdeas(),
        ),
        _buildHelpCard(
          Icons.event_outlined,
          'Dress for it',
          'Make an occasion feel effortless.',
          () => _showOccasionIdeas(),
        ),
      ],
    );
  }

  Widget _buildHelpCard(
    IconData icon,
    String title,
    String description,
    VoidCallback onTap,
  ) {
    return Material(
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
                  color: _softPink,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: _brown),
              ),
              const Spacer(),
              Text(
                title,
                style: const TextStyle(
                  color: _text,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _muted,
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPersonalNote() {
    return Container(
      width: double.infinity,
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
              style: TextStyle(
                color: _muted,
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showStylingIdeas(bool hasProfile) {
    _showBottomSheet(
      title: 'Let’s build your look',
      icon: Icons.checkroom_outlined,
      children: [
        _sheetText(
          hasProfile
              ? 'For $_selectedOccasion, start with one colour you already know suits you.'
              : 'Once you complete your colour analysis, we can make this more personal.',
        ),
        _sheetItem('Top', 'Choose your most flattering colour.'),
        _sheetItem('Bottom', 'Keep the base simple and comfortable.'),
        _sheetItem('Shoes & accessories', 'Add one detail that feels like you.'),
      ],
    );
  }

  void _showColourIdeas() {
    final result = context.read<AnalysisProvider>().result;
    final colours = result?.colours ?? const <String>[];

    _showBottomSheet(
      title: 'Mix & match',
      icon: Icons.palette_outlined,
      children: [
        _sheetText(
          colours.isEmpty
              ? 'Complete your colour analysis to see your personalised palette here.'
              : 'Try pairing one of your recommended colours with a soft neutral. This keeps the outfit easy to wear.',
        ),
        if (colours.isNotEmpty)
          ...colours.take(5).map(
                (colour) => _sheetItem(
                  colour,
                  'Use it as a main piece, accent or accessory.',
                ),
              ),
      ],
    );
  }

  void _showShoppingIdeas() {
    _showBottomSheet(
      title: 'Shopping assistant',
      icon: Icons.shopping_bag_outlined,
      children: [
        _sheetText(
          'Before buying something new, ask yourself: does it work with at least three pieces you already own?',
        ),
        _sheetItem('Look for', 'Colours from your personal palette.'),
        _sheetItem('Prioritise', 'Pieces you can wear in more than one way.'),
        _sheetItem('Skip', 'Items you only like because they are trending.'),
      ],
    );
  }

  void _showOccasionIdeas() {
    _showBottomSheet(
      title: 'Dress for the occasion',
      icon: Icons.event_outlined,
      children: [
        _sheetItem('Work', 'Polished, comfortable and easy to repeat.'),
        _sheetItem('Date', 'Keep your favourite colour close to your face.'),
        _sheetItem('Event', 'Choose one statement piece and keep the rest balanced.'),
        _sheetItem('Weekend', 'Prioritise comfort without losing your personal style.'),
      ],
    );
  }

  void _showBottomSheet({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: _cream,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        color: _softPink,
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
        );
      },
    );
  }

  Widget _sheetText(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Text(
        text,
        style: const TextStyle(
          color: _muted,
          height: 1.5,
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _sheetItem(String title, String description) {
    return Container(
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
            style: const TextStyle(
              color: _text,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: const TextStyle(
              color: _muted,
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Color _colourFromName(String name) {
    final value = name.toLowerCase();

    if (value.contains('pink') || value.contains('rose')) {
      return const Color(0xFFE8A7B7);
    }
    if (value.contains('red') || value.contains('coral')) {
      return const Color(0xFFD97968);
    }
    if (value.contains('orange') || value.contains('peach')) {
      return const Color(0xFFE7A16F);
    }
    if (value.contains('yellow') || value.contains('gold')) {
      return const Color(0xFFD8B85A);
    }
    if (value.contains('green') || value.contains('olive')) {
      return const Color(0xFF8A9A68);
    }
    if (value.contains('blue') || value.contains('navy')) {
      return const Color(0xFF7189A8);
    }
    if (value.contains('purple') || value.contains('violet')) {
      return const Color(0xFF9A7AA8);
    }
    if (value.contains('brown') || value.contains('beige') || value.contains('neutral')) {
      return const Color(0xFFB59A83);
    }

    return const Color(0xFFC9B7AD);
  }
}
