import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../data/professional_style_data.dart';
import '../../data/season_colour_guide.dart';
import '../../models/colour_analysis_result.dart';
import '../../widgets/colour_swatch.dart';

enum FlashScanResultAction {
  continueOnboarding,
  rescan,
}

class FlashScanResultScreen extends StatelessWidget {
  final ColourAnalysisResult result;
  final File scanImage;

  const FlashScanResultScreen({
    super.key,
    required this.result,
    required this.scanImage,
  });

  @override
  Widget build(BuildContext context) {
    final season = SeasonColourGuide.forSeason(result.season);
    final avoid = ProfessionalStyleData.avoidColours[result.season] ??
        const <String>[];
    final bestColours = season.bestColours.isNotEmpty
        ? season.bestColours
        : result.colours;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned(
              left: -80,
              bottom: -130,
              child: _blob(260, AppColors.blush.withValues(alpha: .40)),
            ),
            Positioned(
              right: -90,
              bottom: -150,
              child: _blob(280, AppColors.primarySoft.withValues(alpha: .46)),
            ),
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 8, 18, 4),
                  child: Row(
                    children: [
                      Material(
                        color: AppColors.surface,
                        shape: const CircleBorder(),
                        child: IconButton(
                          tooltip: 'Rescan',
                          onPressed: () => Navigator.pop(
                            context,
                            FlashScanResultAction.rescan,
                          ),
                          icon: const Icon(
                            Icons.arrow_back_ios_new_rounded,
                            size: 18,
                          ),
                        ),
                      ),
                      const Spacer(),
                      const Text(
                        'Your Scan Result  ✨',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const Spacer(),
                      const SizedBox(width: 48),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(18, 6, 18, 20),
                    children: [
                      _scanImageCard(),
                      const SizedBox(height: 2),
                      _resultCard(
                        context: context,
                        season: season,
                        bestColours: bestColours,
                        avoid: avoid,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _scanImageCard() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: AspectRatio(
        aspectRatio: .93,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.file(scanImage, fit: BoxFit.cover),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      Colors.transparent,
                      Colors.black.withValues(alpha: .18),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),
            Positioned(
              top: 18,
              left: 18,
              child: _cornerShape(topLeft: true),
            ),
            Positioned(
              top: 18,
              right: 18,
              child: _cornerShape(topRight: true),
            ),
            Positioned(
              bottom: 18,
              left: 18,
              child: _cornerShape(bottomLeft: true),
            ),
            Positioned(
              bottom: 18,
              right: 18,
              child: _cornerShape(bottomRight: true),
            ),
            Positioned.fill(
              child: Center(
                child: Container(
                  width: 188,
                  height: 248,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Colors.white.withValues(alpha: .84),
                      width: 1.3,
                    ),
                    borderRadius: BorderRadius.circular(100),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 20,
              right: 10,
              child: Column(
                children: const [
                  _ResultTip(icon: Icons.wb_sunny_outlined, label: 'Good\nlighting'),
                  SizedBox(height: 11),
                  _ResultTip(
                    icon: Icons.face_retouching_natural_outlined,
                    label: 'No makeup\nor filters',
                  ),
                  SizedBox(height: 11),
                  _ResultTip(
                    icon: Icons.person_outline_rounded,
                    label: 'Hair tied\nback',
                  ),
                  SizedBox(height: 11),
                  _ResultTip(
                    icon: Icons.sentiment_satisfied_alt_outlined,
                    label: 'Look\nstraight',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _resultCard({
    required BuildContext context,
    required SeasonColourProfile season,
    required List<String> bestColours,
    required List<String> avoid,
  }) {
    return Container(
      margin: const EdgeInsets.only(top: -6),
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFAFC),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.border.withValues(alpha: .7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Center(
            child: Text(
              'Your Best Color Season',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(height: 7),
          Center(
            child: Text(
              result.season,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.primaryDark,
                fontSize: 31,
                fontWeight: FontWeight.w900,
                letterSpacing: -.7,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              season.description,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                height: 1.45,
              ),
            ),
          ),
          const SizedBox(height: 17),
          Row(
            children: [
              Expanded(
                child: _attribute(
                  icon: Icons.thermostat_outlined,
                  title: 'Color Type',
                  value: '${result.undertone} & ${result.brightness}',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _attribute(
                  icon: Icons.contrast_rounded,
                  title: 'Overall Contrast',
                  value: result.contrast,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Divider(color: AppColors.border.withValues(alpha: .7)),
          const SizedBox(height: 17),
          const Text(
            'Your Best Colors',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 11),
          SizedBox(
            height: 43,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: bestColours.take(7).length,
              separatorBuilder: (_, index) => const SizedBox(width: 8),
              itemBuilder: (_, index) => ColourSwatch(
                name: bestColours[index],
                size: 43,
              ),
            ),
          ),
          const SizedBox(height: 19),
          const Text(
            'Avoid',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 11),
          SizedBox(
            height: 43,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: avoid.take(7).length,
              separatorBuilder: (_, index) => const SizedBox(width: 8),
              itemBuilder: (_, index) => ColourSwatch(
                name: avoid[index],
                size: 43,
              ),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => Navigator.pop(
                context,
                FlashScanResultAction.continueOnboarding,
              ),
              icon: const Icon(Icons.arrow_forward_rounded),
              label: const Text('Continue'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: TextButton.icon(
              onPressed: () => Navigator.pop(
                context,
                FlashScanResultAction.rescan,
              ),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Rescan'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primaryDark,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _attribute({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(11, 12, 11, 12),
      decoration: BoxDecoration(
        color: AppColors.lavenderMist.withValues(alpha: .66),
        borderRadius: BorderRadius.circular(17),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _cornerShape({
    bool topLeft = false,
    bool topRight = false,
    bool bottomLeft = false,
    bool bottomRight = false,
  }) {
    return SizedBox(
      width: 42,
      height: 42,
      child: CustomPaint(
        painter: _CornerPainter(
          topLeft: topLeft,
          topRight: topRight,
          bottomLeft: bottomLeft,
          bottomRight: bottomRight,
        ),
      ),
    );
  }

  Widget _blob(double size, Color color) => Container(
        width: size,
        height: size * .62,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(size),
        ),
      );
}

class _ResultTip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _ResultTip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 22),
        const SizedBox(height: 3),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 8.5,
            fontWeight: FontWeight.w700,
            height: 1.05,
          ),
        ),
      ],
    );
  }
}

class _CornerPainter extends CustomPainter {
  final bool topLeft;
  final bool topRight;
  final bool bottomLeft;
  final bool bottomRight;

  const _CornerPainter({
    required this.topLeft,
    required this.topRight,
    required this.bottomLeft,
    required this.bottomRight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: .88)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    const line = 18.0;

    if (topLeft) {
      canvas.drawLine(const Offset(2, 2), const Offset(line, 2), paint);
      canvas.drawLine(const Offset(2, 2), const Offset(2, line), paint);
    }
    if (topRight) {
      canvas.drawLine(Offset(size.width - 2, 2), Offset(size.width - line, 2), paint);
      canvas.drawLine(Offset(size.width - 2, 2), Offset(size.width - 2, line), paint);
    }
    if (bottomLeft) {
      canvas.drawLine(Offset(2, size.height - 2), Offset(line, size.height - 2), paint);
      canvas.drawLine(Offset(2, size.height - 2), Offset(2, size.height - line), paint);
    }
    if (bottomRight) {
      canvas.drawLine(Offset(size.width - 2, size.height - 2), Offset(size.width - line, size.height - 2), paint);
      canvas.drawLine(Offset(size.width - 2, size.height - 2), Offset(size.width - 2, size.height - line), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _CornerPainter oldDelegate) => false;
}
