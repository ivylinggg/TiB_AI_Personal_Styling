import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/constants/app_colors.dart';
import '../../models/user_model.dart';
import '../../services/firestore_service.dart';
import '../ai/ai_stylist_screen.dart';
import '../ai/style_preferences_screen.dart';
import '../auth/login_screen.dart';
import '../wardrobe/wardrobe_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  UserModel? user;
  bool isLoading = true;
  bool isLoggingOut = false;
  bool isUploadingPhoto = false;
  bool isPremium = false;

  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    loadUser();
  }

  Future<void> loadUser() async {
    final firebaseUser = FirebaseAuth.instance.currentUser;

    if (firebaseUser == null) {
      if (!mounted) {
        return;
      }
      setState(() => isLoading = false);
      return;
    }

    try {
      final result = await FirestoreService.getUser(firebaseUser.uid);
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(firebaseUser.uid)
          .get();

      if (!mounted) {
        return;
      }
      setState(() {
        user = result;
        isPremium = userDoc.data()?['isPremium'] as bool? ?? false;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to load profile: $e')),
      );
    }
  }

  Future<void> changeProfilePhoto() async {
    if (isUploadingPhoto) {
      return;
    }

    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser == null) {
      return;
    }

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(24, 4, 24, 12),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Update profile photo',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              ListTile(
                leading: const CircleAvatar(child: Icon(Icons.camera_alt_outlined)),
                title: const Text('Take a photo'),
                onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
              ),
              ListTile(
                leading: const CircleAvatar(child: Icon(Icons.photo_library_outlined)),
                title: const Text('Choose from gallery'),
                onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );

    if (source == null) {
      return;
    }

    try {
      setState(() => isUploadingPhoto = true);

      final picked = await _imagePicker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1200,
      );

      if (picked == null) {
        if (mounted) setState(() => isUploadingPhoto = false);
        return;
      }

      final file = File(picked.path);
      final ref = FirebaseStorage.instance
          .ref()
          .child('profile_photos')
          .child('${firebaseUser.uid}.jpg');

      await ref.putFile(file, SettableMetadata(contentType: 'image/jpeg'));
      final url = await ref.getDownloadURL();

      await FirestoreService.updateUser(firebaseUser.uid, {'photoUrl': url});

      if (!mounted) {
        return;
      }
      setState(() => isUploadingPhoto = false);
      await loadUser();

      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile photo updated.')),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() => isUploadingPhoto = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to update profile photo: $e')),
      );
    }
  }

  Future<void> logout() async {
    if (isLoggingOut) {
      return;
    }

    setState(() => isLoggingOut = true);

    try {
      await FirebaseAuth.instance.signOut();
      if (!mounted) {
        return;
      }
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() => isLoggingOut = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Logout failed: $e')),
      );
    }
  }

  Future<void> confirmLogout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('You can sign in again anytime with your account.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (shouldLogout == true) {
      await logout();
    }
  }

  Future<void> openEditProfile() async {
    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser == null || user == null) {
      return;
    }

    final nameController = TextEditingController(text: user!.name);
    final formKey = GlobalKey<FormState>();

    final updated = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        bool saving = false;

        return StatefulBuilder(
          builder: (dialogContext, setDialogState) => AlertDialog(
            title: const Text('Edit Profile'),
            content: Form(
              key: formKey,
              child: TextFormField(
                controller: nameController,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  labelText: 'Full Name',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Please enter your name.'
                    : null,
              ),
            ),
            actions: [
              TextButton(
                onPressed: saving ? null : () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: saving
                    ? null
                    : () async {
                        if (!formKey.currentState!.validate()) return;
                        setDialogState(() => saving = true);
                        try {
                          await FirestoreService.updateUser(firebaseUser.uid, {
                            'name': nameController.text.trim(),
                          });
                          if (!dialogContext.mounted) return;
                          Navigator.pop(dialogContext, true);
                        } catch (e) {
                          if (!dialogContext.mounted) return;
                          setDialogState(() => saving = false);
                          ScaffoldMessenger.of(dialogContext).showSnackBar(
                            SnackBar(content: Text('Unable to update profile: $e')),
                          );
                        }
                      },
                child: saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save'),
              ),
            ],
          ),
        );
      },
    );

    nameController.dispose();
    if (updated == true) await loadUser();
  }

  Future<void> changePassword() async {
    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser == null || firebaseUser.email == null) {
      return;
    }

    final shouldSendReset = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Change Password'),
        content: Text(
          'A password reset email will be sent to:\n\n${firebaseUser.email}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Send Email'),
          ),
        ],
      ),
    );

    if (shouldSendReset != true) {
      return;
    }

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: firebaseUser.email!,
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password reset email sent. Please check your inbox.')),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'Unable to send password reset email.')),
      );
    }
  }

  void openWardrobe() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const WardrobeScreen()),
    );
  }

  void openAIStylist() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AIStylistScreen()),
    );
  }

  Future<void> openStylePreferences() async {
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => const StylePreferencesScreen(),
      ),
    );

    if (updated == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Your style profile is up to date.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('My Profile'),
        actions: [
          IconButton(
            tooltip: 'Refresh profile',
            onPressed: isLoading ? null : loadUser,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: loadUser,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
                children: [
                  _buildProfileHeader(),
                  const SizedBox(height: 28),
                  _buildPersonalSection(),
                  const SizedBox(height: 28),
                  _buildStyleSection(),
                  const SizedBox(height: 28),
                  _buildAccountSection(),
                  const SizedBox(height: 30),
                  _buildLogoutButton(),
                ],
              ),
            ),
    );
  }

  Widget _buildProfileHeader() {
    final name = user?.name.trim();
    final email = user?.email.trim();

    return Column(
      children: [
        Stack(
          alignment: Alignment.bottomRight,
          children: [
            CircleAvatar(
              radius: 58,
              backgroundColor: const Color(0xFFF5D8C7),
              backgroundImage: user?.photoUrl != null && user!.photoUrl!.isNotEmpty
                  ? NetworkImage(user!.photoUrl!)
                  : null,
              child: user?.photoUrl == null || user!.photoUrl!.isEmpty
                  ? const Icon(Icons.person, size: 58, color: Colors.white)
                  : null,
            ),
            Material(
              color: const Color(0xFFC58F73),
              shape: const CircleBorder(),
              child: InkWell(
                onTap: isUploadingPhoto ? null : changeProfilePhoto,
                customBorder: const CircleBorder(),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: isUploadingPhoto
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.camera_alt_outlined, size: 18, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          name?.isNotEmpty == true ? name! : 'TiB AI User',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 5),
        Text(
          email?.isNotEmpty == true
              ? email!
              : FirebaseAuth.instance.currentUser?.email ?? '',
          style: Theme.of(context).textTheme.bodyMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
          decoration: BoxDecoration(
            color: isPremium ? const Color(0xFFFFF1D8) : const Color(0xFFF4F1EF),
            borderRadius: BorderRadius.circular(30),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isPremium ? Icons.workspace_premium : Icons.person_outline,
                size: 17,
                color: isPremium ? const Color(0xFFB27B27) : Colors.grey.shade700,
              ),
              const SizedBox(width: 7),
              Text(
                isPremium ? 'Premium Member' : 'Free Member',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPersonalSection() {
    return _section(
      title: 'Personal Information',
      children: [
        _buildInfoCard(
          icon: Icons.person_outline,
          title: 'Full Name',
          value: user?.name.isNotEmpty == true ? user!.name : 'Not set',
        ),
        const SizedBox(height: 10),
        _buildInfoCard(
          icon: Icons.email_outlined,
          title: 'Email',
          value: user?.email.isNotEmpty == true ? user!.email : 'Not available',
        ),
        const SizedBox(height: 10),
        _buildInfoCard(
          icon: Icons.palette_outlined,
          title: 'Colour Season',
          value: user?.colourSeason?.isNotEmpty == true
              ? user!.colourSeason!
              : 'Not analysed yet',
        ),
        const SizedBox(height: 10),
        _buildInfoCard(
          icon: Icons.face_outlined,
          title: 'Skin Tone',
          value: user?.skinTone?.isNotEmpty == true
              ? user!.skinTone!
              : 'Not analysed yet',
        ),
      ],
    );
  }

  Widget _buildStyleSection() {
    return _section(
      title: 'My Style',
      children: [
        _actionCard(
          icon: Icons.auto_awesome_outlined,
          title: 'AI Stylist',
          subtitle: 'Get outfit ideas based on your profile and preferences',
          onTap: openAIStylist,
        ),
        const SizedBox(height: 10),
        _actionCard(
          icon: Icons.checkroom_outlined,
          title: 'My Wardrobe',
          subtitle: 'Manage the clothes you already own',
          onTap: openWardrobe,
        ),
        const SizedBox(height: 10),
        _actionCard(
          icon: Icons.tune_rounded,
          title: 'My Style Preferences',
          subtitle: 'Tell your stylist what feels most like you',
          onTap: openStylePreferences,
        ),
        const SizedBox(height: 10),
        _actionCard(
          icon: Icons.edit_outlined,
          title: 'Edit Profile',
          subtitle: 'Update your personal information',
          onTap: openEditProfile,
        ),
      ],
    );
  }

  Widget _buildAccountSection() {
    return _section(
      title: 'Account & Security',
      children: [
        _actionCard(
          icon: Icons.lock_outline,
          title: 'Change Password',
          subtitle: 'Send a secure password reset email',
          onTap: changePassword,
        ),
        const SizedBox(height: 10),
        _actionCard(
          icon: Icons.verified_user_outlined,
          title: 'Account Status',
          subtitle: user?.isActive == true
              ? 'Your account is active and ready to use'
              : 'Your account is currently inactive',
          trailing: Icon(
            user?.isActive == true ? Icons.check_circle : Icons.error_outline,
            color: user?.isActive == true ? Colors.green : Colors.red,
          ),
        ),
      ],
    );
  }

  Widget _buildLogoutButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: isLoggingOut ? null : confirmLogout,
        icon: isLoggingOut
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.logout),
        label: Text(isLoggingOut ? 'Logging Out...' : 'Logout'),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(double.infinity, 52),
          foregroundColor: Colors.red,
          side: const BorderSide(color: Colors.red),
        ),
      ),
    );
  }

  Widget _section({required String title, required List<Widget> children}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 13),
        ...children,
      ],
    );
  }

  Widget _actionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
    Widget? trailing,
  }) {
    return Card(
      elevation: 0,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        leading: CircleAvatar(
          backgroundColor: const Color(0xFFF5D8C7),
          child: Icon(icon, color: const Color(0xFFC58F73)),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(subtitle),
        ),
        trailing: trailing ?? const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Card(
      elevation: 0,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: CircleAvatar(
          backgroundColor: const Color(0xFFF5D8C7),
          child: Icon(icon, color: const Color(0xFFC58F73)),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(value),
        ),
      ),
    );
  }
}
