import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_radius.dart';

/// Shared colour-name -> Color mapping. Colour Analysis keeps the full
/// seasonal palette; the surrounding VYEA interface remains neutral.
class ColourNameMapper {
  ColourNameMapper._();

  static Color colourFor(String name) {
    final value = name.toLowerCase();
    if (value.contains('pink') || value.contains('rose')) return const Color(0xFFE1A0AE);
    if (value.contains('red') || value.contains('coral') || value.contains('terracotta') || value.contains('rust') || value.contains('berry') || value.contains('ruby')) return const Color(0xFFC96F63);
    if (value.contains('orange') || value.contains('peach')) return const Color(0xFFD99A72);
    if (value.contains('yellow') || value.contains('gold') || value.contains('mustard')) return const Color(0xFFC9A84E);
    if (value.contains('green') || value.contains('olive') || value.contains('sage') || value.contains('emerald')) return const Color(0xFF7E8D63);
    if (value.contains('blue') || value.contains('navy') || value.contains('cobalt')) return const Color(0xFF667F9C);
    if (value.contains('purple') || value.contains('violet') || value.contains('lavender') || value.contains('mauve')) return const Color(0xFF8F7698);
    if (value.contains('brown') || value.contains('beige') || value.contains('camel') || value.contains('neutral') || value.contains('taupe') || value.contains('cream')) return const Color(0xFFB09A85);
    if (value.contains('black') || value.contains('charcoal')) return const Color(0xFF363431);
    if (value.contains('white') || value.contains('grey') || value.contains('gray')) return const Color(0xFFC7C2BC);
    return const Color(0xFFC3B2A8);
  }
}

/// Presentation-only colour swatch. Data and selection remain controlled by
/// the parent screen, so existing analysis and wardrobe behaviour is intact.
class ColourSwatch extends StatelessWidget {
  final String name;
  final double size;
  final bool showLabel;
  final bool selected;
  final VoidCallback? onTap;

  const ColourSwatch({
    super.key,
    required this.name,
    this.size = 44,
    this.showLabel = false,
    this.selected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colour = ColourNameMapper.colourFor(name);
    final circle = AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: colour,
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? AppColors.primary : AppColors.background,
          width: selected ? 2.5 : 2,
        ),
        boxShadow: [
          BoxShadow(
            color: colour.withValues(alpha: selected ? .28 : .18),
            blurRadius: selected ? 9 : 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: selected ? const Icon(Icons.check_rounded, color: Colors.white, size: 18) : null,
    );

    final content = showLabel
        ? Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              circle,
              const SizedBox(height: 6),
              SizedBox(
                width: size + 20,
                child: Text(
                  name,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          )
        : circle;

    if (onTap == null) return content;
    return InkWell(onTap: onTap, borderRadius: BorderRadius.circular(AppRadius.full), child: content);
  }
}
