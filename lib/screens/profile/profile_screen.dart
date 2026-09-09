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
  ColourAnalysisResult? previewAnalysis;

  PreviewContext get previewContext => context.read<PreviewContext>();

  String? get activeUid {
    final previewUid = previewContext.customerUid;
    return previewUid?.isNotEmpty == true ? previewUid : FirebaseAuth.instance.currentUser?.uid;
  }

  bool get isPreview => previewContext.isCustomerPreview;

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
      if (isPreview) {
        final previewData = await FirestoreService.getCustomerPreviewContext(uid);
        loadedUser = previewData.user;
        loadedAnalysis = previewData.colourAnalysis;
        loadedStyles = previewData.styles;
        loadedPreferences = previewData.preferences;
        loadedWardrobeCount = previewData.wardrobe.length;
        loadedFavouriteCount = previewData.favouriteWardrobeCount;
        loadedSavedLookCount = previewData.savedLooks.length;
      } else {
        loadedUser = await FirestoreService.getUser(uid);
        loadedAnalysis = await FirestoreService.getLatestColourAnalysis(uid);
        final contextData = await FirestoreService.getPersonalStyleContext(uid);
        loadedUser ??= contextData.user;
        loadedAnalysis ??= contextData.colourAnalysis;
        loadedStyles = contextData.styles;
        loadedPreferences = contextData.preferences;
        loadedWardrobeCount = contextData.wardrobe.length;
        loadedFavouriteCount = contextData.favouriteWardrobeCount;
        loadedSavedLookCount = contextData.savedLooks.length;
      }
    } catch (error) {
      loadError = 'Unable to load profile data: $error';
    }

    try {
      loadedJourney = await TibStyleJourneyService.load(uid);
    } catch (_) {}

    if (!mounted) return;

    final authUser = FirebaseAuth.instance.currentUser;
    final fallbackUser = loadedUser ?? (authUser != null && !isPreview && authUser.uid == uid
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
      previewAnalysis = loadedAnalysis;
      isLoading = false;
      if (fallbackUser == null && loadError == null) {
        loadError = isPreview
            ? 'This customer profile is temporarily unavailable. Please try again.'
            : 'Unable to load your profile. Please try again.';
      }
    });

    if (!isPreview && loadedAnalysis != null) {
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
    final accountAnalysis = context.watch<AnalysisProvider>().result;
    final analysis = isPreview ? previewAnalysis : accountAnalysis;
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
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 10.5, fontWeight: FontWeight.w800),
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
                Text(
                  isPremium ? 'PERSONAL+' : 'PERSONAL',
                  style: const TextStyle(color: Colors.white70, fontSize: 8.5, fontWeight: FontWeight.w900, letterSpacing: .9),
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
          Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
          const SizedBox(height: 2),
          Text(label, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textMuted, fontSize: 9.5, fontWeight: FontWeight.w700)),
        ],
      );

  Widget metricDivider() => Container(width: 1, height: 30, color: AppColors.border);

  Widget identityPanel(ColourAnalysisResult? analysis) {
    final hasAnalysis = analysis != null;
    final season = analysis?.season.trim().isNotEmpty == true ? analysis!.season : 'Not analysed yet';
    final undertone = analysis?.undertone.trim().isNotEmpty == true ? analysis!.undertone : '—';
    final contrast = analysis?.contrast.trim().isNotEmpty == true ? analysis!.contrast : '—';
    final faceShape = analysis?.faceShape.trim().isNotEmpty == true ? analysis!.faceShape : '—';
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
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(14)),
                child: const Icon(Icons.palette_outlined, color: AppColors.primaryDark),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Colour + face profile', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                    SizedBox(height: 3),
                    Text('Your visual traits used by VYEA when styling you.', style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                  ],
                ),
              ),
              if (hasAnalysis) const PremiumBadge(compact: true),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              StyleChip(label: season, selected: hasAnalysis),
              StyleChip(label: 'Undertone · $undertone', selected: false),
              StyleChip(label: 'Contrast · $contrast', selected: false),
              StyleChip(label: 'Face · $faceShape', selected: false),
            ],
          ),
          if (reasons.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Text('Why this suits you', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
            const SizedBox(height: 7),
            ...reasons.take(3).map((reason) => Padding(
                  padding: const EdgeInsets.only(bottom: 5),
                  child: Text('• $reason', style: const TextStyle(color: AppColors.textSecondary, fontSize: 11.5, height: 1.35)),
                )),
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
    final title = journey?.currentStep ?? 'Build your personal style';
    final subtitle = journey?.nextAction ?? 'Complete more of your style profile to make VYEA smarter.';

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
        ],
      ),
    );
  }

  Widget toolGrid() => GridView.count(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.5,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          toolTile('Wardrobe', 'Manage your pieces', Icons.checkroom_outlined, openWardrobe),
          toolTile('AI Stylist', 'Style me with TiB', Icons.auto_awesome_outlined, openAIStylist),
          toolTile('Saved Looks', 'Keep your best outfits', Icons.bookmark_border_rounded, openSavedLooks),
          toolTile('Colour Profile', 'See your analysis', Icons.palette_outlined, openColourAnalysis),
        ],
      );

  Widget toolTile(String title, String subtitle, IconData icon, VoidCallback onTap) => Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.border)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: AppColors.primaryDark),
                const Spacer(),
                Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900)),
                const SizedBox(height: 2),
                Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.textMuted, fontSize: 10.5)),
              ],
            ),
          ),
        ),
      );

  Widget preferencesCard() {
    final hasData = styles.isNotEmpty || preferences.isNotEmpty;
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
          if (!hasData)
            const Text('No style preferences saved yet.', style: TextStyle(color: AppColors.textSecondary, fontSize: 12))
          else ...[
            if (styles.isNotEmpty) ...[
              const Text('Style direction', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Wrap(spacing: 7, runSpacing: 7, children: styles.map((item) => StyleChip(label: item, selected: true)).toList()),
            ],
            if (preferences.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text('Preferences', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Wrap(spacing: 7, runSpacing: 7, children: preferences.map((item) => StyleChip(label: item, selected: false)).toList()),
            ],
          ],
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: isPreview ? null : openStylePreferences,
            icon: const Icon(Icons.tune_rounded, size: 18),
            label: Text(isPreview ? 'View-only in Customer Preview' : 'Edit style preferences'),
          ),
        ],
      ),
    );
  }

  Widget accountSection() => Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            accountTile(
              icon: Icons.person_outline_rounded,
              title: 'Account',
              subtitle: isPreview ? 'Customer account · view only' : 'Profile and security settings',
              onTap: isPreview ? null : openSettings,
            ),
            const Divider(height: 1),
            accountTile(
              icon: Icons.workspace_premium_outlined,
              title: 'Membership',
              subtitle: isPremium ? 'Premium member' : 'Free member',
              onTap: isPreview ? null : openSettings,
            ),
          ],
        ),
      );

  Widget accountTile({required IconData icon, required String title, required String subtitle, required VoidCallback? onTap}) => ListTile(
        enabled: onTap != null,
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(color: AppColors.secondary, borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: AppColors.primaryDark),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text(subtitle),
        trailing: onTap == null ? null : const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
      );
}
