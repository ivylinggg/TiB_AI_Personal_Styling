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
import '../../services/preview_context.dart';
import '../../services/tib_style_journey_service.dart';
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
  String? loadError;
  List<String> styles = const [];
  List<String> preferences = const [];
  int wardrobeCount = 0;
  int wardrobeFavouriteCount = 0;
  int savedLookCount = 0;
  TibStyleJourney? styleJourney;

  String? get activeUid {
    final previewUid = context.read<PreviewContext>().customerUid;
    return (previewUid != null && previewUid.isNotEmpty)
        ? previewUid
        : FirebaseAuth.instance.currentUser?.uid;
  }

  bool get isPreview => context.read<PreviewContext>().isCustomerPreview;

  @override
  void initState() {
    super.initState();
    loadUser();
  }

  Future<void> loadUser() async {
    final uid = activeUid;
    if (uid == null) {
      if (mounted) setState(() => isLoading = false);
      return;
    }
    setState(() {
      isLoading = true;
      loadError = null;
    });
    try {
      final data = await FirestoreService.getPersonalStyleContext(uid);
      final journey = await TibStyleJourneyService.load(uid);
      if (!mounted) return;
      setState(() {
        user = data.user;
        styles = data.styles;
        preferences = data.preferences;
        wardrobeCount = data.wardrobe.length;
        wardrobeFavouriteCount = data.favouriteWardrobeCount;
        savedLookCount = data.savedLooks.length;
        styleJourney = journey;
        isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        loadError = 'Unable to load your profile: $error';
        isLoading = false;
      });
    }
  }

  Future<void> openEditProfile() async {
    if (isPreview || user == null) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
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
            decoration: const InputDecoration(labelText: 'Full Name'),
            validator: (value) => value == null || value.trim().isEmpty
                ? 'Please enter your name.'
                : null,
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              await FirestoreService.updateUser(uid, {'name': controller.text.trim()});
              if (dialogContext.mounted) Navigator.pop(dialogContext, true);
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
    if (isPreview) return;
    final email = FirebaseAuth.instance.currentUser?.email;
    if (email == null) return;
    await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password reset email sent.')),
      );
    }
  }

  void openWardrobe() => Navigator.push(context, MaterialPageRoute(builder: (_) => const WardrobeScreen()));
  void openAIStylist() => Navigator.push(context, MaterialPageRoute(builder: (_) => const AIStylistScreen()));
  void openSavedLooks() => Navigator.push(context, MaterialPageRoute(builder: (_) => const SavedLooksScreen()));
  void openColourAnalysis() => Navigator.push(context, MaterialPageRoute(builder: (_) => const AnalysisScreen()));
  void openAnalysisResult(ColourAnalysisResult result) => Navigator.push(context, MaterialPageRoute(builder: (_) => AnalysisResultScreen(result: result)));

  Future<void> openStylePreferences() async {
    if (isPreview) return;
    final updated = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => const StylePreferencesScreen()));
    if (updated == true) await loadUser();
  }

  Future<void> showThemeSheet() async {
    final provider = context.read<ThemeProvider>();
    final current = provider.themeMode;
    final selected = await showModalBottomSheet<ThemeMode>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Align(alignment: Alignment.centerLeft, child: Text('Appearance', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800))),
              const SizedBox(height: 12),
              _themeTile(sheetContext, ThemeMode.system, 'System', Icons.brightness_auto_outlined),
              _themeTile(sheetContext, ThemeMode.light, 'Light', Icons.light_mode_outlined),
              _themeTile(sheetContext, ThemeMode.dark, 'Dark', Icons.dark_mode_outlined),
            ],
          ),
        ),
      ),
    );
    if (selected != null && selected != current && mounted) {
      await provider.setThemeMode(selected);
    }
  }

  Widget _themeTile(BuildContext context, ThemeMode mode, String label, IconData icon) => ListTile(
        leading: CircleAvatar(backgroundColor: AppColors.surfaceMuted, child: Icon(icon, color: AppColors.primary)),
        title: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
        trailing: Radio<ThemeMode>(value: mode),
        onTap: () => Navigator.pop(context, mode),
      );

  @override
  Widget build(BuildContext context) {
    final analysis = context.watch<AnalysisProvider>().result;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        titleSpacing: 20,
        title: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('VYEA', style: TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 2.8)),
          Text('Your profile', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
        ]),
        actions: [
          IconButton(onPressed: isLoading ? null : loadUser, icon: const Icon(Icons.refresh_rounded)),
          if (!isPreview)
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'theme') showThemeSheet();
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
      body: buildBody(analysis),
    );
  }

  Widget buildBody(ColourAnalysisResult? analysis) {
    if (isLoading) return const Center(child: CircularProgressIndicator());
    if (activeUid == null) return const Center(child: Text('Please login to view your profile.'));
    if (user == null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: EmptyState(
          icon: Icons.cloud_off_rounded,
          title: 'Could not load your profile',
          description: loadError ?? 'Please try again.',
          ctaLabel: 'Try Again',
          onCta: loadUser,
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: loadUser,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 36),
        children: [
          identityHero(),
          const SizedBox(height: 24),
          sectionLabel('YOUR STYLE IDENTITY', 'The colours and style direction that make VYEA personal to you.'),
          const SizedBox(height: 12),
          identityPanel(analysis),
          const SizedBox(height: 24),
          sectionLabel('YOUR STYLE JOURNEY', 'Turn your styling activity into visible progress.'),
          const SizedBox(height: 12),
          styleJourneyCard(),
          const SizedBox(height: 24),
          sectionLabel('YOUR STYLE SPACE', 'The VYEA tools you use to build your looks.'),
          const SizedBox(height: 12),
          toolGrid(),
          const SizedBox(height: 24),
          sectionLabel('STYLE PREFERENCES', 'Refine what you like so recommendations feel more like you.'),
          const SizedBox(height: 12),
          preferencesCard(),
          const SizedBox(height: 24),
          sectionLabel('ACCOUNT', 'Profile access and app settings.'),
          const SizedBox(height: 12),
          accountSection(),
        ],
      ),
    );
  }

  Widget sectionLabel(String title, String subtitle) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(color: AppColors.textMuted, fontSize: 9.5, fontWeight: FontWeight.w900, letterSpacing: 1.35)),
        const SizedBox(height: 5),
        Text(subtitle, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.4)),
      ]);

  Widget identityHero() {
    final name = user?.name.trim().isNotEmpty == true ? user!.name.trim() : 'VYEA User';
    final email = user?.email.trim().isNotEmpty == true ? user!.email.trim() : (FirebaseAuth.instance.currentUser?.email ?? '');
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      decoration: BoxDecoration(gradient: AppGradients.soft, borderRadius: BorderRadius.circular(AppRadius.xl), border: Border.all(color: AppColors.border)),
      child: Column(children: [
        Row(children: [
          CircleAvatar(radius: 39, backgroundColor: AppColors.secondary, child: const Icon(Icons.person_outline_rounded, size: 36, color: AppColors.primaryDark)),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [Expanded(child: Text(name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w900))), if (!isPreview) IconButton(onPressed: openEditProfile, icon: const Icon(Icons.edit_outlined, size: 19))]),
            Text(email, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11.5)),
            const SizedBox(height: 8),
            Text(isPremium ? 'Premium member' : 'Free member', style: const TextStyle(color: AppColors.textSecondary, fontSize: 10.5, fontWeight: FontWeight.w800)),
          ])),
        ]),
        const SizedBox(height: 16),
        Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.border)), child: Row(children: [Expanded(child: metric('$wardrobeCount', 'Wardrobe')), metricDivider(), Expanded(child: metric('$savedLookCount', 'Saved looks')), metricDivider(), Expanded(child: metric('$wardrobeFavouriteCount', 'Favourites'))])),
        const SizedBox(height: 10),
        Container(padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11), decoration: BoxDecoration(color: AppColors.primaryDark, borderRadius: BorderRadius.circular(17)), child: Text('${styles.length} styles · ${preferences.length} preferences saved', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
      ]),
    );
  }

  Widget metric(String value, String label) => Column(children: [Text(value, style: const TextStyle(color: AppColors.primary, fontSize: 17, fontWeight: FontWeight.w900)), const SizedBox(height: 2), Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 9.5))]);
  Widget metricDivider() => Container(width: 1, height: 30, color: AppColors.border);

  Widget styleJourneyCard() {
    final journey = styleJourney;
    if (journey == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.xl), border: Border.all(color: AppColors.border)),
      child: Row(children: [
        const Icon(Icons.auto_awesome_rounded, color: AppColors.primary, size: 34),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Level ${journey.level} · ${journey.levelTitle}', style: const TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text('${journey.points} XP · ${journey.streak} day streak · ${journey.completedChallenges} challenges', style: const TextStyle(color: AppColors.textSecondary, fontSize: 10.5)),
        ])),
      ]),
    );
  }

  Widget identityPanel(ColourAnalysisResult? result) {
    if (result == null) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(gradient: AppGradients.primary, borderRadius: BorderRadius.circular(AppRadius.xl)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Build your colour identity', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          SizedBox(width: double.infinity, child: FilledButton(onPressed: isPreview ? null : openColourAnalysis, child: Text(isPreview ? 'Preview only' : 'Start Colour Analysis'))),
        ]),
      );
    }
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(gradient: AppGradients.season(result.season), borderRadius: BorderRadius.circular(AppRadius.xl)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(result.season, style: const TextStyle(color: Colors.white, fontSize: 29, fontWeight: FontWeight.w900)),
        const SizedBox(height: 5),
        Text('${result.undertone} • ${result.brightness} • ${result.contrast}', style: const TextStyle(color: Colors.white70)),
        if (styles.isNotEmpty) ...[const SizedBox(height: 12), Wrap(spacing: 6, children: styles.take(3).map((style) => Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6), decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(20)), child: Text(style, style: const TextStyle(color: Colors.white, fontSize: 10)))).toList())],
      ]),
    );
  }

  Widget toolGrid() => Column(children: [
        toolTile(Icons.checkroom_outlined, 'My Wardrobe', wardrobeCount == 0 ? 'Add pieces and start building your wardrobe.' : '$wardrobeCount pieces · $wardrobeFavouriteCount favourites', openWardrobe),
        const SizedBox(height: 10),
        toolTile(Icons.auto_awesome_rounded, 'VYEA Personal Stylist', 'Turn your wardrobe and colours into outfit ideas.', openAIStylist, isPremium),
        const SizedBox(height: 10),
        toolTile(Icons.bookmark_border_rounded, 'Saved Looks', savedLookCount == 0 ? 'Save outfits you want to come back to.' : '$savedLookCount saved outfits · revisit your favourites', openSavedLooks),
      ]);

  Widget toolTile(IconData icon, String title, String subtitle, VoidCallback onTap, [bool badge = false]) => Material(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.lg), child: InkWell(borderRadius: BorderRadius.circular(AppRadius.lg), onTap: onTap, child: Container(padding: const EdgeInsets.all(15), decoration: BoxDecoration(borderRadius: BorderRadius.circular(AppRadius.lg), border: Border.all(color: AppColors.border)), child: Row(children: [Container(width: 46, height: 46, decoration: const BoxDecoration(color: AppColors.secondary, shape: BoxShape.circle), child: Icon(icon, color: AppColors.primaryDark)), const SizedBox(width: 13), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Flexible(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800))), if (badge) ...[const SizedBox(width: 7), const PremiumBadge(compact: true)]]), const SizedBox(height: 3), Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11.5))])), const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted)]))));

  Widget preferencesCard() => Container(width: double.infinity, padding: const EdgeInsets.all(17), decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.lg), border: Border.all(color: AppColors.border)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_preferenceGroup('Styles', styles), const SizedBox(height: 17), _preferenceGroup('Preferences', preferences), if (!isPreview) ...[const SizedBox(height: 14), SizedBox(width: double.infinity, child: OutlinedButton.icon(onPressed: openStylePreferences, icon: const Icon(Icons.tune_rounded), label: const Text('Refine My Style Profile'))]]));

  Widget _preferenceGroup(String title, List<String> values) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title.toUpperCase(), style: const TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.w900)), const SizedBox(height: 8), values.isEmpty ? const Text('Nothing saved yet.', style: TextStyle(color: AppColors.textMuted, fontSize: 12)) : Wrap(spacing: 7, runSpacing: 7, children: values.map((value) => StyleChip(label: value, selected: true)).toList())]);

  Widget accountSection() => Column(children: [_toolTile(Icons.lock_outline_rounded, 'Change Password', 'Send a secure password reset email.', changePassword), const SizedBox(height: 10), Container(padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.lg), border: Border.all(color: AppColors.border)), child: Row(children: [const Icon(Icons.verified_user_outlined, color: AppColors.primaryDark), const SizedBox(width: 13), const Expanded(child: Text('Your account status is shown from your profile record.', style: TextStyle(color: AppColors.textSecondary, fontSize: 11.5)))]))]);
}
