import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_radius.dart';

/// The single, shared colour-name -> Color mapping for the whole app.
///
/// Before this, the same mapping logic was implemented three times
/// independently (ai_stylist_screen.dart, profile_screen.dart,
/// widgets/todays_colour_card.dart), each with slightly different keyword
/// coverage. This centralises the most complete version of it (the one
/// from todays_colour_card.dart). Those three screens will be switched
/// over to call this instead of their own private copy when they are
/// redesigned -- that is a screen-level change, out of scope for this
/// design-system-only phase, so their existing private copies are left
/// untouched for now and still work exactly as before.
class ColourNameMapper {
  ColourNameMapper._();

  static Color colourFor(String name) {
    final value = name.toLowerCase();

    if (value.contains('pink') || value.contains('rose')) {
      return const Color(0xFFE8A7B7);
    }
    if (value.contains('red') ||
        value.contains('coral') ||
        value.contains('terracotta') ||
        value.contains('rust') ||
        value.contains('berry') ||
        value.contains('ruby')) {
      return const Color(0xFFD97968);
    }
    if (value.contains('orange') || value.contains('peach')) {
      return const Color(0xFFE7A16F);
    }
    if (value.contains('yellow') ||
        value.contains('gold') ||
        value.contains('mustard')) {
      return const Color(0xFFD8B85A);
    }
    if (value.contains('green') ||
        value.contains('olive') ||
        value.contains('sage') ||
        value.contains('emerald')) {
      return const Color(0xFF8A9A68);
    }
    if (value.contains('blue') ||
        value.contains('navy') ||
        value.contains('cobalt')) {
      return const Color(0xFF7189A8);
    }
    if (value.contains('purple') ||
        value.contains('violet') ||
        value.contains('lavender') ||
        value.contains('mauve')) {
      return const Color(0xFF9A7AA8);
    }
    if (value.contains('brown') ||
        value.contains('beige') ||
        value.contains('camel') ||
        value.contains('neutral') ||
        value.contains('taupe') ||
        value.contains('cream')) {
      return const Color(0xFFB59A83);
    }
    if (value.contains('black') || value.contains('charcoal')) {
      return const Color(0xFF3A3A3A);
    }
    if (value.contains('white') ||
        value.contains('grey') ||
        value.contains('gray')) {
      return const Color(0xFFC9C4BE);
    }

    return const Color(0xFFC9B7AD);
  }
}

/// A single recommended/wardrobe colour, shown as a coloured circle with
/// an optional name label beneath it and an optional selected state.
/// [name] must always be a real colour string (e.g. a
/// ColourAnalysisResult.colours entry or a WardrobeItem.colour) -- this
/// widget never invents a colour, it only visualises real data.
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
          color: selected ? AppColors.primaryDark : AppColors.background,
          width: selected ? 2.5 : 2,
        ),
        boxShadow: [
          BoxShadow(
            color: colour.withValues(alpha: 0.35),
            blurRadius: selected ? 10 : 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: selected
          ? const Icon(Icons.check_rounded, color: AppColors.background, size: 18)
          : null,
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

    if (onTap == null) {
      return content;
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.full),
      child: content,
    );
  }
}
