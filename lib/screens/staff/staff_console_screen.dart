import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_gradients.dart';
import '../auth/login_screen.dart';

class StaffConsoleScreen extends StatefulWidget {
  const StaffConsoleScreen({super.key});

  @override
  State<StaffConsoleScreen> createState() => _StaffConsoleScreenState();
}

class _StaffConsoleScreenState extends State<StaffConsoleScreen> {
  final _formKey = GlobalKey<FormState>();
  final _trainerController = TextEditingController();
  final _scoreController = TextEditingController();
  final _notesController = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  bool _groomingCompleted = false;
  Map<String, dynamic> _profile = {};

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _trainerController.dispose();
    _scoreController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (mounted) {
        setState(() => _loading = false);
      }
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final data = doc.data() ?? {};
      if (!mounted) return;
      setState(() {
        _profile = data;
        _trainerController.text = _text(data['trainerName']);
        _scoreController.text = _text(data['groomingScore']);
        _notesController.text = _text(data['groomingNotes']);
        _groomingCompleted = data['groomingCompleted'] as bool? ?? false;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      _message('Unable to load your staff profile.');
    }
  }

  String _text(dynamic value) => value?.toString().trim() ?? '';

  Future<void> _saveGrooming() async {
    if (!_formKey.currentState!.validate()) return;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final scoreText = _scoreController.text.trim();
    final score = double.tryParse(scoreText);
    if (scoreText.isNotEmpty && score == null) {
      _message('Grooming score must be a valid number.');
      return;
    }
    if (score != null && (score < 0 || score > 100)) {
      _message('Grooming score must be between 0 and 100.');
      return;
    }

    setState(() => _saving = true);
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'trainerName': _trainerController.text.trim(),
        'groomingCompleted': _groomingCompleted,
        'groomingScore': score,
        'groomingNotes': _notesController.text.trim(),
        'groomingCompletedAt': _groomingCompleted
            ? (_profile['groomingCompletedAt'] ?? FieldValue.serverTimestamp())
            : null,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await _loadProfile();
      if (!mounted) return;
      _message('Staff profile updated successfully.');
    } on FirebaseException catch (error) {
      _message(error.message ?? 'Unable to save your staff profile.');
    } catch (_) {
      _message('Unable to save your staff profile.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text), behavior: SnackBarBehavior.floating));
  }

  Widget _valueCard(String label, String value, IconData icon) {
    return Expanded(
      child: Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              Icon(icon, color: AppColors.primary),
              const SizedBox(height: 6),
              Text(value.isEmpty ? '—' : value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              const SizedBox(height: 3),
              Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final name = _text(_profile['name']);
    final staffId = _text(_profile['staffId']);
    final email = _text(_profile['email']);
    final role = _text(_profile['role']);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Staff Console'),
        actions: [
          IconButton(
            tooltip: 'Log out',
            onPressed: _saving ? null : _logout,
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadProfile,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 32),
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
              decoration: BoxDecoration(
                gradient: AppGradients.blush,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 31,
                    backgroundColor: Colors.white.withValues(alpha: .82),
                    backgroundImage: _text(_profile['photoUrl']).isNotEmpty
                        ? NetworkImage(_text(_profile['photoUrl']))
                        : null,
                    child: _text(_profile['photoUrl']).isEmpty
                        ? const Icon(Icons.badge_outlined, color: AppColors.primaryDark, size: 29)
                        : null,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name.isEmpty ? 'Staff Member' : name, style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w900)),
                        const SizedBox(height: 4),
                        Text(staffId.isEmpty ? 'Staff ID not assigned' : 'Staff ID: $staffId', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                        const SizedBox(height: 3),
                        Text(email, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                _valueCard('Role', role.isEmpty ? 'Staff' : role, Icons.work_outline_rounded),
                const SizedBox(width: 8),
                _valueCard('Status', _profile['isActive'] == false ? 'Inactive' : 'Active', Icons.verified_user_outlined),
                const SizedBox(width: 8),
                _valueCard('Grooming', _groomingCompleted ? 'Done' : 'Pending', Icons.check_circle_outline_rounded),
              ],
            ),
            const SizedBox(height: 22),
            const Text('Grooming & Training', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
            const SizedBox(height: 5),
            const Text('Keep your staff training record updated for the administrator.', style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5)),
            const SizedBox(height: 16),
            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _trainerController,
                    decoration: const InputDecoration(
                      labelText: 'Trainer Name',
                      prefixIcon: Icon(Icons.school_outlined),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile.adaptive(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                    title: const Text('Grooming Completed', style: TextStyle(fontWeight: FontWeight.w800)),
                    subtitle: const Text('Mark this when the grooming assessment has been completed.'),
                    value: _groomingCompleted,
                    onChanged: _saving ? null : (value) => setState(() => _groomingCompleted = value),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _scoreController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Grooming Score',
                      hintText: '0 – 100',
                      prefixIcon: Icon(Icons.star_outline_rounded),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _notesController,
                    maxLines: 6,
                    decoration: const InputDecoration(
                      labelText: 'Grooming Result / Notes',
                      hintText: 'Add training feedback, strengths and areas to improve...',
                      alignLabelWithHint: true,
                      prefixIcon: Padding(
                        padding: EdgeInsets.only(bottom: 72),
                        child: Icon(Icons.notes_rounded),
                      ),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _saving ? null : _saveGrooming,
                      icon: _saving
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.save_outlined),
                      label: Text(_saving ? 'Saving...' : 'Save Staff Record'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Card(
              elevation: 0,
              child: const Padding(
                padding: EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline_rounded),
                    SizedBox(width: 11),
                    Expanded(
                      child: Text(
                        'Your administrator can review your Staff ID, trainer, grooming status, score and notes from Staff Management.',
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
