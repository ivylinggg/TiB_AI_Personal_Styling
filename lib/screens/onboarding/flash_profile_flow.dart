import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_radius.dart';
import '../../providers/analysis_provider.dart';
import '../../services/firestore_service.dart';
import '../../services/image_picker_service.dart';
import '../../widgets/primary_button.dart';
import '../analysis/analysis_result_screen.dart';
import '../analysis/face_scan_screen.dart';
import '../auth/auth_service.dart';
import 'style_setup_flow.dart';

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
    'Zara', 'Uniqlo', 'Shein', 'Cotton On', 'H&M', 'Forever 21', 'Mango',
    'Primark', 'Fashion Nova', 'Gap', 'Cider', 'ASOS', 'Romwe', 'Bershka',
    'Target', 'Charlotte Russe', 'Dynamite',
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
        4 => _scanImage != null,
        _ => false,
      };

  Future<void> _continue() async {
    if (!_canContinue || _saving) return;
    if (_step < 4) {
      setState(() => _step += 1);
      return;
    }

    final uid = AuthService.currentUser?.uid;
    if (uid == null || _scanImage == null) return;

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

      final provider = context.read<AnalysisProvider>();
      provider.setImage(_scanImage!);
      final success = await provider.analyse(uid: uid);
      if (!mounted) return;

      if (!success || provider.result == null) {
        setState(() => _saving = false);
        _message(provider.errorMessage ?? 'We could not generate your colour profile yet.');
        return;
      }

      await FirestoreService.updateUser(uid, {
        'onboardingComplete': true,
        'onboardingScanCompleted': true,
      });

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AnalysisResultScreen(result: provider.result!),
        ),
      );

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const StyleSetupFlow(initialStep: 1)),
      );
    } catch (error) {
      if (mounted) {
        setState(() => _saving = false);
        _message('Your profile could not be saved. Please try again.');
      }
    }
  }

  void _back() {
    if (_saving) return;
    if (_step == 0) {
      Navigator.pop(context);
    } else {
      setState(() => _step -= 1);
    }
  }

  Future<void> _openFaceScan() async {
    if (_saving) return;
    final file = await Navigator.push<File?>(
      context,
      MaterialPageRoute(builder: (_) => const FaceScanScreen()),
    );
    if (!mounted || file == null) return;
    setState(() => _scanImage = file);
  }

  Future<void> _pickPhoto() async {
    if (_saving) return;
    final file = await ImagePickerService.pickGallery();
    if (!mounted || file == null) return;
    setState(() => _scanImage = file);
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

  void _message(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message), behavior: SnackBarBehavior.floating));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned(left: -80, bottom: -120, child: _blob(240, AppColors.blush.withValues(alpha: .42))),
            Positioned(right: -90, bottom: -140, child: _blob(270, AppColors.primarySoft.withValues(alpha: .48))),
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
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 4, 22, 22),
                  child: PrimaryButton(
                    text: _saving ? 'Building your profile…' : 'Continue',
                    icon: _saving ? null : Icons.arrow_forward_rounded,
                    onPressed: _canContinue && !_saving ? _continue : null,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _blob(double size, Color color) {
    return Transform.rotate(
      angle: -.28,
      child: Container(
        width: size,
        height: size * .62,
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(size)),
      ),
    );
  }

  Widget _topBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 0),
      child: Row(
        children: [
          IconButton(onPressed: _saving ? null : _back, icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18)),
          const Spacer(),
          Text('${_step + 1} of 5', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
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

  Widget _buildStep() => switch (_step) {
        0 => _choiceStep(
            title: 'What’s your gender? ✨',
            subtitle: 'This helps us personalize your style recommendations',
            options: _genders,
            selected: _gender,
            onSelect: (v) => setState(() => _gender = v),
            emojis: ['👩🏻', '👨🏻', '🌈', '🔒'],
          ),
        1 => _choiceStep(
            title: 'What’s your age range? 📅',
            subtitle: 'We’ll tailor style tips to your life stage',
            options: _ages,
            selected: _ageRange,
            onSelect: (v) => setState(() => _ageRange = v),
            emojis: ['🧸', '🌸', '✨', '🌿', '💜', '🔵'],
          ),
        2 => _choiceStep(
            title: 'What’s your ethnicity? 🌎',
            subtitle: 'Helps us understand your unique coloring',
            options: _ethnicities,
            selected: _ethnicity,
            onSelect: (v) => setState(() => _ethnicity = v),
            emojis: ['🤍', '👩🏻', '👩🏽', '🧑🏻', '👩🏻', '🧑🏽', '🧑🏿', '🤎', '🌈'],
          ),
        3 => _brandStep(),
        4 => _scanStep(),
        _ => const SizedBox.shrink(),
      };

  Widget _choiceStep({
    required String title,
    required String subtitle,
    required List<String> options,
    required String? selected,
    required ValueChanged<String> onSelect,
    required List<String> emojis,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -.5)),
        const SizedBox(height: 10),
        Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.45)),
        const SizedBox(height: 28),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.only(bottom: 10),
            itemCount: options.length,
            separatorBuilder: (_, index) => const SizedBox(height: 10),
            itemBuilder: (_, index) {
              final option = options[index];
              final isSelected = selected == option;
              return _selectCard(
                option,
                emoji: emojis[index],
                selected: isSelected,
                onTap: () => onSelect(option),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _selectCard(String label, {required String emoji, required bool selected, required VoidCallback onTap}) {
    return InkWell(
      onTap: _saving ? null : onTap,
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: selected ? AppColors.lavenderMist : Colors.white.withValues(alpha: .92),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: selected ? AppColors.primary.withValues(alpha: .45) : AppColors.border, width: selected ? 1.3 : 1),
          boxShadow: selected ? [BoxShadow(color: AppColors.primary.withValues(alpha: .10), blurRadius: 16, offset: const Offset(0, 5))] : null,
        ),
        child: Row(
          children: [
            Container(width: 40, height: 40, alignment: Alignment.center, decoration: BoxDecoration(color: selected ? AppColors.primarySoft : AppColors.surfaceMuted, shape: BoxShape.circle), child: Text(emoji, style: const TextStyle(fontSize: 20))),
            const SizedBox(width: 12),
            Expanded(child: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600))),
            if (selected) const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 23),
          ],
        ),
      ),
    );
  }

  Widget _brandStep() {
    final remaining = _brands.where((brand) => !_preferredBrands.contains(brand)).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        const Center(child: Text('What brands\nmatch your vibe? 🛍️', textAlign: TextAlign.center, style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800, height: 1.1))),
        const SizedBox(height: 10),
        const Center(child: Text('Pick a few — we’ll tailor\nyour recommendations', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4))),
        const SizedBox(height: 22),
        Row(children: [const Expanded(child: Text('Your picks', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800))), Text('${_preferredBrands.length}/10', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w700))]),
        const SizedBox(height: 9),
        if (_preferredBrands.isNotEmpty)
          Wrap(spacing: 8, runSpacing: 8, children: _preferredBrands.map((brand) => InputChip(label: Text(brand, style: const TextStyle(fontSize: 11)), onDeleted: () => _toggleBrand(brand), backgroundColor: AppColors.lavenderMist, side: BorderSide(color: AppColors.primary.withValues(alpha: .22)), deleteIconColor: AppColors.textMuted)).toList())
        else
          const Text('Tap the brands you actually wear.', style: TextStyle(color: AppColors.textSecondary, fontSize: 11.5)),
        const SizedBox(height: 20),
        const Text('You might also like', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
        const SizedBox(height: 9),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.only(bottom: 10),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 3.9),
            itemCount: remaining.length,
            itemBuilder: (_, index) {
              final brand = remaining[index];
              return InkWell(
                onTap: () => _toggleBrand(brand),
                borderRadius: BorderRadius.circular(15),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: .95), borderRadius: BorderRadius.circular(15), border: Border.all(color: AppColors.border)),
                  child: Row(children: [Expanded(child: Text(brand, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600))), const Icon(Icons.favorite_border_rounded, color: AppColors.textMuted, size: 18)]),
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
        const Text('Let’s scan your\nbeautiful you ✨', textAlign: TextAlign.center, style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800, height: 1.1)),
        const SizedBox(height: 10),
        const Text('We’ll analyze your natural coloring\nto find the best shades for you', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4)),
        const SizedBox(height: 18),
        Expanded(
          child: Container(
            width: double.infinity,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(color: AppColors.surfaceMuted, borderRadius: BorderRadius.circular(26), border: Border.all(color: AppColors.border)),
            child: Stack(
              children: [
                if (_scanImage != null) Positioned.fill(child: Image.file(_scanImage!, fit: BoxFit.cover)) else const Positioned.fill(child: Center(child: Icon(Icons.face_retouching_natural_rounded, color: AppColors.primary, size: 70))),
                Positioned.fill(child: Padding(padding: const EdgeInsets.all(28), child: _faceFrame())),
                Positioned(right: 12, top: 48, child: _tips()),
                Positioned(left: 16, right: 16, bottom: 18, child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white.withValues(alpha: .90), borderRadius: BorderRadius.circular(18)), child: const Text('Use natural lighting and remove makeup & glasses.', style: TextStyle(color: AppColors.textSecondary, fontSize: 11.5, height: 1.35)))),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(children: [
          IconButton.filledTonal(onPressed: _pickPhoto, icon: const Icon(Icons.photo_library_outlined)),
          const SizedBox(width: 16),
          Expanded(child: Center(child: InkWell(onTap: _openFaceScan, customBorder: const CircleBorder(), child: Container(width: 68, height: 68, decoration: BoxDecoration(color: AppColors.primary, shape: BoxShape.circle, border: Border.all(color: AppColors.white, width: 5), boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: .26), blurRadius: 18, offset: const Offset(0, 8))]), child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 28))))),
          const SizedBox(width: 52),
        ]),
      ],
    );
  }

  Widget _faceFrame() {
    return CustomPaint(painter: _CornerPainter(), child: const SizedBox.expand());
  }

  Widget _tips() {
    return Column(children: const [
      _Tip(icon: Icons.wb_sunny_outlined, label: 'Good\nlighting'),
      SizedBox(height: 12),
      _Tip(icon: Icons.face_retouching_off_outlined, label: 'No makeup\nor filters'),
      SizedBox(height: 12),
      _Tip(icon: Icons.visibility_off_outlined, label: 'Hair tied\nback'),
      SizedBox(height: 12),
      _Tip(icon: Icons.sentiment_satisfied_alt_outlined, label: 'Look\nstraight'),
    ]);
  }

  Widget _miniLogo() => const SizedBox.shrink();
}

class _Tip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _Tip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => Container(width: 76, padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6), decoration: BoxDecoration(color: Colors.black.withValues(alpha: .28), borderRadius: BorderRadius.circular(14)), child: Column(children: [Icon(icon, color: Colors.white, size: 18), const SizedBox(height: 4), Text(label, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 8.5, height: 1.15))]));
}

class _CornerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white..strokeWidth = 2.2..style = PaintingStyle.stroke;
    const l = 26.0;
    const r = 22.0;
    final left = 18.0;
    final right = size.width - 18.0;
    final top = 24.0;
    final bottom = size.height - 24.0;
    canvas.drawLine(Offset(left, top + l), Offset(left, top), paint);
    canvas.drawLine(Offset(left, top), Offset(left + r, top), paint);
    canvas.drawLine(Offset(right - r, top), Offset(right, top), paint);
    canvas.drawLine(Offset(right, top), Offset(right, top + l), paint);
    canvas.drawLine(Offset(left, bottom - l), Offset(left, bottom), paint);
    canvas.drawLine(Offset(left, bottom), Offset(left + r, bottom), paint);
    canvas.drawLine(Offset(right - r, bottom), Offset(right, bottom), paint);
    canvas.drawLine(Offset(right, bottom - l), Offset(right, bottom), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
