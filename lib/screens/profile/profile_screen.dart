import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_gradients.dart';
import '../../core/constants/app_radius.dart';
import '../../models/colour_analysis_result.dart';
import '../../models/user_model.dart';
import '../../providers/analysis_provider.dart';
import '../../services/firestore_service.dart';
import '../../services/preview_context.dart';
import '../../services/tib_style_journey_service.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/premium_badge.dart';
import '../../widgets/style_chip.dart';
import '../ai/ai_stylist_screen.dart';
import '../ai/style_preferences_screen.dart';
import '../analysis/analysis_result_screen.dart';
import '../analysis/analysis_screen.dart';
import '../wardrobe/wardrobe_screen.dart';
import 'saved_looks_screen.dart';
import 'settings_screen.dart';

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
  int savedLookCount = 0;
  TibStyleJourney? styleJourney;

  String? get activeUid {
    final previewUid = context.read<PreviewContext>().customerUid;
    return previewUid?.isNotEmpty == true ? previewUid : FirebaseAuth.instance.currentUser?.uid;
  }

  bool get isPreview => context.read<PreviewContext>().isCustomerPreview;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) loadUser();
    });
  }

  Future<void> loadUser() async {
    final uid = activeUid;
    if (uid == null || uid.isEmpty) {
      if (mounted) setState(() => isLoading = false);
      return;
    }

    if (mounted) {
      setState(() {
        isLoading = true;
        loadError = null;
      });
    }

    UserModel? loadedUser;
    List<String> loadedStyles = const [];
    List<String> loadedPreferences = const [];
    int loadedWardrobeCount = 0;
    int loadedFavouriteCount = 0;
    int loadedSavedLookCount = 0;
    TibStyleJourney? loadedJourney;
    ColourAnalysisResult? loadedAnalysis;

    try {
      loadedUser = await FirestoreService.getUser(uid);
    } catch (_) {}
    try {
      loadedAnalysis = await FirestoreService.getLatestColourAnalysis(uid);
    } catch (_) {}
    try {
      final contextData = await FirestoreService.getPersonalStyleContext(uid);
      loadedUser ??= contextData.user;
      loadedAnalysis ??= contextData.colourAnalysis;
      loadedStyles = contextData.styles;
      loadedPreferences = contextData.preferences;
      loadedWardrobeCount = contextData.wardrobe.length;
      loadedFavouriteCount = contextData.favouriteWardrobeCount;
      loadedSavedLookCount = contextData.savedLooks.length;
    } catch (_) {}
    try {
      loadedJourney = await TibStyleJourneyService.load(uid);
    } catch (_) {}

    if (!mounted) return;

    final authUser = FirebaseAuth.instance.currentUser;
    final fallbackUser = loadedUser ??
        (authUser != null && !isPreview && authUser.uid == uid
            ? UserModel(
                uid: uid,
                name: (authUser.displayName?.trim().isNotEmpty ?? false)
                    ? authUser.displayName!.trim()
                    : 'VYEA User',
                email: authUser.email?.trim() ?? '',
                isPremium: false,
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
              )
            : null);

    setState(() {
      user = fallbackUser;
      isPremium = fallbackUser?.isPremium ?? false;
      styles = loadedStyles;
      preferences = loadedPreferences;
      wardrobeCount = loadedWardrobeCount;
      wardrobeFavouriteCount = loadedFavouriteCount;
      savedLookCount = loadedSavedLookCount;
      styleJourney = loadedJourney;
      isLoading = false;
      loadError = fallbackUser == null
          ? (isPreview
              ? 'This customer profile is temporarily unavailable. Please try again.'
              : 'Unable to load your profile. Please try again.')
          : null;
    });

    if (loadedAnalysis != null) {
      final analysisProvider = context.read<AnalysisProvider>();
      if (analysisProvider.result == null || analysisProvider.loadedUid != uid) {
        await analysisProvider.loadLatestResult(uid);
      }
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
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              try {
                await FirestoreService.updateUser(
                  uid,
                  {'name': controller.text.trim()},
                );
                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext, true);
                }
              } catch (error) {
                if (dialogContext.mounted) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    SnackBar(content: Text('Unable to update profile: $error')),
                  );
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

  void openSettings() => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const SettingsScreen()),
      );

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
    if (isPreview) return;
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const StylePreferencesScreen()),
    );
    if (updated == true) await loadUser();
  }

  @override
  Widget build(BuildContext context) {
    final analysis = context.watch<AnalysisProvider>().result;
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
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 2.8,
              ),
            ),
            Text(
              'Your profile',
              style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: isLoading ? null : loadUser,
            icon: const Icon(Icons.refresh_rounded),
          ),
          if (!isPreview)
            IconButton(
              onPressed: openSettings,
              tooltip: 'Settings',
              icon: const Icon(Icons.settings_outlined),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: buildBody(analysis),
    );
  }

  Widget buildBody(ColourAnalysisResult? analysis) {
    if (isLoading) return const Center(child: CircularProgressIndicator());
    if (activeUid == null) {
      return const Center(child: Text('Please login to view your profile.'));
    }
    if (user == null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: EmptyState(
          icon: Icons.cloud_off_rounded,
          title: isPreview ? 'Customer profile is unavailable' : 'Could not load your profile',
          description: loadError ??
              (isPreview
                  ? 'This customer account does not have a readable profile document yet.'
                  : 'Please try again.'),
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
          sectionLabel(
            'YOUR STYLE IDENTITY',
            'The colours and style direction that make VYEA personal to you.',
          ),
          const SizedBox(height: 12),
          identityPanel(analysis),
          const SizedBox(height: 24),
          sectionLabel(
            'YOUR STYLE JOURNEY',
            'Turn your styling activity into visible progress.',
          ),
          const SizedBox(height: 12),
          styleJourneyCard(),
          const SizedBox(height: 24),
          sectionLabel(
            'YOUR STYLE SPACE',
            'The VYEA tools you use to build your looks.',
          ),
          const SizedBox(height: 12),
          toolGrid(),
          const SizedBox(height: 24),
          sectionLabel(
            'STYLE PREFERENCES',
            'Refine what you like so recommendations feel more like you.',
          ),
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

  Widget sectionLabel(String title, String subtitle) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 9.5,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.35,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            subtitle,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ],
      );

  Widget identityHero() {
    final name = user?.name.trim().isNotEmpty == true ? user!.name.trim() : 'VYEA User';
    final authEmail = FirebaseAuth.instance.currentUser?.email?.trim() ?? '';
    final email = user?.email.trim().isNotEmpty == true ? user!.email.trim() : authEmail;
    final photoUrl = user?.photoUrl?.trim() ?? FirebaseAuth.instance.currentUser?.photoURL?.trim() ?? '';

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
                backgroundImage: photoUrl.isNotEmpty ? CachedNetworkImageProvider(photoUrl) : null,
                child: photoUrl.isNotEmpty
                    ? null
                    : const Icon(
                        Icons.person_outline_rounded,
                        size: 36,
                        color: AppColors.primaryDark,
                      ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 23,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        if (!isPreview)
                          IconButton(
                            onPressed: openEditProfile,
                            icon: const Icon(Icons.edit_outlined, size: 19),
                          ),
                      ],
                    ),
                    Text(
                      email,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          isPremium
                              ? Icons.auto_awesome_rounded
                              : Icons.person_outline_rounded,
                          size: 14,
                          color: isPremium
                              ? AppColors.premiumAccentDark
                              : AppColors.textSecondary,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          isPremium ? 'Premium member' : 'Free member',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Expanded(child: metric('$wardrobeCount', 'Wardrobe')),
                metricDivider(),
                Expanded(child: metric('$savedLookCount', 'Saved looks')),
                metricDivider(),
                Expanded(child: metric('$wardrobeFavouriteCount', 'Favourites')),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
            decoration: BoxDecoration(
              color: AppColors.primaryDark,
              borderRadius: BorderRadius.circular(17),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.auto_awesome_rounded,
                  size: 17,
                  color: AppColors.peach,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${styles.length} styles · ${preferences.length} preferences saved',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  isPremium ? 'PERSONAL+' : 'PERSONAL',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 8.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: .9,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget metric(String value, String label) => Column(
        children: [
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 3),
          Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 9.5)),
        ],
      );

  Widget metricDivider() => Container(
        width: 1,
        height: 28,
        color: AppColors.border,
      );

  Widget identityPanel(ColourAnalysisResult? analysis) {
    final hasAnalysis = analysis != null;
    final season = analysis?.season.trim().isNotEmpty == true ? analysis!.season : 'Unknown';
    final undertone = analysis?.undertone.trim().isNotEmpty == true ? analysis!.undertone : 'Unknown';
    final faceShape = analysis?.faceShape.trim().isNotEmpty == true ? analysis!.faceShape : 'Unknown';
    final reasons = analysis?.colourReasons ?? const <String>[];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  hasAnalysis ? season : 'Your colour profile',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                ),
              ),
              if (isPremium) const PremiumBadge(compact: true),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              StyleChip(label: hasAnalysis ? 'Undertone: $undertone' : 'Colour pending', selected: hasAnalysis),
              StyleChip(label: 'Face: $faceShape', selected: hasAnalysis),
              if (analysis?.brightness.trim().isNotEmpty == true)
                StyleChip(label: 'Value: ${analysis!.brightness}', selected: true),
              if (analysis?.contrast.trim().isNotEmpty == true)
                StyleChip(label: 'Contrast: ${analysis!.contrast}', selected: true),
            ],
          ),
          if (reasons.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Text('Why this suits you', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
            const SizedBox(height: 7),
            ...reasons.take(3).map(
                  (reason) => Padding(
                    padding: const EdgeInsets.only(bottom: 5),
                    child: Text(
                      '• $reason',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11.5,
                        height: 1.35,
                      ),
                    ),
                  ),
                ),
          ],
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: hasAnalysis ? () => openAnalysisResult(analysis) : openColourAnalysis,
            icon: Icon(hasAnalysis ? Icons.insights_outlined : Icons.camera_alt_outlined, size: 18),
            label: Text(hasAnalysis ? 'View full colour profile' : 'Start colour analysis'),
          ),
        ],
      ),
    );
  }

  Widget styleJourneyCard() {
    final journey = styleJourney;
    final completion = journey == null ? 0.0 : journey.progress.clamp(0.0, 1.0).toDouble();
    final title = journey == null ? 'Build your personal style' : journey.levelTitle;
    final subtitle = journey == null
        ? 'Complete more of your style profile to make VYEA smarter.'
        : 'Level ${journey.level} · ${journey.points} XP · ${journey.completedChallenges} challenge${journey.completedChallenges == 1 ? '' : 's'} completed';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: AppGradients.soft,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.route_rounded, color: AppColors.primaryDark),
              const SizedBox(width: 9),
              Expanded(child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900))),
              Text('${(completion * 100).round()}%', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900)),
            ],
          ),
          const SizedBox(height: 9),
          Text(subtitle, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11.5, height: 1.4)),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(value: completion, minHeight: 7),
          ),
          const SizedBox(height: 14),
          if (journey != null && journey.badges.isNotEmpty)
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: journey.badges.take(4).map((badge) {
                return StyleChip(
                  label: '${badge.icon} ${badge.title}',
                  selected: badge.unlocked,
                );
              }).toList(),
            )
          else
            const Text(
              'Your progress will appear here as you build your style habits.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 11.5),
            ),
        ],
      ),
    );
  }

  Widget toolGrid() => GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.35,
        children: [
          toolTile('Wardrobe', 'Organise the pieces you own.', Icons.checkroom_outlined, openWardrobe),
          toolTile('Style Me', 'Ask VYEA to build a look.', Icons.auto_awesome_outlined, openAIStylist),
          toolTile('Saved Looks', 'Revisit looks you loved.', Icons.bookmark_border_rounded, openSavedLooks),
          toolTile('Colour Analysis', 'Review your personal palette.', Icons.palette_outlined, openColourAnalysis),
        ],
      );

  Widget toolTile(String title, String subtitle, IconData icon, VoidCallback onTap) => Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.secondary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: AppColors.primaryDark, size: 20),
                ),
                const Spacer(),
                Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                const SizedBox(height: 3),
                Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.textSecondary, fontSize: 10.5, height: 1.3)),
              ],
            ),
          ),
        ),
      );

  Widget preferencesCard() => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (styles.isNotEmpty || preferences.isNotEmpty)
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: [
                  ...styles.map((value) => StyleChip(label: value, selected: true)),
                  ...preferences.map((value) => StyleChip(label: value, selected: true)),
                ],
              )
            else
              const Text(
                'No style preferences saved yet.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: isPreview ? null : openStylePreferences,
                icon: const Icon(Icons.tune_rounded, size: 18),
                label: Text(isPreview ? 'Read only in preview' : 'Edit preferences'),
              ),
            ),
          ],
        ),
      );

  Widget accountSection() => Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            ListTile(
              leading: const Icon(Icons.settings_outlined),
              title: const Text('App Settings'),
              subtitle: Text(isPreview ? 'Disabled while previewing a customer' : 'Notifications, appearance and account settings'),
              trailing: const Icon(Icons.chevron_right_rounded),
              enabled: !isPreview,
              onTap: isPreview ? null : openSettings,
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.privacy_tip_outlined),
              title: const Text('Profile visibility'),
              subtitle: Text(isPreview ? 'Read-only customer preview' : 'Your personal styling data stays connected to your account'),
              trailing: Icon(isPreview ? Icons.visibility_outlined : Icons.verified_user_outlined),
            ),
          ],
        ),
      );
}
