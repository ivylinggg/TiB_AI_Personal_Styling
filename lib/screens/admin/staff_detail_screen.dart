import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';

class StaffDetailScreen extends StatefulWidget {
  final String staffId;

  const StaffDetailScreen({super.key, required this.staffId});

  @override
  State<StaffDetailScreen> createState() => _StaffDetailScreenState();
}

class _StaffDetailScreenState extends State<StaffDetailScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _staffIdController = TextEditingController();
  final _emailController = TextEditingController();
  final _trainerController = TextEditingController();
  final _photoController = TextEditingController();
  final _scoreController = TextEditingController();
  final _notesController = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  bool _editing = false;
  bool _groomingCompleted = false;
  String _role = 'consultant';
  DateTime? _registeredAt;
  DateTime? _groomingCompletedAt;

  DocumentReference<Map<String, dynamic>> get _reference =>
      FirebaseFirestore.instance.collection('users').doc(widget.staffId);

  @override
  void initState() {
    super.initState();
    _loadStaff();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _staffIdController.dispose();
    _emailController.dispose();
    _trainerController.dispose();
    _photoController.dispose();
    _scoreController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadStaff() async {
    try {
      final snapshot = await _reference.get();
      final data = snapshot.data() ?? {};
      _nameController.text = _string(data['name']);
      _staffIdController.text = _string(data['staffId'], fallback: widget.staffId);
      _emailController.text = _string(data['email']);
      _trainerController.text = _string(data['trainerName']);
      _photoController.text = _string(data['photoUrl']);
      _scoreController.text = _string(data['groomingScore']);
      _notesController.text = _string(data['groomingNotes']);
      _role = _string(data['role'], fallback: 'consultant').toLowerCase();
      _groomingCompleted = data['groomingCompleted'] as bool? ?? false;
      _registeredAt = _date(data['registeredAt']) ?? _date(data['createdAt']);
      _groomingCompletedAt = _date(data['groomingCompletedAt']);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not load this staff profile.')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _string(dynamic value, {String fallback = ''}) {
    if (value == null) return fallback;
    return value.toString().trim().isEmpty ? fallback : value.toString().trim();
  }

  DateTime? _date(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  String _formatDate(DateTime? value) {
    if (value == null) return 'Not recorded';
    final d = value.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year}';
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final scoreText = _scoreController.text.trim();
    final score = double.tryParse(scoreText);
    final groomingChangedToComplete = _groomingCompleted && _groomingCompletedAt == null;

    try {
      await _reference.set({
        'name': _nameController.text.trim(),
        'staffId': _staffIdController.text.trim(),
        'email': _emailController.text.trim(),
        'trainerName': _trainerController.text.trim(),
        'photoUrl': _photoController.text.trim(),
        'role': _role,
        'groomingCompleted': _groomingCompleted,
        'groomingScore': score ?? (scoreText.isEmpty ? null : scoreText),
        'groomingNotes': _notesController.text.trim(),
        'registeredAt': _registeredAt == null
            ? FieldValue.serverTimestamp()
            : Timestamp.fromDate(_registeredAt!),
        'groomingCompletedAt': _groomingCompleted
            ? Timestamp.fromDate(
                groomingChangedToComplete ? DateTime.now() : _groomingCompletedAt!,
              )
            : null,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;
      setState(() {
        _editing = false;
        if (groomingChangedToComplete) _groomingCompletedAt = DateTime.now();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Staff profile saved successfully.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save the staff profile.')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _sectionTitle(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.primary),
          const SizedBox(width: 8),
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    TextInputType? keyboardType,
    int maxLines = 1,
    bool readOnly = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        readOnly: readOnly || !_editing,
        keyboardType: keyboardType,
        maxLines: maxLines,
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
        validator: (value) {
          if ((label == 'Staff ID' || label == 'Name' || label == 'Email') &&
              (value == null || value.trim().isEmpty)) {
            return '$label is required';
          }
          return null;
        },
      ),
    );
  }

  Widget _statusCard() {
    final color = _groomingCompleted ? AppColors.success : AppColors.textSecondary;
    return Card(
      elevation: 0,
      color: _groomingCompleted
          ? AppColors.success.withValues(alpha: .08)
          : AppColors.surfaceMuted,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color.withValues(alpha: .15),
              child: Icon(
                _groomingCompleted ? Icons.check_rounded : Icons.pending_outlined,
                color: color,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _groomingCompleted ? 'Grooming Completed' : 'Grooming Pending',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 3),
                  Text('Completed: ${_formatDate(_groomingCompletedAt)}'),
                ],
              ),
            ),
            if (_editing)
              Switch(
                value: _groomingCompleted,
                onChanged: (value) => setState(() => _groomingCompleted = value),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final photoUrl = _photoController.text.trim();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Staff Profile'),
        actions: [
          if (!_editing)
            IconButton(
              tooltip: 'Edit profile',
              onPressed: () => setState(() => _editing = true),
              icon: const Icon(Icons.edit_outlined),
            ),
          if (_editing)
            IconButton(
              tooltip: 'Save profile',
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.save_outlined),
            ),
        ],
      ),
      body: AbsorbPointer(
        absorbing: _saving,
        child: Form(
          key: _formKey,
          child: RefreshIndicator(
            onRefresh: _loadStaff,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
              children: [
                Center(
                  child: CircleAvatar(
                    radius: 48,
                    backgroundColor: AppColors.secondary,
                    backgroundImage: photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                    child: photoUrl.isEmpty
                        ? const Icon(Icons.person_outline_rounded, size: 42, color: AppColors.primary)
                        : null,
                  ),
                ),
                const SizedBox(height: 12),
                Center(
                  child: Text(
                    _nameController.text.isEmpty ? 'Staff Member' : _nameController.text,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(height: 4),
                Center(child: Text(_role == 'admin' ? 'Administrator' : 'Consultant / Staff')),
                const SizedBox(height: 22),
                _sectionTitle('Staff Information', Icons.badge_outlined),
                _field(_staffIdController, 'Staff ID'),
                _field(_nameController, 'Name'),
                _field(_emailController, 'Email', keyboardType: TextInputType.emailAddress),
                _field(_trainerController, 'Trainer Name'),
                _field(_photoController, 'Photo URL', keyboardType: TextInputType.url),
                Card(
                  elevation: 0,
                  child: ListTile(
                    leading: const Icon(Icons.event_outlined),
                    title: const Text('Registration Date'),
                    subtitle: Text(_formatDate(_registeredAt)),
                  ),
                ),
                const SizedBox(height: 22),
                _sectionTitle('Grooming Assessment', Icons.fact_check_outlined),
                _statusCard(),
                const SizedBox(height: 12),
                _field(
                  _scoreController,
                  'Grooming Score',
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                _field(_notesController, 'Grooming Notes / Result', maxLines: 5),
                if (_editing) ...[
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: const Icon(Icons.save_rounded),
                    label: const Text('Save Staff Profile'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
