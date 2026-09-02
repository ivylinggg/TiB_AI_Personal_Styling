import 'package:cloud_functions/cloud_functions.dart';
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
  final _password = TextEditingController();
  final _score = TextEditingController();
  final _notes = TextEditingController();
  bool _groomingCompleted = false;
  bool _obscurePassword = true;
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
      _password,
      _score,
      _notes,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final scoreText = _score.text.trim();
    final scoreValue = double.tryParse(scoreText);
    if (scoreText.isNotEmpty && scoreValue == null) {
      _message('Grooming score must be a valid number.');
      return;
    }

    setState(() => _saving = true);
    try {
      final callable = FirebaseFunctions.instanceFor(region: 'asia-southeast1')
          .httpsCallable('createStaffAccount');
      final result = await callable.call(<String, dynamic>{
        'staffId': _staffId.text.trim(),
        'name': _name.text.trim(),
        'email': _email.text.trim().toLowerCase(),
        'trainerName': _trainer.text.trim(),
        'photoUrl': _photo.text.trim(),
        'password': _password.text,
        'role': _role,
        'groomingCompleted': _groomingCompleted,
        'groomingScore': scoreValue,
        'groomingNotes': _notes.text.trim(),
      });

      final data = result.data;
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Staff Account Created'),
          content: Text(
            'The Firebase Authentication account and staff profile are ready.\n\n'
            'Staff ID: ${data is Map ? data['staffId'] ?? _staffId.text.trim() : _staffId.text.trim()}\n'
            'Email: ${data is Map ? data['email'] ?? _email.text.trim() : _email.text.trim()}\n\n'
            'The staff member can sign in with the temporary password and use Forgot password later to set a new password.',
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
    } on FirebaseFunctionsException catch (error) {
      _message(_functionsError(error));
    } catch (_) {
      _message('Could not create staff account. Please try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _functionsError(FirebaseFunctionsException error) {
    switch (error.code) {
      case 'unauthenticated':
        return 'Your admin session has expired. Please sign in again.';
      case 'permission-denied':
        return 'Only an active administrator can create staff accounts.';
      case 'already-exists':
        return error.message ?? 'The Staff ID or email is already registered.';
      case 'invalid-argument':
        return error.message ?? 'Please check the staff details.';
      case 'unavailable':
        return 'Staff account service is temporarily unavailable.';
      default:
        return error.message ?? 'Could not create staff account.';
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
                      Icon(Icons.verified_user_outlined),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'This creates a real Firebase Authentication account and the matching staff profile. Only active administrators can use this flow.',
                          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              _field(_staffId, 'Staff ID', validator: (value) => _required(value, 'Staff ID')),
              _field(_name, 'Name', validator: (value) => _required(value, 'Name')),
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
              TextFormField(
                controller: _password,
                obscureText: _obscurePassword,
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Temporary password is required';
                  if (value.length < 8) return 'Use at least 8 characters';
                  return null;
                },
                decoration: InputDecoration(
                  labelText: 'Temporary Password',
                  helperText: 'Give this password to the staff member securely.',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
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
                onChanged: (value) => setState(() => _role = value ?? 'consultant'),
              ),
              const SizedBox(height: 12),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Grooming Completed',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                value: _groomingCompleted,
                onChanged: (value) => setState(() => _groomingCompleted = value),
              ),
              _field(
                _score,
                'Grooming Score',
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
                label: Text(_saving ? 'Creating account...' : 'Create Staff Account'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
