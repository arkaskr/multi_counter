import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:daily_counter/core/theme/app_theme.dart';
import 'package:daily_counter/core/theme/theme_presets.dart';
import 'package:daily_counter/shared/components/neumorphic_button.dart';
import 'package:daily_counter/shared/components/neumorphic_container.dart';
import 'package:daily_counter/shared/components/neumorphic_icon_button.dart';
import 'package:daily_counter/shared/components/neumorphic_progress.dart';

void main() {
  testWidgets('Neumorphic components render and interact cleanly', (WidgetTester tester) async {
    final themeData = AppThemeData.fromPalette(ThemePresets.softLight).toThemeData();
    bool tapped = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: themeData,
        home: Scaffold(
          body: Center(
            child: Column(
              children: [
                const NeumorphicContainer(
                  child: Text('Container Content'),
                ),
                NeumorphicButton(
                  onTap: () => tapped = true,
                  child: const Text('Tap Me'),
                ),
                NeumorphicIconButton(
                  icon: Icons.add,
                  onTap: () {},
                ),
                const NeumorphicProgress(progress: 0.5),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.text('Container Content'), findsOneWidget);
    expect(find.text('Tap Me'), findsOneWidget);
    expect(find.byIcon(Icons.add), findsOneWidget);

    await tester.tap(find.text('Tap Me'));
    await tester.pump(const Duration(milliseconds: 150));
    expect(tapped, true);
  });
}
