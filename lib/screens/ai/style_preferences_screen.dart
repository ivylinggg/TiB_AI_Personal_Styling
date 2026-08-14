import 'package:flutter/material.dart';

import '../../screens/auth/auth_service.dart';
import '../../services/style_preference_service.dart';

class StylePreferencesScreen extends StatefulWidget {
  const StylePreferencesScreen({super.key});

  @override
  State<StylePreferencesScreen> createState() => _StylePreferencesScreenState();
}

class _StylePreferencesScreenState extends State<StylePreferencesScreen> {
  static const Color _brown = Color(0xFF8E5E46);
  static const Color _softPink = Color(0xFFF8E3DC);
  static const Color _cream = Color(0xFFFFFAF7);
  static const Color _text = Color(0xFF302A27);
  static const Color _muted = Color(0xFF756B67);

  final Set<String> _styles = <String>{};
  final Set<String> _preferences = <String>{};
  bool _loading = true;
  bool _saving = false;

  static const _styleOptions = [
    ('Minimal', 'Clean and uncomplicated'),
    ('Elegant', 'Polished and timeless'),
    ('Casual', 'Relaxed and effortless'),
    ('Smart Casual', 'Put-together but comfortable'),
    ('Feminine', 'Soft and expressive'),
    ('Trendy', 'Modern and experimental'),
  ];

  static const _preferenceOptions = [
    ('Comfort first', 'I want clothes that feel easy to wear.'),
    ('Keep it simple', 'I prefer fewer pieces and cleaner looks.'),
    ('I like layering', 'I enjoy combining different pieces.'),
    ('I love accessories', 'Accessories are part of my style.'),
  ];

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final user = AuthService.currentUser;

    if (user == null) {
      if (mounted) {
        setState(() => _loading = false);
      }
      return;
    }

    try {
      final data = await StylePreferenceService.getStylePreferences(user.uid);

      if (!mounted) {
        return;
      }

      setState(() {
        _styles
          ..clear()
          ..addAll(List<String>.from(data?['styles'] ?? const []));
        _preferences
          ..clear()
          ..addAll(List<String>.from(data?['preferences'] ?? const []));
        _loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _save() async {
    final user = AuthService.currentUser;

    if (user == null) {
      return;
    }

    if (_styles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choose at least one style you like.')),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      await StylePreferenceService.saveStylePreferences(
        uid: user.uid,
        styles: _styles.toList(),
        preferences: _preferences.toList(),
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Your style preferences have been saved.'),
        ),
      );
      Navigator.pop(context, true);
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not save your preferences. Please try again.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _cream,
      appBar: AppBar(
        backgroundColor: _cream,
        elevation: 0,
        iconTheme: const IconThemeData(color: _text),
        title: const Text(
          'My Style',
          style: TextStyle(color: _text, fontWeight: FontWeight.w700),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _intro(),
                    const SizedBox(height: 16),
                    _selectionSummary(),
                    const SizedBox(height: 26),
                    _sectionTitle(
                      'What feels most like you?',
                      'Choose as many as you like.',
                    ),
                    const SizedBox(height: 12),
                    ..._styleOptions.map(
                      (item) => _optionCard(
                        title: item.$1,
                        subtitle: item.$2,
                        selected: _styles.contains(item.$1),
                        onTap: () => setState(() {
                          if (_styles.contains(item.$1)) {
                            _styles.remove(item.$1);
                          } else {
                            _styles.add(item.$1);
                          }
                        }),
                      ),
                    ),
                    const SizedBox(height: 20),
                    _sectionTitle(
                      'What matters when you get dressed?',
                      'A little more detail helps your recommendations feel personal.',
                    ),
                    const SizedBox(height: 12),
                    ..._preferenceOptions.map(
                      (item) => _optionCard(
                        title: item.$1,
                        subtitle: item.$2,
                        selected: _preferences.contains(item.$1),
                        onTap: () => setState(() {
                          if (_preferences.contains(item.$1)) {
                            _preferences.remove(item.$1);
                          } else {
                            _preferences.add(item.$1);
                          }
                        }),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _softPink,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Text(
                        'There is no right style. These choices simply help your stylist understand you better.',
                        style: TextStyle(
                          color: _muted,
                          height: 1.45,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _saving ? null : _save,
                        icon: _saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.favorite_border_rounded),
                        label: Text(
                          _saving ? 'Saving your style...' : 'Save My Style',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _brown,
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(52),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
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

  Widget _intro() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF4D5C8), Color(0xFFF9EAE5)],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: const Row(
        children: [
          Icon(Icons.auto_awesome_rounded, color: _brown, size: 32),
          SizedBox(width: 14),
          Expanded(
            child: Text(
              'Tell me a little about your style. I will use it to make future suggestions feel more like you.',
              style: TextStyle(
                color: _text,
                fontSize: 15,
                height: 1.45,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _selectionSummary() {
    final styleCount = _styles.length;
    final preferenceCount = _preferences.length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFF0DDD2)),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 20,
            backgroundColor: _softPink,
            child: Icon(Icons.tune_rounded, color: _brown),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              styleCount == 0 && preferenceCount == 0
                  ? 'Start with what feels most like you.'
                  : '$styleCount style ${styleCount == 1 ? 'choice' : 'choices'} · $preferenceCount ${preferenceCount == 1 ? 'preference' : 'preferences'} selected',
              style: const TextStyle(
                color: _text,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: _text,
            fontSize: 19,
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
  }

  Widget _optionCard({
    required String title,
    required String subtitle,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: selected ? _brown : _softPink,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    selected ? Icons.check_rounded : Icons.add_rounded,
                    color: selected ? Colors.white : _brown,
                  ),
                ),
                const SizedBox(width: 13),
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
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: _muted,
                          fontSize: 12.5,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                if (selected)
                  const Icon(Icons.favorite_rounded, color: _brown, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
