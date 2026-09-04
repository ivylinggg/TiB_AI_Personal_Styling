import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_gradients.dart';
import '../../core/constants/app_radius.dart';
import '../../models/colour_analysis_result.dart';
import '../../models/user_model.dart';
import '../../providers/analysis_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/firestore_service.dart';
import '../../services/style_preference_service.dart';
import '../../widgets/colour_swatch.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/premium_badge.dart';
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

class _ProfileScreenState extends State<ProfileScreen> {
  UserModel? user;
  bool isLoading = true;
  bool isPremium = false;
  String? loadError;
  List<String> styles = const [];
  List<String> preferences = const [];
  int wardrobeCount = 0;
  int wardrobeFavouriteCount = 0;

  @override
  void initState() {
    super.initState();
    loadUser();
  }

  Future<void> loadUser() async {
    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser == null) {
      if (mounted) setState(() => isLoading = false);
      return;
    }

    setState(() {
      isLoading = true;
      loadError = null;
    });

    try {
      final result = await FirestoreService.getUser(firebaseUser.uid);
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(firebaseUser.uid).get();
      final stylePreferences = await StylePreferenceService.getStylePreferences(firebaseUser.uid);
      final wardrobeItems = await FirestoreService.getWardrobeItems(firebaseUser.uid);

      if (!mounted) return;
      setState(() {
        user = result;
        isPremium = userDoc.data()?['isPremium'] as bool? ?? false;
        styles = List<String>.from(stylePreferences?['styles'] ?? const []);
        preferences = List<String>.from(stylePreferences?['preferences'] ?? const []);
        wardrobeCount = wardrobeItems.length;
        wardrobeFavouriteCount = wardrobeItems.where((item) => item.isFavourite).length;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isLoading = false;
        loadError = 'Unable to load your profile: $e';
      });
    }
  }

  Future<void> openEditProfile() async {
    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser == null || user == null) return;
    final controller = TextEditingController(text: user!.name);
    final formKey = GlobalKey<FormState>();

    final updated = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit Profile'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            decoration: const InputDecoration(labelText: 'Full Name', prefixIcon: Icon(Icons.person_outline)),
            validator: (value) => value == null || value.trim().isEmpty ? 'Please enter your name.' : null,
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              try {
                await FirestoreService.updateUser(firebaseUser.uid, {'name': controller.text.trim()});
                if (dialogContext.mounted) Navigator.pop(dialogContext, true);
              } catch (e) {
                if (dialogContext.mounted) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(SnackBar(content: Text('Unable to update profile: $e')));
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (updated == true) await loadUser();
  }

  Future<void> changePassword() async {
    final email = FirebaseAuth.instance.currentUser?.email;
    if (email == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Change Password'),
        content: Text('A password reset email will be sent to:\n\n$email'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Send Email')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password reset email sent.')));
    } on FirebaseAuthException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message ?? 'Unable to send password reset email.')));
    }
  }

  void openWardrobe() => Navigator.push(context, MaterialPageRoute(builder: (_) => const WardrobeScreen()));
  void openAIStylist() => Navigator.push(context, MaterialPageRoute(builder: (_) => const AIStylistScreen()));
  void openSavedLooks() => Navigator.push(context, MaterialPageRoute(builder: (_) => const SavedLooksScreen()));
  void openColourAnalysis() => Navigator.push(context, MaterialPageRoute(builder: (_) => const AnalysisScreen()));
  void openAnalysisResult(ColourAnalysisResult result) => Navigator.push(context, MaterialPageRoute(builder: (_) => AnalysisResultScreen(result: result)));

  Future<void> openStylePreferences() async {
    final updated = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => const StylePreferencesScreen()));
    if (updated == true) await loadUser();
  }

  Future<void> _showThemeSheet() async {
    final provider = context.read<ThemeProvider>();
    final current = provider.themeMode;
    final selected = await showModalBottomSheet<ThemeMode>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Appearance', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              const Text('Choose how VYEA should look on this device.', style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5)),
              const SizedBox(height: 12),
              RadioGroup<ThemeMode>(
                groupValue: current,
                onChanged: (value) {
                  if (value != null) Navigator.pop(sheetContext, value);
                },
                child: Column(
                  children: [
                    _themeTile(sheetContext, ThemeMode.system, 'System', Icons.brightness_auto_outlined),
                    _themeTile(sheetContext, ThemeMode.light, 'Light', Icons.light_mode_outlined),
                    _themeTile(sheetContext, ThemeMode.dark, 'Dark', Icons.dark_mode_outlined),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (selected != null && selected != current && mounted) await provider.setThemeMode(selected);
  }

  Widget _themeTile(BuildContext sheetContext, ThemeMode mode, String label, IconData icon) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      leading: CircleAvatar(backgroundColor: AppColors.surfaceMuted, child: Icon(icon, color: AppColors.primary)),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
      trailing: Radio<ThemeMode>(value: mode),
      onTap: () => Navigator.pop(sheetContext, mode),
    );
  }

  @override
  Widget build(BuildContext context) {
    final analysisResult = context.watch<AnalysisProvider>().result;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: 20,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('VYEA', style: TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 2.8)),
            Text('Your profile', style: TextStyle(color: AppColors.textPrimary, fontSize: 21, fontWeight: FontWeight.w800)),
          ],
        ),
        actions: [
          IconButton(tooltip: 'Refresh profile', onPressed: isLoading ? null : loadUser, icon: const Icon(Icons.refresh_rounded)),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'theme') _showThemeSheet();
              if (value == 'preferences') openStylePreferences();
              if (value == 'password') changePassword();
            },
            itemBuilder: (_) => const [
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

  Widget _buildBody(ColourAnalysisResult? analysisResult) {
    if (isLoading) return const Center(child: CircularProgressIndicator());
    if (FirebaseAuth.instance.currentUser == null) return const Center(child: Text('Please login to view your profile.'));
    if (user == null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: EmptyState(
            icon: Icons.cloud_off_rounded,
            title: 'Could not load your profile',
            description: loadError ?? 'Please try again.',
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
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 36),
        children: [
          _buildIdentityHero(),
          const SizedBox(height: 26),
          _sectionLabel('YOUR STYLE IDENTITY', 'The colours and style direction that make VYEA personal to you.'),
          const SizedBox(height: 12),
          _buildIdentityPanel(analysisResult),
          const SizedBox(height: 26),
          _sectionLabel('YOUR STYLE SPACE', 'The VYEA tools you use to build your looks.'),
          const SizedBox(height: 12),
          _buildToolGrid(),
          const SizedBox(height: 26),
          _sectionLabel('STYLE PREFERENCES', 'Refine what you like so recommendations feel more like you.'),
          const SizedBox(height: 12),
          _buildPreferencesCard(),
          const SizedBox(height: 26),
          _sectionLabel('ACCOUNT', 'Profile access and app settings.'),
          const SizedBox(height: 12),
          _buildAccountSection(),
        ],
      ),
    );
  }

  Widget _sectionLabel(String title, String subtitle) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: AppColors.textMuted, fontSize: 9.5, fontWeight: FontWeight.w900, letterSpacing: 1.35)),
          const SizedBox(height: 5),
          Text(subtitle, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.4)),
        ],
      );

  Widget _buildIdentityHero() {
    final name = user?.name.trim();
    final email = user?.email.trim();
    final displayName = name?.isNotEmpty == true ? name! : 'VYEA User';
    final displayEmail = email?.isNotEmpty == true ? email! : (FirebaseAuth.instance.currentUser?.email ?? '');
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      decoration: BoxDecoration(
        gradient: AppGradients.soft,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 39,
                backgroundColor: AppColors.secondary,
                backgroundImage: user?.photoUrl?.isNotEmpty == true ? CachedNetworkImageProvider(user!.photoUrl!) : null,
                child: user?.photoUrl?.isNotEmpty == true ? null : const Icon(Icons.person_outline_rounded, size: 36, color: AppColors.primaryDark),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(displayName, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w900, letterSpacing: -.4))),
                        IconButton(onPressed: openEditProfile, tooltip: 'Edit profile', icon: const Icon(Icons.edit_outlined, size: 19)),
                      ],
                    ),
                    Text(displayEmail, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11.5)),
                    const SizedBox(height: 9),
                    Row(children: [
                      Icon(isPremium ? Icons.auto_awesome_rounded : Icons.person_outline_rounded, size: 14, color: isPremium ? AppColors.premiumAccentDark : AppColors.textSecondary),
                      const SizedBox(width: 5),
                      Text(isPremium ? 'Premium member' : 'Free member', style: TextStyle(color: isPremium ? AppColors.premiumAccentDark : AppColors.textSecondary, fontSize: 10.5, fontWeight: FontWeight.w800)),
                    ]),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: AppColors.surface.withValues(alpha: .78), borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.border)),
            child: Row(children: [
              Expanded(child: _heroMetric('$wardrobeCount', 'Wardrobe')),
              _metricDivider(),
              Expanded(child: _heroMetric('$wardrobeFavouriteCount', 'Favourites')),
              _metricDivider(),
              Expanded(child: _heroMetric('${styles.length}', 'Style tags')),
            ]),
          ),
          const SizedBox(height: 13),
          SizedBox(width: double.infinity, child: OutlinedButton.icon(onPressed: openEditProfile, icon: const Icon(Icons.edit_outlined, size: 16), label: const Text('Edit Profile'))),
        ],
      ),
    );
  }

  Widget _heroMetric(String value, String label) => Column(
        children: [
          Text(value, style: const TextStyle(color: AppColors.primary, fontSize: 17, fontWeight: FontWeight.w900)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 9.5)),
        ],
      );

  Widget _metricDivider() => Container(width: 1, height: 30, color: AppColors.border);

  Widget _buildIdentityPanel(ColourAnalysisResult? result) {
    if (result == null) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: AppGradients.primary,
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Build your colour identity', style: TextStyle(color: AppColors.background, fontSize: 20, fontWeight: FontWeight.w900)),
            const SizedBox(height: 7),
            Text('Discover the colours that feel natural on you and make styling decisions easier.', style: TextStyle(color: AppColors.background.withValues(alpha: .74), fontSize: 12.5, height: 1.45)),
            const SizedBox(height: 15),
            SizedBox(width: double.infinity, child: FilledButton(onPressed: openColourAnalysis, style: FilledButton.styleFrom(backgroundColor: AppColors.background, foregroundColor: AppColors.primaryDark), child: const Text('Start Colour Analysis'))),
          ],
        ),
      );
    }

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
          decoration: BoxDecoration(gradient: AppGradients.season(result.season), borderRadius: BorderRadius.circular(AppRadius.xl)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Expanded(child: Text('COLOUR IDENTITY', style: TextStyle(color: Colors.white70, fontSize: 9.5, fontWeight: FontWeight.w900, letterSpacing: 1.3))),
              TextButton(onPressed: () => openAnalysisResult(result), style: TextButton.styleFrom(foregroundColor: Colors.white), child: const Text('View')),
            ]),
            Text(result.season, style: const TextStyle(color: Colors.white, fontSize: 29, fontWeight: FontWeight.w900, letterSpacing: -.6)),
            const SizedBox(height: 5),
            Text('${result.undertone} • ${result.brightness} • ${result.contrast}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
            if (styles.isNotEmpty) ...[
              const SizedBox(height: 14),
              const Text('STYLE DIRECTION', style: TextStyle(color: Colors.white70, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1)),
              const SizedBox(height: 7),
              Wrap(spacing: 6, runSpacing: 6, children: styles.take(3).map(_lightStyleTag).toList()),
            ],
          ]),
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(17),
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.lg), border: Border.all(color: AppColors.border)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [const Expanded(child: Text('YOUR PALETTE', style: TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: .8))), TextButton(onPressed: () => openAnalysisResult(result), child: const Text('Details'))]),
            const SizedBox(height: 6),
            Wrap(spacing: 15, runSpacing: 13, children: result.colours.take(10).map((colour) => ColourSwatch(name: colour, size: 43, showLabel: true)).toList()),
          ]),
        ),
      ],
    );
  }

  Widget _lightStyleTag(String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: .14), borderRadius: BorderRadius.circular(AppRadius.full), border: Border.all(color: Colors.white.withValues(alpha: .18))),
        child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800)),
      );

  Widget _buildToolGrid() => Column(children: [
        _toolTile(icon: Icons.checkroom_outlined, title: 'My Wardrobe', subtitle: wardrobeCount == 0 ? 'Add pieces and start building your wardrobe.' : '$wardrobeCount pieces · $wardrobeFavouriteCount favourites', onTap: openWardrobe),
        const SizedBox(height: 10),
        _toolTile(icon: Icons.auto_awesome_rounded, title: 'VYEA Personal Stylist', subtitle: 'Turn your wardrobe and colours into outfit ideas.', onTap: openAIStylist, badge: isPremium),
        const SizedBox(height: 10),
        _toolTile(icon: Icons.bookmark_border_rounded, title: 'Saved Looks', subtitle: 'Return to outfits that already feel like you.', onTap: openSavedLooks),
      ]);

  Widget _toolTile({required IconData icon, required String title, required String subtitle, required VoidCallback onTap, bool badge = false}) => Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(AppRadius.lg), border: Border.all(color: AppColors.border)),
            child: Row(children: [
              Container(width: 46, height: 46, decoration: const BoxDecoration(color: AppColors.secondary, shape: BoxShape.circle), child: Icon(icon, color: AppColors.primaryDark)),
              const SizedBox(width: 13),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [Flexible(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800))), if (badge) ...[const SizedBox(width: 7), const PremiumBadge(compact: true)]]),
                const SizedBox(height: 3),
                Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11.5, height: 1.35)),
              ])),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
            ]),
          ),
        ),
      );

  Widget _buildPreferencesCard() => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(17),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.lg), border: Border.all(color: AppColors.border)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _preferenceGroup('Styles', styles, emptyText: 'No style direction saved yet.'),
          const SizedBox(height: 17),
          _preferenceGroup('Preferences', preferences, emptyText: 'No preferences saved yet.'),
          const SizedBox(height: 14),
          SizedBox(width: double.infinity, child: OutlinedButton.icon(onPressed: openStylePreferences, icon: const Icon(Icons.tune_rounded, size: 17), label: const Text('Refine My Style Profile'))),
        ]),
      );

  Widget _preferenceGroup(String label, List<String> values, {required String emptyText}) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label.toUpperCase(), style: const TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: .6)),
        const SizedBox(height: 9),
        values.isEmpty ? Text(emptyText, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)) : Wrap(spacing: 7, runSpacing: 7, children: values.map((value) => StyleChip(label: value, selected: true)).toList()),
      ]);

  Widget _buildAccountSection() => Column(children: [
        _toolTile(icon: Icons.lock_outline_rounded, title: 'Change Password', subtitle: 'Send a secure password reset email.', onTap: changePassword),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.lg), border: Border.all(color: AppColors.border)),
          child: Row(children: [
            Container(width: 46, height: 46, decoration: const BoxDecoration(color: AppColors.secondary, shape: BoxShape.circle), child: const Icon(Icons.verified_user_outlined, color: AppColors.primaryDark)),
            const SizedBox(width: 13),
            const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Account Status', style: TextStyle(fontWeight: FontWeight.w800)), SizedBox(height: 3), Text('Your account status is shown from your profile record.', style: TextStyle(color: AppColors.textSecondary, fontSize: 11.5, height: 1.35))])),
            const SizedBox(width: 8),
            Icon(user?.isActive == true ? Icons.check_circle_rounded : Icons.error_outline_rounded, color: user?.isActive == true ? AppColors.success : AppColors.error),
          ]),
        ),
      ]);
}
