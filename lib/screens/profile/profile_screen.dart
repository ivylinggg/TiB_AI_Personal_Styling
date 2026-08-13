import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../models/user_model.dart';
import '../../services/firestore_service.dart';
import '../auth/login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  UserModel? user;

  bool isLoading = true;
  bool isLoggingOut = false;

  @override
  void initState() {
    super.initState();
    loadUser();
  }

  // ============================================================
  // LOAD USER
  // ============================================================

  Future<void> loadUser() async {
    final firebaseUser = FirebaseAuth.instance.currentUser;

    if (firebaseUser == null) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
      });

      return;
    }

    try {
      final result = await FirestoreService.getUser(firebaseUser.uid);

      if (!mounted) return;

      setState(() {
        user = result;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Unable to load profile: $e')));
    }
  }

  // ============================================================
  // LOGOUT
  // ============================================================

  Future<void> logout() async {
    if (isLoggingOut) return;

    setState(() {
      isLoggingOut = true;
    });

    try {
      await FirebaseAuth.instance.signOut();

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isLoggingOut = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Logout failed: $e')));
    }
  }

  // ============================================================
  // CONFIRM LOGOUT
  // ============================================================

  Future<void> confirmLogout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Logout'),
          content: const Text('Are you sure you want to logout?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Logout'),
            ),
          ],
        );
      },
    );

    if (shouldLogout == true) {
      await logout();
    }
  }

  // ============================================================
  // EDIT PROFILE
  // ============================================================

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
          builder: (context, setDialogState) {
            return AlertDialog(
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
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter your name.';
                    }

                    return null;
                  },
                ),
              ),

              actions: [
                TextButton(
                  onPressed: saving
                      ? null
                      : () {
                          Navigator.pop(dialogContext, false);
                        },
                  child: const Text('Cancel'),
                ),

                ElevatedButton(
                  onPressed: saving
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) {
                            return;
                          }

                          setDialogState(() {
                            saving = true;
                          });

                          try {
                            await FirestoreService.updateUser(
                              firebaseUser.uid,
                              {
                                'name': nameController.text.trim(),
                                'updatedAt': DateTime.now(),
                              },
                            );

                            if (!context.mounted) {
                              return;
                            }

                            Navigator.pop(dialogContext, true);
                          } catch (e) {
                            if (!context.mounted) {
                              return;
                            }

                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Unable to update profile: $e'),
                              ),
                            );

                            setDialogState(() {
                              saving = false;
                            });
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
            );
          },
        );
      },
    );

    nameController.dispose();

    if (updated == true) {
      await loadUser();
    }
  }

  // ============================================================
  // CHANGE PASSWORD
  // ============================================================

  Future<void> changePassword() async {
    final firebaseUser = FirebaseAuth.instance.currentUser;

    if (firebaseUser == null || firebaseUser.email == null) {
      return;
    }

    final shouldSendReset = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Change Password'),
          content: Text(
            'A password reset email will be sent to:\n\n'
            '${firebaseUser.email}',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Send Email'),
            ),
          ],
        );
      },
    );

    if (shouldSendReset != true) {
      return;
    }

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: firebaseUser.email!,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password reset email sent. Please check your inbox.'),
        ),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message ?? 'Unable to send password reset email.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to send password reset email.')),
      );
    }
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,

      appBar: AppBar(title: const Text('My Profile')),

      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: loadUser,
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  // ==================================================
                  // PROFILE PHOTO
                  // ==================================================
                  Center(
                    child: CircleAvatar(
                      radius: 55,
                      backgroundColor: const Color(0xFFF5D8C7),
                      backgroundImage:
                          user?.photoUrl != null && user!.photoUrl!.isNotEmpty
                          ? NetworkImage(user!.photoUrl!)
                          : null,
                      child: user?.photoUrl == null || user!.photoUrl!.isEmpty
                          ? const Icon(
                              Icons.person,
                              size: 55,
                              color: Colors.white,
                            )
                          : null,
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ==================================================
                  // NAME
                  // ==================================================
                  Center(
                    child: Text(
                      user?.name.isNotEmpty == true
                          ? user!.name
                          : 'TiB AI User',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),

                  const SizedBox(height: 6),

                  // ==================================================
                  // EMAIL
                  // ==================================================
                  Center(
                    child: Text(
                      user?.email ??
                          FirebaseAuth.instance.currentUser?.email ??
                          '',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),

                  const SizedBox(height: 32),

                  // ==================================================
                  // PERSONAL INFORMATION
                  // ==================================================
                  Text(
                    'Personal Information',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 14),

                  _buildInfoCard(
                    icon: Icons.person_outline,
                    title: 'Full Name',
                    value: user?.name.isNotEmpty == true
                        ? user!.name
                        : 'Not set',
                  ),

                  const SizedBox(height: 12),

                  _buildInfoCard(
                    icon: Icons.email_outlined,
                    title: 'Email',
                    value: user?.email.isNotEmpty == true
                        ? user!.email
                        : 'Not available',
                  ),

                  const SizedBox(height: 12),

                  _buildInfoCard(
                    icon: Icons.palette_outlined,
                    title: 'Colour Season',
                    value: user?.colourSeason?.isNotEmpty == true
                        ? user!.colourSeason!
                        : 'Not analysed yet',
                  ),

                  const SizedBox(height: 12),

                  _buildInfoCard(
                    icon: Icons.face_outlined,
                    title: 'Skin Tone',
                    value: user?.skinTone?.isNotEmpty == true
                        ? user!.skinTone!
                        : 'Not analysed yet',
                  ),

                  const SizedBox(height: 32),

                  // ==================================================
                  // ACCOUNT
                  // ==================================================
                  Text(
                    'Account',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 14),

                  // ==================================================
                  // EDIT PROFILE
                  // ==================================================
                  Card(
                    elevation: 0,
                    child: ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Color(0xFFF5D8C7),
                        child: Icon(
                          Icons.edit_outlined,
                          color: Color(0xFFC58F73),
                        ),
                      ),
                      title: const Text('Edit Profile'),
                      subtitle: const Text('Update your personal information'),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: openEditProfile,
                    ),
                  ),

                  const SizedBox(height: 12),

                  // ==================================================
                  // CHANGE PASSWORD
                  // ==================================================
                  Card(
                    elevation: 0,
                    child: ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Color(0xFFF5D8C7),
                        child: Icon(
                          Icons.lock_outline,
                          color: Color(0xFFC58F73),
                        ),
                      ),
                      title: const Text('Change Password'),
                      subtitle: const Text('Update your account password'),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: changePassword,
                    ),
                  ),

                  const SizedBox(height: 30),

                  // ==================================================
                  // LOGOUT
                  // ==================================================
                  SizedBox(
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
                  ),

                  const SizedBox(height: 30),
                ],
              ),
            ),
    );
  }

  // ============================================================
  // INFO CARD
  // ============================================================

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Card(
      elevation: 0,
      child: ListTile(
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
