import 'package:flutter/material.dart';

/// Shows the user's recommended colours from their latest saved colour
/// analysis. Pass [season] and [colours] from the real analysis result;
/// when they are null/empty (no analysis yet), an empty state is shown
/// instead of fabricated colours.
class TodaysColourCard extends StatelessWidget {
  final String? season;
  final List<String>? colours;

  const TodaysColourCard({super.key, this.season, this.colours});

  @override
  Widget build(BuildContext context) {
    final hasData =
        season != null &&
        season!.isNotEmpty &&
        colours != null &&
        colours!.isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 15,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Today's Colour",
            style: Theme.of(context).textTheme.titleMedium,
          ),

          const SizedBox(height: 16),

          if (hasData) ...[
            Row(
              children: colours!
                  .take(3)
                  .map(
                    (colour) => Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: _colourCircle(_colourFor(colour)),
                    ),
                  )
                  .toList(),
            ),

            const SizedBox(height: 20),

            Text(season!, style: Theme.of(context).textTheme.titleLarge),

            const SizedBox(height: 8),

            Text(
              colours!.take(3).join(' • '),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ] else ...[
            Text(
              "Complete your colour analysis to see your recommended colours here.",
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ],
      ),
    );
  }

  Widget _colourCircle(Color color) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }

  Color _colourFor(String name) {
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
