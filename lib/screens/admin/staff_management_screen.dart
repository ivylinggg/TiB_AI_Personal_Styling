import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import 'staff_create_screen.dart';
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
  int get _groomedCount => _staff.where((doc) => doc.data()['groomingCompleted'] as bool? ?? false).length;

  Future<void> _openCreateStaff() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const StaffCreateScreen()),
    );
    if (created == true && mounted) await _loadStaff();
  }

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
                    initialValue: role,
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
                  _dialogField(score, 'Grooming Score', keyboardType: const TextInputType.numberWithOptions(decimal: true)),
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

    if (result != true) {
      name.dispose();
      staffId.dispose();
      email.dispose();
      trainer.dispose();
      photo.dispose();
      score.dispose();
      notes.dispose();
      return;
    }

    final staffIdValue = staffId.text.trim();
    final nameValue = name.text.trim();
    final emailValue = email.text.trim();
    final trainerValue = trainer.text.trim();
    final photoValue = photo.text.trim();
    final scoreText = score.text.trim();
    final notesValue = notes.text.trim();

    name.dispose();
    staffId.dispose();
    email.dispose();
    trainer.dispose();
    photo.dispose();
    score.dispose();
    notes.dispose();

    if (staffIdValue.isEmpty || nameValue.isEmpty || emailValue.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Staff ID, name and email are required.')),
        );
      }
      return;
    }

    setState(() => _saving = true);
    try {
      final scoreValue = double.tryParse(scoreText);
      if (scoreText.isNotEmpty && scoreValue == null) {
        throw const FormatException('Invalid grooming score');
      }
      final oldCompleted = data['groomingCompleted'] as bool? ?? false;
      await doc.reference.set({
        'staffId': staffIdValue,
        'name': nameValue,
        'email': emailValue,
        'trainerName': trainerValue,
        'photoUrl': photoValue,
        'role': role,
        'groomingCompleted': groomingCompleted,
        'groomingScore': scoreValue,
        'groomingNotes': notesValue,
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Staff profile updated successfully.')));
    } on FormatException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Grooming score must be a valid number.')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not save the staff profile.')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _dialogField(TextEditingController controller, String label, {TextInputType? keyboardType, int maxLines = 1}) {
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
                child: photo.isEmpty ? const Icon(Icons.person_outline_rounded, color: AppColors.primary, size: 28) : null,
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
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(10)),
      child: Text(label, style: TextStyle(color: foreground, fontSize: 10, fontWeight: FontWeight.w800)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Staff Management'),
        actions: [
          IconButton(tooltip: 'Refresh', onPressed: _loading ? null : _loadStaff, icon: const Icon(Icons.refresh_rounded)),
          IconButton(tooltip: 'Register Staff', onPressed: _saving ? null : _openCreateStaff, icon: const Icon(Icons.person_add_alt_1_rounded)),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadStaff,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 30),
                children: [
                  Row(children: [
                    _stat('Total', '${_staff.length}', Icons.groups_rounded),
                    const SizedBox(width: 8),
                    _stat('Active', '$_activeCount', Icons.verified_user_outlined),
                    const SizedBox(width: 8),
                    _stat('Groomed', '$_groomedCount', Icons.check_circle_outline_rounded),
                  ]),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search staff ID, name, email, trainer...',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: _searchController.text.isEmpty ? null : IconButton(onPressed: _searchController.clear, icon: const Icon(Icons.clear_rounded)),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'All', label: Text('All')),
                      ButtonSegment(value: 'Active', label: Text('Active')),
                      ButtonSegment(value: 'Inactive', label: Text('Inactive')),
                    ],
                    selected: {_status},
                    onSelectionChanged: (selection) {
                      setState(() => _status = selection.first);
                      _filter();
                    },
                  ),
                  const SizedBox(height: 16),
                  if (_saving) const LinearProgressIndicator(),
                  const SizedBox(height: 8),
                  if (_filtered.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 60),
                      child: Column(
                        children: [
                          Icon(Icons.badge_outlined, size: 54, color: AppColors.textSecondary),
                          const SizedBox(height: 12),
                          const Text('No staff found', style: TextStyle(fontWeight: FontWeight.w800)),
                          const SizedBox(height: 5),
                          Text('Use Register Staff to add the first staff record.', style: TextStyle(color: AppColors.textSecondary)),
                        ],
                      ),
                    )
                  else
                    ..._filtered.map(_card),
                ],
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _saving ? null : _openCreateStaff,
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('Register Staff'),
      ),
    );
  }
}
