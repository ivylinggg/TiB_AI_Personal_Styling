import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_radius.dart';
import '../../providers/analysis_provider.dart';
import '../../services/firestore_service.dart';
import '../../widgets/flash_face_scan_panel.dart';
import '../../widgets/primary_button.dart';
import '../auth/auth_service.dart';
import '../main/main_screen.dart';
import 'flash_scan_result_screen.dart';

class FlashProfileFlow extends StatefulWidget {
  const FlashProfileFlow({super.key});

  @override
  State<FlashProfileFlow> createState() => _FlashProfileFlowState();
}

class _FlashProfileFlowState extends State<FlashProfileFlow> {
  static const _genders = ['Female', 'Male', 'Non-binary', 'Prefer not to say'];
  static const _ages = ['Under 18', '18–24', '25–34', '35–44', '45–54', '55+'];
  static const _ethnicities = [
    'White / Caucasian',
    'East Asian',
    'South Asian',
    'Southeast Asian',
    'Middle Eastern',
    'Hispanic / Latino',
    'Black / African',
    'Mixed / Multiracial',
    'Other',
  ];
  static const _brands = [
    'Zara',
    'Uniqlo',
    'Shein',
    'Cotton On',
    'H&M',
    'Forever 21',
    'Mango',
    'Primark',
    'Fashion Nova',
    'Gap',
    'Cider',
    'ASOS',
    'Romwe',
    'Bershka',
    'Target',
    'Charlotte Russe',
    'Dynamite',
  ];

  int _step = 0;
  String? _gender;
  String? _ageRange;
  String? _ethnicity;
  final List<String> _preferredBrands = [];
  File? _scanImage;
  bool _saving = false;

  double get _progress => (_step + 1) / 5;

  bool get _canContinue => switch (_step) {
        0 => _gender != null,
        1 => _ageRange != null,
        2 => _ethnicity != null,
        3 => _preferredBrands.isNotEmpty,
        _ => false,
      };

  Future<void> _continue() async {
    if (!_canContinue || _saving || _step >= 4) return;
    setState(() => _step += 1);
  }

  Future<void> _handleFaceScan(File file) async {
    if (_saving) return;
    setState(() => _scanImage = file);
    await _runColourAnalysis();
  }

  Future<void> _runColourAnalysis() async {
    if (_saving || _scanImage == null) return;

    final uid = AuthService.currentUser?.uid;
    final scanImage = _scanImage;
    if (uid == null || scanImage == null) {
      _message('Please complete the face scan first.');
      return;
    }

    setState(() => _saving = true);

    try {
      await FirestoreService.updateUser(uid, {
        'gender': _gender,
        'ageRange': _ageRange,
        'ethnicity': _ethnicity,
        'preferredBrands': List<String>.from(_preferredBrands),
        'onboardingProfile': {
          'gender': _gender,
          'ageRange': _ageRange,
          'ethnicity': _ethnicity,
          'preferredBrands': List<String>.from(_preferredBrands),
          'source': 'flash_questions',
        },
      });

      if (!mounted) return;
      final provider = context.read<AnalysisProvider>();
      provider.setImage(scanImage);

      final success = await provider.analyse(uid: uid);
      if (!mounted) return;

      if (!success || provider.result == null) {
        setState(() => _saving = false);
        _message(
          provider.errorMessage ??
              'We could not generate your colour profile yet.',
        );
        return;
      }

      final result = provider.result!;
      setState(() => _saving = false);

      final action = await Navigator.push<FlashScanResultAction>(
        context,
        MaterialPageRoute(
          builder: (_) => FlashScanResultScreen(
            result: result,
            scanImage: scanImage,
          ),
        ),
      );

      if (!mounted) return;

      if (action == FlashScanResultAction.continueOnboarding) {
        await FirestoreService.updateUser(uid, {
          'onboardingComplete': true,
          'onboardingScanCompleted': true,
        });

        if (!mounted) return;
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const MainScreen()),
          (_) => false,
        );
        return;
      }

      if (action == FlashScanResultAction.rescan) {
        setState(() => _scanImage = null);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      _message(
        'Your colour profile could not be generated. Please try again.',
      );
    }
  }

  void _toggleBrand(String brand) {
    setState(() {
      if (_preferredBrands.contains(brand)) {
        _preferredBrands.remove(brand);
      } else if (_preferredBrands.length < 10) {
        _preferredBrands.add(brand);
      } else {
        _message('Choose up to 10 brands.');
      }
    });
  }

  void _back() {
    if (_saving) return;
    if (_step == 0) {
      Navigator.pop(context);
    } else {
      setState(() {
        _step -= 1;
        if (_step < 4) _scanImage = null;
      });
    }
  }

  void _message(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned(
              left: -80,
              bottom: -120,
              child: _blob(240, AppColors.blush.withValues(alpha: .42)),
            ),
            Positioned(
              right: -90,
              bottom: -140,
              child: _blob(270, AppColors.primarySoft.withValues(alpha: .48)),
            ),
            Column(
              children: [
                _topBar(),
                _progressBar(),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 240),
                    child: Padding(
                      key: ValueKey(_step),
                      padding: const EdgeInsets.fromLTRB(20, 22, 20, 10),
                      child: _buildStep(),
                    ),
                  ),
                ),
                if (_step < 4)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(22, 4, 22, 22),
                    child: PrimaryButton(
                      text: 'Continue',
                      icon: Icons.arrow_forward_rounded,
                      onPressed: _saving || !_canContinue ? null : _continue,
                    ),
                  ),
                if (_step == 4 && _saving)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(22, 4, 22, 22),
                    child: PrimaryButton(
                      text: 'Creating your colour profile…',
                      onPressed: null,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep() => switch (_step) {
        0 => _choiceStep(
            'What’s your gender? ✨',
            'This helps us personalize your style recommendations',
            _genders,
            _gender,
            (v) => setState(() => _gender = v),
            ['👩🏻', '👨🏻', '🌈', '🔒'],
          ),
        1 => _choiceStep(
            'What’s your age range? 📅',
            'We’ll tailor style tips to your life stage',
            _ages,
            _ageRange,
            (v) => setState(() => _ageRange = v),
            ['🧸', '🌸', '✨', '🌿', '💜', '🔵'],
          ),
        2 => _choiceStep(
            'What’s your ethnicity? 🌎',
            'Helps us understand your unique coloring',
            _ethnicities,
            _ethnicity,
            (v) => setState(() => _ethnicity = v),
            ['🤍', '👩🏻', '👩🏽', '🧑🏻', '👩🏻', '🧑🏽', '🧑🏿', '🤎', '🌈'],
          ),
        3 => _brandStep(),
        4 => _scanStep(),
        _ => const SizedBox.shrink(),
      };

  Widget _choiceStep(
    String title,
    String subtitle,
    List<String> options,
    String? selected,
    ValueChanged<String> onSelect,
    List<String> emojis,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Center(
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              letterSpacing: -.5,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Center(
          child: Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              height: 1.45,
            ),
          ),
        ),
        const SizedBox(height: 28),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.only(bottom: 10),
            itemCount: options.length,
            separatorBuilder: (_, index) => const SizedBox(height: 10),
            itemBuilder: (_, index) {
              final option = options[index];
              return _selectCard(
                option,
                emoji: emojis[index],
                selected: selected == option,
                onTap: () => onSelect(option),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _selectCard(
    String label, {
    required String emoji,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: _saving ? null : onTap,
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.lavenderMist
              : Colors.white.withValues(alpha: .92),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected
                ? AppColors.primary.withValues(alpha: .45)
                : AppColors.border,
            width: selected ? 1.3 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.primarySoft
                    : AppColors.surfaceMuted,
                shape: BoxShape.circle,
              ),
              child: Text(emoji, style: const TextStyle(fontSize: 20)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (selected)
              const Icon(
                Icons.check_circle_rounded,
                color: AppColors.primary,
                size: 23,
              ),
          ],
        ),
      ),
    );
  }

  Widget _brandStep() {
    final remaining = _brands
        .where((brand) => !_preferredBrands.contains(brand))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        const Center(
          child: Text(
            'What brands\nmatch your vibe? 🛍️',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 25,
              fontWeight: FontWeight.w800,
              height: 1.1,
            ),
          ),
        ),
        const SizedBox(height: 10),
        const Center(
          child: Text(
            'Pick a few — we’ll tailor\nyour recommendations',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ),
        const SizedBox(height: 22),
        Row(
          children: [
            const Expanded(
              child: Text(
                'Your picks',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
              ),
            ),
            Text(
              '${_preferredBrands.length}/10',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 9),
        if (_preferredBrands.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _preferredBrands
                .map(
                  (brand) => InputChip(
                    label: Text(brand, style: const TextStyle(fontSize: 11)),
                    onDeleted: () => _toggleBrand(brand),
                    backgroundColor: AppColors.lavenderMist,
                    side: BorderSide(
                      color: AppColors.primary.withValues(alpha: .22),
                    ),
                    deleteIconColor: AppColors.textMuted,
                  ),
                )
                .toList(),
          )
        else
          const Text(
            'Tap the brands you actually wear.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 11.5),
          ),
        const SizedBox(height: 20),
        const Text(
          'You might also like',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 9),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.only(bottom: 10),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 3.9,
            ),
            itemCount: remaining.length,
            itemBuilder: (_, index) {
              final brand = remaining[index];
              return InkWell(
                onTap: () => _toggleBrand(brand),
                borderRadius: BorderRadius.circular(15),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .95),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          brand,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.favorite_border_rounded,
                        color: AppColors.textMuted,
                        size: 18,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _scanStep() {
    return Column(
      children: [
        const SizedBox(height: 8),
        const Text(
          'Let’s scan your\nbeautiful you ✨',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 25,
            fontWeight: FontWeight.w800,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'We’ll analyze your natural coloring\nto find the best shades for you',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 13,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: FlashFaceScanPanel(
            busy: _saving,
            onCaptured: _handleFaceScan,
          ),
        ),
      ],
    );
  }

  Widget _blob(double size, Color color) {
    return Transform.rotate(
      angle: -.28,
      child: Container(
        width: size,
        height: size * .62,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(size),
        ),
      ),
    );
  }

  Widget _topBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 0),
      child: Row(
        children: [
          IconButton(
            onPressed: _saving ? null : _back,
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          ),
          const Spacer(),
          Text(
            '${_step + 1} of 5',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
          const Spacer(),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _progressBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(64, 0, 64, 4),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.full),
        child: LinearProgressIndicator(
          minHeight: 3,
          value: _progress,
          backgroundColor: AppColors.border,
          valueColor: const AlwaysStoppedAnimation(AppColors.primary),
        ),
      ),
    );
  }
}
