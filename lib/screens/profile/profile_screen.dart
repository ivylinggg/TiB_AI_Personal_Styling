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
  int _loadRequest = 0;

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
    final requestId = ++_loadRequest;
    if (uid == null || uid.isEmpty) {
      if (mounted) {
        setState(() {
          user = null;
          isLoading = false;
          loadError = 'Please login to view your profile.';
        });
      }
      return;
    }

    setState(() {
      isLoading = true;
      loadError = null;
    });

    UserModel? loadedUser;
    List<String> loadedStyles = const [];
    List<String> loadedPreferences = const [];
    int loadedWardrobeCount = 0;
    int loadedFavouriteCount = 0;
    int loadedSavedLookCount = 0;
    TibStyleJourney? loadedJourney;
    ColourAnalysisResult? loadedAnalysis;
    var criticalLoadFailed = false;

    try {
      loadedUser = await FirestoreService.getUser(uid);
    } catch (_) {
      criticalLoadFailed = true;
    }

    if (!mounted || requestId != _loadRequest || activeUid != uid) return;

    try {
      final colourResult = await FirestoreService.getLatestColourAnalysis(uid);
      loadedAnalysis = colourResult;
    } catch (_) {}

    try {
      final preferenceData = await FirestoreService.getPersonalStyleContext(uid);
      loadedStyles = preferenceData.styles;
      loadedPreferences = preferenceData.preferences;
      loadedWardrobeCount = preferenceData.wardrobe.length;
      loadedFavouriteCount = preferenceData.favouriteWardrobeCount;
      loadedSavedLookCount = preferenceData.savedLooks.length;
      if (loadedUser == null) loadedUser = preferenceData.user;
      if (loadedAnalysis == null) loadedAnalysis = preferenceData.colourAnalysis;
    } catch (_) {}

    try {
      loadedJourney = await TibStyleJourneyService.load(uid);
    } catch (_) {}

    if (!mounted || requestId != _loadRequest || activeUid != uid) return;

    final authUser = FirebaseAuth.instance.currentUser;
    if (loadedUser == null && authUser != null && !isPreview && authUser.uid == uid) {
      final fallbackName = authUser.displayName?.trim() ?? '';
      final fallbackEmail = authUser.email?.trim() ?? '';
      loadedUser = UserModel(
        uid: uid,
        name: fallbackName.isEmpty ? 'VYEA User' : fallbackName,
        email: fallbackEmail,
        isPremium: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    }

    setState(() {
      user = loadedUser;
      isPremium = loadedUser?.isPremium ?? false;
      styles = loadedStyles;
      preferences = loadedPreferences;
      wardrobeCount = loadedWardrobeCount;
      wardrobeFavouriteCount = loadedFavouriteCount;
      savedLookCount = loadedSavedLookCount;
      styleJourney = loadedJourney;
      isLoading = false;
      loadError = loadedUser == null && criticalLoadFailed
          ? (isPreview
              ? 'This customer profile is temporarily unavailable. Please try again.'
              : 'Unable to load your profile. Please try again.')
          : null;
    });

    if (loadedAnalysis != null) {
      final analysisProvider = context.read<AnalysisProvider>();
      if (analysisProvider.loadedUid != uid) {
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
            validator: (value) => value == null || value.trim().isEmpty ? 'Please enter your name.' : null,
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
                await FirestoreService.updateUser(uid, {'name': controller.text.trim()});
                if (dialogContext.mounted) Navigator.pop(dialogContext, true);
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
    if (activeUid == null) return const Center(child: Text('Please login to view your profile.'));
    if (user == null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: EmptyState(
          icon: Icons.cloud_off_rounded,
          title: isPreview ? 'Customer profile is unavailable' : 'Could not load your profile',
          description: loadError ?? (isPreview ? 'This customer account does not have a readable profile document yet.' : 'Please try again.'),
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
                child: photoUrl.isNotEmpty ? null : const Icon(Icons.person_outline_rounded, size: 36, color: AppColors.primaryDark),
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
                            style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w900),
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
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 11.5),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          isPremium ? Icons.auto_awesome_rounded : Icons.person_outline_rounded,
                          size: 14,
                          color: isPremium ? AppColors.premiumAccentDark : AppColors.textSecondary,
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
                const Icon(Icons.auto_awesome_rounded, size: 17, color: AppColors.peach),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${styles.length} styles · ${preferences.length} preferences saved',
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
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
          if (!isPreview) ...[
            const SizedBox(height: 13),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: openEditProfile,
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: const Text('Edit Profile'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget metric(String value, String label) => Column(
        children: [
          Text(
            value,
            style: const TextStyle(color: AppColors.primary, fontSize: 17, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 9.5)),
        ],
      );

  Widget metricDivider() => Container(width: 1, height: 30, color: AppColors.border);

  Widget styleJourneyCard() {
    final journey = styleJourney;
    if (journey == null) return const SizedBox.shrink();
    final unlocked = journey.badges.where((badge) => badge.unlocked).length;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: const BoxDecoration(
                  gradient: AppGradients.primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.auto_awesome_rounded, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Level ${journey.level} · ${journey.levelTitle}',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${journey.points} XP · ${journey.streak} day streak · ${journey.completedChallenges} challenges',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 10.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Text(
                'NEXT LEVEL',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  letterSpacing: .9,
                ),
              ),
              const Spacer(),
              Text(
                journey.nextLevelPoints > journey.currentLevelPoints
                    ? '${journey.points} / ${journey.nextLevelPoints} XP'
                    : 'MAX LEVEL',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: journey.progress,
              minHeight: 8,
              backgroundColor: AppColors.secondary,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          ),
          const SizedBox(height: 15),
          Row(
            children: [
              const Text(
                'BADGES',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  letterSpacing: .9,
                ),
              ),
              const Spacer(),
              Text(
                '$unlocked / ${journey.badges.length} unlocked',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: journey.badges
                .map(
                  (badge) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
                    decoration: BoxDecoration(
                      color: badge.unlocked ? AppColors.secondary : AppColors.surfaceMuted,
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(badge.icon, style: const TextStyle(fontSize: 13)),
                        const SizedBox(width: 5),
                        Text(
                          badge.title,
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            color: badge.unlocked ? AppColors.textPrimary : AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget identityPanel(ColourAnalysisResult? result) {
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
            const Text(
              'Build your colour identity',
              style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            const Text(
              'Complete Colour Analysis to unlock your personal palette, face-shape guidance and smarter outfit recommendations.',
              style: TextStyle(color: Colors.white70, fontSize: 11.5, height: 1.45),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: isPreview ? null : openColourAnalysis,
                child: Text(isPreview ? 'Preview only' : 'Start Colour Analysis'),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: AppGradients.season(result.season),
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            result.season,
            style: const TextStyle(color: Colors.white, fontSize: 29, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 5),
          Text(
            '${result.undertone} • ${result.brightness} • ${result.contrast}',
            style: const TextStyle(color: Colors.white70),
          ),
          if (result.faceShape.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Face shape · ${result.faceShape}',
              style: const TextStyle(color: Colors.white70, fontSize: 11.5, fontWeight: FontWeight.w700),
            ),
          ],
          if (styles.isNotEmpty) ...[
            const SizedBox(height: 12),
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

  Widget _lightStyleTag(String style) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white24,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(style, style: const TextStyle(color: Colors.white, fontSize: 10)),
      );

  Widget toolGrid() => Column(
        children: [
          toolTile(
            Icons.checkroom_outlined,
            'My Wardrobe',
            wardrobeCount == 0 ? 'Add pieces and start building your wardrobe.' : '$wardrobeCount pieces · $wardrobeFavouriteCount favourites',
            openWardrobe,
          ),
          const SizedBox(height: 10),
          toolTile(
            Icons.auto_awesome_rounded,
            'VYEA Personal Stylist',
            'Turn your wardrobe and colours into outfit ideas.',
            openAIStylist,
            isPremium,
          ),
          const SizedBox(height: 10),
          toolTile(
            Icons.bookmark_border_rounded,
            'Saved Looks',
            savedLookCount == 0 ? 'Save outfits you want to come back to.' : '$savedLookCount saved outfits · revisit your favourites',
            openSavedLooks,
          ),
        ],
      );

  Widget toolTile(
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap,
    [bool badge = false]
  ) => Material(
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
                              style: const TextStyle(fontWeight: FontWeight.w800),
                            ),
                          ),
                          if (badge) ...[
                            const SizedBox(width: 7),
                            const PremiumBadge(compact: true),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 11.5),
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

  Widget preferencesCard() => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(17),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _preferenceGroup('Styles', styles),
            const SizedBox(height: 17),
            _preferenceGroup('Preferences', preferences),
            if (!isPreview) ...[
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
          ],
        ),
      );

  Widget _preferenceGroup(String title, List<String> values) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: .6,
            ),
          ),
          const SizedBox(height: 8),
          values.isEmpty
              ? const Text('Nothing saved yet.', style: TextStyle(color: AppColors.textMuted, fontSize: 12))
              : Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: values
                      .map((value) => StyleChip(label: value, selected: true))
                      .toList(),
                ),
        ],
      );

  Widget accountSection() => Column(
        children: [
          toolTile(
            Icons.settings_outlined,
            'Settings',
            'Appearance, notifications, security and account controls.',
            openSettings,
          ),
        ],
      );
}
