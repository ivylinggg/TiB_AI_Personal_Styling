import 'package:flutter/material.dart';

class TodaysColourCard extends StatelessWidget {
  const TodaysColourCard({super.key});

  @override
  Widget build(BuildContext context) {
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

          Row(
            children: [
              _colourCircle(const Color(0xFFE7B38A)),
              const SizedBox(width: 12),
              _colourCircle(const Color(0xFFB8A16A)),
              const SizedBox(width: 12),
              _colourCircle(const Color(0xFF8A6A4A)),
            ],
          ),

          const SizedBox(height: 20),

          Text("Warm Spring", style: Theme.of(context).textTheme.titleLarge),

          const SizedBox(height: 8),

          Text(
            "Peach • Olive • Camel",
            style: Theme.of(context).textTheme.bodyMedium,
          ),
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
}
