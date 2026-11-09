import 'package:flutter/material.dart';
import 'package:daily_counter/core/theme/app_theme.dart';
import 'package:daily_counter/shared/components/neumorphic_container.dart';

class HubCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color iconColor;
  final Color iconBgColor;
  final VoidCallback onTap;

  const HubCard({
    super.key,
    required this.icon,
    required this.title,
    required this.iconColor,
    required this.iconBgColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.appTheme;

    return GestureDetector(
      onTap: onTap,
      child: NeumorphicContainer(
        borderRadius: 24,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 26),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Icon squircle
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: iconBgColor,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(icon, color: iconColor, size: 30),
            ),
            const SizedBox(height: 16),
            // Title
            Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: theme.text,
                letterSpacing: -0.2,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
