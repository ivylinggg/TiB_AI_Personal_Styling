import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,

      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 10),

              Text(
                "Good Morning 👋",
                style: Theme.of(context).textTheme.titleMedium,
              ),

              const SizedBox(height: 6),

              Text(
                "Welcome to TiB AI",
                style: Theme.of(context).textTheme.headlineMedium,
              ),

              const SizedBox(height: 35),

              _buildMainCard(),

              const SizedBox(height: 20),

              Row(
                children: [
                  Expanded(
                    child: _buildSmallCard(
                      icon: Icons.palette_outlined,
                      title: "Colour\nAnalysis",
                    ),
                  ),

                  const SizedBox(width: 15),

                  Expanded(
                    child: _buildSmallCard(
                      icon: Icons.checkroom_outlined,
                      title: "Wardrobe",
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              Row(
                children: [
                  Expanded(
                    child: _buildSmallCard(
                      icon: Icons.auto_awesome,
                      title: "AI Stylist",
                    ),
                  ),

                  const SizedBox(width: 15),

                  Expanded(
                    child: _buildSmallCard(
                      icon: Icons.school_outlined,
                      title: "Learning",
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 30),

              Text(
                "Today's Recommendation",
                style: Theme.of(context).textTheme.titleLarge,
              ),

              const SizedBox(height: 15),

              _buildRecommendation(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMainCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(25),

      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(25),
        gradient: const LinearGradient(
          colors: [Color(0xffC58F73), Color(0xffEFB8C8)],
        ),
      ),

      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.auto_awesome, color: Colors.white, size: 42),

          SizedBox(height: 18),

          Text(
            "Discover Your Best Colours",
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),

          SizedBox(height: 8),

          Text(
            "Start your AI personal styling journey today.",
            style: TextStyle(color: Colors.white70, fontSize: 15),
          ),
        ],
      ),
    );
  }

  Widget _buildSmallCard({required IconData icon, required String title}) {
    return Container(
      height: 140,

      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [BoxShadow(blurRadius: 15, color: Colors.black12)],
      ),

      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: AppColors.primary, size: 38),

          const SizedBox(height: 15),

          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendation() {
    return Container(
      padding: const EdgeInsets.all(20),

      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),

      child: const Row(
        children: [
          CircleAvatar(radius: 28, child: Icon(Icons.lightbulb)),

          SizedBox(width: 15),

          Expanded(
            child: Text(
              "Try wearing warm beige or soft peach today to enhance your natural complexion.",
            ),
          ),
        ],
      ),
    );
  }
}
