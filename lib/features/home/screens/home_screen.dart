import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../core/utils/date_utils.dart';
import '../../../shared/components/neumorphic_button.dart';
import '../../../shared/components/neumorphic_container.dart';
import '../../../shared/components/neumorphic_progress.dart';
import '../../../shared/models/daily_record.dart';
import '../../auth/providers/auth_providers.dart';
import '../../daily_edit/screens/daily_edit_screen.dart';
import '../../settings/providers/settings_providers.dart';
import '../providers/home_providers.dart';

class HomeScreen extends ConsumerWidget {
  final VoidCallback? onOpenSettings;

  const HomeScreen({
    super.key,
    this.onOpenSettings,
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
    final unitAmount = settings?.unitAmount ?? 45.0;
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
                // Header Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _getGreeting(),
                          style: TextStyle(
                            fontSize: 14,
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
                    // Food Days Counter Badge: only increments on days with food
                    ref.watch(foodDaysCountProvider).maybeWhen(
                          data: (foodDays) => NeumorphicContainer(
                            borderRadius: 16,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.lunch_dining_rounded, size: 16, color: theme.accent),
                                const SizedBox(width: 6),
                                Text(
                                  '$foodDays ${foodDays == 1 ? "Day" : "Days"}',
                                  style: TextStyle(
                                    fontSize: 13,
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
                const SizedBox(height: 28),

                // Main Counter Card (Hero Section)
                NeumorphicContainer(
                  borderRadius: 28,
                  elevation: 1.2,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                  child: Column(
                    children: [
                      Text(
                        "TODAY'S COUNTER",
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.5,
                          color: theme.secondaryText,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Animated Counter Display: "1 / 2"
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        transitionBuilder: (child, animation) {
                          return ScaleTransition(scale: animation, child: child);
                        },
                        child: Row(
                          key: ValueKey<int>(count),
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              '$count',
                              style: TextStyle(
                                fontSize: 64,
                                fontWeight: FontWeight.w900,
                                color: theme.text,
                                height: 1.0,
                              ),
                            ),
                            Text(
                              ' / $dailyLimit',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w700,
                                color: theme.secondaryText,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Remaining or Completed status
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: isCompleted
                              ? Colors.green.withValues(alpha: 0.15)
                              : theme.accent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          isCompleted
                              ? '✓ DAILY GOAL COMPLETED'
                              : 'REMAINING: $remaining',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.0,
                            color: isCompleted ? Colors.green : theme.accent,
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),

                      // Big Tactile +1 Button
                      SizedBox(
                        width: 140,
                        height: 64,
                        child: NeumorphicButton(
                          isProminent: true,
                          isEnabled: !isCompleted,
                          borderRadius: 24,
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
                            ref.invalidate(foodDaysCountProvider);
                            ref.read(syncServiceProvider).autoSync();
                          },
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_rounded, size: 28, color: Colors.white),
                              SizedBox(width: 4),
                              Text(
                                '1',
                                style: TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),

                      // Today's Amount Display
                      Text(
                        "TODAY'S AMOUNT",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.3,
                          color: theme.secondaryText,
                        ),
                      ),
                      const SizedBox(height: 6),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        child: Text(
                          CurrencyUtils.formatCurrency(todayAmount, currencySymbol),
                          key: ValueKey<double>(todayAmount),
                          style: TextStyle(
                            fontSize: 34,
                            fontWeight: FontWeight.w900,
                            color: theme.accent,
                          ),
                        ),
                      ),
                      if (todayRecord.amountOverride != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          '(Custom Override Applied)',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.amber[800],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Today's Summary 2x2 Grid Card
                NeumorphicContainer(
                  borderRadius: 22,
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildSummaryStat(
                          context,
                          label: 'Today Count',
                          value: '$count',
                          icon: Icons.tag_rounded,
                        ),
                      ),
                      Container(
                        height: 40,
                        width: 1,
                        color: theme.secondaryText.withValues(alpha: 0.15),
                      ),
                      Expanded(
                        child: _buildSummaryStat(
                          context,
                          label: 'Today Amount',
                          value: CurrencyUtils.formatCurrency(todayAmount, currencySymbol),
                          icon: Icons.payments_outlined,
                        ),
                      ),
                    ],
                  ),
                ),
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

  Widget _buildSummaryStat(
    BuildContext context, {
    required String label,
    required String value,
    required IconData icon,
  }) {
    final theme = context.appTheme;
    return Column(
      children: [
        Icon(icon, size: 20, color: theme.secondaryText),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: theme.text,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: theme.secondaryText,
          ),
        ),
      ],
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
}
