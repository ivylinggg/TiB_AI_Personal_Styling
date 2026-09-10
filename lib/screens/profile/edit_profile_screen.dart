import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../services/firestore_service.dart';
import '../../models/user_model.dart';

class EditProfileScreen extends StatefulWidget {
  final UserModel user;

  const EditProfileScreen({super.key, required this.user});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  static const _genders = ['Female', 'Male', 'Non-binary', 'Prefer not to say'];
  static const _ages = ['Under 18', '18–24', '25–34', '35–44', '45–54', '55+'];
  static const _ethnicities = [
    'White / Caucasian', 'East Asian', 'South Asian', 'Southeast Asian',
    'Middle Eastern', 'Hispanic / Latino', 'Black / African',
    'Mixed / Multiracial', 'Other',
  ];
  static const _occupations = [
    'Student', 'Office / Corporate', 'Business Owner', 'Healthcare',
    'Education / Teacher', 'Hospitality / Service', 'Creative / Design',
    'Beauty / Fashion', 'Sales / Retail', 'Freelancer', 'Homemaker',
    'Retired', 'Currently looking for work', 'Other',
  ];
  static const _brands = [
    'Zara', 'Uniqlo', 'Shein', 'Cotton On', 'H&M', 'Forever 21', 'Mango',
    'Primark', 'Fashion Nova', 'Gap', 'Cider', 'ASOS', 'Romwe', 'Bershka',
    'Target', 'Charlotte Russe', 'Dynamite',
  ];

  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late String? _gender;
  late String? _ageRange;
  late String? _ethnicity;
  late String? _occupation;
  late final TextEditingController _occupationOtherController;
  late List<String> _preferredBrands;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user.name);
    _emailController = TextEditingController(text: widget.user.email);
    _gender = _validOrNull(widget.user.gender, _genders);
    _ageRange = _validOrNull(widget.user.ageRange, _ages);
    _ethnicity = _validOrNull(widget.user.ethnicity, _ethnicities);
    final occupation = widget.user.occupation?.trim();
    if (occupation != null && _occupations.contains(occupation)) {
      _occupation = occupation;
    } else if (occupation != null && occupation.isNotEmpty) {
      _occupation = 'Other';
    } else {
      _occupation = null;
    }
    _occupationOtherController = TextEditingController(
      text: _occupation == 'Other' ? occupation : '',
    );
    _preferredBrands = widget.user.preferredBrands
        .where((brand) => _brands.contains(brand))
        .toList();
  }

  String? _validOrNull(String? value, List<String> options) {
    final clean = value?.trim();
    return clean != null && options.contains(clean) ? clean : null;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _occupationOtherController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    FocusScope.of(context).unfocus();

    final uid = FirebaseAuth.instance.currentUser?.uid;
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    if (uid == null || uid != widget.user.uid) {
      _message('Your account session has changed. Please reopen your profile.');
      return;
    }
    if (name.isEmpty) {
      _message('Please enter your name.');
      return;
    }
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      _message('Please enter a valid Gmail or email address.');
      return;
    }
    if (_occupation == 'Other' && _occupationOtherController.text.trim().isEmpty) {
      _message('Please tell us your occupation.');
      return;
    }

    final currentAuthUser = FirebaseAuth.instance.currentUser!;
    final currentEmail = currentAuthUser.email?.trim() ?? '';
    final emailChanged = email.toLowerCase() != currentEmail.toLowerCase();

    setState(() => _saving = true);
    try {
      // Firebase Authentication remains the source of truth for the login email.
      // Firestore is updated only after the auth email update succeeds.
      if (emailChanged) {
        await currentAuthUser.updateEmail(email);
        await currentAuthUser.reload();
      }

      final occupation = _occupation == 'Other'
          ? _occupationOtherController.text.trim()
          : _occupation;
      await FirestoreService.updateUser(uid, {
        'name': name,
        'email': email,
        'gender': _gender,
        'ageRange': _ageRange,
        'ethnicity': _ethnicity,
        'occupation': occupation,
        'preferredBrands': List<String>.from(_preferredBrands),
        'onboardingProfile': {
          'gender': _gender,
          'ageRange': _ageRange,
          'ethnicity': _ethnicity,
          'preferredBrands': List<String>.from(_preferredBrands),
          'occupation': occupation,
          'occupationCategory': _occupation,
          'source': 'profile_edit',
        },
      });

      if (!mounted) return;
      Navigator.pop(context, true);
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      final message = switch (error.code) {
        'requires-recent-login' => 'For security, please sign in again before changing your email.',
        'email-already-in-use' => 'That email is already linked to another account.',
        'invalid-email' => 'Please enter a valid email address.',
        'operation-not-allowed' => 'Email changes are not enabled for this sign-in method.',
        _ => error.message ?? 'Could not update your account email.',
      };
      _message(message);
    } catch (error) {
      if (mounted) _message(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _toggleBrand(String brand) {
    setState(() {
      if (_preferredBrands.contains(brand)) {
        _preferredBrands.remove(brand);
      } else if (_preferredBrands.length < 10) {
        _preferredBrands.add(brand);
      } else {
        _message('Choose up to 10 brands.');
      }
    });
  }

  void _message(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message), behavior: SnackBarBehavior.floating));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('VYEA', style: TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 2.7)),
            Text('Edit profile', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
          ],
        ),
        actions: [
          TextButton(onPressed: _saving ? null : _save, child: const Text('Save')),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
        children: [
          _introCard(),
          const SizedBox(height: 22),
          _sectionTitle('ACCOUNT DETAILS'),
          const SizedBox(height: 8),
          _card([
            _textField('Name', _nameController, Icons.person_outline_rounded),
            const Divider(height: 1),
            _textField('Gmail / Email', _emailController, Icons.mail_outline_rounded, keyboardType: TextInputType.emailAddress),
          ]),
          const SizedBox(height: 22),
          _sectionTitle('ABOUT YOU'),
          const SizedBox(height: 8),
          _card([
            _dropdown('Gender', _gender, _genders, (value) => setState(() => _gender = value)),
            const Divider(height: 1),
            _dropdown('Age range', _ageRange, _ages, (value) => setState(() => _ageRange = value)),
            const Divider(height: 1),
            _dropdown('Ethnicity', _ethnicity, _ethnicities, (value) => setState(() => _ethnicity = value)),
            const Divider(height: 1),
            _dropdown('Occupation', _occupation, _occupations, (value) => setState(() => _occupation = value)),
            if (_occupation == 'Other') ...[
              const Divider(height: 1),
              _textField('Your occupation', _occupationOtherController, Icons.work_outline_rounded),
            ],
          ]),
          const SizedBox(height: 22),
          _sectionTitle('FAVOURITE BRANDS'),
          const SizedBox(height: 8),
          _brandCard(),
          const SizedBox(height: 22),
          _sectionTitle('COLOUR PROFILE'),
          const SizedBox(height: 8),
          _infoCard(
            Icons.palette_outlined,
            'Colour analysis is kept separately',
            'Your season, undertone, brightness, contrast and face-shape analysis are generated from your scan. You can rescan from your profile whenever you want to update them.',
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.check_rounded),
              label: Text(_saving ? 'Saving changes…' : 'Save changes'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _introCard() => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.border)),
        child: const Row(
          children: [
            CircleAvatar(backgroundColor: AppColors.secondary, child: Icon(Icons.edit_outlined, color: AppColors.primary)),
            SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Keep your style profile current', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
              SizedBox(height: 4),
              Text('These are the details you gave VYEA during sign-up and your personal style questions. Changes are used for future recommendations.', style: TextStyle(color: AppColors.textSecondary, fontSize: 11.5, height: 1.4)),
            ])),
          ],
        ),
      );

  Widget _sectionTitle(String title) => Text(title, style: const TextStyle(color: AppColors.textMuted, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.4));

  Widget _card(List<Widget> children) => Container(
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.border)),
        child: Column(children: children),
      );

  Widget _textField(String label, TextEditingController controller, IconData icon, {TextInputType? keyboardType}) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 5, 16, 5),
        child: TextField(
          controller: controller,
          keyboardType: keyboardType,
          enabled: !_saving,
          decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon), border: InputBorder.none),
        ),
      );

  Widget _dropdown(String label, String? value, List<String> options, ValueChanged<String?> onChanged) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        child: DropdownButtonFormField<String>(
          initialValue: value,
          decoration: InputDecoration(labelText: label, prefixIcon: const Icon(Icons.tune_rounded), border: InputBorder.none),
          items: options.map((option) => DropdownMenuItem(value: option, child: Text(option))).toList(),
          onChanged: _saving ? null : onChanged,
        ),
      );

  Widget _brandCard() => Container(
        padding: const EdgeInsets.fromLTRB(16, 15, 16, 16),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.border)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${_preferredBrands.length}/10 selected', style: const TextStyle(color: AppColors.textSecondary, fontSize: 11.5, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: _brands.map((brand) => FilterChip(
                label: Text(brand, style: const TextStyle(fontSize: 11)),
                selected: _preferredBrands.contains(brand),
                onSelected: _saving ? null : (_) => _toggleBrand(brand),
              )).toList(),
            ),
          ],
        ),
      );

  Widget _infoCard(IconData icon, String title, String subtitle) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.border)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          CircleAvatar(backgroundColor: AppColors.secondary, child: Icon(icon, color: AppColors.primary)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.w900)), const SizedBox(height: 4), Text(subtitle, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11.5, height: 1.4))])),
        ]),
      );
}
