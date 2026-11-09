import 'package:flutter/material.dart';
import 'package:daily_counter/core/theme/app_theme.dart';
import 'package:daily_counter/shared/components/neumorphic_button.dart';
import 'package:daily_counter/shared/components/neumorphic_container.dart';

class CalorieCounterScreen extends StatelessWidget {
  const CalorieCounterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.appTheme;
    const accentColor = Color(0xFFFF6D00); // Warm orange / fire

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
          'Calorie Counter',
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
                      color: accentColor.withValues(alpha: 0.25),
                      blurRadius: 24,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.local_fire_department_rounded,
                  size: 48,
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
                child: const Text(
                  'COMING SOON',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                    color: accentColor,
                  ),
                ),
              ),
              const SizedBox(height: 14),

              Text(
                'Track Your Daily Calories',
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
                'We are building a smart calorie & nutrition logger to seamlessly complement your meal counter with macro breakdown and hydration targets.',
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
                  'PLANNED FEATURES',
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
                icon: Icons.track_changes_rounded,
                title: 'Daily Caloric Target',
                description: 'Set custom calorie goals based on fitness targets (maintenance, deficit, or surplus).',
                accent: accentColor,
              ),
              const SizedBox(height: 12),
              _buildFeatureItem(
                context,
                icon: Icons.pie_chart_rounded,
                title: 'Macronutrient Split',
                description: 'Track protein, carb, and healthy fat distribution per meal with visual progress rings.',
                accent: accentColor,
              ),
              const SizedBox(height: 12),
              _buildFeatureItem(
                context,
                icon: Icons.qr_code_scanner_rounded,
                title: 'Barcode & Food Search',
                description: 'Quickly scan packaged foods or search common meals for instant nutritional breakdown.',
                accent: accentColor,
              ),
              const SizedBox(height: 12),
              _buildFeatureItem(
                context,
                icon: Icons.water_drop_rounded,
                title: 'Hydration Tracking',
                description: 'Log daily water intake with quick-add reminders and streak tracking.',
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

