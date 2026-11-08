import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_presets.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../core/utils/date_utils.dart';
import '../../../shared/components/neumorphic_button.dart';
import '../../../shared/components/neumorphic_container.dart';
import '../../../shared/components/neumorphic_input.dart';
import '../../../shared/components/neumorphic_theme_card.dart';
import '../../../shared/models/daily_record.dart';
import '../../home/providers/home_providers.dart';
import '../providers/settings_providers.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final TextEditingController _unitAmountController = TextEditingController();
  final TextEditingController _customLimitController = TextEditingController();
  final TextEditingController _currencySymbolController = TextEditingController();

  @override
  void dispose() {
    _unitAmountController.dispose();
    _customLimitController.dispose();
    _currencySymbolController.dispose();
    super.dispose();
  }

  void _showConflictDialog(List<DailyRecord> conflicts, int newLimit) {
    final theme = context.appTheme;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Daily Limit Conflict',
          style: TextStyle(color: theme.text, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Cannot set daily limit to $newLimit because ${conflicts.length} historical record(s) have counts higher than $newLimit:',
              style: TextStyle(color: theme.secondaryText, fontSize: 14),
            ),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 180),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: conflicts.length,
                itemBuilder: (c, i) {
                  final rec = conflicts[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      '• ${AppDateUtils.formatShortDate(rec.date)}: count ${rec.count}',
                      style: TextStyle(color: theme.text, fontWeight: FontWeight.w600),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Please lower or reset the count for those days before setting the limit to $newLimit.',
              style: TextStyle(color: Colors.amber[800], fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('OK', style: TextStyle(color: theme.accent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _trySetDailyLimit(int newLimit) async {
    final service = ref.read(settingsServiceProvider);
    final conflicts = await service.checkDailyLimitConflicts(newLimit);
    if (conflicts.isNotEmpty && mounted) {
      _showConflictDialog(conflicts, newLimit);
      return;
    }

    await ref.read(settingsNotifierProvider.notifier).updateDailyLimit(newLimit);
    ref.invalidate(todayRecordProvider);
    ref.invalidate(homeWeeklySummaryProvider);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Daily limit updated to $newLimit')),
      );
    }
  }

  Future<void> _updateUnitAmount() async {
    final val = double.tryParse(_unitAmountController.text.trim());
    if (val == null || val <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid positive unit amount'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    await ref.read(settingsNotifierProvider.notifier).updateUnitAmount(val);
    _unitAmountController.clear();
    ref.invalidate(todayRecordProvider);
    ref.invalidate(homeWeeklySummaryProvider);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unit amount updated to $val')),
      );
    }
  }

  Future<void> _confirmResetToday() async {
    final theme = context.appTheme;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Reset Today?', style: TextStyle(color: theme.text, fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to reset today\'s count to 0?', style: TextStyle(color: theme.secondaryText)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancel', style: TextStyle(color: theme.secondaryText))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Reset', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold))),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final todayStr = AppDateUtils.getTodayDateString();
      final counterService = ref.read(counterServiceProvider);
      await counterService.resetDay(todayStr);
      ref.invalidate(todayRecordProvider);
      ref.invalidate(homeWeeklySummaryProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Today has been reset')),
        );
      }
    }
  }

  Future<void> _confirmResetWeek() async {
    final theme = context.appTheme;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Reset Current Week?', style: TextStyle(color: theme.text, fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to reset all counts and amounts for the current week to 0?', style: TextStyle(color: theme.secondaryText)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancel', style: TextStyle(color: theme.secondaryText))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Reset Week', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold))),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final settings = ref.read(settingsNotifierProvider).value;
      final weekStart = settings?.weekStart ?? 'monday';
      final weekDates = AppDateUtils.getWeekDates(DateTime.now(), weekStart);
      final counterService = ref.read(counterServiceProvider);
      await counterService.resetWeek(weekDates);
      ref.invalidate(todayRecordProvider);
      ref.invalidate(homeWeeklySummaryProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Current week has been reset')),
        );
      }
    }
  }

  Future<void> _confirmResetAllData() async {
    final theme = context.appTheme;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Reset All Data?', style: TextStyle(color: theme.text, fontWeight: FontWeight.bold)),
        content: Text(
          'This will permanently delete all daily counts and history records. Your preferences and themes will be preserved.',
          style: TextStyle(color: theme.secondaryText),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancel', style: TextStyle(color: theme.secondaryText))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete Everything', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold))),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final counterService = ref.read(counterServiceProvider);
      await counterService.resetAllData();
      ref.invalidate(todayRecordProvider);
      ref.invalidate(homeWeeklySummaryProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All data has been reset')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.appTheme;
    final settingsAsync = ref.watch(settingsNotifierProvider);
    final settings = settingsAsync.value;

    final unitAmount = settings?.unitAmount ?? 45.0;
    final dailyLimit = settings?.dailyLimit ?? 2;
    final weekStart = settings?.weekStart ?? 'monday';
    final currencySymbol = settings?.currencySymbol ?? '₹';
    final selectedThemeId = theme.id;

    const limitPresets = [1, 2, 3, 4, 5, 10];
    const currencyPresets = ['₹', '\$', '€', '£', '¥'];

    return Scaffold(
      backgroundColor: theme.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Text(
                'PREFERENCES',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: theme.accent,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Settings',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: theme.text,
                ),
              ),
              const SizedBox(height: 24),

              // SECTION A: COUNTER SETTINGS
              _buildSectionHeader('COUNTER SETTINGS'),
              const SizedBox(height: 12),
              NeumorphicContainer(
                borderRadius: 24,
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Unit Amount
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Unit Amount',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: theme.text),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Current: ${CurrencyUtils.formatCurrency(unitAmount, currencySymbol)}',
                              style: TextStyle(fontSize: 13, color: theme.secondaryText),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: NeumorphicInput(
                            controller: _unitAmountController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            prefixText: '$currencySymbol ',
                            hintText: 'New amount (e.g. 50)',
                          ),
                        ),
                        const SizedBox(width: 12),
                        NeumorphicButton(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          onTap: _updateUnitAmount,
                          child: const Text('Update'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Divider(color: theme.secondaryText.withValues(alpha: 0.15)),
                    const SizedBox(height: 16),

                    // Daily Maximum
                    Text(
                      'Daily Maximum Limit',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: theme.text),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Maximum allowed increments per day (current: $dailyLimit)',
                      style: TextStyle(fontSize: 13, color: theme.secondaryText),
                    ),
                    const SizedBox(height: 14),
                    // Limit Presets Row
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: limitPresets.map((limit) {
                        final isSelected = limit == dailyLimit;
                        return NeumorphicButton(
                          width: 48,
                          height: 44,
                          padding: EdgeInsets.zero,
                          color: isSelected ? theme.accent : null,
                          isProminent: isSelected,
                          onTap: () => _trySetDailyLimit(limit),
                          child: Text(
                            '$limit',
                            style: TextStyle(
                              color: isSelected ? Colors.white : theme.text,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 14),
                    // Custom Limit Input
                    Row(
                      children: [
                        Expanded(
                          child: NeumorphicInput(
                            controller: _customLimitController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            hintText: 'Custom limit',
                          ),
                        ),
                        const SizedBox(width: 12),
                        NeumorphicButton(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          onTap: () {
                            final val = int.tryParse(_customLimitController.text.trim());
                            if (val != null && val > 0) {
                              _trySetDailyLimit(val);
                              _customLimitController.clear();
                            }
                          },
                          child: const Text('Set'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Divider(color: theme.secondaryText.withValues(alpha: 0.15)),
                    const SizedBox(height: 16),

                    // Week Starts On
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Week Starts On',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: theme.text),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              weekStart == 'monday' ? 'Monday - Sunday' : 'Sunday - Saturday',
                              style: TextStyle(fontSize: 13, color: theme.secondaryText),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            NeumorphicButton(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              isProminent: weekStart == 'monday',
                              onTap: () async {
                                await ref.read(settingsNotifierProvider.notifier).updateWeekStart('monday');
                                ref.invalidate(homeWeeklySummaryProvider);
                              },
                              child: const Text('Mon'),
                            ),
                            const SizedBox(width: 8),
                            NeumorphicButton(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              isProminent: weekStart == 'sunday',
                              onTap: () async {
                                await ref.read(settingsNotifierProvider.notifier).updateWeekStart('sunday');
                                ref.invalidate(homeWeeklySummaryProvider);
                              },
                              child: const Text('Sun'),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Divider(color: theme.secondaryText.withValues(alpha: 0.15)),
                    const SizedBox(height: 16),

                    // Currency Symbol
                    Text(
                      'Currency Symbol',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: theme.text),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: currencyPresets.map((sym) {
                        final isSelected = sym == currencySymbol;
                        return NeumorphicButton(
                          width: 44,
                          height: 40,
                          padding: EdgeInsets.zero,
                          isProminent: isSelected,
                          onTap: () => ref.read(settingsNotifierProvider.notifier).updateCurrencySymbol(sym),
                          child: Text(
                            sym,
                            style: TextStyle(
                              color: isSelected ? Colors.white : theme.text,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // SECTION B: THEME CUSTOMIZATION
              _buildSectionHeader('THEME PRESETS (6 THEMES)'),
              const SizedBox(height: 12),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: ThemePresets.allThemes.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                  childAspectRatio: 0.95,
                ),
                itemBuilder: (context, index) {
                  final palette = ThemePresets.allThemes[index];
                  final isSelected = palette.id == selectedThemeId;

                  return NeumorphicThemeCard(
                    palette: palette,
                    isSelected: isSelected,
                    onTap: () {
                      ref.read(themeProvider.notifier).setTheme(palette.id);
                    },
                  );
                },
              ),
              const SizedBox(height: 28),

              // SECTION C: DATA MANAGEMENT
              _buildSectionHeader('DATA MANAGEMENT'),
              const SizedBox(height: 12),
              NeumorphicContainer(
                borderRadius: 24,
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    _buildDestructiveActionRow(
                      title: 'Reset Today',
                      subtitle: 'Reset today\'s count to zero',
                      buttonLabel: 'Reset',
                      onPressed: _confirmResetToday,
                    ),
                    Divider(color: theme.secondaryText.withValues(alpha: 0.15)),
                    _buildDestructiveActionRow(
                      title: 'Reset Current Week',
                      subtitle: 'Clear all records in the active week',
                      buttonLabel: 'Reset',
                      onPressed: _confirmResetWeek,
                    ),
                    Divider(color: theme.secondaryText.withValues(alpha: 0.15)),
                    _buildDestructiveActionRow(
                      title: 'Reset All Data',
                      subtitle: 'Delete all records (settings preserved)',
                      buttonLabel: 'Delete All',
                      isHighRisk: true,
                      onPressed: _confirmResetAllData,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // SECTION D: ABOUT & PRIVACY
              _buildSectionHeader('ABOUT & PRIVACY'),
              const SizedBox(height: 12),
              NeumorphicContainer(
                borderRadius: 24,
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: theme.accent.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(Icons.shield_outlined, color: theme.accent, size: 22),
                        ),
                        const SizedBox(width: 14),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${AppConstants.appName} v${AppConstants.appVersion}',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: theme.text,
                              ),
                            ),
                            Text(
                              'Offline SQLite • No Cloud Tracking',
                              style: TextStyle(
                                fontSize: 12,
                                color: theme.secondaryText,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'All your daily counts, amount calculations, and preferences are stored exclusively on your device in a shared local SQLite database. No internet permission, accounts, or analytics SDKs are used.',
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.4,
                        color: theme.secondaryText,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    final theme = context.appTheme;
    return Text(
      title,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.2,
        color: theme.secondaryText,
      ),
    );
  }

  Widget _buildDestructiveActionRow({
    required String title,
    required String subtitle,
    required String buttonLabel,
    required VoidCallback onPressed,
    bool isHighRisk = false,
  }) {
    final theme = context.appTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: isHighRisk ? Colors.redAccent : theme.text,
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
          ),
          NeumorphicButton(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            onTap: onPressed,
            child: Text(
              buttonLabel,
              style: TextStyle(
                color: isHighRisk ? Colors.redAccent : theme.text,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
