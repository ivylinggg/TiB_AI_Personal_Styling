import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_gradients.dart';
import '../ai/style_me_screen.dart';
import '../ai/style_personality_screen.dart';
import '../analysis/analysis_screen.dart';
import '../dashboard/dashboard_screen.dart';
import '../wardrobe/wardrobe_screen.dart';

class StyleSetupFlow extends StatefulWidget {
  const StyleSetupFlow({super.key});

  @override
  State<StyleSetupFlow> createState() => _StyleSetupFlowState();
}

class _StyleSetupFlowState extends State<StyleSetupFlow> {
  int _step = 0;

  static const _steps = [
    _SetupStep('01 · COLOUR', 'Discover your colours.', 'Start with your personal colour profile.', Icons.palette_outlined, AppGradients.blush),
    _SetupStep('02 · PERSONALITY', 'Find your style language.', 'Choose the looks that naturally feel like you.', Icons.auto_awesome_outlined, AppGradients.soft),
    _SetupStep('03 · WARDROBE', 'Bring your wardrobe in.', 'Add pieces TiB can actually style for you.', Icons.checkroom_outlined, AppGradients.ai),
    _SetupStep('04 · YOUR STYLIST', 'Meet your personal stylist.', 'Use everything TiB has learned to create your next look.', Icons.auto_awesome_rounded, AppGradients.primary),
  ];

  Future<void> _continue() async {
    if (_step == 0) {
      await Navigator.push(context, MaterialPageRoute(builder: (_) => const AnalysisScreen()));
    } else if (_step == 1) {
      await Navigator.push(context, MaterialPageRoute(builder: (_) => const StylePersonalityScreen()));
    } else if (_step == 2) {
      await Navigator.push(context, MaterialPageRoute(builder: (_) => const WardrobeScreen()));
    } else {
      await Navigator.push(context, MaterialPageRoute(builder: (_) => const StyleMeScreen()));
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const DashboardScreen()), (_) => false);
      return;
    }
    if (!mounted) return;
    if (_step < _steps.length - 1) setState(() => _step++);
  }

  void _skip() => Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const DashboardScreen()), (_) => false);

  @override
  Widget build(BuildContext context) {
    final current = _steps[_step];
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 10, 22, 0),
              child: Row(children: [
                const Text('TiB', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: -1)),
                const Spacer(),
                TextButton(onPressed: _skip, child: const Text('Do this later')),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
              child: Row(children: List.generate(_steps.length, (i) => Expanded(child: Container(height: 4, margin: EdgeInsets.only(right: i == _steps.length - 1 ? 0 : 5), decoration: BoxDecoration(color: i <= _step ? AppColors.primary : AppColors.border, borderRadius: BorderRadius.circular(10))))),
            ),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 280),
                child: Padding(
                  key: ValueKey(_step),
                  padding: const EdgeInsets.fromLTRB(24, 22, 24, 10),
                  child: Column(children: [
                    Expanded(child: Container(width: double.infinity, decoration: BoxDecoration(gradient: current.gradient, borderRadius: BorderRadius.circular(34)), child: Stack(children: [
                      Positioned(top: 24, left: 24, child: Container(padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7), decoration: BoxDecoration(color: Colors.white.withValues(alpha: .20), borderRadius: BorderRadius.circular(30)), child: Text(current.eyebrow, style: const TextStyle(color: Colors.white, fontSize: 8.5, fontWeight: FontWeight.w800, letterSpacing: .9)))),
                      Center(child: Container(width: 180, height: 180, decoration: BoxDecoration(color: Colors.white.withValues(alpha: .82), shape: BoxShape.circle), child: Icon(current.icon, size: 70, color: AppColors.primaryDark))),
                      Positioned(right: 25, bottom: 24, child: Text('0${_step + 1}', style: TextStyle(color: Colors.white.withValues(alpha: .72), fontSize: 38, fontWeight: FontWeight.w200))),
                    ]))),
                    const SizedBox(height: 25),
                    Text(current.title, textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800, height: 1.08, letterSpacing: -.7)),
                    const SizedBox(height: 11),
                    Text(current.subtitle, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.5)),
                  ]),
                ),
              ),
            ),
            Padding(padding: const EdgeInsets.fromLTRB(24, 4, 24, 24), child: SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: _continue, icon: Icon(_step == _steps.length - 1 ? Icons.auto_awesome_rounded : Icons.arrow_forward_rounded), label: Text(_step == _steps.length - 1 ? 'Meet TiB' : 'Continue')))),
          ],
        ),
      ),
    );
  }
}

class _SetupStep {
  final String eyebrow;
  final String title;
  final String subtitle;
  final IconData icon;
  final LinearGradient gradient;
  const _SetupStep(this.eyebrow, this.title, this.subtitle, this.icon, this.gradient);
}
