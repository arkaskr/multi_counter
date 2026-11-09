import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:daily_counter/core/constants/app_constants.dart';
import 'package:daily_counter/core/theme/app_theme.dart';
import 'package:daily_counter/core/utils/currency_utils.dart';
import 'package:daily_counter/core/utils/date_utils.dart';
import 'package:daily_counter/shared/components/neumorphic_button.dart';
import 'package:daily_counter/shared/components/neumorphic_container.dart';
import 'package:daily_counter/shared/components/neumorphic_progress.dart';
import 'package:daily_counter/shared/models/daily_record.dart';
import 'package:daily_counter/features/auth/providers/auth_providers.dart';
import '../providers/home_providers.dart';
import '../providers/settings_providers.dart';
import 'daily_edit_screen.dart';

class HomeScreen extends ConsumerWidget {
  final VoidCallback? onOpenSettings;
  final VoidCallback? onBackToHub;

  const HomeScreen({
    super.key,
    this.onOpenSettings,
    this.onBackToHub,
  });

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning!';
    if (hour < 17) return 'Good afternoon!';
    return 'Good evening!';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = context.appTheme;
    final todayStr = AppDateUtils.getTodayDateString();

    final todayRecordAsync = ref.watch(todayRecordProvider);
    final settingsAsync = ref.watch(settingsNotifierProvider);
    final weeklySummaryAsync = ref.watch(homeWeeklySummaryProvider);

    final settings = settingsAsync.value;
    final dailyLimit = settings?.dailyLimit ?? 2;
    final unitAmount = settings?.unitAmount ?? AppConstants.defaultUnitAmount;
    final currencySymbol = settings?.currencySymbol ?? '₹';

    final todayRecord = todayRecordAsync.value ?? DailyRecord.empty(todayStr);
    final count = todayRecord.count;
    final remaining = (dailyLimit - count).clamp(0, dailyLimit);
    final isCompleted = count >= dailyLimit;
    final todayAmount = todayRecord.calculateAmount(unitAmount);

    return Scaffold(
      backgroundColor: theme.background,
      body: SafeArea(
        child: RefreshIndicator(
          color: theme.accent,
          backgroundColor: theme.surface,
          onRefresh: () async {
            await ref.read(todayRecordProvider.notifier).refresh();
            ref.invalidate(homeWeeklySummaryProvider);
            ref.invalidate(foodDaysCountProvider);
            await ref.read(syncStatusProvider.notifier).triggerSync();
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Navigation & Badges Bar
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (onBackToHub != null || Navigator.of(context).canPop())
                      GestureDetector(
                        onTap: onBackToHub ?? () => Navigator.of(context).maybePop(),
                        child: NeumorphicContainer(
                          borderRadius: 14,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.arrow_back_ios_new_rounded, size: 12, color: theme.secondaryText),
                              const SizedBox(width: 4),
                              Icon(Icons.grid_view_rounded, size: 14, color: theme.accent),
                              const SizedBox(width: 6),
                              Text(
                                'Hub',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: theme.text,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      const SizedBox.shrink(),

                    // Cycle Meals Counter Badge: shows total meals in current cycle
                    ref.watch(cycleMealsCountProvider).maybeWhen(
                          data: (cycleMeals) => NeumorphicContainer(
                            borderRadius: 14,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.restaurant_rounded, size: 14, color: theme.accent),
                                const SizedBox(width: 6),
                                Text(
                                  '$cycleMeals Meal',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: theme.text,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          orElse: () => const SizedBox.shrink(),
                        ),
                  ],
                ),
                const SizedBox(height: 16),

                // Greeting & Date Section (Uncrowded, spacious layout)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getGreeting(),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: theme.accent,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      AppDateUtils.formatDisplayDate(todayStr),
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: theme.text,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Minimal Today's Counter Hero Card
                NeumorphicContainer(
                  borderRadius: 24,
                  elevation: 1.2,
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      // Top Row: Count & Limit on left, Buttons on right
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Left side: Counter Label, Count Display, and Goal Status
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "TODAY'S COUNTER",
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.2,
                                  color: theme.secondaryText,
                                ),
                              ),
                              const SizedBox(height: 6),
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 200),
                                transitionBuilder: (child, animation) =>
                                    ScaleTransition(scale: animation, child: child),
                                child: Row(
                                  key: ValueKey<int>(count),
                                  crossAxisAlignment: CrossAxisAlignment.baseline,
                                  textBaseline: TextBaseline.alphabetic,
                                  children: [
                                    Text(
                                      '$count',
                                      style: TextStyle(
                                        fontSize: 44,
                                        fontWeight: FontWeight.w900,
                                        color: theme.text,
                                        height: 1.0,
                                      ),
                                    ),
                                    Text(
                                      ' / $dailyLimit',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                        color: theme.secondaryText,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isCompleted
                                      ? Colors.green.withValues(alpha: 0.15)
                                      : theme.accent.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  isCompleted ? '✓ GOAL MET' : 'REMAINING: $remaining',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.8,
                                    color: isCompleted ? Colors.green : theme.accent,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          // Right side: - and +1 Actions
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (count > 0) ...[
                                GestureDetector(
                                  onTap: () async {
                                    await ref.read(todayRecordProvider.notifier).decrement();
                                    ref.invalidate(homeWeeklySummaryProvider);
                                    ref.invalidate(cycleMealsCountProvider);
                                    ref.invalidate(cycleTotalAmountProvider);
                                    ref.read(syncServiceProvider).autoSync();
                                  },
                                  child: NeumorphicContainer(
                                    borderRadius: 16,
                                    padding: const EdgeInsets.all(12),
                                    child: Icon(Icons.remove_rounded, size: 20, color: theme.secondaryText),
                                  ),
                                ),
                                const SizedBox(width: 10),
                              ],
                              SizedBox(
                                width: 92,
                                height: 56,
                                child: NeumorphicButton(
                                  isProminent: true,
                                  isEnabled: !isCompleted,
                                  borderRadius: 18,
                                  onTap: () async {
                                    final res = await ref.read(todayRecordProvider.notifier).increment();
                                    if (!res.success && res.message != null && context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(res.message!),
                                          backgroundColor: Colors.amber[800],
                                        ),
                                      );
                                    }
                                    ref.invalidate(homeWeeklySummaryProvider);
                                    ref.invalidate(cycleMealsCountProvider);
                                    ref.invalidate(cycleTotalAmountProvider);
                                    ref.read(syncServiceProvider).autoSync();
                                  },
                                  child: const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.add_rounded, size: 22, color: Colors.white),
                                      SizedBox(width: 2),
                                      Text(
                                        '1',
                                        style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w900,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),
                      Divider(color: theme.secondaryText.withValues(alpha: 0.12), height: 1),
                      const SizedBox(height: 12),

                      // Bottom Row: Today's Amount & Rate info
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: theme.accent.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(Icons.payments_outlined, size: 16, color: theme.accent),
                              ),
                              const SizedBox(width: 8),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "TODAY'S AMOUNT",
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.8,
                                      color: theme.secondaryText,
                                    ),
                                  ),
                                  AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 200),
                                    child: Text(
                                      CurrencyUtils.formatCurrency(todayAmount, currencySymbol),
                                      key: ValueKey<double>(todayAmount),
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w900,
                                        color: theme.accent,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          if (todayRecord.amountOverride != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.amber.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Custom Override',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.amber[800],
                                ),
                              ),
                            )
                          else
                            Text(
                              '${CurrencyUtils.formatCurrency(settings?.unitAmount ?? AppConstants.defaultUnitAmount, currencySymbol)} / meal',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: theme.secondaryText,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Current Cycle & Checkpoint Card
                _buildCycleCheckpointCard(context, ref, theme, currencySymbol, todayStr),
                const SizedBox(height: 24),

                // Weekly Preview Section Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'WEEKLY PREVIEW',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1,
                        color: theme.text,
                      ),
                    ),
                    Text(
                      'Tap to edit',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.secondaryText,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Weekly Horizontal 7-Day Preview
                weeklySummaryAsync.when(
                  data: (summary) => _buildWeeklyPreview(context, ref, summary, dailyLimit),
                  loading: () => const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: CircularProgressIndicator(),
                    ),
                  ),
                  error: (e, _) => Center(
                    child: Text('Error loading preview: $e', style: TextStyle(color: theme.text)),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWeeklyPreview(
    BuildContext context,
    WidgetRef ref,
    dynamic summary,
    int dailyLimit,
  ) {
    final theme = context.appTheme;
    final weekDates = summary.weekDates as List<String>;
    final todayStr = AppDateUtils.getTodayDateString();

    return Row(
      children: weekDates.map((date) {
        final record = summary.records[date] as DailyRecord? ?? DailyRecord.empty(date);
        final isToday = date == todayStr;
        final dayAbbr = AppDateUtils.getDayOfWeekAbbr(date);
        final progress = dailyLimit > 0 ? (record.count / dailyLimit).clamp(0.0, 1.0) : 0.0;

        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: GestureDetector(
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => DailyEditScreen(date: date),
                  ),
                );
                ref.invalidate(todayRecordProvider);
                ref.invalidate(homeWeeklySummaryProvider);
              },
              child: NeumorphicContainer(
                borderRadius: 16,
                elevation: isToday ? 1.2 : 0.8,
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                border: isToday
                    ? Border.all(color: theme.accent, width: 1.5)
                    : null,
                child: Column(
                  children: [
                    Text(
                      dayAbbr,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: isToday ? theme.accent : theme.secondaryText,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${record.count}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: theme.text,
                      ),
                    ),
                    const SizedBox(height: 8),
                    NeumorphicProgress(
                      progress: progress,
                      height: 5,
                      borderRadius: 4,
                      color: isToday ? theme.accent : null,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCycleCheckpointCard(
    BuildContext context,
    WidgetRef ref,
    dynamic theme,
    String currencySymbol,
    String todayStr,
  ) {
    final settings = ref.watch(settingsNotifierProvider).value;
    final checkpointDate = settings?.checkpointDate;
    final cycleMeals = ref.watch(cycleMealsCountProvider).value ?? 0;
    final cycleAmount = ref.watch(cycleTotalAmountProvider).value ?? 0.0;

    final subtitle = (checkpointDate != null && checkpointDate.isNotEmpty)
        ? 'Since ${AppDateUtils.formatDisplayDate(checkpointDate)}'
        : 'All-time billing cycle';

    return NeumorphicContainer(
      borderRadius: 24,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'CURRENT BILLING CYCLE',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                      color: theme.accent,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.secondaryText,
                    ),
                  ),
                ],
              ),
              if (checkpointDate != null && checkpointDate.isNotEmpty)
                GestureDetector(
                  onTap: () async {
                    await ref.read(counterServiceProvider).clearCheckpoint();
                    ref.invalidate(settingsNotifierProvider);
                    ref.invalidate(cycleMealsCountProvider);
                    ref.invalidate(cycleTotalAmountProvider);
                    ref.read(syncServiceProvider).autoSync();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: theme.secondaryText.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'Clear',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: theme.secondaryText,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$cycleMeals',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: theme.text,
                      ),
                    ),
                    Text(
                      cycleMeals == 1 ? 'Meal in cycle' : 'Meals in cycle',
                      style: TextStyle(fontSize: 12, color: theme.secondaryText),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      CurrencyUtils.formatCurrency(cycleAmount, currencySymbol),
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: theme.accent,
                      ),
                    ),
                    Text(
                      'Cycle amount due',
                      style: TextStyle(fontSize: 12, color: theme.secondaryText),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          NeumorphicButton(
            borderRadius: 18,
            onTap: () => _showCheckpointDialog(
              context,
              ref,
              todayStr,
              cycleMeals,
              cycleAmount,
              currencySymbol,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.flag_rounded, size: 18, color: theme.accent),
                const SizedBox(width: 8),
                Text(
                  'Checkpoint (Settle up to today)',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: theme.text,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showCheckpointDialog(
    BuildContext context,
    WidgetRef ref,
    String todayStr,
    int cycleMeals,
    double cycleAmount,
    String currencySymbol,
  ) async {
    final theme = context.appTheme;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          backgroundColor: theme.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Row(
            children: [
              Icon(Icons.flag_rounded, color: theme.accent),
              const SizedBox(width: 10),
              Text(
                'Set Checkpoint',
                style: TextStyle(fontWeight: FontWeight.w800, color: theme.text),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Settling your bill for today (${AppDateUtils.formatDisplayDate(todayStr)})?',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: theme.text),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '$cycleMeals ${cycleMeals == 1 ? "Meal" : "Meals"}',
                      style: TextStyle(fontWeight: FontWeight.w700, color: theme.text),
                    ),
                    Text(
                      CurrencyUtils.formatCurrency(cycleAmount, currencySymbol),
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: theme.accent,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Starting tomorrow, your widget and cycle counters will start fresh from 0 for your next payment cycle. All your past records remain intact in Analytics.',
                style: TextStyle(fontSize: 12, color: theme.secondaryText, height: 1.4),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx, false),
              child: Text('Cancel', style: TextStyle(color: theme.secondaryText)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.accent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () => Navigator.pop(dialogCtx, true),
              child: const Text('Confirm Checkpoint', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );

    if (confirmed == true && context.mounted) {
      await ref.read(counterServiceProvider).setCheckpoint(todayStr);
      ref.invalidate(settingsNotifierProvider);
      ref.invalidate(cycleMealsCountProvider);
      ref.invalidate(cycleTotalAmountProvider);
      ref.read(syncServiceProvider).autoSync();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Checkpoint created for ${AppDateUtils.formatDisplayDate(todayStr)}!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }
}
