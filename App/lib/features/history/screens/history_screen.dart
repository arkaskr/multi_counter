import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../core/utils/date_utils.dart';
import '../../../shared/components/neumorphic_container.dart';
import '../../../shared/components/neumorphic_icon_button.dart';
import '../../../shared/components/neumorphic_progress.dart';
import '../../../shared/models/daily_record.dart';
import '../../../shared/models/weekly_summary.dart';
import '../../daily_edit/screens/daily_edit_screen.dart';
import '../../home/providers/home_providers.dart';
import '../../settings/providers/settings_providers.dart';
import '../providers/history_providers.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = context.appTheme;
    final anchorDate = ref.watch(historyAnchorDateProvider);
    final settingsAsync = ref.watch(settingsNotifierProvider);
    final historySummaryAsync = ref.watch(historyWeeklySummaryProvider);

    final settings = settingsAsync.value;
    final dailyLimit = settings?.dailyLimit ?? 2;
    final unitAmount = settings?.unitAmount ?? AppConstants.defaultUnitAmount;
    final currencySymbol = settings?.currencySymbol ?? '₹';
    final weekStart = settings?.weekStart ?? 'monday';

    final weekDates = AppDateUtils.getWeekDates(anchorDate, weekStart);
    final weekRangeStr = AppDateUtils.formatWeekRange(weekDates);
    final isAtCurrentWeek = !AppDateUtils.isFutureWeek(
      AppDateUtils.getNextWeekAnchor(anchorDate),
      weekStart,
    );

    return Scaffold(
      backgroundColor: theme.background,
      body: SafeArea(
        child: SingleChildScrollView(
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
                        'WEEKLY BREAKDOWN',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                          color: theme.accent,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'History',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: theme.text,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      if (AppDateUtils.formatDate(anchorDate) != AppDateUtils.formatDate(DateTime.now()))
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: NeumorphicIconButton(
                            icon: Icons.today_rounded,
                            tooltip: 'Current Week',
                            onTap: () {
                              ref.read(historyAnchorDateProvider.notifier).setAnchor(DateTime.now());
                            },
                          ),
                        ),
                      NeumorphicIconButton(
                        icon: Icons.calendar_month_rounded,
                        tooltip: 'Select Date',
                        onTap: () => _pickDateFromCalendar(context, ref, anchorDate),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Week Selector Navigator Card
              NeumorphicContainer(
                borderRadius: 20,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    NeumorphicIconButton(
                      icon: Icons.chevron_left_rounded,
                      size: 40,
                      iconSize: 22,
                      tooltip: 'Previous Week',
                      onTap: () {
                        ref.read(historyAnchorDateProvider.notifier).setAnchor(
                            AppDateUtils.getPreviousWeekAnchor(anchorDate));
                      },
                    ),
                    Text(
                      weekRangeStr,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: theme.text,
                      ),
                    ),
                    NeumorphicIconButton(
                      icon: Icons.chevron_right_rounded,
                      size: 40,
                      iconSize: 22,
                      tooltip: 'Next Week',
                      isEnabled: isAtCurrentWeek,
                      onTap: () {
                        if (isAtCurrentWeek) {
                          ref.read(historyAnchorDateProvider.notifier).setAnchor(
                              AppDateUtils.getNextWeekAnchor(anchorDate));
                        }
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Weekly Summary Stats
              historySummaryAsync.when(
                data: (summary) => _buildWeeklySummaryCard(context, summary, currencySymbol),
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(),
                  ),
                ),
                error: (e, _) => Center(
                  child: Text('Error loading history: $e', style: TextStyle(color: theme.text)),
                ),
              ),
              const SizedBox(height: 24),

              // Daily Breakdown Section Header
              Text(
                'DAILY BREAKDOWN',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                  color: theme.secondaryText,
                ),
              ),
              const SizedBox(height: 12),

              // 7 Days List
              historySummaryAsync.when(
                data: (summary) => _buildDailyList(context, ref, summary, dailyLimit, unitAmount, currencySymbol),
                loading: () => const SizedBox.shrink(),
                error: (e, _) => const SizedBox.shrink(),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickDateFromCalendar(
    BuildContext context,
    WidgetRef ref,
    DateTime anchorDate,
  ) async {
    final now = DateTime.now();
    final theme = context.appTheme;

    final picked = await showDatePicker(
      context: context,
      initialDate: anchorDate.isAfter(now) ? now : anchorDate,
      firstDate: DateTime(2020),
      lastDate: now,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: theme.accent,
              onPrimary: Colors.white,
              surface: theme.surface,
              onSurface: theme.text,
            ),
            dialogBackgroundColor: theme.surface,
          ),
          child: child!,
        );
      },
    );

    if (picked != null && context.mounted) {
      ref.read(historyAnchorDateProvider.notifier).setAnchor(picked);
      final pickedDateStr = AppDateUtils.formatDate(picked);
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DailyEditScreen(date: pickedDateStr),
        ),
      );
      ref.invalidate(historyWeeklySummaryProvider);
      ref.invalidate(homeWeeklySummaryProvider);
      ref.invalidate(todayRecordProvider);
    }
  }

  Widget _buildWeeklySummaryCard(
    BuildContext context,
    WeeklySummary summary,
    String currencySymbol,
  ) {
    final theme = context.appTheme;

    return NeumorphicContainer(
      borderRadius: 24,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
      child: Row(
        children: [
          Expanded(
            child: _buildSummaryItem(
              context,
              title: 'Total Count',
              value: '${summary.totalCount}',
              subtitle: 'units',
              icon: Icons.tag_rounded,
            ),
          ),
          Container(height: 48, width: 1, color: theme.secondaryText.withValues(alpha: 0.15)),
          Expanded(
            child: _buildSummaryItem(
              context,
              title: 'Total Amount',
              value: CurrencyUtils.formatCurrency(summary.totalAmount, currencySymbol),
              subtitle: 'earned',
              icon: Icons.payments_rounded,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(
    BuildContext context, {
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
  }) {
    final theme = context.appTheme;

    return Column(
      children: [
        Icon(icon, size: 20, color: theme.accent),
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
          title,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: theme.secondaryText,
          ),
        ),
      ],
    );
  }

  Widget _buildDailyList(
    BuildContext context,
    WidgetRef ref,
    WeeklySummary summary,
    int dailyLimit,
    double unitAmount,
    String currencySymbol,
  ) {
    final theme = context.appTheme;
    final todayStr = AppDateUtils.getTodayDateString();

    return Column(
      children: summary.weekDates.map((date) {
        final record = summary.records[date] ?? DailyRecord.empty(date);
        final isToday = date == todayStr;
        final hasOverride = record.amountOverride != null;
        final dailyAmount = record.calculateAmount(unitAmount);
        final progress = dailyLimit > 0 ? (record.count / dailyLimit).clamp(0.0, 1.0) : 0.0;

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: GestureDetector(
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => DailyEditScreen(date: date),
                ),
              );
              ref.invalidate(historyWeeklySummaryProvider);
              ref.invalidate(homeWeeklySummaryProvider);
              ref.invalidate(todayRecordProvider);
            },
            child: NeumorphicContainer(
              borderRadius: 20,
              padding: const EdgeInsets.all(16),
              border: isToday
                  ? Border.all(color: theme.accent.withValues(alpha: 0.7), width: 1.5)
                  : null,
              child: Row(
                children: [
                  // Day Badge
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: isToday
                          ? theme.accent.withValues(alpha: 0.15)
                          : theme.background,
                      borderRadius: BorderRadius.circular(16),
                      border: isToday
                          ? Border.all(color: theme.accent, width: 1.5)
                          : null,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          AppDateUtils.getDayOfWeekAbbr(date),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: isToday ? theme.accent : theme.text,
                          ),
                        ),
                        Text(
                          AppDateUtils.parseDate(date).day.toString(),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: isToday ? theme.accent : theme.secondaryText,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Middle details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              AppDateUtils.getDayOfWeekFull(date),
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: theme.text,
                              ),
                            ),
                            if (isToday) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: theme.accent,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  'TODAY',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                            if (hasOverride) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.amber.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  'OVERRIDE',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.amber,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Text(
                              'Count: ${record.count}',
                              style: TextStyle(
                                fontSize: 13,
                                color: theme.secondaryText,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              CurrencyUtils.formatCurrency(dailyAmount, currencySymbol),
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: theme.accent,
                              ),
                            ),
                          ],
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
                  const SizedBox(width: 12),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: theme.secondaryText.withValues(alpha: 0.5),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
