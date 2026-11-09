import 'package:flutter/material.dart';
import 'package:daily_counter/core/theme/app_theme.dart';
import 'package:daily_counter/shared/components/neumorphic_button.dart';
import 'package:daily_counter/shared/components/neumorphic_container.dart';

class SurpriseScreen extends StatelessWidget {
  const SurpriseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.appTheme;
    const accentColor = Color(0xFFA855F7); // Radiant Purple / Violet

    return Scaffold(
      backgroundColor: theme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: theme.text),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Surprise',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: theme.text,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 12),
              // Hero Icon with glow
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: accentColor.withValues(alpha: 0.4), width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: accentColor.withValues(alpha: 0.3),
                      blurRadius: 26,
                      spreadRadius: 3,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  size: 46,
                  color: accentColor,
                ),
              ),
              const SizedBox(height: 20),

              // Title & Status
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: accentColor.withValues(alpha: 0.4)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.stars_rounded, size: 14, color: accentColor),
                    SizedBox(width: 6),
                    Text(
                      'COMING SOON',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                        color: accentColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              Text(
                'Something Special is Cooking!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: theme.text,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 10),

              Text(
                'We are designing exclusive gamified features, milestone achievements, streak rewards, and intelligent meal insights to keep you motivated.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: theme.secondaryText,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 32),

              // Planned Features Preview
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'SNEAK PEEK',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                    color: theme.secondaryText,
                  ),
                ),
              ),
              const SizedBox(height: 14),

              _buildFeatureItem(
                context,
                icon: Icons.military_tech_rounded,
                title: 'Streak Rewards & Milestones',
                description: 'Unlock special badges and celebratory themes as you maintain consistent logging streaks.',
                accent: accentColor,
              ),
              const SizedBox(height: 12),
              _buildFeatureItem(
                context,
                icon: Icons.psychology_rounded,
                title: 'AI Meal & Budget Insights',
                description: 'Personalized recommendations on optimizing your monthly meal spending without compromising nutrition.',
                accent: accentColor,
              ),
              const SizedBox(height: 12),
              _buildFeatureItem(
                context,
                icon: Icons.casino_rounded,
                title: 'Mystery Challenges',
                description: 'Fun weekly challenges to save extra money or try balanced, healthy recipes.',
                accent: accentColor,
              ),
              const SizedBox(height: 12),
              _buildFeatureItem(
                context,
                icon: Icons.palette_rounded,
                title: 'Secret Custom Themes',
                description: 'Exclusive community neumorphic theme palettes unlocked through secret Easter eggs.',
                accent: accentColor,
              ),

              const SizedBox(height: 32),

              // Back to Hub Button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: NeumorphicButton(
                  isProminent: true,
                  onTap: () => Navigator.of(context).pop(),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.grid_view_rounded, size: 18, color: Colors.white),
                      SizedBox(width: 8),
                      Text(
                        'Back to Modules Hub',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String description,
    required Color accent,
  }) {
    final theme = context.appTheme;

    return NeumorphicContainer(
      borderRadius: 18,
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: accent, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: theme.text,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.secondaryText,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

