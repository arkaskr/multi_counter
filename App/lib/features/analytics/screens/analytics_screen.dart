import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../core/utils/date_utils.dart';
import '../../../shared/components/neumorphic_container.dart';
import '../../../shared/components/neumorphic_icon_button.dart';
import '../../daily_edit/screens/daily_edit_screen.dart';
import '../../home/providers/home_providers.dart';
import '../../settings/providers/settings_providers.dart';
import '../models/analytics_data.dart';
import '../providers/analytics_providers.dart';

class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = context.appTheme;
    final filter = ref.watch(analyticsFilterProvider);
    final reportAsync = ref.watch(analyticsReportProvider);
    final settingsAsync = ref.watch(settingsNotifierProvider);
    final currencySymbol = settingsAsync.value?.currencySymbol ?? '₹';

    return Scaffold(
      backgroundColor: theme.background,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Screen Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'OVERVIEW & SPENDING',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                          color: theme.accent,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Analytics',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: theme.text,
                        ),
                      ),
                    ],
                  ),
                  NeumorphicIconButton(
                    icon: Icons.refresh_rounded,
                    size: 42,
                    onTap: () {
                      ref.invalidate(analyticsReportProvider);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Filter Tabs (Weekly, 15 Days, Monthly, Custom)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: [
                    _buildRangePill(
                      context,
                      ref,
                      label: 'Weekly',
                      type: AnalyticsRangeType.weekly,
                      isSelected: filter.rangeType == AnalyticsRangeType.weekly,
                    ),
                    const SizedBox(width: 8),
                    _buildRangePill(
                      context,
                      ref,
                      label: '15 Days',
                      type: AnalyticsRangeType.fifteenDays,
                      isSelected: filter.rangeType == AnalyticsRangeType.fifteenDays,
                    ),
                    const SizedBox(width: 8),
                    _buildRangePill(
                      context,
                      ref,
                      label: 'Monthly',
                      type: AnalyticsRangeType.monthly,
                      isSelected: filter.rangeType == AnalyticsRangeType.monthly,
                    ),
                    const SizedBox(width: 8),
                    _buildRangePill(
                      context,
                      ref,
                      label: 'Custom Range',
                      type: AnalyticsRangeType.custom,
                      isSelected: filter.rangeType == AnalyticsRangeType.custom,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Range Navigator (Prev, Title, Next, Date Picker)
              reportAsync.when(
                data: (report) => _buildRangeNavigator(context, ref, report, filter),
                loading: () => const SizedBox(height: 48),
                error: (_, __) => const SizedBox.shrink(),
              ),
              const SizedBox(height: 20),

              // Report Content
              reportAsync.when(
                data: (report) => _buildReportContent(context, ref, report, currencySymbol),
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child: CircularProgressIndicator(),
                  ),
                ),
                error: (e, st) => Center(
                  child: Text('Error: $e', style: TextStyle(color: theme.text)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRangePill(
    BuildContext context,
    WidgetRef ref, {
    required String label,
    required AnalyticsRangeType type,
    required bool isSelected,
  }) {
    final theme = context.appTheme;

    return GestureDetector(
      onTap: () {
        if (type == AnalyticsRangeType.custom) {
          _pickCustomDateRange(context, ref);
        } else {
          ref.read(analyticsFilterProvider.notifier).setRangeType(type);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? theme.accent : theme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? theme.accent : theme.secondaryText.withValues(alpha: 0.2),
            width: 1.2,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: theme.accent.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: isSelected ? Colors.white : theme.text,
          ),
        ),
      ),
    );
  }

  Widget _buildRangeNavigator(
    BuildContext context,
    WidgetRef ref,
    AnalyticsReport report,
    AnalyticsFilterState filter,
  ) {
    final theme = context.appTheme;

    return NeumorphicContainer(
      borderRadius: 20,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          NeumorphicIconButton(
            icon: Icons.chevron_left_rounded,
            size: 36,
            onTap: () {
              ref.read(analyticsFilterProvider.notifier).previous();
            },
          ),
          Expanded(
            child: GestureDetector(
              onTap: () {
                if (filter.rangeType == AnalyticsRangeType.custom) {
                  _pickCustomDateRange(context, ref);
                }
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      report.title,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: theme.text,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (filter.rangeType == AnalyticsRangeType.custom) ...[
                    const SizedBox(width: 6),
                    Icon(Icons.date_range_rounded, size: 16, color: theme.accent),
                  ],
                ],
              ),
            ),
          ),
          NeumorphicIconButton(
            icon: Icons.chevron_right_rounded,
            size: 36,
            onTap: () {
              ref.read(analyticsFilterProvider.notifier).next();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildReportContent(
    BuildContext context,
    WidgetRef ref,
    AnalyticsReport report,
    String currencySymbol,
  ) {
    final theme = context.appTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Primary Hero Card: Total Spending
        NeumorphicContainer(
          borderRadius: 28,
          elevation: 1.2,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 26),
          child: Column(
            children: [
              Text(
                'TOTAL SPENDING',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.4,
                  color: theme.secondaryText,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                CurrencyUtils.formatCurrency(report.totalSpending, currencySymbol),
                style: TextStyle(
                  fontSize: 42,
                  fontWeight: FontWeight.w900,
                  color: theme.accent,
                ),
              ),
              const SizedBox(height: 14),

              // Badges
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildHeroBadge(
                    context,
                    icon: Icons.restaurant_rounded,
                    label: '${report.totalMeals} ${report.totalMeals == 1 ? "Meal" : "Meals"}',
                  ),
                  const SizedBox(width: 12),
                  _buildHeroBadge(
                    context,
                    icon: Icons.calendar_today_rounded,
                    label: '${report.activeDays} Days Active',
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Key Insights 2x2 Grid
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                context,
                title: 'Daily Average',
                value: CurrencyUtils.formatCurrency(report.averageSpendingPerDay, currencySymbol),
                subtitle: 'per calendar day',
                icon: Icons.trending_up_rounded,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricCard(
                context,
                title: 'Meals Pace',
                value: '${report.averageMealsPerDay.toStringAsFixed(1)} / day',
                subtitle: '${report.totalMeals} meals total',
                icon: Icons.speed_rounded,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                context,
                title: 'Goal Completed',
                value: '${report.completedDays} / ${report.totalDaysInRange}',
                subtitle: 'days limit reached',
                icon: Icons.check_circle_outline_rounded,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricCard(
                context,
                title: 'Active Days',
                value: '${report.activeDays} Days',
                subtitle: 'with food logged',
                icon: Icons.done_all_rounded,
              ),
            ),
          ],
        ),
        const SizedBox(height: 26),

        // Spending Distribution Bar Chart
        Text(
          'DAILY SPENDING BREAKDOWN',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.1,
            color: theme.text,
          ),
        ),
        const SizedBox(height: 14),

        _buildBarChart(context, report, currencySymbol),
        const SizedBox(height: 26),

        // Daily Detailed List
        Text(
          'DAY-BY-DAY DETAILS',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.1,
            color: theme.text,
          ),
        ),
        const SizedBox(height: 14),

        _buildDailyList(context, ref, report, currencySymbol),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildHeroBadge(
    BuildContext context, {
    required IconData icon,
    required String label,
  }) {
    final theme = context.appTheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: theme.accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: theme.accent),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: theme.accent,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(
    BuildContext context, {
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
  }) {
    final theme = context.appTheme;

    return NeumorphicContainer(
      borderRadius: 20,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: theme.accent),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: theme.text,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: theme.text,
            ),
          ),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 10,
              color: theme.secondaryText,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBarChart(
    BuildContext context,
    AnalyticsReport report,
    String currencySymbol,
  ) {
    final theme = context.appTheme;
    final items = report.dailyItems;
    if (items.isEmpty) {
      return NeumorphicContainer(
        borderRadius: 20,
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Text('No records in this range', style: TextStyle(color: theme.secondaryText)),
        ),
      );
    }

    final maxSpend = items.map((e) => e.amount).fold<double>(0.0, max);
    final effectiveMax = maxSpend > 0 ? maxSpend : 1.0;

    return NeumorphicContainer(
      borderRadius: 22,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
      child: SizedBox(
        height: 150,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: items.map((item) {
              final ratio = (item.amount / effectiveMax).clamp(0.06, 1.0);
              final barHeight = 90.0 * ratio;
              final dayNum = DateTime.tryParse(item.date)?.day.toString() ?? item.date;

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (item.amount > 0)
                      Text(
                        '${item.amount.toInt()}',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: theme.secondaryText,
                        ),
                      )
                    else
                      const SizedBox(height: 12),
                    const SizedBox(height: 4),
                    Container(
                      width: 14,
                      height: barHeight,
                      decoration: BoxDecoration(
                        color: item.amount > 0
                            ? theme.accent
                            : theme.secondaryText.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(7),
                        boxShadow: item.amount > 0
                            ? [
                                BoxShadow(
                                  color: theme.accent.withValues(alpha: 0.35),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      dayNum,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: item.amount > 0 ? theme.text : theme.secondaryText,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildDailyList(
    BuildContext context,
    WidgetRef ref,
    AnalyticsReport report,
    String currencySymbol,
  ) {
    final theme = context.appTheme;
    final items = report.dailyItems.reversed.toList();

    return Column(
      children: items.map((item) {
        final parsedDate = DateTime.tryParse(item.date);
        final formattedDate = parsedDate != null
            ? AppDateUtils.formatDisplayDate(item.date)
            : item.date;

        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: GestureDetector(
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => DailyEditScreen(date: item.date),
                ),
              );
              ref.invalidate(analyticsReportProvider);
              ref.invalidate(todayRecordProvider);
              ref.invalidate(homeWeeklySummaryProvider);
            },
            child: NeumorphicContainer(
              borderRadius: 18,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: item.count > 0
                          ? theme.accent.withValues(alpha: 0.15)
                          : theme.secondaryText.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        '${item.count}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: item.count > 0 ? theme.accent : theme.secondaryText,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          formattedDate,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: theme.text,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Text(
                              '${item.count} ${item.count == 1 ? "meal" : "meals"}',
                              style: TextStyle(
                                fontSize: 11,
                                color: theme.secondaryText,
                              ),
                            ),
                            if (item.isOverride) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: Colors.amber.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'Custom',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.amber[800],
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  Text(
                    CurrencyUtils.formatCurrency(item.amount, currencySymbol),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: item.amount > 0 ? theme.text : theme.secondaryText,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
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

  Future<void> _pickCustomDateRange(BuildContext context, WidgetRef ref) async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      initialDateRange: DateTimeRange(
        start: now.subtract(const Duration(days: 14)),
        end: now,
      ),
    );

    if (picked != null) {
      ref.read(analyticsFilterProvider.notifier).setCustomRange(picked.start, picked.end);
    }
  }
}

