import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import 'staff_detail_screen.dart';

class StaffManagementScreen extends StatefulWidget {
  const StaffManagementScreen({super.key});

  @override
  State<StaffManagementScreen> createState() => _StaffManagementScreenState();
}

class _StaffManagementScreenState extends State<StaffManagementScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _staff = [];
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _filtered = [];
  bool _loading = true;
  bool _saving = false;
  String _status = 'All';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_filter);
    _loadStaff();
  }

  @override
  void dispose() {
    _searchController.removeListener(_filter);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadStaff() async {
    if (mounted) setState(() => _loading = true);
    try {
      final snapshot = await FirebaseFirestore.instance.collection('users').get();
      final documents = snapshot.docs.where((doc) {
        final role = _text(doc.data()['role']).toLowerCase();
        return role == 'admin' || role == 'staff' || role == 'consultant';
      }).toList()
        ..sort((a, b) => _text(a.data()['name']).toLowerCase().compareTo(
              _text(b.data()['name']).toLowerCase(),
            ));

      if (!mounted) return;
      setState(() {
        _staff = documents;
        _loading = false;
      });
      _filter();
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not load staff. Please try again.')),
      );
    }
  }

  String _text(dynamic value, {String fallback = ''}) {
    if (value == null) return fallback;
    final text = value.toString().trim();
    return text.isEmpty ? fallback : text;
  }

  void _filter() {
    if (!mounted) return;
    final query = _searchController.text.trim().toLowerCase();
    final results = _staff.where((doc) {
      final data = doc.data();
      final active = data['isActive'] as bool? ?? true;
      final name = _text(data['name']).toLowerCase();
      final email = _text(data['email']).toLowerCase();
      final staffId = _text(data['staffId'], fallback: doc.id).toLowerCase();
      final trainer = _text(data['trainerName']).toLowerCase();
      final role = _text(data['role']).toLowerCase();
      final grooming = _text(data['groomingNotes']).toLowerCase();

      final matchesQuery = query.isEmpty ||
          name.contains(query) ||
          email.contains(query) ||
          staffId.contains(query) ||
          trainer.contains(query) ||
          role.contains(query) ||
          grooming.contains(query);
      final matchesStatus = _status == 'All' ||
          (_status == 'Active' && active) ||
          (_status == 'Inactive' && !active);
      return matchesQuery && matchesStatus;
    }).toList();

    setState(() => _filtered = results);
  }

  int get _activeCount => _staff.where((doc) => doc.data()['isActive'] as bool? ?? true).length;

  Future<void> _toggleActive(QueryDocumentSnapshot<Map<String, dynamic>> doc) async {
    final data = doc.data();
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final role = _text(data['role']).toLowerCase();
    if (doc.id == currentUserId && role == 'admin') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You cannot deactivate your own administrator account.')),
      );
      return;
    }

    final active = data['isActive'] as bool? ?? true;
    try {
      await doc.reference.update({
        'isActive': !active,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      await _loadStaff();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(active ? 'Staff account deactivated.' : 'Staff account activated.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not update staff status.')),
      );
    }
  }

  Future<void> _sendPasswordReset(QueryDocumentSnapshot<Map<String, dynamic>> doc) async {
    final email = _text(doc.data()['email']);
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This staff account has no email address.')),
      );
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Send Password Reset?'),
        content: Text('Send a password reset link to $email?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Send')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Password reset email sent to $email.')),
      );
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not send reset email: ${error.message ?? error.code}.')),
      );
    }
  }

  Future<void> _editStaff(QueryDocumentSnapshot<Map<String, dynamic>> doc) async {
    final data = doc.data();
    final name = TextEditingController(text: _text(data['name']));
    final staffId = TextEditingController(text: _text(data['staffId'], fallback: doc.id));
    final email = TextEditingController(text: _text(data['email']));
    final trainer = TextEditingController(text: _text(data['trainerName']));
    final photo = TextEditingController(text: _text(data['photoUrl']));
    final score = TextEditingController(text: _text(data['groomingScore']));
    final notes = TextEditingController(text: _text(data['groomingNotes']));
    var role = _text(data['role'], fallback: 'consultant').toLowerCase();
    if (role == 'staff') role = 'consultant';
    var groomingCompleted = data['groomingCompleted'] as bool? ?? false;

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit Staff Profile'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _dialogField(staffId, 'Staff ID'),
                  _dialogField(name, 'Name'),
                  _dialogField(email, 'Email', keyboardType: TextInputType.emailAddress),
                  _dialogField(trainer, 'Trainer Name'),
                  _dialogField(photo, 'Photo URL', keyboardType: TextInputType.url),
                  DropdownButtonFormField<String>(
                    value: role,
                    decoration: const InputDecoration(labelText: 'Role'),
                    items: const [
                      DropdownMenuItem(value: 'consultant', child: Text('Consultant / Staff')),
                      DropdownMenuItem(value: 'admin', child: Text('Administrator')),
                    ],
                    onChanged: (value) {
                      if (value != null) setDialogState(() => role = value);
                    },
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Grooming Completed', style: TextStyle(fontWeight: FontWeight.w700)),
                    value: groomingCompleted,
                    onChanged: (value) => setDialogState(() => groomingCompleted = value),
                  ),
                  _dialogField(
                    score,
                    'Grooming Score',
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                  _dialogField(notes, 'Grooming Result / Notes', maxLines: 4),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Save')),
          ],
        ),
      ),
    );

    name.dispose();
    staffId.dispose();
    email.dispose();
    trainer.dispose();
    photo.dispose();
    score.dispose();
    notes.dispose();
    if (result != true) return;

    if (staffId.text.trim().isEmpty || name.text.trim().isEmpty || email.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      final scoreValue = double.tryParse(score.text.trim());
      final oldCompleted = data['groomingCompleted'] as bool? ?? false;
      await doc.reference.set({
        'staffId': staffId.text.trim(),
        'name': name.text.trim(),
        'email': email.text.trim(),
        'trainerName': trainer.text.trim(),
        'photoUrl': photo.text.trim(),
        'role': role,
        'groomingCompleted': groomingCompleted,
        'groomingScore': scoreValue ?? (score.text.trim().isEmpty ? null : score.text.trim()),
        'groomingNotes': notes.text.trim(),
        'registeredAt': data['registeredAt'] ?? data['createdAt'] ?? FieldValue.serverTimestamp(),
        'groomingCompletedAt': groomingCompleted
            ? (oldCompleted && data['groomingCompletedAt'] != null
                ? data['groomingCompletedAt']
                : FieldValue.serverTimestamp())
            : null,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      await _loadStaff();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Staff profile updated successfully.')),
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

  Widget _dialogField(
    TextEditingController controller,
    String label, {
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
      ),
    );
  }

  void _openDetails(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => StaffDetailScreen(staffId: doc.id)),
    ).then((_) => _loadStaff());
  }

  Widget _stat(String title, String value, IconData icon) {
    return Expanded(
      child: Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
          child: Column(
            children: [
              Icon(icon, size: 22, color: AppColors.primary),
              const SizedBox(height: 5),
              Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              Text(title, style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _card(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final name = _text(data['name'], fallback: 'Unnamed Staff');
    final email = _text(data['email'], fallback: 'No email');
    final staffId = _text(data['staffId'], fallback: doc.id);
    final trainer = _text(data['trainerName'], fallback: 'Trainer not assigned');
    final role = _text(data['role'], fallback: 'consultant').toLowerCase();
    final active = data['isActive'] as bool? ?? true;
    final completed = data['groomingCompleted'] as bool? ?? false;
    final photo = _text(data['photoUrl']);
    final score = _text(data['groomingScore']);

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: AppColors.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _openDetails(doc),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: AppColors.secondary,
                backgroundImage: photo.isNotEmpty ? NetworkImage(photo) : null,
                child: photo.isEmpty
                    ? const Icon(Icons.person_outline_rounded, color: AppColors.primary, size: 28)
                    : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 3),
                    Text('Staff ID: $staffId', style: TextStyle(color: AppColors.primaryDark, fontWeight: FontWeight.w700, fontSize: 12)),
                    const SizedBox(height: 3),
                    Text(email, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                    const SizedBox(height: 3),
                    Text('Trainer: $trainer', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 5,
                      children: [
                        _badge(role == 'admin' ? 'ADMIN' : 'STAFF', AppColors.surfaceMuted, AppColors.primaryDark),
                        _badge(active ? 'ACTIVE' : 'INACTIVE', active ? AppColors.success.withValues(alpha: .12) : AppColors.error.withValues(alpha: .12), active ? AppColors.success : AppColors.error),
                        _badge(completed ? 'GROOMING DONE' : 'GROOMING PENDING', completed ? AppColors.success.withValues(alpha: .12) : AppColors.surfaceMuted, completed ? AppColors.success : AppColors.textSecondary),
                        if (score.isNotEmpty) _badge('SCORE $score', AppColors.surfaceMuted, AppColors.primaryDark),
                      ],
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'Staff actions',
                onSelected: (value) {
                  if (value == 'details') _openDetails(doc);
                  if (value == 'edit') _editStaff(doc);
                  if (value == 'reset') _sendPasswordReset(doc);
                  if (value == 'toggle') _toggleActive(doc);
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'details', child: Text('View Full Profile')),
                  const PopupMenuItem(value: 'edit', child: Text('Edit Staff & Grooming')),
                  const PopupMenuItem(value: 'reset', child: Text('Send Password Reset')),
                  PopupMenuItem(value: 'toggle', child: Text(active ? 'Deactivate' : 'Activate')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _badge(String label, Color background, Color foreground) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: TextStyle(color: foreground, fontSize: 9, fontWeight: FontWeight.w800)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Staff Management'),
        actions: [
          IconButton(onPressed: _loading ? null : _loadStaff, tooltip: 'Refresh', icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      body: AbsorbPointer(
        absorbing: _saving,
        child: RefreshIndicator(
          onRefresh: _loadStaff,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
                child: Row(
                  children: [
                    _stat('All', _staff.length.toString(), Icons.groups_outlined),
                    const SizedBox(width: 8),
                    _stat('Active', _activeCount.toString(), Icons.verified_user_outlined),
                    const SizedBox(width: 8),
                    _stat('Inactive', (_staff.length - _activeCount).toString(), Icons.person_off_outlined),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search staff ID, name, email, trainer or grooming result',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _searchController.text.isEmpty ? null : IconButton(onPressed: _searchController.clear, icon: const Icon(Icons.clear_rounded)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 8),
                child: Row(
                  children: [
                    for (final value in const ['All', 'Active', 'Inactive']) ...[
                      FilterChip(
                        label: Text(value),
                        showCheckmark: false,
                        selected: _status == value,
                        onSelected: (_) {
                          setState(() => _status = value);
                          _filter();
                        },
                      ),
                      const SizedBox(width: 8),
                    ],
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('${_filtered.length} staff member${_filtered.length == 1 ? '' : 's'}', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                ),
              ),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _filtered.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: const [
                              SizedBox(height: 120),
                              Center(child: Text('No staff found.')),
                            ],
                          )
                        : ListView.builder(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                            itemCount: _filtered.length,
                            itemBuilder: (_, index) => _card(_filtered[index]),
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
