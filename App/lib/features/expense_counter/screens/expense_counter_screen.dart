import 'package:flutter/material.dart';
import 'package:daily_counter/core/theme/app_theme.dart';
import 'package:daily_counter/shared/components/neumorphic_button.dart';
import 'package:daily_counter/shared/components/neumorphic_container.dart';

class ExpenseCounterScreen extends StatelessWidget {
  const ExpenseCounterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.appTheme;
    const accentColor = Color(0xFF2979FF); // Electric Blue

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
          'Expense Counter',
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
                  Icons.account_balance_wallet_rounded,
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
                'Track Food & Daily Expenses',
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
                'A dedicated financial tracker for meals, grocery hauls, dining out, and split bills. Stay within budget without messy spreadsheets.',
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
                icon: Icons.savings_rounded,
                title: 'Monthly Food & Meal Budgets',
                description: 'Set a maximum spending limit for your food cycle with warnings when approaching threshold.',
                accent: accentColor,
              ),
              const SizedBox(height: 12),
              _buildFeatureItem(
                context,
                icon: Icons.category_rounded,
                title: 'Category Breakdown',
                description: 'Tag expenses by Mess, Groceries, Dining Out, Coffee, and Delivery with interactive visual charts.',
                accent: accentColor,
              ),
              const SizedBox(height: 12),
              _buildFeatureItem(
                context,
                icon: Icons.group_rounded,
                title: 'Split Bills with Roommates',
                description: 'Easily calculate shared meal costs and generate clean split summaries.',
                accent: accentColor,
              ),
              const SizedBox(height: 12),
              _buildFeatureItem(
                context,
                icon: Icons.file_download_rounded,
                title: 'Export Statements',
                description: 'Export itemized CSV or PDF statements for your monthly expense accounting.',
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

