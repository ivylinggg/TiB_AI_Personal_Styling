import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_gradients.dart';
import '../../core/constants/app_radius.dart';
import '../../models/colour_analysis_result.dart';
import '../../models/user_model.dart';
import '../../providers/analysis_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/firestore_service.dart';
import '../../services/storage_service.dart';
import '../../services/style_preference_service.dart';
import '../../widgets/colour_swatch.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/gradient_card.dart';
import '../../widgets/premium_badge.dart';
import '../../widgets/section_header.dart';
import '../../widgets/style_chip.dart';
import '../ai/ai_stylist_screen.dart';
import '../ai/style_preferences_screen.dart';
import '../analysis/analysis_result_screen.dart';
import '../analysis/analysis_screen.dart';
import '../wardrobe/wardrobe_screen.dart';
import 'saved_looks_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

enum _PhotoAction { camera, gallery, remove }

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  UserModel? user;
  bool isLoading = true;
  bool isUploadingPhoto = false;
  bool isPremium = false;
  String? loadError;
  List<String> styles = const [];
  List<String> preferences = const [];
  int wardrobeCount = 0;
  int wardrobeFavouriteCount = 0;

  final ImagePicker _imagePicker = ImagePicker();

  late final AnimationController _revealController;
  late final Animation<double> _heroReveal;
  late final Animation<double> _styleReveal;
  late final Animation<double> _connectionsReveal;
  late final Animation<double> _preferencesReveal;

  @override
  void initState() {
    super.initState();
    loadUser();
    _revealController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _heroReveal = _stage(0.00, 0.35);
    _styleReveal = _stage(0.15, 0.60);
    _connectionsReveal = _stage(0.35, 0.80);
    _preferencesReveal = _stage(0.55, 1.00);
    _revealController.forward();
  }

  Animation<double> _stage(double begin, double end) => CurvedAnimation(
        parent: _revealController,
        curve: Interval(begin, end, curve: Curves.easeOut),
      );

  Widget _reveal(Animation<double> animation, Widget child) => AnimatedBuilder(
        animation: animation,
        builder: (context, animatedChild) {
          final value = animation.value.clamp(0.0, 1.0);
          return Opacity(
            opacity: value,
            child: Transform.translate(
              offset: Offset(0, (1 - value) * 14),
              child: animatedChild,
            ),
          );
        },
        child: child,
      );

  @override
  void dispose() {
    _revealController.dispose();
    super.dispose();
  }

  Future<void> loadUser() async {
    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser == null) {
      if (!mounted) return;
      setState(() => isLoading = false);
      return;
    }

    try {
      final result = await FirestoreService.getUser(firebaseUser.uid);
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(firebaseUser.uid)
          .get();
      final stylePreferences =
          await StylePreferenceService.getStylePreferences(firebaseUser.uid);
      final wardrobeItems =
          await FirestoreService.getWardrobeItems(firebaseUser.uid);

      if (!mounted) return;
      setState(() {
        user = result;
        isPremium = userDoc.data()?['isPremium'] as bool? ?? false;
        styles = List<String>.from(stylePreferences?['styles'] ?? const []);
        preferences =
            List<String>.from(stylePreferences?['preferences'] ?? const []);
        wardrobeCount = wardrobeItems.length;
        wardrobeFavouriteCount =
            wardrobeItems.where((item) => item.isFavourite).length;
        loadError = null;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isLoading = false;
        loadError = user == null ? 'Unable to load profile: $e' : null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to load profile: $e')),
      );
    }
  }

  Future<void> changeProfilePhoto() async {
    if (isUploadingPhoto) return;
    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser == null) return;

    final action = await _pickPhotoAction();
    if (action == null || !mounted) return;

    if (action == _PhotoAction.remove) {
      await _confirmAndRemovePhoto(firebaseUser.uid);
      return;
    }

    final source = action == _PhotoAction.camera
        ? ImageSource.camera
        : ImageSource.gallery;
    final picked = await _imagePicker.pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 1200,
    );
    if (picked == null || !mounted) return;
    await _showPhotoPreview(firebaseUser.uid, File(picked.path));
  }

  Future<_PhotoAction?> _pickPhotoAction() {
    final hasPhoto = user?.photoUrl != null && user!.photoUrl!.isNotEmpty;
    return showModalBottomSheet<_PhotoAction>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Profile photo',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(height: 10),
              ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                tileColor: AppColors.surfaceMuted,
                leading: const CircleAvatar(
                  backgroundColor: AppColors.secondary,
                  child: Icon(Icons.camera_alt_outlined),
                ),
                title: const Text('Take a photo'),
                onTap: () => Navigator.pop(sheetContext, _PhotoAction.camera),
              ),
              const SizedBox(height: 8),
              ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                tileColor: AppColors.surfaceMuted,
                leading: const CircleAvatar(
                  backgroundColor: AppColors.secondary,
                  child: Icon(Icons.photo_library_outlined),
                ),
                title: const Text('Choose from gallery'),
                onTap: () => Navigator.pop(sheetContext, _PhotoAction.gallery),
              ),
              if (hasPhoto) ...[
                const SizedBox(height: 8),
                ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  tileColor: AppColors.surfaceMuted,
                  leading: CircleAvatar(
                    backgroundColor: AppColors.error.withValues(alpha: .1),
                    child: const Icon(Icons.delete_outline, color: AppColors.error),
                  ),
                  title: const Text(
                    'Remove photo',
                    style: TextStyle(color: AppColors.error),
                  ),
                  onTap: () => Navigator.pop(sheetContext, _PhotoAction.remove),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmAndRemovePhoto(String uid) async {
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove Profile Photo?'),
        content: const Text(
          'Your profile photo will be removed. You can add a new one anytime.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _removeProfilePhoto(uid);
  }

  Future<void> _removeProfilePhoto(String uid) async {
    if (!mounted) return;
    final previousPhotoUrl = user?.photoUrl;
    try {
      setState(() => isUploadingPhoto = true);
      await FirestoreService.updateUser(uid, {'photoUrl': null});
      if (!mounted) return;
      setState(() => isUploadingPhoto = false);
      await loadUser();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile photo removed.')),
      );
      unawaited(StorageService.removeProfileImage(photoUrl: previousPhotoUrl));
    } catch (e) {
      if (!mounted) return;
      setState(() => isUploadingPhoto = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to remove profile photo: $e')),
      );
    }
  }

  Future<void> _showPhotoPreview(String uid, File image) async {
    if (!mounted) return;
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Preview your photo',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(height: 6),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'This will be visible on your profile.',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
              const SizedBox(height: 18),
              Center(
                child: ClipOval(
                  child: Image.file(image, width: 160, height: 160, fit: BoxFit.cover),
                ),
              ),
              const SizedBox(height: 24),
              OutlinedButton(
                onPressed: () => Navigator.pop(sheetContext, false),
                child: const Text('Choose a Different Photo'),
              ),
              const SizedBox(height: 10),
              FilledButton(
                onPressed: () => Navigator.pop(sheetContext, true),
                child: const Text('Use This Photo'),
              ),
            ],
          ),
        ),
      ),
    );
    if (confirmed != true) return;
    await _uploadProfilePhoto(uid, image);
  }

  Future<void> _uploadProfilePhoto(String uid, File image) async {
    if (!mounted) return;
    try {
      setState(() => isUploadingPhoto = true);
      final url = await StorageService.uploadProfileImage(uid: uid, image: image);
      await FirestoreService.updateUser(uid, {'photoUrl': url});
      if (!mounted) return;
      setState(() => isUploadingPhoto = false);
      await loadUser();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile photo updated.')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => isUploadingPhoto = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to update profile photo: $e')),
      );
    }
  }

  Future<void> openEditProfile() async {
    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser == null || user == null) return;
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
                decoration: InputDecoration(
                  labelText: 'Full Name',
                  prefixIcon: const Icon(Icons.person_outline),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
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
              FilledButton(
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
    if (firebaseUser == null || firebaseUser.email == null) return;
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
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Send Email'),
          ),
        ],
      ),
    );
    if (shouldSendReset != true) return;

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: firebaseUser.email!,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password reset email sent. Please check your inbox.')),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'Unable to send password reset email.')),
      );
    }
  }

  void openWardrobe() => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const WardrobeScreen()),
      );

  void openAIStylist() => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const AIStylistScreen()),
      );

  void openSavedLooks() => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const SavedLooksScreen()),
      );

  void openColourAnalysis() => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const AnalysisScreen()),
      );

  void openAnalysisResult(ColourAnalysisResult result) => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => AnalysisResultScreen(result: result)),
      );

  Future<void> openStylePreferences() async {
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const StylePreferencesScreen()),
    );
    if (updated == true && mounted) await loadUser();
  }

  @override
  Widget build(BuildContext context) {
    final analysisResult = context.watch<AnalysisProvider>().result;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        titleSpacing: 20,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'VYEA',
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 14,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.8,
              ),
            ),
            Text(
              'Profile',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 21,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh profile',
            onPressed: isLoading ? null : loadUser,
            icon: const Icon(Icons.refresh_rounded),
          ),
          PopupMenuButton<String>(
            tooltip: 'Profile settings',
            onSelected: (value) {
              switch (value) {
                case 'theme':
                  _showThemeSheet();
                case 'preferences':
                  openStylePreferences();
                case 'password':
                  changePassword();
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'theme', child: Text('Appearance')),
              PopupMenuItem(value: 'preferences', child: Text('Style preferences')),
              PopupMenuItem(value: 'password', child: Text('Change password')),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _buildBody(analysisResult),
    );
  }

  Future<void> _showThemeSheet() async {
    final provider = context.read<ThemeProvider>();
    final current = provider.themeMode;
    final selected = await showModalBottomSheet<ThemeMode>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Appearance',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              const Text(
                'Choose how VYEA should look on this device.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5),
              ),
              const SizedBox(height: 12),
              ...[
                (ThemeMode.system, 'System', Icons.brightness_auto_outlined),
                (ThemeMode.light, 'Light', Icons.light_mode_outlined),
                (ThemeMode.dark, 'Dark', Icons.dark_mode_outlined),
              ].map(
                (entry) => ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                  leading: CircleAvatar(
                    backgroundColor: AppColors.surfaceMuted,
                    child: Icon(entry.$3, color: AppColors.primary),
                  ),
                  title: Text(
                    entry.$2,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  trailing: Radio<ThemeMode>(
                    value: entry.$1,
                    groupValue: current,
                    onChanged: (value) => Navigator.pop(sheetContext, value),
                  ),
                  onTap: () => Navigator.pop(sheetContext, entry.$1),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (selected != null && selected != current && mounted) {
      await provider.setThemeMode(selected);
    }
  }

  Widget _buildBody(ColourAnalysisResult? analysisResult) {
    if (isLoading) return const Center(child: CircularProgressIndicator());
    if (FirebaseAuth.instance.currentUser == null) {
      return const Center(child: Text('Please login to view your profile.'));
    }
    if (user == null && loadError != null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: EmptyState(
            icon: Icons.cloud_off_rounded,
            title: 'Could not load your profile',
            description: loadError!,
            ctaLabel: 'Try Again',
            onCta: loadUser,
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: loadUser,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
        children: [
          _reveal(_heroReveal, _buildHero()),
          const SizedBox(height: 28),
          _reveal(
            _styleReveal,
            const SectionHeader(
              title: 'Your Personal Style',
              subtitle: 'Your colour season, palette and style direction.',
            ),
          ),
          const SizedBox(height: 14),
          _reveal(_styleReveal, _buildStyleSummary(analysisResult)),
          if (analysisResult != null && analysisResult.colours.isNotEmpty) ...[
            const SizedBox(height: 14),
            _reveal(_styleReveal, _buildPaletteCard(analysisResult)),
          ],
          const SizedBox(height: 28),
          _reveal(
            _connectionsReveal,
            const SectionHeader(
              title: 'Your Style Tools',
              subtitle: 'Everything you use to build and refine your look.',
            ),
          ),
          const SizedBox(height: 14),
          _reveal(_connectionsReveal, _buildWardrobeConnectionCard()),
          const SizedBox(height: 10),
          _reveal(_connectionsReveal, _buildAiStylistConnectionCard()),
          const SizedBox(height: 10),
          _reveal(_connectionsReveal, _buildSavedLooksConnectionCard()),
          const SizedBox(height: 28),
          _reveal(
            _preferencesReveal,
            SectionHeader(
              title: 'My Preferences',
              subtitle: styles.isEmpty && preferences.isEmpty
                  ? 'Set a direction and make VYEA feel more like you.'
                  : 'Your saved style direction and personal choices.',
              trailing: TextButton(
                onPressed: openStylePreferences,
                child: const Text('Edit'),
              ),
            ),
          ),
          const SizedBox(height: 14),
          _reveal(_preferencesReveal, _buildPreferencesCard()),
          const SizedBox(height: 28),
          _reveal(
            _preferencesReveal,
            const SectionHeader(
              title: 'Account & Security',
              subtitle: 'Keep your profile and access details up to date.',
            ),
          ),
          const SizedBox(height: 14),
          _reveal(_preferencesReveal, _buildAccountSection()),
        ],
      ),
    );
  }

  Widget _buildHero() {
    final name = user?.name.trim();
    final email = user?.email.trim();
    final displayName = name?.isNotEmpty == true ? name! : 'VYEA User';
    final displayEmail = email?.isNotEmpty == true
        ? email!
        : (FirebaseAuth.instance.currentUser?.email ?? '');
    final hasPhoto = user?.photoUrl != null && user!.photoUrl!.isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      decoration: BoxDecoration(
        gradient: AppGradients.soft,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: isUploadingPhoto ? null : changeProfilePhoto,
            child: Stack(
              alignment: Alignment.bottomRight,
              children: [
                CircleAvatar(
                  radius: 54,
                  backgroundColor: AppColors.secondary,
                  backgroundImage: hasPhoto
                      ? CachedNetworkImageProvider(user!.photoUrl!)
                      : null,
                  child: hasPhoto
                      ? null
                      : const Icon(
                          Icons.person_outline_rounded,
                          size: 48,
                          color: AppColors.primaryDark,
                        ),
                ),
                Material(
                  color: AppColors.primary,
                  shape: const CircleBorder(),
                  child: InkWell(
                    onTap: isUploadingPhoto ? null : changeProfilePhoto,
                    customBorder: const CircleBorder(),
                    child: Padding(
                      padding: const EdgeInsets.all(9),
                      child: isUploadingPhoto
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.background,
                              ),
                            )
                          : const Icon(
                              Icons.camera_alt_outlined,
                              size: 16,
                              color: AppColors.background,
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 15),
          Text(
            displayName,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 24,
              fontWeight: FontWeight.w800,
              letterSpacing: -.3,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            displayEmail,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.full),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isPremium
                      ? Icons.auto_awesome_rounded
                      : Icons.person_outline_rounded,
                  size: 15,
                  color: isPremium
                      ? AppColors.premiumAccentDark
                      : AppColors.textSecondary,
                ),
                const SizedBox(width: 6),
                Text(
                  isPremium ? 'Premium Member' : 'Free Member',
                  style: TextStyle(
                    color: isPremium
                        ? AppColors.premiumAccentDark
                        : AppColors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _heroStat(
                  value: '$wardrobeCount',
                  label: 'Wardrobe pieces',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _heroStat(
                  value: '$wardrobeFavouriteCount',
                  label: 'Favourites',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _heroStat(
                  value: '${styles.length}',
                  label: 'Style tags',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: openEditProfile,
              icon: const Icon(Icons.edit_outlined, size: 17),
              label: const Text('Edit Profile'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroStat({required String value, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: .86),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: AppColors.border.withValues(alpha: .7)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: AppColors.primary,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 9.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStyleSummary(ColourAnalysisResult? result) {
    if (result == null) {
      return GradientCard(
        gradient: AppGradients.primary,
        icon: Icons.palette_outlined,
        onTap: openColourAnalysis,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Build your colour identity',
              style: TextStyle(
                color: AppColors.background,
                fontSize: 19,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              'Find the colours that work with your natural palette and make every outfit decision easier.',
              style: TextStyle(
                color: AppColors.background.withValues(alpha: .72),
                height: 1.5,
                fontSize: 12.5,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: openColourAnalysis,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.background,
                  foregroundColor: AppColors.primaryDark,
                ),
                child: const Text('Start Colour Analysis'),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 17),
      decoration: BoxDecoration(
        gradient: AppGradients.season(result.season),
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'YOUR COLOUR IDENTITY',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                    color: Colors.white70,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => openAnalysisResult(result),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: const Size(0, 0),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('View'),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            result.season,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w800,
              letterSpacing: -.5,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            '${result.undertone} • ${result.brightness} • ${result.contrast}',
            style: const TextStyle(color: Colors.white70, fontSize: 12.5),
          ),
          if (styles.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              'Style direction',
              style: TextStyle(
                color: Colors.white.withValues(alpha: .72),
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: styles.take(3).map(_lightStyleTag).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _lightStyleTag(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .14),
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(color: Colors.white.withValues(alpha: .18)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildPaletteCard(ColourAnalysisResult result) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'YOUR PALETTE',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: .7,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => openAnalysisResult(result),
                child: const Text('Details'),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 16,
            runSpacing: 14,
            children: result.colours
                .take(12)
                .map((c) => ColourSwatch(name: c, size: 46, showLabel: true))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _connectionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Widget? trailingBadge,
  }) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: const BoxDecoration(
                  color: AppColors.secondary,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: AppColors.primaryDark),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (trailingBadge != null) ...[
                          const SizedBox(width: 7),
                          trailingBadge,
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWardrobeConnectionCard() {
    return _connectionCard(
      icon: Icons.checkroom_outlined,
      title: 'My Wardrobe',
      subtitle: wardrobeCount == 0
          ? 'Add a few pieces to start building outfits.'
          : '$wardrobeCount pieces · $wardrobeFavouriteCount favourites',
      onTap: openWardrobe,
    );
  }

  Widget _buildAiStylistConnectionCard() {
    return _connectionCard(
      icon: Icons.auto_awesome_rounded,
      title: 'VYEA Personal Stylist',
      subtitle: 'Turn your wardrobe and personal colours into outfit ideas.',
      onTap: openAIStylist,
      trailingBadge: isPremium ? const PremiumBadge(compact: true) : null,
    );
  }

  Widget _buildSavedLooksConnectionCard() {
    return _connectionCard(
      icon: Icons.bookmark_border_rounded,
      title: 'Saved Looks',
      subtitle: 'Come back to outfits you loved and saved.',
      onTap: openSavedLooks,
    );
  }

  Widget _buildPreferencesCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _preferenceGroup(
            'Styles',
            styles,
            emptyText: 'No style direction saved yet.',
          ),
          const SizedBox(height: 16),
          _preferenceGroup(
            'Preferences',
            preferences,
            emptyText: 'No preferences saved yet.',
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: openStylePreferences,
              icon: const Icon(Icons.tune_rounded, size: 17),
              label: const Text('Refine My Style Profile'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _preferenceGroup(
    String label,
    List<String> values, {
    required String emptyText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            letterSpacing: .6,
          ),
        ),
        const SizedBox(height: 9),
        values.isEmpty
            ? Text(
                emptyText,
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                ),
              )
            : Wrap(
                spacing: 7,
                runSpacing: 7,
                children: values
                    .map((value) => StyleChip(label: value, selected: true))
                    .toList(),
              ),
      ],
    );
  }

  Widget _buildAccountSection() {
    return Column(
      children: [
        _connectionCard(
          icon: Icons.lock_outline_rounded,
          title: 'Change Password',
          subtitle: 'Send a secure password reset email.',
          onTap: changePassword,
        ),
        const SizedBox(height: 10),
        _connectionCard(
          icon: Icons.dark_mode_outlined,
          title: 'Appearance',
          subtitle: _themeLabel(context.watch<ThemeProvider>().themeMode),
          onTap: _showThemeSheet,
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: const BoxDecoration(
                  color: AppColors.secondary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.verified_user_outlined,
                  color: AppColors.primaryDark,
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Account Status',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Your account status is shown from your profile record.',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                user?.isActive == true
                    ? Icons.check_circle_rounded
                    : Icons.error_outline_rounded,
                color: user?.isActive == true
                    ? AppColors.success
                    : AppColors.error,
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _themeLabel(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return 'Follow your device appearance';
      case ThemeMode.light:
        return 'Light mode';
      case ThemeMode.dark:
        return 'Dark mode';
    }
  }
}
