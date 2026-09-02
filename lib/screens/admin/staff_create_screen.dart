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
  bool _groomingCompleted = false;
  final _score = TextEditingController();
  final _notes = TextEditingController();
  String _role = 'consultant';
  bool _saving = false;

  @override
  void dispose() {
    for (final controller in [_staffId, _name, _email, _trainer, _photo, _score, _notes]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final staffId = _staffId.text.trim();
    try {
      final existing = await FirebaseFirestore.instance
          .collection('users')
          .where('staffId', isEqualTo: staffId)
          .limit(1)
          .get();
      if (existing.docs.isNotEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('This Staff ID is already registered.')),
        );
        return;
      }

      final uid = FirebaseFirestore.instance.collection('users').doc().id;
      final scoreText = _score.text.trim();
      final scoreValue = double.tryParse(scoreText);
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'uid': uid,
        'staffId': staffId,
        'name': _name.text.trim(),
        'email': _email.text.trim(),
        'trainerName': _trainer.text.trim(),
        'photoUrl': _photo.text.trim(),
        'role': _role,
        'isActive': true,
        'isPremium': false,
        'groomingCompleted': _groomingCompleted,
        'groomingScore': scoreValue ?? (scoreText.isEmpty ? null : scoreText),
        'groomingNotes': _notes.text.trim(),
        'registeredAt': FieldValue.serverTimestamp(),
        'groomingCompletedAt': _groomingCompleted ? FieldValue.serverTimestamp() : null,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Staff account record created successfully.')),
      );
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not create staff record: $error')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _field(TextEditingController controller, String label, {TextInputType? keyboardType, int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
        validator: (value) {
          if ((label == 'Staff ID' || label == 'Name' || label == 'Email') &&
              (value == null || value.trim().isEmpty)) {
            return '$label is required';
          }
          if (label == 'Email' && value != null && !value.contains('@')) return 'Enter a valid email';
          return null;
        },
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
                      Icon(Icons.person_add_alt_1_rounded),
                      SizedBox(width: 12),
                      Expanded(child: Text('Create the staff record first. Firebase Authentication credentials can be created separately by your privileged account flow.', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600))),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              _field(_staffId, 'Staff ID'),
              _field(_name, 'Name'),
              _field(_email, 'Email', keyboardType: TextInputType.emailAddress),
              _field(_trainer, 'Trainer Name'),
              _field(_photo, 'Photo URL', keyboardType: TextInputType.url),
              DropdownButtonFormField<String>(
                initialValue: _role,
                decoration: const InputDecoration(labelText: 'Role', border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 'consultant', child: Text('Consultant / Staff')),
                  DropdownMenuItem(value: 'admin', child: Text('Administrator')),
                ],
                onChanged: (value) => setState(() => _role = value ?? 'consultant'),
              ),
              const SizedBox(height: 12),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Grooming Completed', style: TextStyle(fontWeight: FontWeight.w700)),
                value: _groomingCompleted,
                onChanged: (value) => setState(() => _groomingCompleted = value),
              ),
              _field(_score, 'Grooming Score', keyboardType: const TextInputType.numberWithOptions(decimal: true)),
              _field(_notes, 'Grooming Result / Notes', maxLines: 5),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: const Icon(Icons.person_add_alt_1_rounded),
                label: Text(_saving ? 'Saving...' : 'Register Staff'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
