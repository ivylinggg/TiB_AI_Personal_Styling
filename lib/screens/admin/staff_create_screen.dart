import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';

class StaffCreateScreen extends StatefulWidget {
  const StaffCreateScreen({super.key});

  @override
  State<StaffCreateScreen> createState() => _StaffCreateScreenState();
}

class _StaffCreateScreenState extends State<StaffCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _staffId = TextEditingController();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _trainer = TextEditingController();
  final _photo = TextEditingController();
  final _score = TextEditingController();
  final _notes = TextEditingController();
  bool _groomingCompleted = false;
  String _role = 'consultant';
  bool _saving = false;

  @override
  void dispose() {
    for (final controller in [
      _staffId,
      _name,
      _email,
      _trainer,
      _photo,
      _score,
      _notes,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final staffId = _staffId.text.trim();
    final email = _email.text.trim().toLowerCase();
    final scoreText = _score.text.trim();
    final scoreValue = double.tryParse(scoreText);
    if (scoreText.isNotEmpty && scoreValue == null) {
      _message('Grooming score must be a valid number.');
      return;
    }

    setState(() => _saving = true);
    try {
      final users = FirebaseFirestore.instance.collection('users');
      final existingStaff = await users
          .where('staffId', isEqualTo: staffId)
          .limit(1)
          .get();
      if (existingStaff.docs.isNotEmpty) {
        _message('This Staff ID is already registered.');
        return;
      }

      final existingEmail = await users
          .where('email', isEqualTo: email)
          .limit(1)
          .get();
      if (existingEmail.docs.isNotEmpty) {
        _message('This email is already linked to a profile.');
        return;
      }

      final uid = users.doc().id;
      await users.doc(uid).set({
        'uid': uid,
        'staffId': staffId,
        'name': _name.text.trim(),
        'email': email,
        'trainerName': _trainer.text.trim(),
        'photoUrl': _photo.text.trim(),
        'role': _role,
        'isActive': true,
        'isPremium': false,
        'onboardingComplete': true,
        'groomingCompleted': _groomingCompleted,
        'groomingScore': scoreValue,
        'groomingNotes': _notes.text.trim(),
        'registeredAt': FieldValue.serverTimestamp(),
        'groomingCompletedAt': _groomingCompleted
            ? FieldValue.serverTimestamp()
            : null,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Staff Profile Created'),
          content: const Text(
            'The staff profile has been added successfully.\n\n'
            'Authentication account creation is temporarily kept outside this flow while the project remains on Firebase\'s free plan.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Done'),
            ),
          ],
        ),
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } on FirebaseException catch (error) {
      _message(error.message ?? 'Could not create the staff profile.');
    } catch (_) {
      _message('Could not create the staff profile. Please try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String? _required(String? value, String label) {
    if (value == null || value.trim().isEmpty) return '$label is required';
    return null;
  }

  void _message(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    TextInputType? keyboardType,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Register Staff')),
      body: AbsorbPointer(
        absorbing: _saving,
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Card(
                elevation: 0,
                color: AppColors.secondary,
                child: const Padding(
                  padding: EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.badge_outlined),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Create the staff profile now. Firebase Authentication account creation will be added later without blocking the rest of the staff workflow.',
                          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              _field(
                _staffId,
                'Staff ID',
                validator: (value) => _required(value, 'Staff ID'),
              ),
              _field(
                _name,
                'Name',
                validator: (value) => _required(value, 'Name'),
              ),
              _field(
                _email,
                'Email',
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  final required = _required(value, 'Email');
                  if (required != null) return required;
                  final email = value!.trim();
                  if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
                    return 'Enter a valid email address';
                  }
                  return null;
                },
              ),
              _field(_trainer, 'Trainer Name'),
              _field(_photo, 'Photo URL', keyboardType: TextInputType.url),
              DropdownButtonFormField<String>(
                initialValue: _role,
                decoration: const InputDecoration(
                  labelText: 'Role',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'consultant',
                    child: Text('Consultant / Staff'),
                  ),
                  DropdownMenuItem(
                    value: 'admin',
                    child: Text('Administrator'),
                  ),
                ],
                onChanged: (value) => setState(
                  () => _role = value ?? 'consultant',
                ),
              ),
              const SizedBox(height: 12),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Grooming Completed',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                value: _groomingCompleted,
                onChanged: (value) => setState(
                  () => _groomingCompleted = value,
                ),
              ),
              _field(
                _score,
                'Grooming Score',
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
              _field(
                _notes,
                'Grooming Result / Notes',
                maxLines: 5,
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: const Icon(Icons.person_add_alt_1_rounded),
                label: Text(
                  _saving ? 'Saving...' : 'Create Staff Profile',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
