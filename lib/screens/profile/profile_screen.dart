import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_gradients.dart';
import '../../core/constants/app_radius.dart';
import '../../models/colour_analysis_result.dart';
import '../../models/user_model.dart';
import '../../services/admin_preview_service.dart';
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
  ColourAnalysisResult? analysis;
  TibStyleJourney? styleJourney;
  bool isLoading = true;
  bool isPremium = false;
  String? loadError;
  List<String> styles = const [];
  List<String> preferences = const [];
  int wardrobeCount = 0;
  int wardrobeFavouriteCount = 0;
  int savedLookCount = 0;

  String? get activeUid {
    final previewUid = context.read<PreviewContext>().customerUid;
    if (previewUid != null && previewUid.isNotEmpty) return previewUid;
    return FirebaseAuth.instance.currentUser?.uid;
  }

  bool get isPreview => context.read<PreviewContext>().isCustomerPreview;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) loadProfile();
    });
  }

  Future<void> loadProfile() async {
    final uid = activeUid;
    if (uid == null || uid.isEmpty) {
      if (mounted) {
        setState(() {
          isLoading = false;
          loadError = isPreview ? 'No customer was selected for preview.' : 'No signed-in user was found.';
        });
      }
      return;
    }

    setState(() {
      isLoading = true;
      loadError = null;
      user = null;
      analysis = null;
      styles = const [];
      preferences = const [];
      wardrobeCount = 0;
      wardrobeFavouriteCount = 0;
      savedLookCount = 0;
      styleJourney = null;
    });

    try {
      final data = await AdminPreviewService.loadCustomerProfile(uid);
      if (!mounted) return;
      setState(() {
        user = data.user;
        analysis = data.colourAnalysis;
        styles = data.styles;
        preferences = data.preferences;
        wardrobeCount = data.wardrobe.length;
        wardrobeFavouriteCount = data.wardrobe.where((item) => item.isFavourite).length;
        savedLookCount = data.savedLooks.length;
        isPremium = data.user?.isPremium ?? false;
        isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        isLoading = false;
        loadError = error.toString();
      });
    }

    try {
      final journey = await TibStyleJourneyService.load(uid);
      if (mounted) setState(() => styleJourney = journey);
    } catch (_) {}
  }

  void openSettings() => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
  void openWardrobe() => Navigator.push(context, MaterialPageRoute(builder: (_) => const WardrobeScreen()));
  void openAIStylist() => Navigator.push(context, MaterialPageRoute(builder: (_) => const AIStylistScreen()));
  void openSavedLooks() => Navigator.push(context, MaterialPageRoute(builder: (_) => const SavedLooksScreen()));
  void openColourAnalysis() => Navigator.push(context, MaterialPageRoute(builder: (_) => const AnalysisScreen()));
  void openAnalysisResult(ColourAnalysisResult result) => Navigator.push(context, MaterialPageRoute(builder: (_) => AnalysisResultScreen(result: result)));

  Future<void> openStylePreferences() async {
    if (isPreview) return;
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const StylePreferencesScreen()));
    await loadProfile();
  }

  @override
  Widget build(BuildContext context) {
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
          IconButton(onPressed: isLoading ? null : loadProfile, icon: const Icon(Icons.refresh_rounded)),
          if (!isPreview) IconButton(onPressed: openSettings, icon: const Icon(Icons.settings_outlined)),
          const SizedBox(width: 8),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (isLoading) return const Center(child: CircularProgressIndicator());
    if (user == null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: EmptyState(
          icon: Icons.cloud_off_rounded,
          title: 'Customer profile is unavailable',
          description: loadError ?? 'The selected customer data could not be loaded.',
          ctaLabel: 'Try Again',
          onCta: loadProfile,
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: loadProfile,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 36),
        children: [
          _identityHero(),
          const SizedBox(height: 24),
          _sectionLabel('YOUR STYLE IDENTITY', 'The colours and style direction that make VYEA personal to you.'),
          const SizedBox(height: 12),
          _identityPanel(),
          const SizedBox(height: 24),
          _sectionLabel('YOUR STYLE JOURNEY', 'Turn your styling activity into visible progress.'),
          const SizedBox(height: 12),
          _styleJourneyCard(),
          const SizedBox(height: 24),
          _sectionLabel('YOUR STYLE SPACE', 'The VYEA tools you use to build your looks.'),
          const SizedBox(height: 12),
          _toolGrid(),
          const SizedBox(height: 24),
          _sectionLabel('STYLE PREFERENCES', 'Refine what you like so recommendations feel more like you.'),
          const SizedBox(height: 12),
          _preferencesCard(),
          const SizedBox(height: 24),
          _sectionLabel('ACCOUNT', 'Profile access and app settings.'),
          const SizedBox(height: 12),
          _accountSection(),
        ],
      ),
    );
  }

  Widget _sectionLabel(String title, String subtitle) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(title, style: const TextStyle(color: AppColors.textMuted, fontSize: 9.5, fontWeight: FontWeight.w900, letterSpacing: 1.35)),
    const SizedBox(height: 5),
    Text(subtitle, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.4)),
  ]);

  Widget _identityHero() {
    final displayName = user!.name.trim().isEmpty ? 'Customer' : user!.name.trim();
    final email = user!.email.trim();
    final photoUrl = user!.photoUrl?.trim() ?? '';
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      decoration: BoxDecoration(gradient: AppGradients.soft, borderRadius: BorderRadius.circular(AppRadius.xl), border: Border.all(color: AppColors.border)),
      child: Column(children: [
        Row(children: [
          CircleAvatar(radius: 39, backgroundColor: AppColors.secondary, backgroundImage: photoUrl.isNotEmpty ? CachedNetworkImageProvider(photoUrl) : null, child: photoUrl.isEmpty ? const Icon(Icons.person_outline_rounded, size: 36, color: AppColors.primaryDark) : null),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(displayName, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w900)),
            Text(email.isEmpty ? 'Email not available' : email, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11.5)),
            const SizedBox(height: 8),
            Row(children: [Icon(isPremium ? Icons.auto_awesome_rounded : Icons.person_outline_rounded, size: 14), const SizedBox(width: 5), Text(isPremium ? 'Premium member' : 'Free member', style: const TextStyle(color: AppColors.textSecondary, fontSize: 10.5, fontWeight: FontWeight.w800))]),
          ])),
        ]),
        const SizedBox(height: 16),
        Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.border)), child: Row(children: [Expanded(child: _metric('$wardrobeCount', 'Wardrobe')), _metricDivider(), Expanded(child: _metric('$savedLookCount', 'Saved looks')), _metricDivider(), Expanded(child: _metric('$wardrobeFavouriteCount', 'Favourites'))])),
        const SizedBox(height: 10),
        Container(padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11), decoration: BoxDecoration(color: AppColors.primaryDark, borderRadius: BorderRadius.circular(17)), child: Row(children: [const Icon(Icons.auto_awesome_rounded, size: 17, color: AppColors.peach), const SizedBox(width: 8), Expanded(child: Text('${styles.length} styles · ${preferences.length} preferences saved', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700))), Text(isPremium ? 'PERSONAL+' : 'PERSONAL', style: const TextStyle(color: Colors.white70, fontSize: 8.5, fontWeight: FontWeight.w900, letterSpacing: .9))])),
      ]),
    );
  }

  Widget _metric(String value, String label) => Column(children: [Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)), const SizedBox(height: 3), Text(label, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary, fontSize: 9.5))]);
  Widget _metricDivider() => Container(width: 1, height: 28, color: AppColors.border);

  Widget _identityPanel() {
    final result = analysis;
    final hasAnalysis = result != null;
    final season = hasAnalysis ? result!.season : 'Colour profile pending';
    final undertone = hasAnalysis ? result.undertone : 'Not analysed';
    final face = hasAnalysis ? result.faceShape : 'Not analysed';
    final reasons = result?.colourReasons ?? const <String>[];
    final value = result?.brightness.trim();
    final contrast = result?.contrast.trim();
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Expanded(child: Text(season, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900))), if (isPremium) const PremiumBadge(compact: true)]),
        const SizedBox(height: 10),
        Wrap(spacing: 7, runSpacing: 7, children: [
          StyleChip(label: 'Undertone: $undertone', selected: hasAnalysis),
          StyleChip(label: 'Face: $face', selected: hasAnalysis),
          if (value != null && value.isNotEmpty) StyleChip(label: 'Value: $value', selected: true),
          if (contrast != null && contrast.isNotEmpty) StyleChip(label: 'Contrast: $contrast', selected: true),
        ]),
        if (reasons.isNotEmpty) ...[
          const SizedBox(height: 14),
          const Text('Why this suits you', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
          const SizedBox(height: 7),
          ...reasons.take(3).map((reason) => Padding(padding: const EdgeInsets.only(bottom: 5), child: Text('• $reason', style: const TextStyle(color: AppColors.textSecondary, fontSize: 11.5, height: 1.35)))),
        ],
        const SizedBox(height: 14),
        OutlinedButton.icon(onPressed: hasAnalysis ? () => openAnalysisResult(result!) : openColourAnalysis, icon: Icon(hasAnalysis ? Icons.insights_outlined : Icons.camera_alt_outlined, size: 18), label: Text(hasAnalysis ? 'View full colour profile' : 'Start colour analysis')),
      ]),
    );
  }

  Widget _styleJourneyCard() {
    final journey = styleJourney;
    final completion = journey?.progress.clamp(0.0, 1.0).toDouble() ?? 0.0;
    final title = journey?.levelTitle ?? 'Build your personal style';
    final subtitle = journey == null ? 'Complete more of your style profile to make VYEA smarter.' : 'Level ${journey.level} · ${journey.points} XP · ${journey.completedChallenges} challenge${journey.completedChallenges == 1 ? '' : 's'} completed';
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(gradient: AppGradients.soft, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [const Icon(Icons.route_rounded, color: AppColors.primaryDark), const SizedBox(width: 9), Expanded(child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900))), Text('${(completion * 100).round()}%', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900))]),
        const SizedBox(height: 9),
        Text(subtitle, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11.5, height: 1.4)),
        const SizedBox(height: 14),
        ClipRRect(borderRadius: BorderRadius.circular(99), child: LinearProgressIndicator(value: completion, minHeight: 7)),
        if (journey != null && journey.badges.isNotEmpty) ...[
          const SizedBox(height: 14),
          Wrap(spacing: 7, runSpacing: 7, children: journey.badges.take(4).map((badge) => StyleChip(label: '${badge.icon} ${badge.title}', selected: badge.unlocked)).toList()),
        ],
      ]),
    );
  }

  Widget _toolGrid() => GridView.count(crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 1.55, children: [
    _toolTile('Wardrobe', 'Manage your pieces', Icons.checkroom_outlined, openWardrobe),
    _toolTile('Saved Looks', 'Your outfit library', Icons.bookmark_border_rounded, openSavedLooks),
    _toolTile('AI Stylist', 'Style with VYEA', Icons.auto_awesome_outlined, openAIStylist),
    _toolTile('Colour Analysis', 'Understand your palette', Icons.palette_outlined, analysis == null ? openColourAnalysis : () => openAnalysisResult(analysis!)),
  ]);

  Widget _toolTile(String title, String subtitle, IconData icon, VoidCallback onTap) => Card(elevation: 0, margin: EdgeInsets.zero, color: AppColors.surface, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: const BorderSide(color: AppColors.border)), child: InkWell(borderRadius: BorderRadius.circular(18), onTap: isPreview && title == 'Colour Analysis' ? null : onTap, child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(icon, size: 23), const Spacer(), Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900)), const SizedBox(height: 3), Text(subtitle, style: const TextStyle(color: AppColors.textSecondary, fontSize: 10.5))]))));

  Widget _preferencesCard() => Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.border)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    if (styles.isEmpty && preferences.isEmpty) ...[
      const Text('No style preferences saved yet.', style: TextStyle(color: AppColors.textSecondary, fontSize: 11.5)),
    ] else ...[
      if (styles.isNotEmpty) ...[
        const Text('Style direction', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Wrap(spacing: 7, runSpacing: 7, children: styles.map((style) => StyleChip(label: style, selected: true)).toList()),
      ],
      if (preferences.isNotEmpty) ...[
        if (styles.isNotEmpty) const SizedBox(height: 14),
        const Text('Preferences', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Wrap(spacing: 7, runSpacing: 7, children: preferences.map((preference) => StyleChip(label: preference, selected: false)).toList()),
      ],
    ],
    const SizedBox(height: 14),
    Align(alignment: Alignment.centerLeft, child: OutlinedButton.icon(onPressed: isPreview ? null : openStylePreferences, icon: const Icon(Icons.tune_rounded, size: 17), label: Text(isPreview ? 'Preview only' : 'Edit preferences'))),
  ]);

  Widget _accountSection() => Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.border)), child: Column(children: [
    if (!isPreview) ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.settings_outlined), title: const Text('Settings', style: TextStyle(fontWeight: FontWeight.w800)), subtitle: const Text('App and account controls'), trailing: const Icon(Icons.chevron_right_rounded), onTap: openSettings),
    if (!isPreview) const Divider(height: 1),
    ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.shield_outlined), title: const Text('Privacy & security', style: TextStyle(fontWeight: FontWeight.w800)), subtitle: Text(isPreview ? 'Admin preview mode' : 'Your account stays protected'), trailing: const Icon(Icons.chevron_right_rounded), onTap: () {}),
  ]));
}
