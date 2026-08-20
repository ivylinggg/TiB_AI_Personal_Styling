import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';

class PersonalBrandScreen extends StatefulWidget {
  const PersonalBrandScreen({super.key});

  @override
  State<PersonalBrandScreen> createState() => _PersonalBrandScreenState();
}

class _PersonalBrandScreenState extends State<PersonalBrandScreen> {
  static const roles = ['Student', 'Professional', 'Entrepreneur', 'Creative', 'Sales / Client-facing', 'Other'];
  static const impressions = ['Professional', 'Confident', 'Creative', 'Approachable', 'Elegant', 'Trustworthy', 'Energetic', 'Modern'];

  final _statementController = TextEditingController();
  String? _role;
  final List<String> _impressions = [];
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _statementController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final data = doc.data()?['personalBrand'];
      if (mounted) {
        setState(() {
          if (data is Map<String, dynamic>) {
            _role = data['role'] as String?;
            _impressions
              ..clear()
              ..addAll(List<String>.from(data['impressions'] ?? const []));
            _statementController.text = data['statement'] as String? ?? '';
          }
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || _saving) return;
    setState(() => _saving = true);
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'personalBrand': {
          'role': _role,
          'impressions': List<String>.from(_impressions),
          'statement': _statementController.text.trim(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
      }, SetOptions(merge: true));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Personal Brand saved.')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not save your Personal Brand yet.')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: const Text('Personal Brand'),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.primary, AppColors.primaryDark],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('YOUR PERSONAL BRAND', style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.1)),
                      SizedBox(height: 8),
                      Text('How do you want to be remembered?', style: TextStyle(color: Colors.white, fontSize: 25, fontWeight: FontWeight.w800, height: 1.08)),
                      SizedBox(height: 8),
                      Text('TiB will use this direction when shaping professional styling ideas, colours and outfit recommendations.', style: TextStyle(color: Colors.white70, fontSize: 12.5, height: 1.45)),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const Text('YOUR ROLE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: .7, color: AppColors.textMuted)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _role,
                  decoration: _decoration('Choose your main context'),
                  items: roles.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                  onChanged: (value) => setState(() => _role = value),
                ),
                const SizedBox(height: 20),
                const Text('HOW YOU WANT TO COME ACROSS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: .7, color: AppColors.textMuted)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.border)),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: impressions.map((item) {
                      final selected = _impressions.contains(item);
                      return FilterChip(
                        label: Text(item),
                        selected: selected,
                        onSelected: (value) => setState(() {
                          if (value) {
                            if (_impressions.length < 4) _impressions.add(item);
                          } else {
                            _impressions.remove(item);
                          }
                        }),
                        selectedColor: AppColors.primarySoft,
                        checkmarkColor: AppColors.primaryDark,
                        side: BorderSide(color: selected ? AppColors.primary.withValues(alpha: .25) : AppColors.border),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 20),
                const Text('MY SIGNATURE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: .7, color: AppColors.textMuted)),
                const SizedBox(height: 8),
                TextField(
                  controller: _statementController,
                  maxLines: 4,
                  maxLength: 180,
                  decoration: _decoration('Example: Warm, polished and approachable.').copyWith(alignLabelWithHint: true),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving ? const SizedBox(width: 17, height: 17, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.save_outlined),
                    label: Text(_saving ? 'Saving…' : 'Save Personal Brand'),
                    style: FilledButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, minimumSize: const Size.fromHeight(52), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                  ),
                ),
              ],
            ),
    );
  }

  InputDecoration _decoration(String hint) => InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.primary, width: 1.2)),
      );
}
